/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2025  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 * Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for draw_bg.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

module draw_bg_tb;

  timeunit 1ns; timeprecision 1ps;

  /**
  *  Local parameters
  */

  // f = 74.25 MHz -> T = 13.468 ns
  real CLK_PERIOD = 13.468;
  localparam RST_START_TIME = 30;
  localparam RST_ACTIVE_TIME = 30;


  /**
  * Local variables and signals
  */

  logic clk, rst_n;
  wire vs, hs;
  wire [3:0] r, g, b;

  assign vs = dut_if.vsync;
  assign hs = dut_if.hsync;
  assign {r, g, b} = dut_if.rgb;

  /**
  * Clock generation
  */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end


  /**
  * Submodules instances
  */
  vga_if tim_if ();
  vga_if dut_if ();

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );


  draw_bg dut (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(tim_if.in),
      .vga_out(dut_if.out)
  );


  tiff_writer #(
      .XDIM(16'd1650),
      .YDIM(16'd750),
      .FILE_DIR("../../results")
  ) u_tiff_writer (
      .clk(clk),
      .r  ({r, r}),  // fabricate an 8-bit value
      .g  ({g, g}),  // fabricate an 8-bit value
      .b  ({b, b}),  // fabricate an 8-bit value
      .go (vs)
  );


  /**
  * Main test
  */

  initial begin
    rst_n = 1'b1;
    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    $display("If simulation ends before the testbench");
    $display("completes, use the menu option to run all.");
    $display("Prepare to wait a long time...");

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
