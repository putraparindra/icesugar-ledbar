// Program kosong: semua LED padam (modul LED bar dan RGB aktif-rendah -> pin dibuat HIGH).
module blank(input wire clk, output wire [7:0] led_bar, output wire led_r, led_g, led_b);
    assign led_bar = 8'hFF;
    assign led_r = 1'b1;
    assign led_g = 1'b1;
    assign led_b = 1'b1;
endmodule
