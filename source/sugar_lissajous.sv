`timescale 1ns/100ps
`default_nettype none

/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSED */

`define VARIANT_1
//`define VARIANT_2

module sugar_lissajous
  (input wire CLK12,

   output wire LED_R_N,
   output wire LED_G_N,
   output wire LED_B_N,

   // PMOD 1: two ADC MCP3201
   output wire P1_1,             // R SSN
   input  wire P1_2,             // --
   input  wire P1_3,             // R DAT
   output wire P1_4,             // R CLK
   output wire P1_9,             // L CLK
   input  wire P1_10,            // L DAT
   input  wire P1_11,            // --
   output wire P1_12,            // L SSN

   // PMOD 2: LCD
   input  wire P2_1,             //
   input  wire P2_2,             //
   output wire P2_3,             // DC
   input  wire P2_4,             //
   output wire P2_9,             // CLK
   input  wire P2_10,            //
   output wire P2_11,            // MOSI
   output wire P2_12             // CSN
   );

`ifdef VARIANT_1
    localparam POINTS_COUNT = 128;
    localparam POINTS_FADING = 1;
    localparam DECIMATION = 200;
    localparam ANGLE_INCREMENT = 8;
`elsif VARIANT_2
    localparam POINTS_COUNT = 32;
    localparam POINTS_FADING = 0;
    localparam DECIMATION = 50;
    localparam ANGLE_INCREMENT = 30;
`endif

    assign LED_R_N = 1'b1;
    assign LED_G_N = 1'b1;
    assign LED_B_N = 1'b1;

    logic clock;
    logic reset;
    logic pll_lock;

    pll pll_i
      (.clock_in(CLK12),
       .clock_out(clock),
       .locked(pll_lock));

    pll_lock_reset #(.RESET_LEN(8)) reset_i
      (.pll_clock(clock),
       .pll_lock(pll_lock),
       .reset(reset));

    localparam SPI_SCLK_FREQ = 1000000;
    localparam SAMPLE_RATE = 20000;

    logic [11:0] rdata;
    logic [11:0] ldata;
    logic        strb;

    logic adc_ssn, adc_clk;
    logic radc_dat, ladc_dat;

    assign P1_1  = adc_ssn;
    assign P1_4  = adc_clk;
    assign P1_12 = adc_ssn;
    assign P1_9  = adc_clk;

    assign radc_dat = P1_3;
    assign ladc_dat = P1_10;

    /* Grab audio */
    mcp3201_ma #(.CHANNELS(2),
                 .CLOCK_FREQ(30000000),
                 .SCLK_FREQ(SPI_SCLK_FREQ),
                 .SAMPLE_RATE(SAMPLE_RATE)) adcs_i
      (.clock, .reset,
       .spi_clk_o(adc_clk),
       .spi_ssn_o(adc_ssn),
       .spi_miso_i({ radc_dat, ladc_dat }),
       .data_o({ rdata, ldata }),
       .strb_o(strb));

    /* Filter audio stream */
    logic [15:0] fir_i;
    logic [15:0] fir_o;
    logic fir_i_ready;
    logic fir_o_valid;

    logic [15:0] fir_abs;
    logic fir_strb;

`ifdef TESTBENCH
    always_ff @ (posedge clock)
      if (strb) begin
          fir_abs  <= 1024/2;
          fir_strb <= 1'b1;
      end
      else
        fir_strb <= 1'b0;

