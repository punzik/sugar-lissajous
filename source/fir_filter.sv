`timescale 1ns/100ps
`default_nettype none

module fir_filter  #(parameter LEN = 449,
                     parameter COEFFS_ROM_FILE = "fir_449_50hz_100hz_10db_40db.rom")
    (input wire clock,
     input wire reset,

     input wire signed [15:0] data_i,
     input wire ready_i,

     output wire signed [15:0] data_o,
     output reg valid_o);

    localparam LEN_CW = $clog2(LEN);
    localparam MEM_LEN = 1 << LEN_CW;

    /* Coeffs */
    logic signed [15:0] coeffs[LEN];
    initial $readmemh(COEFFS_ROM_FILE, coeffs, 0, LEN-1);

    logic signed [15:0] coeff;
    logic [LEN_CW-1:0] coeff_addr;

    always_ff @ (posedge clock)
      coeff <= coeffs[coeff_addr];

    /* Z-1 BlockRAM */
    logic signed [15:0] mem[MEM_LEN];
    logic signed [15:0] mem_wdata;
    logic signed [15:0] mem_rdata;
    logic [LEN_CW-1:0] mem_addr;
    logic mem_wr;

    always_ff @ (posedge clock) begin
        if (mem_wr)
          mem[mem_addr] <= mem_wdata;
        mem_rdata <= mem[mem_addr];
    end

    initial begin
        integer i;
        for (i = 0; i < MEM_LEN; i++)
          mem[i] = '0;
    end

    /* MAC */
    logic [31:0] mac_o;
    logic signed [15:0] a;
    logic signed [15:0] b;
    logic signed [15:0] s;

    ice40_mac16x16 #(.SIGNED(1)) mac
      (.clock, .reset,
       .a(a),
       .b(b),
       .s({s, 16'b0}),
       .sub(1'b0),
       .y(mac_o));

    /* FSM */
    enum int unsigned {
        ST_IDLE = 0,
        ST_WRITE,
        ST_CONV,
        ST_DONE
    } state;

    logic [LEN_CW-1:0] new_addr;

    assign mem_wdata = data_i;
    assign data_o = s;
    assign s = coeff_addr == '0 ? '0 : mac_o[31:16];

    always_ff @ (posedge clock, posedge reset)
      if (reset) begin
          state    <= ST_IDLE;
          new_addr <= '0;
          mem_wr   <= 1'b0;
          valid_o  <= 1'b0;
      end
      else
        case (state)
          ST_IDLE: begin
              a <= '0;
              b <= '0;
              mem_addr   <= new_addr;
              coeff_addr <= '0;

              if (ready_i) begin
                  mem_wr <= 1'b1;
                  state  <= ST_WRITE;
              end
          end

          ST_WRITE: begin
              mem_wr <= 1'b0;
              state  <= ST_CONV;
          end

          ST_CONV: begin
              a <= mem_rdata;
              b <= coeff;

              if (coeff_addr == LEN_CW'(LEN-1)) begin
                  valid_o <= 1'b1;
                  state   <= ST_DONE;
              end
              else begin
                  coeff_addr <= coeff_addr + 1'b1;
                  mem_addr   <= mem_addr - 1'b1;
                  state      <= ST_CONV;
              end
          end

          ST_DONE: begin
              new_addr <= new_addr + 1'b1;
              valid_o  <= 1'b0;
              state    <= ST_IDLE;
          end
        endcase

endmodule // fir_filter
