`timescale 1ns/100ps

module tb_circle;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 100MHz (10ns period) */
    always #(10ns/2) clock <= ~clock;

    logic [9:0] angle;
    logic [7:0] r;
    logic [7:0] x0;
    logic [7:0] y0;
    logic [7:0] x;
    logic [7:0] y;
    logic req, ack;

    circle_1024 DUT
      (.clock, .reset,
       .angle,
       .r,
       .x0,
       .y0,
       .x,
       .y,
       .req_i(req),
       .ack_o(ack));

    initial begin
        reset = 1'b1;
        req = 1'b0;
        repeat(10) @(posedge clock) #1;
        reset = 1'b0;

        @(posedge clock) #1;

        angle = '0;
        r = 120;
        x0 = 120;
        y0 = 128;

        for (int i = 0; i < 1024; i ++) begin
            @(posedge clock) #1;
            req = 1'b1;

            wait (ack);
            angle = angle + 1'b1;
        end
        req = 1'b0;

        repeat(10) @(posedge clock) #1;
        $finish;
    end

    initial begin
        $dumpfile("tb_circle.vcd");
        $dumpvars;
    end

endmodule // tb_circle
