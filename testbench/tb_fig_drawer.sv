`timescale 1ns/100ps

module tb_fig_drawer;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 100MHz (10ns period) */
    always #(10ns/2) clock <= ~clock;

    logic [7:0] x;
    logic [8:0] y;
    logic [7:0] h, s, v;
    logic req, ack;

    logic [7:0] fb_x;
    logic [8:0] fb_y;
    logic [15:0] fb_color;
    logic fb_req, fb_ack;

    fig_drawer DUT
      (.clock, .reset,
       .x_i(x), .y_i(y),
       .h_i(h), .s_i(s), .v_i(v),
       .req_i(req), .ack_o(ack),

       .fb_x_o(fb_x),
       .fb_y_o(fb_y),
       .fb_color_o(fb_color),
       .fb_req_o(fb_req),
       .fb_ack_i(fb_ack));

    int fb_lat_n;
    always_ff @ (posedge clock) begin
        fb_ack <= 1'b0;

        if (fb_req)
          if (fb_lat_n == 2) begin
              fb_ack <= 1'b1;
              fb_lat_n <= 0;
          end
          else fb_lat_n <= fb_lat_n + 1;
    end

    always_ff @ (posedge clock)
      if (ack)
        req <= 1'b0;

    initial begin
        reset <= 1'b1;
        repeat(10) @(posedge clock);
        reset <= 1'b0;

        @(posedge clock);
        x   <= 'd20;
        y   <= 'd50;
        h   <= 50;
        s   <= 100;
        v   <= 150;
        req <= 1'b1;

        repeat(1000) @(posedge clock);
        $finish;
    end

    initial begin
        $dumpfile("tb_fig_drawer.vcd");
        $dumpvars;
    end

endmodule // tb_fig_drawer
