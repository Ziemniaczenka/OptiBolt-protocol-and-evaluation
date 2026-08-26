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
 * Testbench for top_display.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

import string_pkg::*;
import bitmap_pkg::*;
import ui_pkg::*;

module top_display_tb;

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

  // PS/2 Simulation Wires
  wire ps2_clk_sim;
  wire ps2_data_sim;
  assign ps2_clk_sim  = 1'b1;
  assign ps2_data_sim = 1'b1;

  logic [3:0] ui_selected_item;
  logic       show_popup;
  logic       show_progress;
  logic [7:0] progress_val;

  /**
    * Clock generation
    */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end


  /**
    * Memory Models
    */

  // Console BRAM
  bram_if #(
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8)
  ) console_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) console_if_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN))
  ) u_bram_console (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(console_if_a),
      .port_b(console_if_b)
  );

  bram_writer #(
      .MAX_LEN(CONSOLE_MAX_LEN)
  ) u_writer_console (
      .clk (clk),
      .port(console_if_a)
  );

  // Input BRAM
  bram_if #(
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN)),
      .DATA_WIDTH(8)
  ) input_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) input_if_b ();
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN))
  ) u_bram_input (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(input_if_a),
      .port_b(input_if_b)
  );

  bram_writer #(
      .MAX_LEN(INPUT_MAX_LEN)
  ) u_writer_input (
      .clk (clk),
      .port(input_if_a)
  );

  // Dynamic Bitmap BRAM (64x64 = 4096 addresses)
  bram_if #(
      .ADDR_WIDTH($clog2(BITMAP_DYN_64x64.WIDTH * BITMAP_DYN_64x64.HEIGHT)),
      .DATA_WIDTH(12)
  ) dyn_bmp_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(BITMAP_DYN_64x64.WIDTH * BITMAP_DYN_64x64.HEIGHT)),
      .DATA_WIDTH(12),
      .READ_ONLY (1)
  ) dyn_bmp_if_b ();
  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH(14)
  ) u_bram_dyn_bmp (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(dyn_bmp_if_a),
      .port_b(dyn_bmp_if_b)
  );


  /**
    * Submodules instances
    */

  top_display dut (
      .clk(clk),
      .rst_n(rst_n),
      .link_status(2'b01),
      .baud_rate(4'd1),
      .oversampling(4'd0),
      .ui_selected_item(ui_selected_item),
      .mode_text(1'b0),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .popup_mode(2'd0),
      .prog_man(8'd0),
      .prog_pre(8'd0),
      .prog_par(8'd0),
      .prog_hlt(8'd255),
      .color_man(12'h0_F_0),
      .color_pre(12'h0_F_0),
      .color_par(12'h0_F_0),
      .color_hlt(12'h0_F_0),
      .vs(vs),
      .hs(hs),
      .r(r),
      .g(g),
      .b(b),
      .console_bram(console_if_b),
      .input_bram(input_if_b),
      .dyn_bmp_bram(dyn_bmp_if_b)
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

    // Init unused writing ports
    console_if_a.we = 1'b0;
    console_if_a.en = 1'b0;
    console_if_a.addr = '0;
    console_if_a.din = '0;
    input_if_a.we = 1'b0;
    input_if_a.en = 1'b0;
    input_if_a.addr = '0;
    input_if_a.din = '0;
    dyn_bmp_if_a.we = 1'b0;
    dyn_bmp_if_a.en = 1'b0;
    dyn_bmp_if_a.addr = '0;
    dyn_bmp_if_a.din = '0;
    ui_selected_item = ITEM_INPUT;
    show_popup = 1'b0;
    show_progress = 1'b0;
    progress_val = 8'd0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    $display("If simulation ends before the testbench");
    $display("completes, use the menu option to run all.");
    $display("Prepare to wait a long time...");

    // Setup initial view
    u_writer_console.write_string("Single line test");
    u_writer_input.write_string("> _");

    // Generate dynamic bitmap simple pattern
    for (int i = 0; i < BITMAP_DYN_64x64.WIDTH * BITMAP_DYN_64x64.HEIGHT; i++) begin
      @(posedge clk);
      dyn_bmp_if_a.we   = 1'b1;
      dyn_bmp_if_a.en   = 1'b1;
      dyn_bmp_if_a.addr = i;
      dyn_bmp_if_a.din  = {i[11:8], i[7:4], i[3:0]};
    end
    @(posedge clk);
    dyn_bmp_if_a.we = 1'b0;
    dyn_bmp_if_a.en = 1'b0;

    wait (vs == 1'b0);
    @(negedge vs) $display("Info: Frame 0 done at %t", $time);
    // Frame 0: ITEM_INPUT selected by default (thicker yellow outline)

    u_writer_console.write_string("Multiline string test\nSecond line\nThird line\nLast line.");
    u_writer_input.write_string("> ping_");

    ui_selected_item = ITEM_ABOUT_BTN;

    @(negedge vs) $display("Info: Frame 1 done at %t", $time);
    // Frame 1: Top About button selected, Input returns to thin purple outline

    u_writer_console.write_string("Different multiline\n Another line\nLast");
    u_writer_input.write_string("> _");

    show_popup = 1'b1;
    ui_selected_item = ITEM_POPUP_BTN;
    show_progress = 1'b1;
    progress_val = 8'd85;  // Approx. 33%

    @(negedge vs) $display("Info: Frame 2 done at %t", $time);
    // Frame 2: Popup window shown with OK button selected, progress bar at 33%

    ui_selected_item = ITEM_NONE;  // Deselect items
    progress_val = 8'd170;  // Approx. 66%

    @(negedge vs) $display("Info: Frame 3 done at %t", $time);
    // Frame 3: No selection (gray elements), progress bar at 66%

    ui_selected_item = ITEM_INPUT;  // Return to input
    progress_val = 8'd255;  // 100%

    @(negedge vs) $display("Info: Frame 4 done at %t", $time);
    // Frame 4: Input selected again, full progress bar (100%) in popup window

    // @(negedge vs) $display("Info: Frame 5 done at %t",$time);
    // @(negedge vs) $display("Info: Frame 6 done at %t",$time);
    // @(negedge vs) $display("Info: Frame 7 done at %t",$time);
    // @(negedge vs) $display("Info: Frame 8 done at %t",$time);
    // @(negedge vs) $display("Info: Frame 9 done at %t",$time);
    @(posedge vs)  //Wait for the frame to finish
    // End the simulation.
    $display(
        "Simulation is over, check the waveforms."
    );

    $finish;
  end

endmodule
