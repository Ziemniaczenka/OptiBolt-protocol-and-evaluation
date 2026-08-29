/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Dual-Clock Asynchronous FIFO with Gray-code pointers.
 * Provides safe clock domain crossing between Evaluation (clk100) and OptiBolt (clk200).
 */

module async_fifo #(
    parameter int DATA_WIDTH = 11,
    parameter int ADDR_WIDTH = 4    // Depth = 2^ADDR_WIDTH (e.g. 16 words)
) (
    // Write Domain
    input  logic                  clk_wr,
    input  logic                  rst_wr_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] din,
    output logic                  full,

    // Read Domain
    input  logic                  clk_rd,
    input  logic                  rst_rd_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] dout,
    output logic                  empty
);

  localparam int DEPTH = 1 << ADDR_WIDTH;

  // Memory Array
  logic [DATA_WIDTH-1:0] mem[0:DEPTH-1];

  // Write Pointer Signals (clk_wr)
  logic [ADDR_WIDTH:0] wptr_bin, wptr_bin_next;
  logic [ADDR_WIDTH:0] wptr_gray, wptr_gray_next;
  (* ASYNC_REG = "TRUE" *) logic [ADDR_WIDTH:0] rptr_gray_sync0, rptr_gray_sync1;

  // Read Pointer Signals (clk_rd)
  logic [ADDR_WIDTH:0] rptr_bin, rptr_bin_next;
  logic [ADDR_WIDTH:0] rptr_gray, rptr_gray_next;
  (* ASYNC_REG = "TRUE" *) logic [ADDR_WIDTH:0] wptr_gray_sync0, wptr_gray_sync1;

  /* Memory Write & Read */
  always_ff @(posedge clk_wr) begin
    if (wr_en && !full) begin
      mem[wptr_bin[ADDR_WIDTH-1:0]] <= din;
    end
  end

  /* Combinational read for First-Word-Fall-Through (FWFT) */
  assign dout = mem[rptr_bin[ADDR_WIDTH-1:0]];

  /* Write Domain Logic (clk_wr) */
  assign wptr_bin_next = wptr_bin + (wr_en && !full ? 1'b1 : 1'b0);
  assign wptr_gray_next = (wptr_bin_next >> 1) ^ wptr_bin_next;

  /* Full condition: MSB and 2nd MSB inverted in Gray code, remaining bits equal */
  wire is_full = (wptr_gray_next == {~rptr_gray_sync1[ADDR_WIDTH:ADDR_WIDTH-1], rptr_gray_sync1[ADDR_WIDTH-2:0]});

  always_ff @(posedge clk_wr or negedge rst_wr_n) begin
    if (!rst_wr_n) begin
      wptr_bin        <= '0;
      wptr_gray       <= '0;
      full            <= 1'b0;
      rptr_gray_sync0 <= '0;
      rptr_gray_sync1 <= '0;
    end else begin
      wptr_bin        <= wptr_bin_next;
      wptr_gray       <= wptr_gray_next;
      full            <= is_full;
      rptr_gray_sync0 <= rptr_gray;
      rptr_gray_sync1 <= rptr_gray_sync0;
    end
  end

  /* Read Domain Logic (clk_rd) */
  assign rptr_bin_next  = rptr_bin + (rd_en && !empty ? 1'b1 : 1'b0);
  assign rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;

  // Empty condition: Read Gray pointer matches synchronized Write Gray pointer
  wire is_empty = (rptr_gray_next == wptr_gray_sync1);

  always_ff @(posedge clk_rd or negedge rst_rd_n) begin
    if (!rst_rd_n) begin
      rptr_bin        <= '0;
      rptr_gray       <= '0;
      empty           <= 1'b1;
      wptr_gray_sync0 <= '0;
      wptr_gray_sync1 <= '0;
    end else begin
      rptr_bin        <= rptr_bin_next;
      rptr_gray       <= rptr_gray_next;
      empty           <= is_empty;
      wptr_gray_sync0 <= wptr_gray;
      wptr_gray_sync1 <= wptr_gray_sync0;
    end
  end

endmodule
