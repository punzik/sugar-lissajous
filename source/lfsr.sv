`timescale 1ns/100ps
`default_nettype none

module lfsr #(parameter POLY = 32'hA3000000)
    (clock,
     preset,
     data_i,
     prnd_o);

    localparam WIDTH = $size(POLY);

    input wire clock;
    input wire preset;
    input wire [WIDTH-1:0] data_i;
    output wire prnd_o;

    logic [WIDTH-1:0] sreg;
    logic feedback;

    initial sreg = '1;

    assign feedback = sreg[0];
    assign prnd_o = feedback;

    integer i;

    always_ff @ (posedge clock)
      if (preset)
        sreg <= (data_i == '0) ? '1 : data_i;
      else begin
          sreg[WIDTH-1] <= feedback;

          for (i = 0; i < (WIDTH-1); i ++)
            sreg[i] <= POLY[i] ? (sreg[i+1] ^ feedback) : sreg[i+1];
      end

endmodule // lfsr