`else // !TESTBENCH

    fir_filter fir_impl
      (.clock, .reset,
       .data_i(fir_i),
       .data_o(fir_o),
       .ready_i(fir_i_ready),
       .valid_o(fir_o_valid));

    always_ff @ (posedge clock, posedge reset)
      if (reset)
        fir_i_ready <= 1'b0;
      else
        if (~fir_i_ready) begin
            fir_strb <= 1'b0;

            if (strb) begin
                fir_i       <= (ldata >= 1024) ? 16'(ldata) - 16'd1024 : 16'd64512 - 16'(ldata);
                fir_i_ready <= 1'b1;
            end
        end
        else
          if (fir_o_valid) begin
              fir_abs     <= fir_o[15] ? 16'hffff - fir_o + 1'b1 : fir_o;
              fir_i_ready <= 1'b0;
              fir_strb    <= 1'b1;
          end
`endif

    /* Make frame redraw tick */
    logic tick_redraw;
    tick_generator #(.PERIOD(600000))
    tick_refresh_gen (.clock, .reset, .tick_o(tick_redraw));

    logic redraw;
    logic redraw_done;

    always_ff @ (posedge clock)
      if (redraw_done)
        redraw <= 1'b0;
      else
        if (tick_redraw)
          redraw <= 1'b1;

    /* LCD connection */
    logic spi_csn, spi_clk, spi_sdo, dcn;
    assign P2_12 = spi_csn;
    assign P2_9 = spi_clk;
    assign P2_11 = spi_sdo;
    assign P2_3 = dcn;

    logic [7:0] lcd_x;
    logic [8:0] lcd_y;
    logic lcd_req;
    logic lcd_ack;
    logic lcd_wr;

    logic [15:0] color_w;
    logic [15:0] color_r;

    lcd_top #(.SPI_CLK_PERIOD(4)) lcd_i
      (.clock, .reset,
       .lcd_spi_csn_o(spi_csn),
       .lcd_spi_clk_o(spi_clk),
       .lcd_spi_dat_o(spi_sdo),
       .lcd_spi_dcn_o(dcn),
       .redraw_i(redraw),
       .done_o(redraw_done),
       .x_i(lcd_x),
       .y_i(lcd_y),
       .color_i(color_w),
       .color_o(color_r),
       .req_i(lcd_req),
       .ack_o(lcd_ack),
       .wr_i(lcd_wr));

    /* Figure drawer */
    logic [7:0] fig_x;
    logic [8:0] fig_y;
    logic [7:0] fig_h;
    logic [7:0] fig_s;
    logic [7:0] fig_v;
    logic fig_req;
    logic fig_ack;

    assign lcd_wr = 1'b1;

    fig_drawer fig_i
      (.clock, .reset,
       .x_i(fig_x),
       .y_i(fig_y),
       .h_i(fig_h),
       .s_i(fig_s),
       .v_i(fig_v),
       .req_i(fig_req),
       .ack_o(fig_ack),

       .fb_x_o(lcd_x),
       .fb_y_o(lcd_y),
       .fb_color_o(color_w),
       .fb_req_o(lcd_req),
       .fb_ack_i(lcd_ack));

    /* Awesome circle */
    logic [9:0] cir_angle;
    logic [7:0] cir_x;
    logic [7:0] cir_y;
    logic cir_req;
    logic cir_ack;

    circle_1024 DUT
      (.clock, .reset,
       .angle(cir_angle),
       .r(fir_abs[11:4]),
       .x0(8'd120),
       .y0(8'd128),
       .x(cir_x),
       .y(cir_y),
       .req_i(cir_req),
       .ack_o(cir_ack));

    /* Points ring buffer */
    logic [7:0] pt_x;
    logic [7:0] pt_y;
    logic [7:0] pt_h;
    logic pt_req;
    logic pt_ack;

    fig_ring #(.POINT_COUNT(POINTS_COUNT),
               .FADING(POINTS_FADING)) fig_ring_i
      (.clock, .reset,
       .pt_x(pt_x),
       .pt_y(pt_y),
       .pt_h(pt_h),
       .pt_req_i(pt_req),
       .pt_ack_o(pt_ack),

       .fig_x_o(fig_x),
       .fig_y_o(fig_y),
       .fig_h_o(fig_h),
       .fig_s_o(fig_s),
       .fig_v_o(fig_v),
       .fig_req_o(fig_req),
       .fig_ack_i(fig_ack));

    /* Decimate audio stream */
    localparam DECIMATION_CW = $clog2(DECIMATION);

    logic [DECIMATION_CW-1:0] decim_cntr;
    logic decim_strobe;

    always_ff @ (posedge clock, posedge reset)
      if (reset)
        decim_cntr <= '0;
      else
        if (decim_cntr == (DECIMATION-1)) begin
            decim_cntr <= '0;
            decim_strobe <= 1'b1;
        end
        else begin
            decim_strobe <= 1'b0;

            if (fir_strb)
              decim_cntr <= decim_cntr + 1'b1;
        end

    /* Draw autio sample on circle */
    enum int unsigned {
        ST_FIG_IDLE = 0,
        ST_FIG_CIRCLE,
        ST_FIG_DRAW
    } state_fig;

    always_ff @ (posedge clock, posedge reset)
      if (reset) begin
          state_fig <= ST_FIG_IDLE;
          cir_req   <= 1'b0;
          pt_req    <= 1'b0;
          cir_angle <= '0;
          pt_h      <= '0;
      end
      else
        case (state_fig)
          ST_FIG_IDLE:
            if (decim_strobe) begin
                cir_req <= 1'b1;
                state_fig <= ST_FIG_CIRCLE;
            end

          ST_FIG_CIRCLE:
            if (cir_ack) begin
                cir_req <= 1'b0;
                pt_x <= cir_x;
                pt_y <= cir_y;
                pt_req <= 1'b1;
                state_fig <= ST_FIG_DRAW;
            end

          ST_FIG_DRAW:
            if (pt_ack) begin
                pt_req    <= 1'b0;
                cir_angle <= cir_angle + ANGLE_INCREMENT;
                pt_h      <= pt_h + 1'b1;
                state_fig <= ST_FIG_IDLE;
            end
        endcase

endmodule // sugar_lissajous
