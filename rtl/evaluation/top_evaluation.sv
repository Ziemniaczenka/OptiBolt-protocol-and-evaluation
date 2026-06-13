/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Evaluation platform top module. Merges display, keyboard and test logic.
 */

import string_pkg::*;

module top_evaluation (
    input  logic       clk74p25,  // VGA clock
    input  logic       clk100,    // Tests and PS/2 clock
    input  logic       rst_n,
    output logic       vs,
    output logic       hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,
    inout  wire        ps2_clk,
    inout  wire        ps2_data
);

  /**
    * Local variables and signals
    */

  // Keyboard signals
  logic cmd_up, cmd_down, cmd_left, cmd_right, cmd_enter, cmd_esc;
  logic char_valid, cmd_backspace;
  logic [7:0] char_ascii;

  // UI state signals
  logic [3:0] ui_selected_item;

  // Memory Interfaces
  logic console_we, input_we, bmp_we;
  logic [$clog2(CONSOLE_MAX_LEN)-1:0] console_addr_w, console_addr_r;
  logic [7:0] console_din, console_dout;

  logic [$clog2(INPUT_MAX_LEN)-1:0] input_addr_w, input_addr_r;
  logic [7:0] input_din, input_dout;

  logic [11:0] bmp_addr_w, bmp_addr_r;
  logic [11:0] bmp_din, bmp_dout;

  // CDC UI Navigation
  logic [3:0] ui_selected_item_clk74;
  cdc_sync #(
      .WIDTH(4)
  ) u_cdc_ui_sync (
      .clk_dst(clk74p25),
      .rst_n(rst_n),
      .d_in(ui_selected_item),
      .d_out(ui_selected_item_clk74)
  );

  /**
    * Signals assignments
    */


  /**
    * FPGA submodules placement
    */

  // --- DEDICATED BRAMS ---
  // Console BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8)
  ) console_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) console_if_b ();

  assign console_if_a.addr = console_addr_w;
  assign console_if_a.din  = console_din;
  assign console_if_a.we   = console_we;
  assign console_if_a.en   = 1'b1;

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN))
  ) u_console_ram (
      .clk_a (clk100),
      .clk_b (clk74p25),
      .port_a(console_if_a),
      .port_b(console_if_b)
  );

  // Input BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN)),
      .DATA_WIDTH(8)
  ) input_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) input_if_b ();

  assign input_if_a.addr = input_addr_w;
  assign input_if_a.din  = input_din;
  assign input_if_a.we   = input_we;
  assign input_if_a.en   = 1'b1;

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN))
  ) u_input_ram (
      .clk_a (clk100),
      .clk_b (clk74p25),
      .port_a(input_if_a),
      .port_b(input_if_b)
  );

  // BMP BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH(12),
      .DATA_WIDTH(12)
  ) bmp_if_a ();
  bram_if #(
      .ADDR_WIDTH(12),
      .DATA_WIDTH(12),
      .READ_ONLY (1)
  ) bmp_if_b ();

  assign bmp_if_a.addr = bmp_addr_w;
  assign bmp_if_a.din  = bmp_din;
  assign bmp_if_a.we   = bmp_we;
  assign bmp_if_a.en   = 1'b1;

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH(12)
  ) u_dyn_bmp_ram (
      .clk_a (clk100),
      .clk_b (clk74p25),
      .port_a(bmp_if_a),
      .port_b(bmp_if_b)
  );

  ui_navigation u_ui_nav (
      .clk(clk100),
      .rst_n(rst_n),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .ui_selected_item(ui_selected_item)
  );

  top_keyboard u_top_keyboard (
      .clk(clk100),
      .rst_n(rst_n),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .mode_text(ui_selected_item == 4'd1),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .cmd_backspace(cmd_backspace),
      .char_ascii(char_ascii)
  );

  evaluation_controller u_eval_ctl (
      .clk(clk100),
      .rst_n(rst_n),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .char_ascii(char_ascii),
      .cmd_backspace(cmd_backspace),
      .console_we(console_we),
      .console_addr(console_addr_w),
      .console_din(console_din),
      .input_we(input_we),
      .input_addr(input_addr_w),
      .input_din(input_din),
      .bmp_we(bmp_we),
      .bmp_addr(bmp_addr_w),
      .bmp_din(bmp_din),
      .ui_selected_item(ui_selected_item)
      // TODO: Connect protocol interface
  );

  top_display u_top_display (
      .clk(clk74p25),
      .rst_n(rst_n),
      .ui_selected_item(ui_selected_item_clk74),
      .show_popup(1'b0),
      .show_progress(1'b0),
      .progress_val(8'd0),
      .console_bram(console_if_b),
      .input_bram(input_if_b),
      .dyn_bmp_bram(bmp_if_b),
      .vs(vs),
      .hs(hs),
      .r(r),
      .g(g),
      .b(b)

  );
endmodule
