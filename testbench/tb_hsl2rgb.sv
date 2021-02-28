`timescale 1ns/100ps

module tb_hsl2rgb;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 100MHz (10ns period) */
    always #(10ns/2) clock <= ~clock;

    logic [7:0] h, s, l;
    logic [7:0] r, g, b;
    logic valid, ready;

    hsl2rgb DUT
      (.clock, .reset,
       .h, .s, .l,
       .ready_i(ready),
       .r, .g, .b,
       .valid_o(valid));

    always_ff @ (posedge clock)
      if (valid)
        $display("%d %d %d", r, g, b);

    initial begin
        reset = 1'b1;
        ready = 1'b0;
        repeat(10) @(posedge clock) #1;
        reset = 1'b0;

        @(posedge clock) #1;
        h = 8'd128;
        s = 8'd255;
        l = 8'd130;
        ready = 1'b1;

        @(posedge clock) #1;
        ready = 1'b0;

        repeat(20) @(posedge clock);
        $finish;
    end

    initial begin
        $dumpfile("tb_hsl2rgb.vcd");
        $dumpvars;
    end

endmodule // tb_hsl2rgb
