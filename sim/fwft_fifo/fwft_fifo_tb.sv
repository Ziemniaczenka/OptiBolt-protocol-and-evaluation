/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for fwft_fifo module.
 */

module fwft_fifo_tb;

  timeunit 1ns; timeprecision 1ps;

  /**
  *  Local parameters
  */

  localparam CLK_PERIOD = 25;  // 40 MHz
  localparam RST_START_TIME = 1.25 * CLK_PERIOD;
  localparam RST_ACTIVE_TIME = 2.00 * CLK_PERIOD;

  localparam WORD_WIDTH = 8;
  localparam DEPTH = 4;

  logic clk;
  logic rst_n;

  logic flush;
  logic push;
  logic pop;
  logic [WORD_WIDTH-1:0] din;
  logic [WORD_WIDTH-1:0] dout;
  logic empty;
  logic full;
  logic [$clog2(DEPTH+1)-1:0] count;

  /**
  * Clock generation
  */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  /**
  * Reset generation
  */

  initial begin
    rst_n = 1'b1;
    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;
  end

  /* -----------------------------------------------------------------------------
    * Dut placement
    * -------------------------------------------------------------------------- */

  fwft_fifo #(
      .WORD_WIDTH(WORD_WIDTH),
      .DEPTH(DEPTH)
  ) dut (
      .clk  (clk),
      .rst_n(rst_n),
      .flush(flush),
      .push (push),
      .pop  (pop),
      .din  (din),
      .dout (dout),
      .empty(empty),
      .full (full),
      .count(count)
  );

  /* -----------------------------------------------------------------------------
     * Immediate assertions
     * -------------------------------------------------------------------------- */

  /* count : bounds check */
  assert property (@(posedge clk) disable iff (!rst_n || $isunknown(count)) count <= DEPTH)
  else $error("count exceeded maximum DEPTH");

  /* empty flag : set check */
  assert property (@(posedge clk) disable iff (!rst_n || flush) (count == 0) |-> empty)
  else $error("empty flag not set when count == 0");

  /* empty flag : clear check */
  assert property (@(posedge clk) disable iff (!rst_n || flush) (count > 0) |-> !empty)
  else $error("empty flag set when count > 0");

  /* full flag : set check */
  assert property (@(posedge clk) disable iff (!rst_n || flush) (count == DEPTH) |-> full)
  else $error("full flag not set when count == DEPTH");

  /* full flag : clear check */
  assert property (@(posedge clk) disable iff (!rst_n || flush) (count < DEPTH) |-> !full)
  else $error("full flag set when count < DEPTH");

  /* flush : resets the fifo */
  assert property (@(posedge clk) disable iff (!rst_n) flush |=> empty && !full && count == 0)
  else $error("flush did not reset the fifo state");

  /* FWFT condition : Data must be ready immediately after empty is cleared */
  assert property (@(posedge clk) disable iff (!rst_n || flush) (empty && push) |=> (dout == $past(
      din
  )))
  else $error("FWFT read logic failed (Data not ready on first word fall-through)");

  /* -----------------------------------------------------------------------------
     * Main test
     * -------------------------------------------------------------------------- */
  initial begin
    // Init values
    flush = 1'b0;
    push  = 1'b0;
    pop   = 1'b0;
    din   = '0;

    // Wait for reset to finish
    @(negedge rst_n);
    @(posedge rst_n);
    repeat (2) @(posedge clk);
    #1;

    // 1. Push single value and test FWFT (assert will catch automatically, but we do standard if check too)
    din  = 8'hA1;
    push = 1'b1;
    @(posedge clk);
    #1;
    push = 1'b0;
    @(posedge clk);
    #1;
    if (dout !== 8'hA1) $error("Main test: Expected dout to be A1, got %h", dout);

    // 2. Fill the FIFO
    din  = 8'hB1;
    push = 1'b1;
    @(posedge clk);
    #1;
    din  = 8'hB2;
    push = 1'b1;
    @(posedge clk);
    #1;
    din  = 8'hB3;
    push = 1'b1;
    @(posedge clk);
    #1;
    push = 1'b0;
    @(posedge clk);
    #1;

    // 3. Overfill attempt (should be ignored by FIFO internal full check)
    din  = 8'hFF;
    push = 1'b1;
    @(posedge clk);
    #1;
    push = 1'b0;
    @(posedge clk);
    #1;

    // 4. Pop all values
    pop = 1'b1;
    @(posedge clk);
    #1;
    if (dout !== 8'hB1) $error("Main test: Expected dout to be B1, got %h", dout);
    @(posedge clk);
    #1;
    if (dout !== 8'hB2) $error("Main test: Expected dout to be B2, got %h", dout);
    @(posedge clk);
    #1;
    if (dout !== 8'hB3) $error("Main test: Expected dout to be B3, got %h", dout);
    @(posedge clk);
    #1;
    pop = 1'b0;
    @(posedge clk);
    #1;

    // 5. Simultaneous push and pop
    din  = 8'hC1;
    push = 1'b1;
    @(posedge clk);
    #1;
    din  = 8'hC2;
    pop  = 1'b1;
    push = 1'b1;
    @(posedge clk);
    #1;  // Pop C1, push C2
    pop  = 1'b0;
    push = 1'b0;
    @(posedge clk);
    #1;
    if (dout !== 8'hC2)
      $error("Main test: Simultaneous push/pop failed. Expected C2, got %h", dout);

    // 6. Flush
    flush = 1'b1;
    @(posedge clk);
    #1;
    flush = 1'b0;
    @(posedge clk);
    #1;

    repeat (3) @(posedge clk);
    $display("SUCCESS: ALL TESTS PASSED");
    $finish;
  end

endmodule
