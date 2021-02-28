`timescale 1ns/100ps
`default_nettype none
`include "assert.vh"

module fig_drawer #(parameter FIG_W = 8,
                    parameter FIG_H = 8,
                    parameter FIG_ROM_FILE = "fig_circle_8x8.rom")
  (input wire clock,
   input wire reset,

   input wire [7:0] x_i,
   input wire [8:0] y_i,
   input wire [7:0] h_i,
   input wire [7:0] s_i,
   input wire [7:0] v_i,
   input wire req_i,
   output reg ack_o,

   output reg [7:0] fb_x_o,
   output reg [8:0] fb_y_o,
   output reg [15:0] fb_color_o,
   output reg fb_req_o,
   input wire fb_ack_i);

    initial begin
        `assert(FIG_W > 0);
        `assert(FIG_H > 0);

        /* Check power of 2 */
        `assert(FIG_W == 1 << $clog2(FIG_W));
        `assert(FIG_H == 1 << $clog2(FIG_H));
    end

    /* Figure bitmap */
    localparam FIG_SIZE = FIG_W * FIG_H;
    localparam FIG_W_CW = $clog2(FIG_W);
    localparam FIG_H_CW = $clog2(FIG_H);
    localparam FIG_CW = $clog2(FIG_SIZE);

    logic [7:0] fig[FIG_SIZE];
    initial $readmemh(FIG_ROM_FILE, fig, 0, FIG_SIZE-1);

    logic [FIG_CW-1:0] fig_addr;
    logic [7:0] fig_data;

    always_ff @ (posedge clock)
      fig_data <= fig[fig_addr];

    /* Scale brightness */
    logic [31:0] mac_v_o;
    logic [7:0] fig_v;

    assign fig_v = mac_v_o[15:8];

    ice40_mac16x16 mac_v
      (.clock, .reset,
       .a({8'b0, fig_data}),
       .b({8'b0, v_i}),
       .s(32'b0),
       .sub(1'b0),
       .y(mac_v_o));

    /* Convert HSV ro RGB */
    logic hsv_ready;
    logic rgb_valid;
    logic [7:0] r, g, b;

    hsv2rgb hsv2rgb_i
      (.clock, .reset,
       .h(h_i), .s(s_i), .v(fig_v),
       .ready_i(hsv_ready),
       .r(r), .g(g), .b(b),
       .valid_o(rgb_valid));

    /* FSM states */
    enum int unsigned {
        ST_IDLE = 0,            // 0
        ST_READ_PIX,            // 1
        ST_MULT_V,              // 2
        ST_HSV_READY,           // 3
        ST_RGB_WAIT,            // 4
        ST_WAIT_FB,             // 5
        ST_NEXT_PIXEL,          // 6
        ST_DONE                 // 7
    } state, next;

    /* FSM sync part */
    always_ff @(posedge clock, posedge reset)
      if (reset) state <= ST_IDLE;
      else       state <= next;

    /* Pixel coordinate */
    logic [FIG_W_CW-1:0] pix_x;
    logic [FIG_H_CW-1:0] pix_y;
    logic pix_reset, pix_next;

    assign fig_addr = {pix_y, pix_x};

    always_ff @(posedge clock)
      if (pix_reset) begin
          pix_x <= '0;
          pix_y <= '0;
      end
      else
        if (pix_next)
          if (pix_x == FIG_H_CW'(FIG_H-1)) begin
              pix_x <= '0;

              if (pix_y == FIG_W_CW'(FIG_W-1))
                pix_y <= '0;
              else
                pix_y <= pix_y + 1'b1;
          end
          else
            pix_x <= pix_x + 1'b1;

    /* Frame buffer control */
    logic [7:0] fb_x;
    logic [8:0] fb_y;
    logic [15:0] fb_color;
    logic fb_hold, fb_restore;
    logic fb_req;

    always_ff @ (posedge clock, posedge reset)
      if (reset)
        fb_req_o <= 1'b0;
      else
        if (fb_req)
          fb_req_o <= 1'b1;
        else
          if (fb_ack_i)
            fb_req_o <= 1'b0;

    assign fb_x = x_i + 8'(pix_x);
    assign fb_y = y_i + 9'(pix_y);

    always_ff @ (posedge clock) begin
        if (rgb_valid) begin
            fb_color <= {r[7:3], g[7:2], b[7:3]};

            if (~fb_hold)
              fb_color_o <= {r[7:3], g[7:2], b[7:3]};
        end

        if (fb_restore)
          fb_color_o <= fb_color;
    end

    always_ff @ (posedge clock)
      if (fb_req) begin
          fb_x_o <= fb_x;
          fb_y_o <= fb_y;
      end

    /* FSM comb part */
    always_comb begin
        next       = state;
        pix_reset  = 1'b0;
        pix_next   = 1'b0;
        fb_req     = 1'b0;
        fb_hold    = 1'b0;
        fb_restore = 1'b0;
        ack_o      = 1'b0;
        hsv_ready  = 1'b0;

        case (state)
          ST_IDLE:
            if (req_i) begin
                pix_reset = 1'b1;
                next = ST_READ_PIX;
            end

          ST_READ_PIX:
            next = ST_MULT_V;

          ST_MULT_V:
            if (fig_data == '0) begin
                pix_next = 1'b1;
                next = ST_NEXT_PIXEL;
            end
            else
              next = ST_HSV_READY;

          ST_HSV_READY: begin
              hsv_ready = 1'b1;
              next = ST_RGB_WAIT;
          end

          ST_RGB_WAIT:
            if (rgb_valid) begin
                if (fb_req_o && !fb_ack_i) begin
                    fb_hold = 1'b1;
                    next    = ST_WAIT_FB;
                end
                else begin
                    fb_req   = 1'b1;
                    pix_next = 1'b1;
                    next     = ST_NEXT_PIXEL;
                end
            end

          ST_WAIT_FB:
            if (fb_ack_i) begin
                fb_restore = 1'b1;
                fb_req     = 1'b1;
                pix_next   = 1'b1;
                next       = ST_NEXT_PIXEL;
            end

          ST_NEXT_PIXEL:
            if (pix_x == '0 && pix_y == '0)
              next = ST_DONE;
            else
              next = ST_MULT_V;

          ST_DONE: begin
              ack_o = 1'b1;
              next = ST_IDLE;
          end
        endcase
    end

endmodule // fig_drawer
