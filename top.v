// ============================================================================
//  LED Bar 8-bit "Marquee" untuk iCESugar v1.5 (iCE40UP5K, clock 12 MHz)
//
//  Delapan pola animasi berganti otomatis (default tiap 8 detik):
//    0  Selang-seling  : 10101010 <-> 01010101
//    1  Berjalan       : satu LED berjalan S0 -> S7, ulang terus
//    2  Ping-pong      : satu LED bolak-balik S0 <-> S7 (Knight Rider)
//    3  Isi & kosongkan: LED menyala berurutan sampai penuh, lalu padam berurutan
//    4  Tengah-keluar  : melebar dari tengah sampai penuh, lalu menyempit
//    5  Counter biner  : menghitung 0..255 dalam biner
//    6  Menyatu        : dua LED dari ujung kiri-kanan bertemu di tengah, lalu menjauh
//    7  Acak (LFSR)    : kedip acak semu
//
//  LED RGB onboard menampilkan nomor pola (mode[0]=R, mode[1]=G, mode[2]=B).
//  Mode 0 = RGB padam.
//
// ============================================================================
`default_nettype none

module top #(
    parameter integer CLK_HZ     = 12_000_000, // clock onboard iCESugar
    parameter integer STEP_HZ    = 8,          // langkah animasi per detik
    parameter integer MODE_STEPS = 64,         // langkah per pola (64 @ 8 Hz = 8 detik)
    parameter         ACTIVE_LOW = 1'b1        // 1: LED nyala saat pin = 0
)(
    input  wire       clk,
    output wire [7:0] led_bar,   // S0..S7 pada modul LED bar
    output wire       led_r,     // RGB onboard (active-low)
    output wire       led_g,
    output wire       led_b
);

    // ------------------------------------------------------------------
    // Pembangkit tick (satu pulsa per langkah animasi)
    // ------------------------------------------------------------------
    localparam integer STEP_CYCLES = CLK_HZ / STEP_HZ;

    reg [23:0] div  = 24'd0;
    reg        tick = 1'b0;

    always @(posedge clk) begin
        if (div == STEP_CYCLES - 1) begin
            div  <= 24'd0;
            tick <= 1'b1;
        end else begin
            div  <= div + 24'd1;
            tick <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // State animasi
    // ------------------------------------------------------------------
    reg [7:0] step     = 8'd0;   // counter langkah (free-running)
    reg [7:0] mode_cnt = 8'd0;   // hitung langkah dalam satu pola
    reg [2:0] mode     = 3'd0;   // pola aktif 0..7
    reg [3:0] pp       = 4'd0;   // posisi ping-pong 0..13
    reg [7:0] lfsr     = 8'hA5;  // pembangkit acak semu (tidak boleh 0)

    always @(posedge clk) begin
        if (tick) begin
            step <= step + 8'd1;

            if (mode_cnt == MODE_STEPS - 1) begin
                mode_cnt <= 8'd0;
                mode     <= mode + 3'd1;
            end else begin
                mode_cnt <= mode_cnt + 8'd1;
            end

            pp   <= (pp == 4'd13) ? 4'd0 : pp + 4'd1;
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    end

    // Posisi ping-pong: 0,1,..,7,6,5,..,1 lalu ulang
    wire [3:0] pp_rev = 4'd14 - pp;
    wire [2:0] pp_pos = (pp < 4'd8) ? pp[2:0] : pp_rev[2:0];

    // ------------------------------------------------------------------
    // Pola (bit 0 = S0 = D0, di sisi kiri modul)
    // ------------------------------------------------------------------
    reg [7:0] pattern;

    always @* begin
        case (mode)
            3'd0: pattern = step[1] ? 8'b1010_1010 : 8'b0101_0101;

            3'd1: pattern = 8'b0000_0001 << step[2:0];

            3'd2: pattern = 8'b0000_0001 << pp_pos;

            3'd3: pattern = step[3] ?  (8'hFF << (step[2:0] + 1))
                                    : ~(8'hFF << (step[2:0] + 1));

            3'd4: case (step[2:0])
                      3'd0:    pattern = 8'b0001_1000;
                      3'd1:    pattern = 8'b0011_1100;
                      3'd2:    pattern = 8'b0111_1110;
                      3'd3:    pattern = 8'b1111_1111;
                      3'd4:    pattern = 8'b0111_1110;
                      3'd5:    pattern = 8'b0011_1100;
                      3'd6:    pattern = 8'b0001_1000;
                      default: pattern = 8'b0000_0000;
                  endcase

            3'd5: pattern = step;

            3'd6: pattern = (8'b0000_0001 << step[2:0]) | (8'b1000_0000 >> step[2:0]);

            default: pattern = lfsr;
        endcase
    end

    reg [7:0] pattern_r = 8'd0;
    always @(posedge clk) pattern_r <= pattern;

    assign led_bar = ACTIVE_LOW ? ~pattern_r : pattern_r;

    // RGB onboard active-low
    assign led_r = ~mode[0];
    assign led_g = ~mode[1];
    assign led_b = ~mode[2];

endmodule
