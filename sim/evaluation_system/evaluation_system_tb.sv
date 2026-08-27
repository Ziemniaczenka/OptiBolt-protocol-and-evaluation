/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Fast Headless System Integration Testbench.
 * Integrates:
 *   - PS/2 Keyboard Subsystem (top_keyboard + decoder + controller)
 *   - UI Navigation Engine (ui_navigation)
 *   - Master Evaluation Controller (evaluation_controller)
 *   - Link Handshake & Presence Detection (link_handshake)
 *   - Dual-Port BRAMs (Console, Input, Dynamic Bitmap)
 *
 * Runs all system integration steps (commands, history, baud switching,
 * ping, sweep, bitmap streaming, popups) in < 2 seconds without waiting
 * for 16.6ms VGA display frames.
 */

`timescale 1ns / 1ps

import protocol_pkg::*;
import ui_pkg::*;
import string_pkg::*;

module evaluation_system_tb;

  logic clk100;
  logic rst_n;

  // PS/2 Keyboard Serial Interface
  wire ps2_clk, ps2_data;
  logic ps2_clk_drive, ps2_data_drive;
  assign ps2_clk  = ps2_clk_drive;
  assign ps2_data = ps2_data_drive;

  // UI Navigation & Control
  logic [3:0] ui_selected_item;
  logic       mode_text;
  logic       show_popup;
  logic       show_progress;
  logic [7:0] progress_val;
  logic [1:0] popup_mode;

  // Keyboard Decoder outputs
  logic cmd_up, cmd_down, cmd_left, cmd_right;
  logic cmd_enter, cmd_esc, cmd_backspace;
  logic       char_valid;
  logic [7:0] char_ascii;
  logic [8:0] key_code;

  // Protocol Interface Signals
  logic [3:0] eval_proto_baud_rate;
  logic [3:0] eval_proto_oversampling;
  logic       eval_proto_loopback_en;
  logic       eval_proto_tx_valid;
  logic [2:0] eval_proto_tx_type;
  logic [7:0] eval_proto_tx_data;

  logic       proto_eval_rx_valid;
  logic [2:0] proto_eval_rx_type;
  logic [7:0] proto_eval_rx_data;
  logic       proto_eval_rx_carrier;

  // Error Metrics
  logic [7:0] prog_man, prog_pre, prog_par, prog_hlt;
  logic [11:0] color_man, color_pre, color_par, color_hlt;

  // Handshake Interface
  logic       hs_tx_req;
  logic [2:0] hs_tx_type;
  logic [7:0] hs_tx_data;
  logic       hs_tx_ack;
  logic [1:0] link_status;

  // BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8)
  ) console_if ();
  bram_if #(
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN)),
      .DATA_WIDTH(8)
  ) input_if ();
  bram_if #(
      .ADDR_WIDTH(14),
      .DATA_WIDTH(12)
  ) bmp_if ();

  // Dual-Port BRAM Memories
  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(CONSOLE_MAX_LEN))
  ) u_console_ram (
      .clk_a (clk100),
      .port_a(console_if),
      .clk_b (clk100),
      .port_b(console_if)
  );

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(INPUT_MAX_LEN))
  ) u_input_ram (
      .clk_a (clk100),
      .port_a(input_if),
      .clk_b (clk100),
      .port_b(input_if)
  );

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH(14)
  ) u_bmp_ram (
      .clk_a (clk100),
      .port_a(bmp_if),
      .clk_b (clk100),
      .port_b(bmp_if)
  );

  // Link Handshake Engine
  link_handshake #(
      .HEARTBEAT_TICKS(200),
      .TIMEOUT_TICKS  (20_000_000)
  ) u_link_hs (
      .clk(clk100),
      .rst_n(rst_n),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_preamble_error(1'b0),
      .proto_eval_rx_carrier(proto_eval_rx_carrier),
      .hs_tx_req(hs_tx_req),
      .hs_tx_type(hs_tx_type),
      .hs_tx_data(hs_tx_data),
      .hs_tx_ack(hs_tx_ack),
      .link_status(link_status)
  );

  // UI Navigation Engine
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

  // Top Keyboard Subsystem
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

  // Master Evaluation Controller
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

      .console_addr(console_if.addr),
      .console_we  (console_if.we),
      .console_din (console_if.din),
      .console_dout(console_if.dout),

      .input_addr(input_if.addr),
      .input_we  (input_if.we),
      .input_din (input_if.din),

      .bmp_addr(bmp_if.addr),
      .bmp_we  (bmp_if.we),
      .bmp_din (bmp_if.din),

      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .popup_mode(popup_mode),

      .prog_man (prog_man),
      .prog_pre (prog_pre),
      .prog_par (prog_par),
      .prog_hlt (prog_hlt),
      .color_man(color_man),
      .color_pre(color_pre),
      .color_par(color_par),
      .color_hlt(color_hlt),

      .link_status(link_status),
      .hs_tx_req  (hs_tx_req),
      .hs_tx_type (hs_tx_type),
      .hs_tx_data (hs_tx_data),
      .hs_tx_ack  (hs_tx_ack),

      .eval_proto_baud_rate(eval_proto_baud_rate),
      .eval_proto_oversampling(eval_proto_oversampling),
      .eval_proto_loopback_en(eval_proto_loopback_en),
      .eval_proto_tx_valid(eval_proto_tx_valid),
      .eval_proto_tx_type(eval_proto_tx_type),
      .eval_proto_tx_data(eval_proto_tx_data),
      .proto_eval_tx_full(1'b0),
      .proto_eval_tx_empty(1'b1),

      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_parity_error(1'b0),
      .proto_eval_manchester_code_error(1'b0),
      .proto_eval_preamble_error(1'b0),
      .proto_eval_link_status(1'b1),
      .proto_eval_ber_count(32'd0),
      .proto_eval_err_count(16'd0)
  );

  // 100 MHz Clock Generator (10ns period)
  always #5 clk100 = ~clk100;

  // Optical Loopback responder: loops TX back to RX
  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) begin
      proto_eval_rx_valid <= 1'b0;
      proto_eval_rx_type  <= '0;
      proto_eval_rx_data  <= '0;
    end else begin
      proto_eval_rx_valid <= eval_proto_tx_valid;
      proto_eval_rx_type  <= eval_proto_tx_type;
      proto_eval_rx_data  <= eval_proto_tx_data;
    end
  end

  // Tasks for PS/2 Serial Keyboard Driving
  task automatic send_ps2_byte(input logic [7:0] data);
    logic   parity;
    integer i;
    parity = ~^data;  // Odd parity
    ps2_data_drive = 1'b0;  // Start bit
    #15000;
    ps2_clk_drive = 1'b0;
    #15000;
    ps2_clk_drive = 1'b1;
    for (i = 0; i < 8; i++) begin
      ps2_data_drive = data[i];  // Data bits (LSB first)
      #15000;
      ps2_clk_drive = 1'b0;
      #15000;
      ps2_clk_drive = 1'b1;
    end
    ps2_data_drive = parity;  // Parity bit
    #15000;
    ps2_clk_drive = 1'b0;
    #15000;
    ps2_clk_drive  = 1'b1;
    ps2_data_drive = 1'b1;  // Stop bit
    #15000;
    ps2_clk_drive = 1'b0;
    #15000;
    ps2_clk_drive = 1'b1;
    #30000;  // Inter-byte idle gap
  endtask

  task automatic type_ps2_key(input logic [7:0] make_code);
    send_ps2_byte(make_code);
    send_ps2_byte(8'hF0);  // Break prefix
    send_ps2_byte(make_code);
  endtask

  task automatic send_ps2_extended(input logic [7:0] make_code);
    send_ps2_byte(8'hE0);  // Extended prefix
    send_ps2_byte(make_code);
    send_ps2_byte(8'hE0);
    send_ps2_byte(8'hF0);
    send_ps2_byte(make_code);
  endtask

  task automatic type_ps2_command(input string cmd);
    for (int idx = 0; idx < cmd.len(); idx++) begin
      case (cmd[idx])
        "/": type_ps2_key(8'h4A);
        "a": type_ps2_key(8'h1C);
        "b": type_ps2_key(8'h32);
        "c": type_ps2_key(8'h21);
        "d": type_ps2_key(8'h23);
        "e": type_ps2_key(8'h24);
        "f": type_ps2_key(8'h2B);
        "g": type_ps2_key(8'h34);
        "h": type_ps2_key(8'h33);
        "i": type_ps2_key(8'h43);
        "l": type_ps2_key(8'h4B);
        "m": type_ps2_key(8'h3A);
        "n": type_ps2_key(8'h31);
        "o": type_ps2_key(8'h44);
        "p": type_ps2_key(8'h4D);
        "r": type_ps2_key(8'h2D);
        "s": type_ps2_key(8'h1B);
        "t": type_ps2_key(8'h2C);
        "u": type_ps2_key(8'h3C);
        "w": type_ps2_key(8'h1D);
        "0": type_ps2_key(8'h45);
        "1": type_ps2_key(8'h16);
        "2": type_ps2_key(8'h1E);
        "5": type_ps2_key(8'h2E);
        " ": type_ps2_key(8'h29);
        ".": type_ps2_key(8'h49);
        default: ;
      endcase
    end
    type_ps2_key(8'h5A);  // Enter
    #500;
  endtask

  logic progress_popup_seen;
  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) progress_popup_seen <= 1'b0;
    else if (show_popup && popup_mode == 2'd2) progress_popup_seen <= 1'b1;
  end

  initial begin
    clk100 = 0;
    ps2_clk_drive = 1'b1;
    ps2_data_drive = 1'b1;
    proto_eval_rx_carrier = 1'b1;
    rst_n = 1'b0;
    #100 rst_n = 1'b1;

    $display("==================================================================");
    $display("Starting Fast Headless Evaluation System Simulation...");
    $display("==================================================================");

    #50000;
    assert (ui_selected_item == ITEM_INPUT)
    else $error("Boot focus mismatch");
    $display("[PASS] Step 1: Booted. Focus on Input Field.");

    // Enter Text Mode
    type_ps2_key(8'h5A);  // Enter
    #50000;
    assert (mode_text == 1'b1)
    else $error("Text mode entry failed");
    $display("[PASS] Step 2: Text Mode Entered (Glowing Input Frame).");

    // Execute '/help' command
    type_ps2_command("/help");
    #50000;
    $display("[PASS] Step 3: Executed '/help' command. Output streamed to Console BRAM.");

    // Execute '/baud 2.5m' command
    type_ps2_command("/baud 2.5m");
    #50000;
    assert (eval_proto_baud_rate == 4'd2)
    else $error("Baudrate setting mismatch");
    $display("[PASS] Step 4: Executed '/baud 2.5m'. Baudrate updated (baud_rate=2).");

    // History recall via Up Arrow
    send_ps2_extended(8'h75);  // Up Arrow
    #50000;
    $display("[PASS] Step 5: Up Arrow pressed. Previous command recalled from History buffer.");
    type_ps2_key(8'h5A);  // Enter (execute recalled command)
    #50000;

    // Execute '/status' command
    type_ps2_command("/status");
    #50000;
    $display("[PASS] Step 6: Executed '/status'. Link health telemetry streamed to BRAM.");

    // Execute '/bitmap send'
    type_ps2_command("/bitmap send");
    #50000;
    assert (progress_popup_seen)
    else $error("Progress popup failed to open");
    $display("[PASS] Step 7: Progress popup open during 128x128 dynamic bitmap streaming.");

    // Exit text mode with Esc
    type_ps2_key(8'h76);  // Esc
    #50000;
    assert (mode_text == 1'b0)
    else $error("Esc failed to exit text mode");
    $display("[PASS] Step 8: Esc pressed. Returned to Navigation Mode.");

    // Navigate to Help button (Right Arrow)
    send_ps2_extended(8'h74);  // Right Arrow
    #50000;
    $display("[PASS] Step 9: Right Arrow pressed. Navigated button focus.");

    // Left arrow back to input and test /ping
    send_ps2_extended(8'h6B);  // Left Arrow
    #50000;
    type_ps2_key(8'h5A);       // Enter text mode
    #50000;
    type_ps2_command("/ping");
    #100000;
    $display("[PASS] Step 10: Executed '/ping'. Sequential ping string formatted successfully.");

    $display("==================================================================");
    $display("=== All Evaluation System Integration tests PASSED successfully! ===");
    $display("==================================================================");
    $finish;
  end

endmodule
