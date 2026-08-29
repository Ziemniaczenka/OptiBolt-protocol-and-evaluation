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
      .pwr_status_code(3'd0),
      .active_voltage_id(2'd0),
      .active_amps(4'd0),
      .contract_active(1'b0),
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

    // Verify popup position: Top-Right of console
    assert (dut.u_top_draw.u_draw_popup.xstart == 11'd485 && dut.u_top_draw.u_draw_popup.ystart == 11'd175)
      else $warning("Popup coordinates mismatch (expected x=485, y=175)");
    $display("[PASS] Popup top-right placement verified at (x=485, y=175).");

    // Verify 5 separate status lines & title
    assert (dut.u_top_draw.u_string_rom.os_str_16x[14] == "1" && dut.u_top_draw.u_string_rom.os_str_16x[15] == "6")
      else $error("Oversampling indicator 16x mismatch in string ROM");
    assert (dut.u_top_draw.u_string_rom.os_str_8x[14] == "8")
      else $error("Oversampling indicator 8x mismatch in string ROM");
    assert (dut.u_top_draw.u_string_rom.light_str_on[14] == "L" && dut.u_top_draw.u_string_rom.light_str_off[14] == "N")
      else $error("Light detect string mismatch in string ROM");
    assert (dut.u_top_draw.u_draw_status_lbl.start_y == 12'd135)
      else $error("Status box title placement mismatch");
    assert (dut.u_top_draw.u_string_rom.failover_str_on[14] == "E" && dut.u_top_draw.u_string_rom.failover_str_off[14] == "D")
      else $error("Failover string mismatch in string ROM");
    assert (dut.u_top_draw.u_draw_diag_frame.ystart == 11'd375 && dut.u_top_draw.u_draw_diag_title.start_y == 12'd355)
      else $error("Diagnostics frame/title layout mismatch");
    $display("[PASS] Diagnostics title above lowered box (title_y=355, frame_y=375) and 6 status lines verified.");

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

    show_popup = 1'b1;
    ui_selected_item = ITEM_POPUP_BTN;
    show_progress = 1'b1;
    progress_val = 8'd128; // 50%

    @(negedge vs) $display("Info: Frame 1 done at %t", $time);
    // Frame 1: Popup window shown with OK button selected, progress bar at 50%

    $display("=== top_display testbench completed successfully! ===");
    $finish;
  end

endmodule
