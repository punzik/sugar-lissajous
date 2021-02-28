`timescale 1ns/100ps
`default_nettype none

module lcd_ili9341_4spi
  (input wire clock,
   input wire reset,

   input wire csn_i,
   input wire clk_i,
   input wire sdi_i,
   input wire dcn_i,

   output int x_o,
   output int y_o,
   output logic [7:0] r_o,
   output logic [7:0] g_o,
   output logic [7:0] b_o,
   output logic strobe_o);

    logic [7:0] readed;
    logic [7:0] spi_sr;
    int bit_cntr;
    logic clk_prev;
    logic rstrobe;

    always_ff @ (posedge clock) clk_prev <= clk_i;

    always_ff @(posedge clock, posedge csn_i)
      if (csn_i || reset) begin
          bit_cntr <= 0;
      end
      else begin
          if (clk_prev == 1'b0 &&
              clk_i    == 1'b1)
            begin
                spi_sr <= { spi_sr[6:0], sdi_i };
                bit_cntr <= bit_cntr + 1;
            end

          if (bit_cntr == 8) begin
              readed <= spi_sr;
              rstrobe <= 1'b1;
              bit_cntr <= 0;
          end
          else
            rstrobe <= 1'b0;
      end

    enum int unsigned {
        ST_IDLE = 0,
        ST_CADDR,
        ST_PADDR,
        ST_MEM_WRITE
    } state;

    logic [15:0] x_beg;
    logic [15:0] x_end;
    logic [15:0] y_beg;
    logic [15:0] y_end;

    initial begin
        x_beg = 0;
        x_end = 239;
        y_beg = 0;
        y_end = 319;
    end

    int n;
    int x, y;

    logic [7:0] tmp;

    always_ff @ (posedge clock, posedge csn_i)
      if (csn_i || reset) begin
          state <= ST_IDLE;
          n <= 0;
          strobe_o <= 1'b0;
      end
      else begin
          strobe_o <= 1'b0;

          if (rstrobe) begin
              if (~dcn_i) begin
                  case (readed)
                    8'h2a: state <= ST_CADDR;
                    8'h2b: state <= ST_PADDR;
                    8'h2c: begin
                        x <= int'(x_beg);
                        y <= int'(y_beg);
                        state <= ST_MEM_WRITE;
                    end
                    default: begin end
                  endcase

                  n <= 0;
              end
              else
                case (state)
                  ST_CADDR: begin
                      n <= n + 1;

                      case (n)
                        0: x_beg[15:8] <= readed;
                        1: x_beg[7:0]  <= readed;
                        2: x_end[15:8] <= readed;
                        3: x_end[7:0]  <= readed;
                      endcase
                  end

                  ST_PADDR: begin
                      n <= n + 1;

                      case (n)
                        0: y_beg[15:8] <= readed;
                        1: y_beg[7:0]  <= readed;
                        2: y_end[15:8] <= readed;
                        3: y_end[7:0]  <= readed;
                      endcase
                  end

                  ST_MEM_WRITE: begin
                      if (n == 0) begin
                          n <= 1;
                          tmp <= readed;
                      end
                      else begin
                          n <= 0;

                          // $display("%d %d %d %d %d", x, y,
                          //          { tmp[7:3], 1'b0 },
                          //          { tmp[2:0], readed[7:5] },
                          //          { readed[4:0], 1'b0 });

                          x_o <= x;
                          y_o <= y;
                          r_o <= { 2'b00, tmp[7:3], 1'b0 };
                          g_o <= { 2'b00, tmp[2:0], readed[7:5] };
                          b_o <= { 2'b00, readed[4:0], 1'b0 };
                          strobe_o <= 1'b1;

                          x <= x + 1;
                          if (x == int'(x_end)) begin
                              x <= int'(x_beg);

                              y <= y + 1;
                              if (y == int'(y_end))
                                y <= int'(y_beg);
                          end

                      end
                  end
                endcase
          end
      end

endmodule // lcd_ili9341_4spi
