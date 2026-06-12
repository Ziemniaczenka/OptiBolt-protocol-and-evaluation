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
 * Testbench for draw_button.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

import font_pkg::*;

module draw_button_tb;

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
  wire [11:0] rgb1, rgb2, rgb3;
  logic en1, en2, en3;

  logic is_selected;

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

  // Text RAM
  bram_if #(
      .ADDR_WIDTH(4),
      .DATA_WIDTH(8)
  ) ram_if_a ();
  bram_if #(
      .ADDR_WIDTH(4),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) ram_if_b ();

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(4)
  ) u_ram (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(ram_if_a),
      .port_b(ram_if_b)
  );

  bram_writer #(
      .MAX_LEN(16)
  ) u_writer (
      .clk (clk),
      .port(ram_if_a)
  );

  // Standard Button
  draw_button #(
      .MAX_TEXT_LEN(16),
      .LEFT_MARGIN (15)
  ) dut1 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd100),
      .ystart(11'd100),
      .width(11'd150),
      .height(11'd30),
      .text_bram(ram_if_b),
      .is_selected(is_selected),
      .vga_in(tim_if.in),
      .rgb_out(rgb1),
      .draw_en_out(en1)
  );

  // Tall Button (Testing vertical center and margin)
  draw_button #(
      .MAX_TEXT_LEN(16),
      .LEFT_MARGIN (40)
  ) dut2 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd300),
      .ystart(11'd100),
      .width(11'd150),
      .height(11'd60),
      .text_bram(ram_if_b),
      .is_selected(is_selected),
      .vga_in(tim_if.in),
      .rgb_out(rgb2),
      .draw_en_out(en2)
  );

  // Default Margin Button
  draw_button #(
      .MAX_TEXT_LEN(16)
  ) dut3 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd500),
      .ystart(11'd100),
      .width(11'd150),
      .height(11'd40),
      .text_bram(ram_if_b),
      .is_selected(!is_selected),
      .vga_in(tim_if.in),
      .rgb_out(rgb3),
      .draw_en_out(en3)
  );

  wire [11:0] rgb_out = en1 ? rgb1 : (en2 ? rgb2 : (en3 ? rgb3 : 12'h222));
  wire draw_en_out = en1 | en2 | en3;

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
    is_selected = 1'b0;
    ram_if_a.we = 1'b0;
    ram_if_a.en = 1'b0;
    ram_if_a.addr = '0;
    ram_if_a.din = '0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    u_writer.write_string("Click Me!");

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0: Standard
    is_selected = 1'b0;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Frame 1: Selected
    u_writer.write_string("Hovered!");
    is_selected = 1'b1;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    // Frame 2: Deselected, different text
    u_writer.write_string("Inactive.");
    is_selected = 1'b0;
    @(posedge vs) $display("Info: Frame 2 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
