/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 * Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for draw_progress_bar.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

module draw_progress_bar_tb;

  timeunit 1ns; timeprecision 1ps;

  /**
    * Local parameters
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
  wire [11:0] rgb_out;
  logic draw_en_out;

  logic [7:0] progress;

  vga_if tim_if ();

  assign vs = tim_if.vsync;
  assign hs = tim_if.hsync;

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

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );

  draw_progress_bar dut (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd100),
      .ystart(11'd100),
      .width(11'd400),
      .height(11'd30),
      .progress(progress),
      .dynamic_color(12'h000),
      .vga_in(tim_if.in),
      .rgb_out(rgb_out),
      .draw_en_out(draw_en_out)
  );

  wire [3:0] r = draw_en_out ? rgb_out[11:8] : 4'h2;
  wire [3:0] g = draw_en_out ? rgb_out[7:4] : 4'h2;
  wire [3:0] b = draw_en_out ? rgb_out[3:0] : 4'h2;

  tiff_writer #(
      .XDIM(16'd1650),
      .YDIM(16'd750),
      .FILE_DIR("../../results")
  ) u_tiff_writer (
      .clk(clk),
      .r  ({r, r}),
      .g  ({g, g}),
      .b  ({b, b}),
      .go (vs)
  );

  /**
    * Main test
    */

  initial begin
    rst_n = 1'b1;
    // value doesn't matter
    progress = 8'd15;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;
    wait (vs == 1'b0);
    @(negedge vs);

    // 0%
    progress = 8'd0;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // 1/255 (smallest value)
    progress = 8'd1;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    // 50%
    progress = 8'd128;
    @(posedge vs) $display("Info: Frame 2 done at %t", $time);

    // 254/255 (almost the biggest)
    progress = 8'd254;
    @(posedge vs) $display("Info: Frame 3 done at %t", $time);

    // 100%
    progress = 8'd255;
    @(posedge vs) $display("Info: Frame 4 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
