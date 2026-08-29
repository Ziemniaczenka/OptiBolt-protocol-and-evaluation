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
 * Testbench for draw_popup.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

import font_pkg::*;

module draw_popup_tb;

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
  wire [11:0] rgb1, rgb2, rgb3, rgb4;
  logic en1, en2, en3, en4;

  logic show_progress;
  logic [7:0] progress_val;
  logic btn_selected;

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

  // Setup Mock Memories for Texts
  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8)
  ) title_a ();
  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) title_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(6)
  ) ram_title (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(title_a),
      .port_b(title_b)
  );

  bram_writer #(.MAX_LEN(32)) u_writer_title (
      .clk(clk),
      .port(title_a)
  );

  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8)
  ) desc_a ();
  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) desc_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(6)
  ) ram_desc (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(desc_a),
      .port_b(desc_b)
  );

  bram_writer #(.MAX_LEN(64)) u_writer_desc (
      .clk(clk),
      .port(desc_a)
  );

  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8)
  ) btn1_a ();
  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) btn1_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(6)
  ) ram_btn1 (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(btn1_a),
      .port_b(btn1_b)
  );

  bram_writer #(.MAX_LEN(8)) u_writer_btn1 (
      .clk(clk),
      .port(btn1_a)
  );

  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8)
  ) btn2_a ();
  bram_if #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) btn2_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(6)
  ) ram_btn2 (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(btn2_a),
      .port_b(btn2_b)
  );

  bram_writer #(.MAX_LEN(8)) u_writer_btn2 (
      .clk(clk),
      .port(btn2_a)
  );

  // DUT 1: 1 Button, No Progress
  draw_popup #(
      .TITLE_LEN(32),
      .DESC_LEN(64),
      .BTN1_LEN(8),
      .TWO_BUTTONS(0)
  ) dut1 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd50),
      .ystart(11'd50),
      .width(11'd400),
      .height(11'd200),
      .title_bram(title_b),
      .desc_bram(desc_b),
      .btn1_bram(btn1_b),
      .btn2_bram(btn2_b),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .btn1_selected(btn_selected),
      .btn2_selected(1'b0),
      .vga_in(tim_if.in),
      .rgb_out(rgb1),
      .draw_en_out(en1)
  );

  // DUT 2: 2 Buttons, No Progress
  draw_popup #(
      .TITLE_LEN(32),
      .DESC_LEN(64),
      .BTN1_LEN(8),
      .BTN2_LEN(8),
      .TWO_BUTTONS(1)
  ) dut2 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd500),
      .ystart(11'd50),
      .width(11'd400),
      .height(11'd200),
      .title_bram(title_b),
      .desc_bram(desc_b),
      .btn1_bram(btn1_b),
      .btn2_bram(btn2_b),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .btn1_selected(!btn_selected),
      .btn2_selected(btn_selected),
      .vga_in(tim_if.in),
      .rgb_out(rgb2),
      .draw_en_out(en2)
  );

  // DUT 3: 1 Button, With Progress
  draw_popup #(
      .TITLE_LEN(32),
      .DESC_LEN(64),
      .BTN1_LEN(8),
      .TWO_BUTTONS(0)
  ) dut3 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd50),
      .ystart(11'd350),
      .width(11'd400),
      .height(11'd200),
      .title_bram(title_b),
      .desc_bram(desc_b),
      .btn1_bram(btn1_b),
      .btn2_bram(btn2_b),
      .show_progress(1'b1),
      .progress_val(progress_val),
      .btn1_selected(btn_selected),
      .btn2_selected(1'b0),
      .vga_in(tim_if.in),
      .rgb_out(rgb3),
      .draw_en_out(en3)
  );

  // DUT 4: 2 Buttons, With Progress
  draw_popup #(
      .TITLE_LEN(32),
      .DESC_LEN(64),
      .BTN1_LEN(8),
      .BTN2_LEN(8),
      .TWO_BUTTONS(1)
  ) dut4 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd500),
      .ystart(11'd350),
      .width(11'd400),
      .height(11'd200),
      .title_bram(title_b),
      .desc_bram(desc_b),
      .btn1_bram(btn1_b),
      .btn2_bram(btn2_b),
      .show_progress(1'b1),
      .progress_val(progress_val),
      .btn1_selected(btn_selected),
      .btn2_selected(!btn_selected),
      .vga_in(tim_if.in),
      .rgb_out(rgb4),
      .draw_en_out(en4)
  );

  wire [11:0] rgb_out = en1 ? rgb1 : (en2 ? rgb2 : (en3 ? rgb3 : (en4 ? rgb4 : 12'h222)));
  wire draw_en_out = en1 | en2 | en3 | en4;

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

    title_a.we = 0;
    title_a.en = 0;
    title_a.addr = 0;
    title_a.din = 0;
    desc_a.we = 0;
    desc_a.en = 0;
    desc_a.addr = 0;
    desc_a.din = 0;
    btn1_a.we = 0;
    btn1_a.en = 0;
    btn1_a.addr = 0;
    btn1_a.din = 0;
    btn2_a.we = 0;
    btn2_a.en = 0;
    btn2_a.addr = 0;
    btn2_a.din = 0;

    show_progress = 1'b0;
    progress_val = 8'd0;
    btn_selected = 1'b0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    u_writer_title.write_string("System Warning");
    u_writer_desc.write_string("Are you sure you want to proceed with this operation?");
    u_writer_btn1.write_string("YES");
    u_writer_btn2.write_string("NO");

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0
    show_progress = 1'b0;
    progress_val  = 8'd0;
    btn_selected  = 1'b0;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Frame 1
    show_progress = 1'b1;
    progress_val  = 8'd128;
    btn_selected  = 1'b0;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    // Frame 2
    show_progress = 1'b1;
    progress_val  = 8'd255;
    btn_selected  = 1'b1;
    @(posedge vs) $display("Info: Frame 2 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
