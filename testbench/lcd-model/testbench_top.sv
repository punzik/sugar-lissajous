`timescale 1ns/100ps
`default_nettype none

/* verilator lint_off PINMISSING */

module testbench_top
  (input wire clock,
   input wire reset,

   output int x,
   output int y,
   output [7:0] r,
   output [7:0] g,
   output [7:0] b,
   output strobe);

    logic csn, mosi, clk, dcn;

    sugar_lissajous DUT
      (.CLK12(clock),
       .P1_3(1'b0),
       .P1_10(1'b1),
       .P2_3(dcn),
       .P2_9(clk),
       .P2_11(mosi),
       .P2_12(csn));

    lcd_ili9341_4spi LCD
      (.clock, .reset,
       .csn_i(csn),
       .clk_i(clk),
       .sdi_i(mosi),
       .dcn_i(dcn),
       .x_o(x),
       .y_o(y),
       .r_o(r),
       .g_o(g),
       .b_o(b),
       .strobe_o(strobe));

endmodule // testbench_top
