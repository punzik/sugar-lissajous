`timescale 1ns/100ps
`default_nettype none

/**
 * HSL to RGB translation.
 *
 * H, S, L = [0..1)
 *
 * Q = | L  < 0.5 ? L + L*S
 *     | L >= 0.5 ? L + S - L*S
 *
 * P = 2 * L - Q
 *
 * TR = H < 2/3 ? H + 1/3 : 1/3 - (1 - H)
 * TG = H
 * TB = H >= 1/3 ? H - 1/3 : 1 - H
 *
 * COLORX = |        TX < 1/6 ? P + ((Q - P) * 6 * TX)
 *          | 1/6 <= TX < 1/2 ? Q
 *          | 1/2 <= TX < 2/3 ? P + ((Q - P) * (2/3 - TX) * 6)
 *          |            else : P
 */

/*
 * Datapath:
 *
 * if l < [1/2]
 *   then: lls = l + (l * s)
 *   else: lls = l - (l * s)
 *
 * m1h = ~(h - 1)
 *
 * tr =
 *   if h < [2/3]
 *     then: h + [1/3]
 *     else: [1/3] - m1h
 *
 * tg = h
 *
 * tb =
 *   if h >= [1/3]
 *     then: h - [1/3]
 *     else: m1h
 *
 * q =
 *   if l < [1/2]
 *     then: lls
 *     else: lls + s
 *
 * p = l * 2 - q
 * qp = (q - l) * 2
 *
 * r =
 *   p + 6 * qp * tr
 *   p + 6 * qp * ([2/3] - tr)
 *
 * g =
 *   p + 6 * qp * tg
 *   p + 6 * qp * ([2/3] - tg)
 *
 * b =
 *   p + 6 * qp * tb
 *   p + 6 * qp * ([2/3] - tb)
 */

module hsl2rgb
  (input wire clock,
   input wire reset,

   input wire [7:0] h,
   input wire [7:0] s,
   input wire [7:0] l,
   input wire ready_i,

   output reg [7:0] r,
   output reg [7:0] g,
   output reg [7:0] b,
   output wire valid_o);

