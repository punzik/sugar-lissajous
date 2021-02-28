`timescale 1ns/100ps
`default_nettype none

/* Yosys do not support SPRAM and MAC inferring */
`define USE_SPRAM_PRIMITIVE
`define USE_MAC_PRIMITIVE

module lcd_top #(parameter SPI_CLK_PERIOD = 6)
    (input  logic clock,
     input  logic reset,

     output logic lcd_spi_csn_o,
     output logic lcd_spi_clk_o,
     output logic lcd_spi_dat_o,
     output logic lcd_spi_dcn_o,

     input logic redraw_i,
     output logic done_o,

     input  logic [7:0] x_i,
     input  logic [8:0] y_i,
     input  logic [15:0] color_i,
     output logic [15:0] color_o,
     input  logic req_i,
     output logic ack_o,
     input  logic wr_i);

    /* Display size */
    localparam DISPLAY_MEM_SIZE = 320 * 240 * 2; // 2 byte per pixel
    localparam DISPLAY_MEM_CW = $clog2(DISPLAY_MEM_SIZE);

    /* Display x/y address width */
    localparam DISPLAY_XCW = 8,
               DISPLAY_YCW = 9;

    /* Screen size and origin */
    localparam XSIZE = 240,
               YSIZE = 272,
               XORIG = 0,
               YORIG = 24;

    localparam FBSIZE = XSIZE * YSIZE;
    localparam FBCW = $clog2(FBSIZE);

    /* Drawing block size */
    localparam BLOCK_XS = 16,   // must be power of 2
               BLOCK_YS = 16;   // must be power of 2

    localparam GRID_XS = XSIZE / BLOCK_XS,
               GRID_YS = YSIZE / BLOCK_YS;

    localparam BLOCK_XS_CW = $clog2(BLOCK_XS);
    localparam BLOCK_YS_CW = $clog2(BLOCK_YS);

    localparam GRID_XS_CW = $clog2(GRID_XS);
    localparam GRID_YS_CW = $clog2(GRID_YS);

    localparam DFLAG_SIZE = GRID_XS * GRID_YS;
    localparam DFLAG_CW = $clog2(DFLAG_SIZE);

    localparam BLOCK_SIZE = BLOCK_XS * BLOCK_YS;
    localparam BLOCK_CW = $clog2(BLOCK_SIZE);

    /* --------- Drawing flags memory --------- */
    logic dflag[DFLAG_SIZE];
    logic dflag_wdata;
    logic dflag_rdata;
    logic [DFLAG_CW-1:0] dflag_waddr;
    logic [DFLAG_CW-1:0] dflag_raddr;
    logic [DFLAG_CW-1:0] dflag_int_addr; // for screen refresher
    logic [DFLAG_CW-1:0] dflag_ext_addr; // for external master
    logic dflag_wr;
    logic dflag_set;
    logic dflag_clr;

    assign dflag_wr = dflag_set | dflag_clr;
    assign dflag_waddr = dflag_clr ? dflag_int_addr : dflag_ext_addr;
    assign dflag_raddr = dflag_int_addr;
    assign dflag_wdata = dflag_set;

    /* Infer as sysMEM Block RAM */
    always_ff @ (posedge clock) begin
        if (dflag_wr)
          dflag[dflag_waddr] <= dflag_wdata;

        dflag_rdata <= dflag[dflag_raddr];
    end

    /* --------- Frame buffer RAM (one-port block RAM)--------- */
    logic [FBCW-1:0] fbaddr;
    logic [15:0] fb_rdata;
    logic [15:0] fb_wdata;
    logic fbwrite;

`ifdef USE_SPRAM_PRIMITIVE
    ice40_spram spram_i
      (.clock(clock),
       .addr(fbaddr),
       .data_i(fb_wdata),
       .data_o(fb_rdata),
       .wr(fbwrite));
`else
    logic [15:0] fbram[FBSIZE];

    always_ff @ (posedge clock)
      if (fbwrite) begin
          fbram[fbaddr] <= fb_wdata;
          fb_rdata <= 'x;
      end
      else
        fb_rdata <= fbram[fbaddr];
