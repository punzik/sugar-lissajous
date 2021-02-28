`timescale 1ns/100ps
`default_nettype none

module circle_1024
  (input wire clock,
   input wire reset,

   input wire [9:0] angle,
   input wire [7:0] r,
   input wire [7:0] x0,
   input wire [7:0] y0,

   output wire [7:0] x,
   output wire [7:0] y,

   input wire req_i,
   output reg ack_o);

    localparam QUADR_LEN = 256;
    localparam QUADR_ROM_FILE = "quadrant_256.rom";
    localparam QUADR_CW = $clog2(QUADR_LEN);
    logic [15:0] q_rom[QUADR_LEN];
    initial $readmemh(QUADR_ROM_FILE, q_rom, 0, QUADR_LEN-1);

    logic [QUADR_CW-1:0] q_addr;
    logic [7:0] kx, ky;

    always_ff @ (posedge clock)
      {kx, ky} <= q_rom[q_addr];

    logic [15:0] macx_o, macy_o;
    logic xsub, ysub;

    ice40_2mac8x8 circle_mac
      (.clock, .reset,
       .a0(r),
       .b0(kx),
       .s0({x0, 8'b0}),
       .sub0(xsub),
       .y0(macx_o),

       .a1(r),
       .b1(ky),
       .s1({y0, 8'b0}),
       .sub1(ysub),
       .y1(macy_o));

    assign q_addr = angle[8] ? 8'd255 - angle[7:0] : angle[7:0];
    assign xsub = angle[9];
    assign ysub = angle[8] == angle[9] ? 1'b0 : 1'b1;
    assign x = macx_o[15:8];
    assign y = macy_o[15:8];

    enum int unsigned {
        ST_IDLE = 0,
        ST_GET_K,
        ST_MAC
    } state;

    always_ff @(posedge clock, posedge reset)
      if (reset) begin
          state <= ST_IDLE;
          ack_o <= 1'b0;
      end
      else
        case (state)
          ST_IDLE:
            if (req_i)
              state <= ST_GET_K;

          ST_GET_K: begin
              ack_o <= 1'b1;
              state <= ST_MAC;
          end

          ST_MAC: begin
              ack_o <= 1'b0;
              state <= ST_IDLE;
          end
        endcase

endmodule // circle