`define C1_6 43
`define C1_3 85
`define C1_2 128
`define C2_3 171
`define C1_1 256

    localparam STAGES = 5;
    logic [STAGES-1:0] valid;

    assign valid_o = valid[STAGES-1];

    always_ff @ (posedge clock, posedge reset)
      if (reset)
        valid <= '0;
      else
        valid <= { valid[STAGES-2:0], ready_i };

    /* ---------------- Stage 1 ---------------- */
    logic [8:0] lls;            // lls = l0 ± (l0 * s0)
    logic ls_sub;

    /* verilator lint_off UNUSED */
    logic [31:0] mac_lls_o;
    /* verilator lint_on UNUSED */

    assign lls = {mac_lls_o[16:8]};
    assign ls_sub = l < `C1_2 ? 1'b0 : 1'b1;

    ice40_mac16x16 mac_lls
      (.clock, .reset,
       .a({8'b0, l}),
       .b({8'b0, s}),
       .s({16'b0, l, 8'b0}),
       .sub(ls_sub),
       .y(mac_lls_o));

    /* propagate to next stage */
    logic [7:0] h1, s1, l1;
    always_ff @ (posedge clock) begin
        h1 <= h;
        s1 <= s;
        l1 <= l;
    end

    /* ---------------- stage 2 ---------------- */
    logic [8:0] q_pre;
    logic [7:0] q;
    logic [7:0] minus1h;            // minus1h = 256 - h = ~(h - 1)

    always_ff @ (posedge clock) begin
        q_pre <= l1 < `C1_2 ? lls : lls + s1;
        minus1h <= ~(h1 - 1);
    end

    assign q = q_pre[8] ? 8'hff : q_pre[7:0];

    /* propagate to next stage */
    logic [7:0] h2, l2;
    always_ff @ (posedge clock) begin
        h2 <= h1;
        l2 <= l1;
    end

    /* ---------------- stage 3 ---------------- */
    logic [7:0] tr, tg, tb;
    logic [8:0] p_pre;
    logic [7:0] p;              // p = l * 2 - q
    logic [7:0] qp;             // qp = q - p

    always_ff @ (posedge clock) begin
        tr <= h2 < 8'(`C2_3) ? h2 + 8'(`C1_3) : 8'(`C1_3) - minus1h;
        tg <= h2;
        tb <= h2 >= 8'(`C1_3) ? h2 - 8'(`C1_3) : minus1h;

        p_pre <= (9'(l2) << 1) - q;
        qp <= 8'((q - l2) << 1);
    end

    assign p = p_pre[8] ? 8'hff : p_pre[7:0];

    /* propagate to next stage */
    logic [7:0] q3;
    always_ff @ (posedge clock)
      q3 <= q;

    /* ---------------- stage 4 ---------------- */
    logic [7:0] trx, tgx, tbx;
    logic [10:0] qp6;

    /* verilator lint_off UNUSED */
    logic [31:0] mac_r_o;
    logic [31:0] mac_g_o;
    logic [31:0] mac_b_o;
    /* verilator lint_on UNUSED */

    assign qp6 = (11'(qp) << 1) + (11'(qp) << 2);
    assign trx = (tr < `C1_6) ? tr : `C2_3 - tr;
    assign tgx = (tg < `C1_6) ? tg : `C2_3 - tg;
    assign tbx = (tb < `C1_6) ? tb : `C2_3 - tb;

    ice40_mac16x16 mac_r
      (.clock, .reset,
       .a({5'b0, qp6}),
       .b({8'b0, trx}),
       .s({16'b0, p, 8'b0}),
       .sub(1'b0),
       .y(mac_r_o));

    ice40_mac16x16 mac_g
      (.clock, .reset,
       .a({5'b0, qp6}),
       .b({8'b0, tgx}),
       .s({16'b0, p, 8'b0}),
       .sub(1'b0),
       .y(mac_g_o));

    ice40_mac16x16 mac_b
      (.clock, .reset,
       .a({5'b0, qp6}),
       .b({8'b0, tbx}),
       .s({16'b0, p, 8'b0}),
       .sub(1'b0),
       .y(mac_b_o));

    /* propagate to next stage */
    logic [7:0] tr4, tg4, tb4;
    logic [7:0] p4;
    logic [7:0] q4;

    always_ff @ (posedge clock) begin
        tr4 <= tr;
        tg4 <= tg;
        tb4 <= tb;
        p4 <= p;
        q4 <= q3;
    end

    /* ---------------- stage 5 ---------------- */
    always_ff @ (posedge clock) begin
        if (tr4 < `C1_6)      r <= mac_r_o[16] ? 8'hff : mac_r_o[15:8];
        else if (tr4 < `C1_2) r <= q4;
        else if (tr4 < `C2_3) r <= mac_r_o[16] ? 8'hff : mac_r_o[15:8];
        else                  r <= p4;
    end

    always_ff @ (posedge clock) begin
        if (tg4 < `C1_6)      g <= mac_g_o[16] ? 8'hff : mac_g_o[15:8];
        else if (tg4 < `C1_2) g <= q4;
        else if (tg4 < `C2_3) g <= mac_g_o[16] ? 8'hff : mac_g_o[15:8];
        else                  g <= p4;
    end

    always_ff @ (posedge clock) begin
        if (tb4 < `C1_6)      b <= mac_b_o[16] ? 8'hff : mac_b_o[15:8];
        else if (tb4 < `C1_2) b <= q4;
        else if (tb4 < `C2_3) b <= mac_b_o[16] ? 8'hff : mac_b_o[15:8];
        else                  b <= p4;
    end

endmodule // hsl2rgb
