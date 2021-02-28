`timescale 1ns/100ps

module tb_lcd_spi;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 50MHz (20ns period) */
    always #(20ns/2) clock <= ~clock;

    logic [7:0] data;
    logic push, done;
    logic sclk, sdo;

    lcd_spi #(.DATA_WIDTH(8),
              .SPI_CLK_PERIOD(16)) DUT
      (.clock, .reset,
       .data_i(data),
       .push_i(push),
       .done_o(done),
       .spi_clk_o(sclk),
       .spi_dat_o(sdo));

    int state;

    always_ff @(posedge clock)
      if (reset) begin
          push <= 1'b0;
          state <= 0;
      end
      else begin
          case (state)
            0: begin
                data  <= $random;
                push  <= 1'b1;
                state <= 1;
            end

            1: begin
                if (done) begin
                    //data  <= $random;
                    push  <= 1'b0;
                    state <= 0;
                end
            end
          endcase
      end


    initial begin
        reset = 1'b1;
        repeat(10) @(posedge clock) #1;
        reset = 1'b0;

        repeat(1000) @(posedge clock);
        $finish;
    end

    initial begin
        $dumpfile("tb_lcd_spi.vcd");
        $dumpvars;
    end

endmodule // tb_lcd_spi
