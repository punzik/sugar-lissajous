`timescale 1ns/100ps
`default_nettype none

/* verilator lint_off PINCONNECTEMPTY */

module ice40_mac16x16 #(parameter SIGNED = 0)
  (input wire clock,
   input wire reset,
   input wire [15:0] a,
   input wire [15:0] b,
   input wire [31:0] s,
   input wire sub,
   output wire [31:0] y);

    /* register 'sub' input */
    logic sub_r;
    always_ff @ (posedge clock)
      sub_r <= sub;

    SB_MAC16
      #(.NEG_TRIGGER(1'b0),
        .C_REG(1'b1),                       // Registered C
        .A_REG(1'b1),                       // Registered A
        .B_REG(1'b1),                       // Registered B
        .D_REG(1'b1),                       // Registered D
        .TOP_8x8_MULT_REG(1'b0),
        .BOT_8x8_MULT_REG(1'b0),
        .PIPELINE_16x16_MULT_REG1(1'b0),
        .PIPELINE_16x16_MULT_REG2(1'b0),
        .TOPOUTPUT_SELECT(2'b00),           // TOP output - ADD/SUB unregistered
        .TOPADDSUB_LOWERINPUT(2'b10),       // TOP adder input 1 - 16x16 multiplier upper word
        .TOPADDSUB_UPPERINPUT(1'b1),        // TOP adder input 2 - input C
        .TOPADDSUB_CARRYSELECT(2'b00),      // TOP adder carry input - constant 0
        .BOTOUTPUT_SELECT(2'b00),           // BOT output - ADD/SUB unregistered
        .BOTADDSUB_LOWERINPUT(2'b10),       // BOT adder input 1 - 16x16 multiplier lower word
        .BOTADDSUB_UPPERINPUT(1'b1),        // BOT adder input 2 - input D
        .BOTADDSUB_CARRYSELECT(2'b00),      // BOT adder carry input - constant 0
        .MODE_8x8(1'b0),
        .A_SIGNED(SIGNED),
        .B_SIGNED(SIGNED))
    mac_r
      (.CLK(clock),
       .CE(1'b1),
       .C(s[31:16]),
       .A(a),
       .B(b),
       .D(s[15:0]),
       .AHOLD(1'b0),
       .BHOLD(1'b0),
       .CHOLD(1'b0),
       .DHOLD(1'b0),
       .IRSTTOP(reset),
       .IRSTBOT(reset),
       .ORSTTOP(reset),
       .ORSTBOT(reset),
       .OLOADTOP(1'b0),
       .OLOADBOT(1'b0),
       .ADDSUBTOP(sub_r),
       .ADDSUBBOT(sub_r),
       .OHOLDTOP(1'b0),
       .OHOLDBOT(1'b0),
       .CI(1'b0),
       .ACCUMCI(1'b0),
       .SIGNEXTIN(1'b0),
       .O(y),
       .CO(),
       .ACCUMCO(),
       .SIGNEXTOUT());

endmodule // ice40_macadd16x16
