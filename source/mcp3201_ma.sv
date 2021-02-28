`timescale 1ns/100ps
`default_nettype none
`include "assert.vh"

/*
 * MCP3201 controller
 * Multichannel and sample rate accurate version.
 */
module mcp3201_ma #(parameter CHANNELS = 1,
                    parameter CLOCK_FREQ = 12000000,
                    parameter SCLK_FREQ = 1000000,
                    parameter SAMPLE_RATE = 44100)
    (input wire clock,
     input wire reset,

     output reg spi_clk_o,
     output reg spi_ssn_o,
     input wire [CHANNELS-1:0] spi_miso_i,

     output reg [CHANNELS*12-1:0] data_o,
     output reg strb_o);

    initial begin
        `assert(CHANNELS > 0);
    end

    /* SCLK frequency not need accuracy */
    localparam SCLK_PERIOD = CLOCK_FREQ/SCLK_FREQ;
    localparam SCLK_CW = $clog2(SCLK_PERIOD);

    logic [SCLK_CW-1:0] sclk_cnt;
    logic sclk_posedge;

    /* Make SPI SCLK */
    always_ff @(posedge clock)
      if (reset | spi_ssn_o) begin
          spi_clk_o    <= 1'b1;
          sclk_cnt     <= '0;
          sclk_posedge <= 1'b0;
      end
      else begin
          sclk_posedge <= 1'b0;
          sclk_cnt <= sclk_cnt + 1'b1;

          if (sclk_cnt == SCLK_CW'(SCLK_PERIOD/2))
            spi_clk_o <= 1'b0;
          else
            if (sclk_cnt == SCLK_CW'(SCLK_PERIOD-1)) begin
                spi_clk_o    <= 1'b1;
                sclk_cnt     <= '0;
                sclk_posedge <= 1'b1;
            end
      end

    /* Sample rate need more accuracy */
    localparam SRATE_PERIOD = $rtoi($floor($itor(CLOCK_FREQ)/$itor(SAMPLE_RATE) + 0.5));
    localparam SRATE_CW = $clog2(SRATE_PERIOD);

    logic [SRATE_CW-1:0] srate_cnt;
    logic sample;

    always_ff @(posedge clock, posedge reset)
      if (reset) begin
          sample    <= 1'b0;
          srate_cnt <= '0;
      end
      else
        if (srate_cnt == SRATE_CW'(SRATE_PERIOD-1)) begin
            sample    <= 1'b1;
            srate_cnt <= '0;
        end
        else begin
            sample    <= 1'b0;
            srate_cnt <= srate_cnt + 1'b1;
        end

    /* Receive data FSM */
    enum int unsigned {
        ST_RELAX = 0,
        ST_SHIFT,
        ST_STROBE
    } state;

    logic [3:0] bit_cnt;
    logic [11:0] data_sr[CHANNELS];
    integer i;

    always_ff @(posedge clock, posedge reset)
      if (reset) begin
          state     <= ST_RELAX;
          bit_cnt   <= '0;
          spi_ssn_o <= 1'b1;
          strb_o    <= 1'b0;
          data_o    <= '0;

          for (i = 0; i < CHANNELS; i ++)
            data_sr[i] <= '0;
      end
      else begin
          strb_o <= 1'b0;

          case (state)
            ST_RELAX:
              if (sample) begin
                  bit_cnt   <= '0;
                  spi_ssn_o <= 1'b0;
                  state     <= ST_SHIFT;
              end

            ST_SHIFT:
              if (sclk_posedge) begin
                  for (i = 0; i < CHANNELS; i ++)
                    data_sr[i] <= { data_sr[i][10:0], spi_miso_i[i] };

                  bit_cnt <= bit_cnt + 1'b1;

                  if (bit_cnt == 4'd14) begin
                      spi_ssn_o <= 1'b1;
                      state <= ST_STROBE;
                  end
              end

            ST_STROBE: begin
                for (i = 0; i < CHANNELS; i ++)
                  data_o[i*12 +: 12] <= data_sr[i];

                strb_o <= 1'b1;
                state  <= ST_RELAX;
            end
          endcase
      end

endmodule // mcp3201_ma
