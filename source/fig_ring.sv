`timescale 1ns/100ps
`default_nettype none
`include "assert.vh"

module fig_ring #(parameter POINT_COUNT = 32,
                  parameter FADING = 1)
  (input wire clock,
   input wire reset,

   input wire [7:0] pt_x,
   input wire [7:0] pt_y,
   input wire [7:0] pt_h,
   input wire pt_req_i,
   output reg pt_ack_o,

   output reg [7:0] fig_x_o,
   output reg [8:0] fig_y_o,
   output reg [7:0] fig_h_o,
   output reg [7:0] fig_s_o,
   output reg [7:0] fig_v_o,
   output reg fig_req_o,
   input wire fig_ack_i);

    initial begin
        `assert(POINT_COUNT > 0);
        `assert(POINT_COUNT == (1 << $clog2(POINT_COUNT)));
    end

    /* Points coordinate RAM */
    localparam POINT_CW = $clog2(POINT_COUNT);
    localparam [7:0] V_INC = FADING == 0 ? 8'd255 : 8'('h100 / POINT_COUNT);

    logic [23:0] pt_ram[POINT_COUNT];
    logic [POINT_CW-1:0] pt_raddr;
    logic [POINT_CW-1:0] pt_waddr;
    logic pt_wr;

    logic [7:0] pt_xw, pt_xr;
    logic [7:0] pt_yw, pt_yr;
    logic [7:0] pt_hw, pt_hr;

    always_ff @ (posedge clock) begin
        if (pt_wr)
          pt_ram[pt_waddr] <= {pt_hw, pt_xw, pt_yw};

        {pt_hr, pt_xr, pt_yr} <= pt_ram[pt_raddr];
    end

`ifdef TESTBENCH
    integer i;
    initial
      for (i = 0; i < POINT_COUNT; i ++)
        pt_ram[i] = {8'(i*5), 8'(i*5 + 20), 8'(i*5 + 30)};
`endif

    /* FSM */
    enum int unsigned {
        ST_IDLE = 0,            // 0
        ST_READ_LAST_PT,        // 1
        ST_STORE_LAST_PT,       // 2
        ST_WRITE_NEW_PT,        // 3
        ST_DRAW_LAST,           // 4
        ST_FIG_DRAW,            // 5
        ST_NEXT_PT,             // 6
        ST_READ_PT,             // 7
        ST_STORE_PT,            // 8
        ST_ACK                  // 9
    } state;

    logic [POINT_CW-1:0] pt_last;

    assign pt_xw = pt_x;
    assign pt_yw = pt_y;
    assign pt_hw = pt_h;

    always_ff @ (posedge clock, posedge reset)
      if (reset) begin
          state     <= ST_IDLE;
          pt_wr     <= 1'b0;
          pt_last   <= '0;
          pt_ack_o  <= 1'b0;
          fig_req_o <= 1'b0;
      end
      else
        case (state)
          ST_IDLE: begin
              if (pt_req_i) begin
                  pt_raddr <= pt_last;
                  pt_waddr <= pt_last;
                  pt_wr    <= 1'b0;
                  fig_v_o  <= '0;
                  state    <= ST_READ_LAST_PT;
              end
          end

          ST_READ_LAST_PT:
            state <= ST_STORE_LAST_PT;

          ST_STORE_LAST_PT: begin
              fig_x_o <= pt_xr;
              fig_y_o <= {1'b0, pt_yr};
              fig_h_o <= pt_hr;
              fig_s_o <= 8'hff; // TODO: add saturation to ring mem
              pt_wr <= 1'b1;
              state <= ST_WRITE_NEW_PT;
          end

          ST_WRITE_NEW_PT: begin
              pt_wr     <= 1'b0;
              fig_req_o <= 1'b1;
              pt_raddr  <= pt_last + 1'b1;
              state     <= ST_DRAW_LAST;
          end

          ST_DRAW_LAST:
            if (fig_ack_i) begin
                fig_req_o <= 1'b0;
                state <= ST_READ_PT;
            end

          ST_FIG_DRAW: begin
              fig_req_o <= 1'b1;
              state <= ST_NEXT_PT;
          end

          ST_NEXT_PT:
            if (fig_ack_i) begin
                fig_req_o <= 1'b0;

                if (pt_raddr == pt_last) begin
                    pt_last  <= pt_last + 1'b1;
                    pt_ack_o <= 1'b1;
                    state    <= ST_ACK;
                end
                else begin
                    if (pt_raddr == POINT_CW'(POINT_COUNT-1))
                      pt_raddr <= '0;
                    else
                      pt_raddr <= pt_raddr + 1'b1;

                    state    <= ST_READ_PT;
                end
            end

          ST_READ_PT:
            state <= ST_STORE_PT;

          ST_STORE_PT: begin
              fig_x_o <= pt_xr;
              fig_y_o <= {1'b0, pt_yr};
              fig_h_o <= pt_hr;
              fig_s_o <= 8'hff; // TODO: add saturation to ring mem

              if (fig_v_o > (255-V_INC))
                fig_v_o <= 8'hff;
              else
                fig_v_o  <= fig_v_o + V_INC;

              state    <= ST_FIG_DRAW;
          end

          ST_ACK: begin
              pt_ack_o <= 1'b0;
              state    <= ST_IDLE;
          end
        endcase

endmodule // fig_ring
