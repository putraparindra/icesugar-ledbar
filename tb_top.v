`timescale 1ns/1ps
// Testbench: waktu dipercepat (1 langkah = 4 clock, 1 pola = 16 langkah)
// ACTIVE_LOW = 0 supaya pola terbaca langsung (1 = LED nyala).
module tb_top;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    wire [7:0] led_bar;
    wire       led_r, led_g, led_b;

    top #(
        .CLK_HZ(40),
        .STEP_HZ(10),
        .MODE_STEPS(16),
        .ACTIVE_LOW(1'b0)
    ) dut (
        .clk(clk),
        .led_bar(led_bar),
        .led_r(led_r), .led_g(led_g), .led_b(led_b)
    );

    // Cetak satu baris setiap langkah animasi (S7..S0 dari kiri ke kanan)
    always @(posedge clk) begin
        if (dut.tick)
            $display("mode=%0d step=%3d  S7..S0=%b  (RGB nyala: R=%b G=%b B=%b)",
                     dut.mode, dut.step, led_bar, ~led_r, ~led_g, ~led_b);
    end

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_top);
        #(10 * 4 * 16 * 9);   // sedikit lebih dari 8 pola
        $finish;
    end
endmodule
