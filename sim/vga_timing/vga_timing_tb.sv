/**
 *  Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 * Modified by: Lukasz Kadlubowski
 *
 * Description:
 * Testbench for vga_timing module.
 */

module vga_timing_tb;

  timeunit 1ns; timeprecision 1ps;

  import vga_pkg::*;


  /**
     *  Local parameters
     */

  localparam CLK_PERIOD = 25;  // 40 MHz
  localparam RST_START_TIME = 1.25 * CLK_PERIOD;
  localparam RST_ACTIVE_TIME = 2.00 * CLK_PERIOD;


  /**
     * Local variables and signals
     */

  logic clk;
  logic rst_n;

  vga_if if_timing ();

  /**
     * Clock generation
     */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b1;
    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;
  end



  vga_timing dut (
      .clk,
      .rst_n,
      .vga_out(if_timing.out)
      // .vcount,
      // .vsync,
      // .vblnk,
      // .hcount,
      // .hsync,
      // .hblnk
  );

  /* -----------------------------------------------------------------------------
     * Immediate assertions
     * -------------------------------------------------------------------------- */

  /* hcount : max value */
  assert property (
  /* run assertion at each positive clock edge: */
  @(posedge clk)
  /* except during reset (optional): */
  disable iff (!rst_n || $realtime < RST_START_TIME)
  /* check whether this condition is true: */
  if_timing.hcount < HOR_TOTAL_TIME)
  else begin
    /* if condition is not true, display error message */
    $error("hcount: max value exceeded");
  end

  /* hcount : zero after max value */
  assert property (
        @(posedge clk)
        if_timing.hcount == (HOR_TOTAL_TIME - 1) |=> if_timing.hcount == 0
    )
  else begin
    $error("hcount: return to 0 after expected max value failed");
  end

  /* hcount : incrementation with every clock tick */
  assert property (
        @(posedge clk)
        disable iff (!rst_n)
        (if_timing.hcount < HOR_TOTAL_TIME - 1) |=> (if_timing.hcount == $past(
      if_timing.hcount
  ) + 1))
  else begin
    $error("hcount: increment at every clk failed");
  end

  /* vcount : max value */
  assert property (
        @(posedge clk)
        disable iff (!rst_n || $realtime < RST_START_TIME)
        if_timing.vcount < VER_TOTAL_TIME
    )
  else begin
    $error("vcount: max value exceeded");
  end

  /* vcount : zero after max value */
  assert property (
        @(posedge clk)
        if_timing.vcount == (VER_TOTAL_TIME - 1) && (if_timing.hcount == HOR_TOTAL_TIME - 1) |=> if_timing.vcount == 0
    )
  else begin
    $error("vcount: return to 0 after expected max value failed");
  end

  /* vcount : incrementation with every clock tick */
  assert property (
        @(posedge clk)
        (if_timing.hcount == HOR_TOTAL_TIME - 1) && if_timing.vcount < (VER_TOTAL_TIME - 1) |=> (if_timing.vcount == $past(
      if_timing.vcount
  ) + 1))
  else begin
    $error("vcount: increment at hcount reset failed");
  end

  /* hblnk : set */
  assert property (
        @(posedge clk)
        if_timing.hcount >= HOR_BLANK_START && if_timing.hcount < HOR_BLANK_START + HOR_BLANK_TIME |-> if_timing.hblnk
    )
  else begin
    $error("hblnk: set failed");
  end

  /* hblnk : clear */
  assert property (@(posedge clk) if_timing.hcount < HOR_BLANK_START |-> !if_timing.hblnk)
  else begin
    $error("hblnk: clear failed");
  end

  /* vblnk : set */
  assert property (
        @(posedge clk)
        if_timing.vcount >= VER_BLANK_START && if_timing.vcount < VER_BLANK_START + VER_BLANK_TIME |-> if_timing.vblnk
    )
  else begin
    $error("vblnk set failed");
  end

  /* vblnk : clear */
  assert property (@(posedge clk) if_timing.vcount < VER_BLANK_START |-> !if_timing.vblnk)
  else begin
    $error("vblnk: clear failed");
  end

  /* hsync : set */
  assert property (
        @(posedge clk)
        if_timing.hcount >= HOR_SYNC_START && if_timing.hcount < HOR_SYNC_START + HOR_SYNC_TIME |-> if_timing.hsync
    )
  else begin
    $error("hsync: set failed");
  end

  /* hsync : clear */
  assert property (
        @(posedge clk)
        (if_timing.hcount < HOR_SYNC_START) || (if_timing.hcount >= (HOR_SYNC_START + HOR_SYNC_TIME)) |-> !if_timing.hsync
    )
  else begin
    $error("hsync: clear failed");
  end

  /* vsync : set */
  assert property (
        @(posedge clk)
        if_timing.vcount >= VER_SYNC_START && if_timing.vcount < VER_SYNC_START + VER_SYNC_TIME |-> if_timing.vsync
    )
  else begin
    $error("vsync: set failed");
  end

  /* vsync : clear */
  assert property (
        @(posedge clk)
        if_timing.vcount < VER_SYNC_START || if_timing.vcount > VER_SYNC_START + VER_SYNC_TIME - 1 |-> !if_timing.vsync
    )
  else begin
    $error("vsync: clear failed");
  end

  /* -----------------------------------------------------------------------------
     * Main test
     * -------------------------------------------------------------------------- */
  initial begin
    @(negedge rst_n);
    @(posedge rst_n);

    /* TODO: modify this condition temporarily if needed */
    wait (if_timing.vsync == 1'b0);
    @(negedge if_timing.vsync);
    @(negedge if_timing.vsync);

    $display("SUCCESS: ALL TESTS PASSED");
    $finish;
  end

endmodule
