`timescale 1ns/100ps
`default_nettype none

/* verilator lint_off PINCONNECTEMPTY */

module ice40_2mac8x8 #(parameter SIGNED = 0)
    (input wire clock,
     input wire reset,
     input wire [7:0] a0,
     input wire [7:0] b0,
     input wire [15:0] s0,
     input wire sub0,
     output wire [15:0] y0,

     input wire [7:0] a1,
     input wire [7:0] b1,
     input wire [15:0] s1,
     input wire sub1,
     output wire [15:0] y1);

    /* register 'sub' input */
    logic sub0_r, sub1_r;
    always_ff @ (posedge clock) begin
        sub0_r <= sub0;
        sub1_r <= sub1;
    end

    logic [31:0] mac_o;
    assign {y0, y1} = mac_o;

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
        .TOPADDSUB_LOWERINPUT(2'b01),       // TOP adder input 1 - 8x8 top multiplier output
        .TOPADDSUB_UPPERINPUT(1'b1),        // TOP adder input 2 - input C
        .TOPADDSUB_CARRYSELECT(2'b00),      // TOP adder carry input - constant 0
        .BOTOUTPUT_SELECT(2'b00),           // BOT output - ADD/SUB unregistered
        .BOTADDSUB_LOWERINPUT(2'b01),       // BOT adder input 1 - 8x8 bot multiplier output
        .BOTADDSUB_UPPERINPUT(1'b1),        // BOT adder input 2 - input D
        .BOTADDSUB_CARRYSELECT(2'b00),      // BOT adder carry input - constant 0
        .MODE_8x8(1'b1),
        .A_SIGNED(SIGNED),
        .B_SIGNED(SIGNED))
    mac_r
      (.CLK(clock),
       .CE(1'b1),
       .C(s0),
       .A({a0, a1}),
       .B({b0, b1}),
       .D(s1),
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
       .ADDSUBTOP(sub0_r),
       .ADDSUBBOT(sub1_r),
       .OHOLDTOP(1'b0),
       .OHOLDBOT(1'b0),
       .CI(1'b0),
       .ACCUMCI(1'b0),
       .SIGNEXTIN(1'b0),
       .O(mac_o),
       .CO(),
       .ACCUMCO(),
       .SIGNEXTOUT());

endmodule // ice40_macadd16x16
