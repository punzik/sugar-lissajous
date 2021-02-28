`timescale 1ns/100ps
`default_nettype none
`include "assert.vh"

module tick_generator #(parameter PERIOD = 1000)
    (input wire clock,
     input wire reset,
     output reg tick_o);

    initial begin
        `assert(PERIOD > 1);
    end

    localparam TICK_CW = $clog2(PERIOD);
    logic [TICK_CW-1:0] cntr;

    always_ff @(posedge clock, posedge reset)
      if (reset) begin
          cntr   <= '0;
          tick_o <= 1'b0;
      end
      else begin
          if (cntr == (PERIOD-1)) begin
              cntr   <= '0;
              tick_o <= 1'b1;
          end
          else begin
              cntr   <= cntr + 1'b1;
              tick_o <= 1'b0;
          end
      end

endmodule // tick_generator
