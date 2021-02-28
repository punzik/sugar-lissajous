`timescale 1ns/100ps

module tb_fig_ring;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 100MHz (10ns period) */
    always #(10ns/2) clock <= ~clock;

    logic pt_ack_o;
    logic [7:0] fig_x_o;
    logic [8:0] fig_y_o;
    logic [7:0] fig_h_o;
    logic [7:0] fig_s_o;
    logic [7:0] fig_v_o;
    logic fig_req_o;
    logic [7:0] pt_x;
    logic [7:0] pt_y;
    logic [7:0] pt_h;
    logic pt_req_i;
    logic fig_ack_i;

    fig_ring DUT (/*AUTOINST*/
                  // Outputs
                  .pt_ack_o             (pt_ack_o),
                  .fig_x_o              (fig_x_o[7:0]),
                  .fig_y_o              (fig_y_o[8:0]),
                  .fig_h_o              (fig_h_o[7:0]),
                  .fig_s_o              (fig_s_o[7:0]),
                  .fig_v_o              (fig_v_o[7:0]),
                  .fig_req_o            (fig_req_o),
                  // Inputs
                  .clock                (clock),
                  .reset                (reset),
                  .pt_x                 (pt_x[7:0]),
                  .pt_y                 (pt_y[7:0]),
                  .pt_h                 (pt_h[7:0]),
                  .pt_req_i             (pt_req_i),
                  .fig_ack_i            (fig_ack_i));

    assign fig_ack_i = 1'b1;

    always_ff @ (posedge clock)
      if (pt_ack_o)
        pt_req_i <= 1'b0;

    initial begin
        reset = 1'b1;
        pt_req_i = 1'b0;

        repeat(10) @(posedge clock) #1;
        reset = 1'b0;

        @(posedge clock) #1;
        pt_x = 0;
        pt_y = 0;
        pt_h = 100;
        pt_req_i = 1'b1;

        repeat(1000) @(posedge clock) #1;
        $finish;
    end

    initial begin
        $dumpfile("tb_fig_ring.vcd");
        $dumpvars;
    end

endmodule // tb_fig_ring
