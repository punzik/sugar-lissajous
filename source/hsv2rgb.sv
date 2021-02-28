`timescale 1ns/100ps
`default_nettype none

module hsv2rgb
  (input wire clock,
   input wire reset,

   input wire [7:0] h,
   input wire [7:0] s,
   input wire [7:0] v,
   input wire ready_i,

   output reg [7:0] r,
   output reg [7:0] g,
   output reg [7:0] b,
   output wire valid_o);

    localparam STAGES = 2;
    logic [STAGES-1:0] valid;

    assign valid_o = valid[STAGES-1];
    always_ff @ (posedge clock, posedge reset)
      if (reset) valid <= '0;
      else       valid <= { valid[STAGES-2:0], ready_i };

    /* ---------------- Stage 1 ---------------- */
    logic [7:0] flip_s;
    logic [7:0] vmin;
    logic [31:0] mac_vmin_o;
    logic [5:0] h_mod_43;

    assign flip_s = 8'd255 - s;
    assign vmin = mac_vmin_o[15:8];

    always_ff @ (posedge clock)
      h_mod_43
        <= (h < 43)  ? 6'(h) :
           (h < 86)  ? 6'(h - 8'd43) :
           (h < 128) ? 6'(h - 8'd86) :
           (h < 171) ? 6'(h - 8'd128) :
           (h < 214) ? 6'(h - 8'd171) :
           6'(h - 8'd214);

    ice40_mac16x16 mac_lls
      (.clock, .reset,
       .a({8'b0, flip_s}),
       .b({8'b0, v}),
       .s(32'b0),
       .sub(1'b0),
       .y(mac_vmin_o));

    logic [7:0] h1, v1;
    always_ff @ (posedge clock) begin
        h1 <= h;
        v1 <= v;
    end

    /* ---------------- Stage 2 ---------------- */
    logic [31:0] mac_a_o;
    logic [7:0] h_mod_43_6;
    logic [7:0] v_vmin;
    logic [7:0] a;

    assign a = mac_a_o[15:8];

    assign h_mod_43_6 = (8'(h_mod_43) << 1) + (8'(h_mod_43) << 2);
    assign v_vmin = v1 - vmin;

    ice40_mac16x16 mac_a
      (.clock, .reset,
       .a({8'b0, v_vmin}),
       .b({8'b0, h_mod_43_6}),
       .s(32'b0),
       .sub(1'b0),
       .y(mac_a_o));

    logic [7:0] h2, v2, vmin2;
    always_ff @ (posedge clock) begin
        h2 <= h1;
        v2 <= v1;
        vmin2 <= vmin;
    end

    /* ---------------- Output ---------------- */
    logic [7:0] vinc, vdec;

    assign vinc = vmin2 + a;
    assign vdec = v2 - a;

    always_comb
      if      (h2 < 43)  {r, g, b} = {v2, vinc, vmin2};
      else if (h2 < 86)  {r, g, b} = {vdec, v2, vmin2};
      else if (h2 < 128) {r, g, b} = {vmin2, v2, vinc};
      else if (h2 < 171) {r, g, b} = {vmin2, vdec, v2};
      else if (h2 < 214) {r, g, b} = {vinc, vmin2, v2};
      else               {r, g, b} = {v2, vmin2, vdec};

endmodule // hsv2rgb
