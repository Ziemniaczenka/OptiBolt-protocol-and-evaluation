/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Top Evaluation Module integrating Display, Keyboard, UI Navigation,
 * Handshake, and Evaluation Controller.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module top_evaluation (
    input logic clk100,
    input logic clk74p25,
    input logic rst_n,

    // Keyboard PS/2
    input logic ps2_clk,
    input logic ps2_data,

    // OptiBolt Protocol Interface
    output logic [3:0] eval_proto_baud_rate,
    output logic [3:0] eval_proto_oversampling,
    output logic       eval_proto_loopback_en,

    // TX Interface
    output logic       eval_proto_tx_valid,
    output logic [2:0] eval_proto_tx_type,
    output logic [7:0] eval_proto_tx_data,
    input  logic       proto_eval_tx_full,
    input  logic       proto_eval_tx_empty,

    // RX Interface
    input  logic       proto_eval_rx_valid,
    input  logic [2:0] proto_eval_rx_type,
    input  logic [7:0] proto_eval_rx_data,
    input  logic       proto_eval_parity_error,
    input  logic       proto_eval_manchester_code_error,
    input  logic       proto_eval_preamble_error,
    input  logic       proto_eval_rx_carrier,

    // Telemetry / Status
    input  logic        proto_eval_link_status,
    input  logic [31:0] proto_eval_ber_count,
    input  logic [15:0] proto_eval_err_count,

    // VGA Output
    output logic       vs,
    output logic       hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,

    // 7-segment Display Output
    output logic [6:0] seg,
    output logic       dp,
    output logic [3:0] an
);

  /**
    * Local variables and signals
    */

  // Keyboard decoded signals
  logic       mode_text;
  logic       cmd_up;
  logic       cmd_down;
  logic       cmd_left;
  logic       cmd_right;
  logic       cmd_enter;
  logic       cmd_esc;
  logic       char_valid;
  logic [7:0] char_ascii;
  logic       cmd_backspace;
  logic [7:0] key_code;

  // UI Navigation
  logic [3:0] ui_selected_item;
  logic       show_popup;
  logic       show_progress;
  logic [7:0] progress_val;
  logic [1:0] popup_mode;

  // Error and Diagnostics Metrics
  logic [15:0] err_man_cnt, err_pre_cnt, err_par_cnt;
  logic [ 7:0] prog_man, prog_pre, prog_par, prog_hlt;
  logic [11:0] color_man, color_pre, color_par, color_hlt;

  // RAM Write Signals from Evaluation Controller
  logic                                           console_we;
  logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr_w;
  logic [                                    7:0] console_din;

  logic                                         input_we;
  logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr_w;
  logic [                                  7:0] input_din;

  logic        bmp_we;
  logic [13:0] bmp_addr_w;
  logic [11:0] bmp_din;

  // Handshake signals
  logic       hs_tx_req;
  logic [2:0] hs_tx_type;
  logic [7:0] hs_tx_data;
  logic       hs_tx_ack;
  logic [1:0] link_status;
  logic       speed_updated_pulse;

  // CDC UI Navigation & Telemetry
  logic [3:0]  ui_selected_item_clk74;
  logic        mode_text_clk74;
  logic        show_popup_clk74;
  logic        show_progress_clk74;
  logic [7:0]  progress_val_clk74;
  logic [1:0]  popup_mode_clk74;
  logic        rx_carrier_clk74;
  logic [1:0]  link_status_clk74;
  logic [3:0]  baud_rate_clk74;
  logic [3:0]  oversampling_clk74;
  logic [7:0]  prog_man_clk74, prog_pre_clk74, prog_par_clk74, prog_hlt_clk74;
  logic [11:0] color_man_clk74, color_pre_clk74, color_par_clk74, color_hlt_clk74;
  logic        eval_failover_en;
  logic        failover_en_clk74;

  cdc_sync #(
      .WIDTH(109)
  ) u_cdc_ui_sync (
      .clk_dst(clk74p25),
      .rst_n(rst_n),
      .d_in({
        eval_failover_en,
        proto_eval_rx_carrier,
        mode_text, ui_selected_item, show_popup, show_progress, progress_val, popup_mode,
        link_status, eval_proto_baud_rate, eval_proto_oversampling,
        prog_man, prog_pre, prog_par, prog_hlt,
        color_man, color_pre, color_par, color_hlt
      }),
      .d_out({
        failover_en_clk74,
        rx_carrier_clk74,
        mode_text_clk74, ui_selected_item_clk74, show_popup_clk74, show_progress_clk74, progress_val_clk74, popup_mode_clk74,
        link_status_clk74, baud_rate_clk74, oversampling_clk74,
        prog_man_clk74, prog_pre_clk74, prog_par_clk74, prog_hlt_clk74,
        color_man_clk74, color_pre_clk74, color_par_clk74, color_hlt_clk74
      })
  );

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

  // BMP BRAM Interfaces (128x128 = 16384 pixels -> ADDR_WIDTH = 14)
  bram_if #(
      .ADDR_WIDTH(14),
      .DATA_WIDTH(12)
  ) bmp_if_a ();
  bram_if #(
      .ADDR_WIDTH(14),
      .DATA_WIDTH(12),
      .READ_ONLY (1)
  ) bmp_if_b ();

  assign bmp_if_a.addr = bmp_addr_w;
  assign bmp_if_a.din  = bmp_din;
  assign bmp_if_a.we   = bmp_we;
  assign bmp_if_a.en   = 1'b1;

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH(14)
  ) u_dyn_bmp_ram (
      .clk_a (clk100),
      .clk_b (clk74p25),
      .port_a(bmp_if_a),
      .port_b(bmp_if_b)
  );

  link_handshake u_link_hs (
      .clk(clk100),
      .rst_n(rst_n),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_preamble_error(proto_eval_preamble_error),
      .proto_eval_rx_carrier(proto_eval_rx_carrier),
      .speed_updated_pulse(speed_updated_pulse),
      .hs_tx_req(hs_tx_req),
      .hs_tx_type(hs_tx_type),
      .hs_tx_data(hs_tx_data),
      .hs_tx_ack(hs_tx_ack),
      .link_status(link_status)
  );

  ui_navigation u_ui_nav (
      .clk(clk100),
      .rst_n(rst_n),
      .show_popup(show_popup),
      .cmd_up(mode_text ? 1'b0 : cmd_up),
      .cmd_down(mode_text ? 1'b0 : cmd_down),
      .cmd_left(mode_text ? 1'b0 : cmd_left),
      .cmd_right(mode_text ? 1'b0 : cmd_right),
      .ui_selected_item(ui_selected_item)
  );

  top_keyboard u_top_keyboard (
      .clk(clk100),
      .rst_n(rst_n),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .mode_text(mode_text),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .cmd_backspace(cmd_backspace),
      .char_ascii(char_ascii),
      .key_code(key_code)
  );

  evaluation_controller u_eval_ctrl (
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
      .console_dout(console_if_a.dout),
      .input_we(input_we),
      .input_addr(input_addr_w),
      .input_din(input_din),
      .bmp_we(bmp_we),
      .bmp_addr(bmp_addr_w),
      .bmp_din(bmp_din),
      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .popup_mode(popup_mode),

      // Diagnostics & Error Metrics
      .err_man_cnt(err_man_cnt),
      .err_pre_cnt(err_pre_cnt),
      .err_par_cnt(err_par_cnt),
      .prog_man(prog_man),
      .prog_pre(prog_pre),
      .prog_par(prog_par),
      .prog_hlt(prog_hlt),
      .color_man(color_man),
      .color_pre(color_pre),
      .color_par(color_par),
      .color_hlt(color_hlt),

      // Handshake Interface
      .hs_tx_req(hs_tx_req),
      .hs_tx_type(hs_tx_type),
      .hs_tx_data(hs_tx_data),
      .hs_tx_ack(hs_tx_ack),
      .link_status(link_status),

      // OptiBolt Protocol Interface
      .eval_proto_baud_rate(eval_proto_baud_rate),
      .eval_proto_oversampling(eval_proto_oversampling),
      .eval_proto_loopback_en(eval_proto_loopback_en),
      .eval_failover_en(eval_failover_en),
      .speed_updated_pulse(speed_updated_pulse),
      .eval_proto_tx_valid(eval_proto_tx_valid),
      .eval_proto_tx_type(eval_proto_tx_type),
      .eval_proto_tx_data(eval_proto_tx_data),
      .proto_eval_tx_full(proto_eval_tx_full),
      .proto_eval_tx_empty(proto_eval_tx_empty),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_parity_error(proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error(proto_eval_preamble_error),
      .proto_eval_rx_carrier(proto_eval_rx_carrier),
      .proto_eval_link_status(proto_eval_link_status),
      .proto_eval_ber_count(proto_eval_ber_count),
      .proto_eval_err_count(proto_eval_err_count)
  );

  top_display u_top_display (
      .clk(clk74p25),
      .rst_n(rst_n),
      .rx_carrier(rx_carrier_clk74),
      .link_status(link_status_clk74),
      .baud_rate(baud_rate_clk74),
      .oversampling(oversampling_clk74),
      .failover_en(failover_en_clk74),
      .ui_selected_item(ui_selected_item_clk74),
      .mode_text(mode_text_clk74),
      .show_popup(show_popup_clk74),
      .show_progress(show_progress_clk74),
      .progress_val(progress_val_clk74),
      .popup_mode(popup_mode_clk74),

      .prog_man(prog_man_clk74),
      .prog_pre(prog_pre_clk74),
      .prog_par(prog_par_clk74),
      .prog_hlt(prog_hlt_clk74),
      .color_man(color_man_clk74),
      .color_pre(color_pre_clk74),
      .color_par(color_par_clk74),
      .color_hlt(color_hlt_clk74),

      .console_bram(console_if_b),
      .input_bram(input_if_b),
      .dyn_bmp_bram(bmp_if_b),
      .vs(vs),
      .hs(hs),
      .r(r),
      .g(g),
      .b(b)
  );

  // --- 7-Segment Debug ---
  logic [15:0] display_data;
  logic [ 7:0] sseg_out;

  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) display_data <= 16'h0000;
    else begin
      if (cmd_up || cmd_down || cmd_left || cmd_right || cmd_enter || cmd_esc || cmd_backspace || char_valid) begin
        display_data[15:8] <= key_code[7:0]; // Left half shows PS/2 scancodes
      end
      if (char_valid) begin
        display_data[7:0] <= char_ascii;
      end else if (cmd_up) display_data[7:0] <= 8'hAA;
      else if (cmd_down) display_data[7:0] <= 8'hBB;
      else if (cmd_left) display_data[7:0] <= 8'hCC;
      else if (cmd_right) display_data[7:0] <= 8'hDD;
      else if (cmd_enter) display_data[7:0] <= 8'hEE;
      else if (cmd_esc) display_data[7:0] <= 8'hFF;
      else if (cmd_backspace) display_data[7:0] <= 8'h88;
    end
  end

  disp_hex_mux u_disp (
      .clk  (clk100),
      .reset(~rst_n),
      .hex3 (display_data[15:12]),
      .hex2 (display_data[11:8]),
      .hex1 (display_data[7:4]),
      .hex0 (display_data[3:0]),
      .dp_in(4'b1111),
      .an   (an),
      .sseg (sseg_out)
  );
  assign seg = {sseg_out[0], sseg_out[1], sseg_out[2], sseg_out[3], sseg_out[4], sseg_out[5], sseg_out[6]};
  assign dp  = sseg_out[7];

endmodule