`endif

    /* --------- Framebuffer arbiter --------- */
    logic [FBCW-1:0] fba_int;   // Frame buffer address from refresher
    logic [FBCW-1:0] fba_ext;   // Frame buffer address from client

    logic fb_busy_int;
    logic fb_busy_ext;
    logic fb_clear;

    assign fbaddr = fb_busy_int ? fba_int : fba_ext;
    assign color_o = fb_rdata;
    assign fb_wdata = fb_clear ? '0 : color_i;

    enum int unsigned {
        FBST_CLEAR = 0,
        FBST_CLEAR_NEXT,
        FBST_WAIT,
        FBST_ADDR,
        FBST_READ,
        FBST_DONE
    } fbst;

    logic [FBCW-1:0] ymult;
    logic [DFLAG_CW-1:0] fmult;

`ifdef USE_MAC_PRIMITIVE
    wire [31:0] ymac_o;
    wire [31:0] fmac_o;

    ice40_mac16x16 ymac_i
      (.clock, .reset,
       .a(16'(y_i)),
       .b(16'(XSIZE)),
       .s(32'b0),
       .sub(1'b0),
       .y(ymac_o));

    ice40_mac16x16 fmac_i
      (.clock, .reset,
       .a(16'(y_i) >> BLOCK_YS_CW),
       .b(16'(GRID_XS)),
       .s(32'b0),
       .sub(1'b0),
       .y(fmac_o));

    assign ymult = ymac_o[FBCW-1:0];
    assign fmult = fmac_o[DFLAG_CW-1:0];
`endif

    always_ff @ (posedge clock, posedge reset)
      if (reset) begin
          fbst        <= FBST_CLEAR;
          ack_o       <= 1'b0;
          fbwrite     <= 1'b0;
          fb_busy_ext <= 1'b0;
          dflag_set   <= 1'b0;
      end
      else
        case (fbst)
          /* Clear frame buffer RAM */
          FBST_CLEAR: begin
              fba_ext        <= '0;
              fbwrite        <= 1'b1;
              fb_busy_ext    <= 1'b1;
              fb_clear       <= 1'b1;
              fbst           <= FBST_CLEAR_NEXT;
          end

          FBST_CLEAR_NEXT:
            if (fba_ext == (FBSIZE-1)) begin
                fbwrite        <= 1'b0;
                fb_busy_ext    <= 1'b0;
                fb_clear       <= 1'b0;
                fbst           <= FBST_WAIT;
            end
            else
                fba_ext <= fba_ext + 1'b1;

          /* Main loop */
          FBST_WAIT:
            if (req_i && !fb_busy_int)
              if (x_i >= XSIZE || y_i >= YSIZE) begin
                  ack_o <= 1'b1;
                  fbst  <= FBST_READ;
              end
              else begin

`ifndef USE_MAC_PRIMITIVE
                  ymult <= y_i * XSIZE;
                  fmult <= GRID_YS_CW'(y_i >> BLOCK_YS_CW) * GRID_XS;
`endif
                  fb_busy_ext <= 1'b1;
                  fbst <= FBST_ADDR;
              end

          FBST_ADDR:
            if (fb_busy_int) begin
                fbst <= FBST_WAIT;
                fb_busy_ext <= 1'b0;
            end
            else begin
                fba_ext <= ymult + FBCW'(x_i);
                dflag_ext_addr <= fmult + DFLAG_CW'(x_i >> BLOCK_XS_CW);

                if (wr_i) begin
                    ack_o     <= 1'b1;
                    fbwrite   <= 1'b1;
                    dflag_set <= 1'b1;
                    fbst      <= FBST_DONE;
                end
                else
                  fbst <= FBST_READ;
            end

          FBST_READ: begin
              ack_o <= 1'b1;
              fbst  <= FBST_DONE;
          end

          FBST_DONE: begin
              fbwrite     <= 1'b0;
              dflag_set   <= 1'b0;
              ack_o       <= 1'b0;
              fb_busy_ext <= 1'b0;
              fbst        <= FBST_WAIT;
          end
        endcase

    /* --------- Read initialization commands from file --------- */
    localparam INIT_FILE = "lcd_init.rom";
    localparam INIT_ROM_SIZE = 64;
    localparam INIT_DATA_SIZE = 61;
    localparam INIT_ROM_CW = $clog2(INIT_ROM_SIZE);

    logic [8:0] init_rom [INIT_ROM_SIZE];
    logic [INIT_ROM_CW-1:0] init_addr;
    logic [8:0] init_data;

    initial $readmemh(INIT_FILE, init_rom, 0, INIT_DATA_SIZE-1);

    /* Block RAM as ROM */
    always_ff @ (posedge clock)
      init_data <= init_rom[init_addr];

    /* --------- SPI master --------- */
    logic [7:0] spi_data;
    logic spi_push;
    logic spi_done;

    lcd_spi #(.DATA_WIDTH(8),
              .SPI_CLK_PERIOD(SPI_CLK_PERIOD),
              .PUSH_ON_DONE(1)) spim_i
      (.clock, .reset,
       .data_i(spi_data),
       .push_i(spi_push),
       .done_o(spi_done),
       .spi_clk_o(lcd_spi_clk_o),
       .spi_dat_o(lcd_spi_dat_o));

    /* --------- Main FSM --------- */
`ifdef TESTBENCH
    localparam INIT_DELAY = 250;
`else
    //    localparam INIT_DELAY = 7500000;
    localparam INIT_DELAY = 250;
`endif

    enum int unsigned {
        ST_PREINIT_DELAY = 0,   // 0
        ST_INIT_PUSH_SPI,
        ST_INIT_WAIT_SPI,
        ST_INIT_WAIT_LAST,
        ST_POSTINIT_DELAY,
        ST_DISPLAY_ON,
        ST_DISPLAY_ONW,
        ST_SCRCLR_CMD,
        ST_SCRCLR,
        ST_SCRCLR_LAST,
        ST_START_REDRAW,        // 10
        ST_READ_FLAG,
        ST_CHECK_FLAG,
        ST_CLEAR_FLAG,
        ST_CADDR_CMD,
        ST_CADDR_0,
        ST_CADDR_1,
        ST_CADDR_2,
        ST_CADDR_3,
        ST_PADDR_CMD,
        ST_PADDR_0,             // 20
        ST_PADDR_1,
        ST_PADDR_2,
        ST_PADDR_3,
        ST_WRITE_CMD,
        ST_WRITE_CMDW,
        ST_FB_READ,
        ST_STORE_PIXEL,
        ST_WRITE_PIXEL_H,
        ST_WRITE_PIXEL_L,
        ST_NEXT_PIXEL,          // 30
        ST_NEXT_BLOCK
    } state, next;

    always_ff @(posedge clock, posedge reset)
      if (reset) state <= ST_PREINIT_DELAY;
      else       state <= next;

    /* Pre/post init delay counter */
    localparam INIT_DELAY_CW = $clog2(INIT_DELAY);
    logic [INIT_DELAY_CW-1:0] delay_cntr;
    logic delay_cntr_incr;

    always_ff @(posedge clock)
      delay_cntr <= (~reset && delay_cntr_incr) ?
                    delay_cntr + 1'b1 : '0;

    /* Initialization ROM address */
    logic init_addr_rst;
    logic init_addr_incr;

    always_ff @ (posedge clock)
      if (reset || init_addr_rst)
        init_addr <= '0;
      else
        if (init_addr_incr)
          init_addr <= init_addr + 1'b1;

    /* LCD chipselect */
    logic spi_disable;

    always_ff @ (posedge clock)
      if (reset || spi_disable)
        lcd_spi_csn_o <= 1'b1;
      else if (spi_push)
        lcd_spi_csn_o <= 1'b0;

    /* LCD data/command */
    logic spi_do_cmd;
    logic spi_do_data;

    always_ff @ (posedge clock)
      // if (spi_do_cmd)
      //   lcd_spi_dcn_o <= 1'b0;
      // else if (spi_do_data)
      //   lcd_spi_dcn_o <= 1'b1;
      if (spi_do_cmd != spi_do_data)
        lcd_spi_dcn_o <= spi_do_data;

    /* Redraw block coordinates */
    logic [GRID_XS_CW-1:0] bx;
    logic [DISPLAY_XCW-1:0] borigx;
    logic [DISPLAY_YCW-1:0] borigy;
    logic [DISPLAY_XCW-1:0] borigx_e;
    logic [DISPLAY_YCW-1:0] borigy_e;

    assign borigx_e = borigx + BLOCK_XS - 1;
    assign borigy_e = borigy + BLOCK_YS - 1;

    logic [FBCW-1:0] fbr_orig;

    logic reset_redraw;
    logic next_block;
    logic is_last_blk;

    always_ff @ (posedge clock)
      if (reset_redraw) begin
          dflag_int_addr <= '0;
          bx             <= '0;
          borigx         <= XORIG;
          borigy         <= YORIG;
          fbr_orig       <= '0;
          is_last_blk    <= 1'b0;
      end
      else
        if (next_block) begin
            dflag_int_addr <= dflag_int_addr + 1'b1;
            is_last_blk    <= (dflag_int_addr == DFLAG_CW'(DFLAG_SIZE-1)) ? 1'b1 : 1'b0;

            if (bx == GRID_XS_CW'(GRID_XS - 1))
              begin
                  bx       <= '0;
                  borigx   <= XORIG;
                  borigy   <= borigy + BLOCK_YS;
                  fbr_orig <= fbr_orig + BLOCK_XS + ((BLOCK_YS - 1) * XSIZE);
              end
            else
              begin
                  bx          <= bx + 1'b1;
                  borigx      <= borigx + BLOCK_XS;
                  fbr_orig    <= fbr_orig + BLOCK_XS;
              end
        end

    /* Framebuffer handling */
    logic [BLOCK_XS_CW-1:0] px;
    logic [BLOCK_CW-1:0] pi;
    logic [15:0] pixel;

    logic start_write;
    logic read_pixel;
    logic next_pixel;

    always_ff @ (posedge clock)
      if (read_pixel)
        pixel <= fb_rdata;

    always_ff @ (posedge clock)
      if (start_write) begin
          fba_int <= fbr_orig;
          px <= '0;
          pi <= '0;
      end
      else
        if (next_pixel) begin
            pi <= pi + 1'b1;

            if (px == BLOCK_XS_CW'(BLOCK_XS-1))
              begin
                  fba_int <= fba_int + XSIZE - BLOCK_XS + 1'b1;
                  px <= '0;
              end
            else
              begin
                  fba_int <= fba_int + 1'b1;
                  px <= px + 1'b1;
              end
        end

    /* Column/page addresses map */
    logic [15:0] caddr_b, caddr_e;
    logic [15:0] paddr_b, paddr_e;

    assign caddr_b = { (16-DISPLAY_XCW)'('0), borigx };
    assign caddr_e = { (16-DISPLAY_XCW)'('0), borigx_e };
    assign paddr_b = { (16-DISPLAY_YCW)'('0), borigy };
    assign paddr_e = { (16-DISPLAY_YCW)'('0), borigy_e };

    /* Clear screen pixel counter */
    logic [DISPLAY_MEM_CW-1:0] scrclr_pcntr;
    logic scrclr_incr;

    always_ff @ (posedge clock)
      if (reset || init_addr_rst)
        scrclr_pcntr <= '0;
      else
        if (scrclr_incr)
          scrclr_pcntr <= scrclr_pcntr + 1'b1;

    /* FSM combinational block */
    always @(*) begin
        next            = state;

        /* FSM outputs default value */
        delay_cntr_incr = 1'b0;
        init_addr_rst   = 1'b0;
        init_addr_incr  = 1'b0;
        scrclr_incr     = 1'b0;
        spi_push        = 1'b0;
        spi_data        = '0;
        spi_disable     = 1'b0;
        spi_do_cmd      = 1'b0;
        spi_do_data     = 1'b0;
        reset_redraw    = 1'b0;
        dflag_clr       = 1'b0;
        next_block      = 1'b0;
        start_write     = 1'b0;
        next_pixel      = 1'b0;
        read_pixel      = 1'b0;
        fb_busy_int     = 1'b0;
        done_o          = 1'b0;

        case (state)
          ST_PREINIT_DELAY: begin
              delay_cntr_incr = 1'b1;
              init_addr_rst   = 1'b1;

              if (delay_cntr == INIT_DELAY)
                next = ST_INIT_PUSH_SPI;
          end

          ST_INIT_PUSH_SPI: begin
              init_addr_incr = 1'b1;
              spi_data       = init_data[7:0];
              spi_push       = 1'b1;

              {spi_do_cmd, spi_do_data}
                = init_data[8] ? 2'b01 : 2'b10;

              if (init_addr == (INIT_DATA_SIZE-1))
                next = ST_INIT_WAIT_LAST;
              else
                next = ST_INIT_WAIT_SPI;
          end

          ST_INIT_WAIT_SPI:
            if (spi_done)
              next = ST_INIT_PUSH_SPI;

          ST_INIT_WAIT_LAST:
            if (spi_done)
              next = ST_POSTINIT_DELAY;

          ST_POSTINIT_DELAY: begin
              spi_disable     = 1'b1;
              delay_cntr_incr = 1'b1;

              if (delay_cntr == INIT_DELAY)
                next = ST_DISPLAY_ON;
          end

          ST_DISPLAY_ON: begin
              spi_data   = 8'h29;
              spi_do_cmd = 1'b1;
              spi_push   = 1'b1;

              next = ST_DISPLAY_ONW;
          end

          ST_DISPLAY_ONW:
            if (spi_done) begin
                spi_disable = 1'b1;
                next = ST_SCRCLR_CMD;
            end

          ST_SCRCLR_CMD: begin
              spi_data = 8'h2c;
              spi_do_cmd = 1'b1;
              spi_push = 1'b1;
              next = ST_SCRCLR;
          end

          ST_SCRCLR:
            if (spi_done) begin
                spi_data    = 8'h00; //8'h32;
                spi_do_data = 1'b1;
                spi_push    = 1'b1;
                scrclr_incr = 1'b1;

                if (scrclr_pcntr ==
`ifdef TESTBENCH
 `ifdef VERILATOR
                    (DISPLAY_MEM_SIZE - 1)
 `else
                    200
 `endif
`else
                    (DISPLAY_MEM_SIZE - 1)
`endif
                    )
                  next = ST_SCRCLR_LAST;
            end

          ST_SCRCLR_LAST:
            if (spi_done)
              next = ST_START_REDRAW;

          ST_START_REDRAW:
            if (redraw_i) begin
                spi_disable  = 1'b1;
                reset_redraw = 1'b1;
                next = ST_READ_FLAG;
            end

          ST_READ_FLAG:
            if (is_last_blk) begin
                done_o = 1'b1;
                next = ST_START_REDRAW;
            end
            else
              next = ST_CHECK_FLAG;

          ST_CHECK_FLAG:
            if (dflag_rdata == 1'b1)
              next = ST_CLEAR_FLAG;
            else
              begin
                  next_block = 1'b1;
                  next       = ST_READ_FLAG;
              end

          ST_CLEAR_FLAG: begin
              dflag_clr = 1'b1;
              next = ST_CADDR_CMD;
          end

          ST_CADDR_CMD: begin
              spi_data   = 8'h2a;
              spi_do_cmd = 1'b1;
              spi_push   = 1'b1;

              next = ST_CADDR_0;
          end

          ST_CADDR_0:
            if (spi_done) begin
                spi_data    = caddr_b[15:8];
                spi_do_data = 1'b1;
                spi_push    = 1'b1;

                next = ST_CADDR_1;
            end

          ST_CADDR_1:
            if (spi_done) begin
                spi_data = caddr_b[7:0];
                spi_push = 1'b1;

                next = ST_CADDR_2;
            end

          ST_CADDR_2:
            if (spi_done) begin
                spi_data = caddr_e[15:8];
                spi_push = 1'b1;

                next = ST_CADDR_3;
            end

          ST_CADDR_3:
            if (spi_done) begin
                spi_data = caddr_e[7:0];
                spi_push = 1'b1;

                next = ST_PADDR_CMD;
            end

          ST_PADDR_CMD:
            if (spi_done) begin
                spi_data   = 8'h2b;
                spi_do_cmd = 1'b1;
                spi_push   = 1'b1;

                next = ST_PADDR_0;
            end

          ST_PADDR_0:
            if (spi_done) begin
                spi_data    = paddr_b[15:8];
                spi_do_data = 1'b1;
                spi_push    = 1'b1;

                next = ST_PADDR_1;
            end

          ST_PADDR_1:
            if (spi_done) begin
                spi_data = paddr_b[7:0];
                spi_push = 1'b1;

                next = ST_PADDR_2;
            end

          ST_PADDR_2:
            if (spi_done) begin
                spi_data = paddr_e[15:8];
                spi_push = 1'b1;

                next = ST_PADDR_3;
            end

          ST_PADDR_3:
            if (spi_done) begin
                spi_data = paddr_e[7:0];
                spi_push = 1'b1;

                next = ST_WRITE_CMD;
            end

          ST_WRITE_CMD:
            if (spi_done) begin
                spi_data    = 8'h2c;
                spi_do_cmd  = 1'b1;
                spi_push    = 1'b1;
                start_write = 1'b1;
                next        = ST_WRITE_CMDW;
            end

          ST_WRITE_CMDW:
            if (spi_done)
              next = ST_FB_READ;

          ST_FB_READ:
            if (!fb_busy_ext) begin
                fb_busy_int = 1'b1;
                next            = ST_STORE_PIXEL;
            end

          ST_STORE_PIXEL: begin
              fb_busy_int = 1'b1;
              read_pixel  = 1'b1;
              next        = ST_WRITE_PIXEL_H;
          end

          ST_WRITE_PIXEL_H: begin
              spi_data    = pixel[15:8];
              spi_do_data = 1'b1;
              spi_push    = 1'b1;
              next        = ST_WRITE_PIXEL_L;
          end

          ST_WRITE_PIXEL_L:
            if (spi_done) begin
                spi_data    = pixel[7:0];
                spi_push    = 1'b1;
                next        = ST_NEXT_PIXEL;
            end

          ST_NEXT_PIXEL:
            if (spi_done) begin
                next_pixel = 1'b1;

                if (pi == (BLOCK_SIZE - 1))
                  next = ST_NEXT_BLOCK;
                else
                  next = ST_FB_READ;
            end

          ST_NEXT_BLOCK: begin
              spi_disable = 1'b1;
              next_block  = 1'b1;
              next        = ST_READ_FLAG;
          end
        endcase
    end

endmodule // lcd_top
