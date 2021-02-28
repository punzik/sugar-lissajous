`timescale 1ns/100ps

module tb_fir_filter;
    logic clock = 1'b0;
    logic reset = 1'b1;

    /* Master clock 100MHz (10ns period) */
    always #(10ns/2) clock <= ~clock;

    logic signed [15:0] data_i;
    logic signed [15:0] data_o;
    logic input_ready, output_valid;

    localparam FILTER_LEN = 425;

    fir_filter #(.LEN(FILTER_LEN),
                 .COEFFS_ROM_FILE("fir_425_50hz_100hz_0db_40db.rom")) DUT
      (.clock, .reset,
       .data_i, .data_o,
       .ready_i(input_ready),
       .valid_o(output_valid));

    event done;
    integer file_o;

    initial begin
        file_o = $fopen("filtered.txt", "w");
        @(done);
        $fclose(file_o);
        $finish;
    end

    initial begin
        reset = 1'b1;
        input_ready = 1'b0;

        repeat(10) @(posedge clock) #1;
        reset = 1'b0;

        @(posedge clock) #1;
        data_i = 16'd32767;
        input_ready = 1'b1;

        @(posedge clock) #1;
        wait (output_valid)
          $fdisplay(file_o, "%d", data_o);
        data_i = '0;

        for (int i = 1; i < FILTER_LEN; i ++) begin
            @(posedge clock) #1;
            wait (output_valid)
              $fdisplay(file_o, "%d", data_o);
        end

        ->done;

        repeat(10) @(posedge clock) #1;
        $finish;
    end

    initial begin
        $dumpfile("tb_fir_filter.vcd");
        $dumpvars;
    end

endmodule // tb_fir_filter
