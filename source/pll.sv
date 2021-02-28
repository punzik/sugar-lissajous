`timescale 1ns/100ps

/**
 * PLL configuration 12MHz->30MHz
 *
 * F_PLLOUT:   30.000 MHz (requested)
 * F_PLLOUT:   30.000 MHz (achieved)
 *
 * FEEDBACK: SIMPLE
 * F_PFD:   12.000 MHz
 * F_VCO:  960.000 MHz
 *
 * DIVR:  0 (4'b0000)
 * DIVF: 79 (7'b1001111)
 * DIVQ:  5 (3'b101)
 *
 * FILTER_RANGE: 1 (3'b001)
 */

`ifdef VERILATOR
 `define TESTBENCH
`endif

module pll
  (input  clock_in,
   output clock_out,
   output locked);

    wire unused_0, unused_1;

`ifdef TESTBENCH
 `ifdef VERILATOR
    /* In Verilator just forward clock_in to clock_out */
    assign clock_out = clock_in;
    assign locked = 1'b1;

 `else // !VERILATOR
    /* In Icarus Verilog generate new clock and 'locked' signal */
    logic clock_tb;
    logic lock_tb;

    assign clock_out = clock_tb;
    assign locked = lock_tb;

    initial begin
        clock_tb = 1'b0;
        lock_tb = 1'b0;
        repeat (100) @(posedge clock_tb);
        lock_tb = 1'b1;
    end

    always #(33ns/2) clock_tb <= ~clock_tb;
 `endif
`else
    /* In HW use PLL primitive */
    SB_PLL40_PAD #(.FEEDBACK_PATH("SIMPLE"),
                   .DIVR(4'd0),
                   /* For 30 MHz: DIVF=79, DIVQ=5
                    * For 50 MHz: DIVF=66, DIVQ=4 */
                   .DIVF(7'd79),
                   .DIVQ(3'd5),
                   .FILTER_RANGE(3'd1))
    uut (.PACKAGEPIN     (clock_in),
         .PLLOUTGLOBAL   (clock_out),
         .EXTFEEDBACK    (1'b0),
         .DYNAMICDELAY   (8'b0),
         .LOCK           (locked),
         .BYPASS         (1'b0),
         .RESETB         (1'b1),
         .LATCHINPUTVALUE(1'b0),
         .PLLOUTCORE     (unused_0),
         .SDO            (unused_1),
         .SDI            (1'b0),
         .SCLK           (1'b0));
`endif

endmodule
