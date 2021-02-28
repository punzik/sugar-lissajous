`timescale 1ns/100ps
`default_nettype none

`include "assert.vh"

module lcd_spi #(parameter DATA_WIDTH = 8,
                 parameter SPI_CLK_PERIOD = 10,
                 parameter PUSH_ON_DONE = 0)
    (input wire clock,
     input wire reset,

     input wire [DATA_WIDTH-1:0] data_i,
     input wire push_i,
     output reg done_o,

     output reg  spi_clk_o,
     output wire spi_dat_o);

    initial begin
        `assert(DATA_WIDTH > 0);
        `assert(SPI_CLK_PERIOD >= 2);
    end

    localparam SCLK_LOW = SPI_CLK_PERIOD / 2;

    logic [$clog2(SPI_CLK_PERIOD)-1:0] sclk_cntr;
    logic sclk_one;
    logic sclk_nededge;
    logic do_push;

    assign sclk_one = (sclk_cntr < SCLK_LOW) ? 1'b0 : 1'b1;

    always_ff @ (posedge clock, posedge reset)
      if (reset) begin
          sclk_cntr    <= '0;
          sclk_nededge <= 1'b0;
          spi_clk_o    <= 1'b0;
      end
      else begin
          sclk_nededge <= 1'b0;
          spi_clk_o <= do_push ? sclk_one : 1'b0;

          if (do_push || sclk_one) begin
              if (sclk_cntr == (SPI_CLK_PERIOD-1)) begin
                  sclk_cntr <= '0;
                  sclk_nededge <= 1'b1;
              end
              else
                sclk_cntr <= sclk_cntr + 1'b1;
          end
          else
            sclk_cntr <= '0;
      end

    localparam BIT_CW = $clog2(DATA_WIDTH);
    logic [BIT_CW-1:0] sbit_cntr;
    logic [DATA_WIDTH-1:0] data_sr;

    assign spi_dat_o = data_sr[DATA_WIDTH-1];

    logic push;

    generate
        if (PUSH_ON_DONE == 0)
          assign push = push_i & done_o;
        else
          assign push = push_i;
    endgenerate

    always_ff @(posedge clock, posedge reset)
      if (reset) begin
          do_push <= 1'b0;
          done_o  <= 1'b0;
      end
      else begin
          if (do_push) begin
              if (sclk_nededge) begin
                  data_sr <= data_sr << 1;
                  sbit_cntr <= sbit_cntr + 1'b1;

                  if (sbit_cntr == BIT_CW'(DATA_WIDTH-1)) begin
                      do_push <= 1'b0;
                      done_o <= 1'b1;
                  end
              end
          end
          else begin
              done_o <= 1'b0;

              if (push) begin
                  data_sr   <= data_i;
                  sbit_cntr <= '0;
                  do_push   <= 1'b1;
              end
          end
      end

endmodule // lcd_spi
