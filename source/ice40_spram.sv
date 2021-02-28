`timescale 1ns/100ps
`default_nettype none

module ice40_spram
  (input wire clock,
   input wire [15:0] addr,
   input wire [15:0] data_i,
   output wire [15:0] data_o,
   input wire wr);

    logic [15:0] data0_o;
    logic [15:0] data1_o;
    logic [15:0] data2_o;
    logic [15:0] data3_o;
    logic w0, w1, w2, w3;

    logic [15:0] datax_o;
    assign data_o = datax_o;

    always @(*) begin
        {w0, w1, w2, w3} = '0;

        case (addr[15:14])
          2'd0: begin
              datax_o = data0_o;
              w0 = wr;
          end

          2'd1: begin
              datax_o = data1_o;
              w1 = wr;
          end

          2'd2: begin
              datax_o = data2_o;
              w2 = wr;
          end

          2'd3: begin
              datax_o = data3_o;
              w3 = wr;
          end
        endcase
    end

    SB_SPRAM256KA spram0
      (.CLOCK(clock),
       .ADDRESS(addr[13:0]),
       .DATAIN(data_i),
       .DATAOUT(data0_o),
       .WREN(w0),
       .MASKWREN({w0, w0, w0, w0}),
       .CHIPSELECT(1'b1),
       .STANDBY(1'b0),
       .SLEEP(1'b0),
       .POWEROFF(1'b1));

    SB_SPRAM256KA spram1
      (.CLOCK(clock),
       .ADDRESS(addr[13:0]),
       .DATAIN(data_i),
       .DATAOUT(data1_o),
       .WREN(w1),
       .MASKWREN({w1, w1, w1, w1}),
       .CHIPSELECT(1'b1),
       .STANDBY(1'b0),
       .SLEEP(1'b0),
       .POWEROFF(1'b1));

    SB_SPRAM256KA spram2
      (.CLOCK(clock),
       .ADDRESS(addr[13:0]),
       .DATAIN(data_i),
       .DATAOUT(data2_o),
       .WREN(w2),
       .MASKWREN({w2, w2, w2, w2}),
       .CHIPSELECT(1'b1),
       .STANDBY(1'b0),
       .SLEEP(1'b0),
       .POWEROFF(1'b1));

    SB_SPRAM256KA spram3
      (.CLOCK(clock),
       .ADDRESS(addr[13:0]),
       .DATAIN(data_i),
       .DATAOUT(data3_o),
       .WREN(w3),
       .MASKWREN({w3, w3, w3, w3}),
       .CHIPSELECT(1'b1),
       .STANDBY(1'b0),
       .SLEEP(1'b0),
       .POWEROFF(1'b1));

endmodule // ice40_spram
