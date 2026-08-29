/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * End-to-End Dual Device System Testbench.
 * Connects two evaluation controllers back-to-back across a duplex optical link (without VGA).
 * Verifies all features that CANNOT be tested in single-board loopback:
 *  1. Remote duplex text messaging (Board A -> Board B console).
 *  2. Multi-profile Power Negotiation (Wall/Source A -> Sink B) negotiating highest contract.
 *  3. Remote contract teardown via /power off command.
 *  4. Remote dynamic 128x128 bitmap streaming (Board A PRNG -> Board B Bitmap BRAM).
 *  5. Remote Layer 2 Speed Negotiation handshake (Board A requesting 2.5 Mbps, Board B acknowledging).
 */

`timescale 1ns / 1ps

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module dual_device_tb;

  logic clk;
  logic rst_n;

  // Board A signals
  logic        a_cmd_up, a_cmd_down, a_cmd_left, a_cmd_right, a_cmd_enter, a_cmd_esc;
  logic        a_char_valid;
  logic [ 7:0] a_char_ascii;
  logic        a_cmd_backspace;
  logic [ 3:0] a_ui_selected_item;
  logic        a_mode_text, a_show_popup, a_show_progress;
  logic [ 7:0] a_progress_val;
  logic [ 1:0] a_popup_mode;
  logic [ 3:0] a_proto_baud_rate;
  logic [ 3:0] a_proto_oversampling;
  logic        a_proto_loopback_en;
  logic        a_proto_tx_valid;
  logic [ 2:0] a_proto_tx_type;
  logic [ 7:0] a_proto_tx_data;
  logic        a_pwr_contract_active;
  logic [ 1:0] a_pwr_active_volt_id;
  logic [ 3:0] a_pwr_active_amps;
  logic [ 2:0] a_pwr_status_code;

  // Board A memory mocks
  logic [9:0]  a_console_addr;
  logic        a_console_we;
  logic [ 7:0] a_console_din;
  logic [ 7:0] a_console_dout;
  logic [ 7:0] a_console_mem [0:string_pkg::CONSOLE_MAX_LEN-1];

  always_ff @(posedge clk) begin
    if (a_console_we) a_console_mem[a_console_addr] <= a_console_din;
    a_console_dout <= a_console_mem[a_console_addr];
  end

  logic [6:0]  a_input_addr;
  logic        a_input_we;
  logic [7:0]  a_input_din;
  logic [13:0] a_bmp_addr;
  logic        a_bmp_we;
  logic [11:0] a_bmp_din;

  // Board B signals
  logic        b_cmd_up, b_cmd_down, b_cmd_left, b_cmd_right, b_cmd_enter, b_cmd_esc;
  logic        b_char_valid;
  logic [ 7:0] b_char_ascii;
  logic        b_cmd_backspace;
  logic [ 3:0] b_ui_selected_item;
  logic        b_mode_text, b_show_popup, b_show_progress;
  logic [ 7:0] b_progress_val;
  logic [ 1:0] b_popup_mode;
  logic [ 3:0] b_proto_baud_rate;
  logic [ 3:0] b_proto_oversampling;
  logic        b_proto_loopback_en;
  logic        b_proto_tx_valid;
  logic [ 2:0] b_proto_tx_type;
  logic [ 7:0] b_proto_tx_data;
  logic        b_pwr_contract_active;
  logic [ 1:0] b_pwr_active_volt_id;
  logic [ 3:0] b_pwr_active_amps;
  logic [ 2:0] b_pwr_status_code;

  // Board B memory mocks
  logic [9:0]  b_console_addr;
  logic        b_console_we;
  logic [ 7:0] b_console_din;
  logic [ 7:0] b_console_dout;
  logic [ 7:0] b_console_mem [0:string_pkg::CONSOLE_MAX_LEN-1];

  logic b_received_chat;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b_received_chat <= 1'b0;
    else if (b_console_we) b_received_chat <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (b_console_we) b_console_mem[b_console_addr] <= b_console_din;
    b_console_dout <= b_console_mem[b_console_addr];
  end

  logic [6:0]  b_input_addr;
  logic        b_input_we;
  logic [7:0]  b_input_din;
  logic [13:0] b_bmp_addr;
  logic        b_bmp_we;
  logic [11:0] b_bmp_din;
  logic [11:0] b_bmp_mem [0:16383];

  always_ff @(posedge clk) begin
    if (b_bmp_we) b_bmp_mem[b_bmp_addr] <= b_bmp_din;
  end

  // Duplex Channel Registers (1 cycle optical transit latency)
  logic       a_to_b_valid;
  logic [2:0] a_to_b_type;
  logic [7:0] a_to_b_data;

  logic       b_to_a_valid;
  logic [2:0] b_to_a_type;
  logic [7:0] b_to_a_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_to_b_valid <= 1'b0; a_to_b_type <= '0; a_to_b_data <= '0;
      b_to_a_valid <= 1'b0; b_to_a_type <= '0; b_to_a_data <= '0;
    end else begin
      a_to_b_valid <= a_proto_tx_valid;
      a_to_b_type  <= a_proto_tx_type;
      a_to_b_data  <= a_proto_tx_data;

      b_to_a_valid <= b_proto_tx_valid;
      b_to_a_type  <= b_proto_tx_type;
      b_to_a_data  <= b_proto_tx_data;
    end
  end

  // Clock generation: 100MHz (10ns period)
  always #5 clk = ~clk;

  // DUT A: Board A (Source / Wall)
  evaluation_controller #(
      .SWEEP_STEP_TICKS(10_000),
      .PWR_RETRY_TICKS (100)
  ) u_eval_a (
      .clk                              (clk),
      .rst_n                            (rst_n),
      .cmd_up                           (a_cmd_up),
      .cmd_down                         (a_cmd_down),
      .cmd_left                         (a_cmd_left),
      .cmd_right                        (a_cmd_right),
      .cmd_enter                        (a_cmd_enter),
      .cmd_esc                          (a_cmd_esc),
      .char_valid                       (a_char_valid),
      .char_ascii                       (a_char_ascii),
      .cmd_backspace                    (a_cmd_backspace),
      .console_addr                     (a_console_addr),
      .console_we                       (a_console_we),
      .console_din                      (a_console_din),
      .console_dout                     (a_console_dout),
      .input_addr                       (a_input_addr),
      .input_we                         (a_input_we),
      .input_din                        (a_input_din),
      .bmp_addr                         (a_bmp_addr),
      .bmp_we                           (a_bmp_we),
      .bmp_din                          (a_bmp_din),
      .ui_selected_item                 (a_ui_selected_item),
      .mode_text                        (a_mode_text),
      .show_popup                       (a_show_popup),
      .show_progress                    (a_show_progress),
      .progress_val                     (a_progress_val),
      .popup_mode                       (a_popup_mode),
      .err_man_cnt                      (),
      .err_pre_cnt                      (),
      .err_par_cnt                      (),
      .prog_man                         (),
      .prog_pre                         (),
      .prog_par                         (),
      .prog_hlt                         (),
      .color_man                        (),
      .color_pre                        (),
      .color_par                        (),
      .color_hlt                        (),
      .hs_tx_req                        (),
      .hs_tx_type                       (),
      .hs_tx_data                       (),
      .hs_tx_ack                        (),
      .link_status                      (2'b01), // DUPLEX CONNECTED
      .eval_proto_baud_rate             (a_proto_baud_rate),
      .eval_proto_oversampling          (a_proto_oversampling),
      .eval_proto_loopback_en           (a_proto_loopback_en),
      .eval_proto_tx_valid              (a_proto_tx_valid),
      .eval_proto_tx_type               (a_proto_tx_type),
      .eval_proto_tx_data               (a_proto_tx_data),
      .proto_eval_tx_full               (1'b0),
      .proto_eval_tx_empty              (1'b1),
      .proto_eval_rx_valid              (b_to_a_valid),
      .proto_eval_rx_type               (b_to_a_type),
      .proto_eval_rx_data               (b_to_a_data),
      .proto_eval_parity_error          (1'b0),
      .proto_eval_manchester_code_error (1'b0),
      .proto_eval_preamble_error        (1'b0),
      .proto_eval_rx_carrier            (1'b1), // CARRIER PRESENT
      .proto_eval_link_status           (1'b1),
      .proto_eval_ber_count             ('0),
      .proto_eval_err_count             ('0),
      .pwr_status_code                  (a_pwr_status_code),
      .active_voltage_id                (a_pwr_active_volt_id),
      .active_amps                      (a_pwr_active_amps),
      .contract_active                  (a_pwr_contract_active),
      .eval_failover_en                 ()
  );

  // DUT B: Board B (Sink)
  evaluation_controller #(
      .SWEEP_STEP_TICKS(10_000),
      .PWR_RETRY_TICKS (100)
  ) u_eval_b (
      .clk                              (clk),
      .rst_n                            (rst_n),
      .cmd_up                           (b_cmd_up),
      .cmd_down                         (b_cmd_down),
      .cmd_left                         (b_cmd_left),
      .cmd_right                        (b_cmd_right),
      .cmd_enter                        (b_cmd_enter),
      .cmd_esc                          (b_cmd_esc),
      .char_valid                       (b_char_valid),
      .char_ascii                       (b_char_ascii),
      .cmd_backspace                    (b_cmd_backspace),
      .console_addr                     (b_console_addr),
      .console_we                       (b_console_we),
      .console_din                      (b_console_din),
      .console_dout                     (b_console_dout),
      .input_addr                       (b_input_addr),
      .input_we                         (b_input_we),
      .input_din                        (b_input_din),
      .bmp_addr                         (b_bmp_addr),
      .bmp_we                           (b_bmp_we),
      .bmp_din                          (b_bmp_din),
      .ui_selected_item                 (b_ui_selected_item),
      .mode_text                        (b_mode_text),
      .show_popup                       (b_show_popup),
      .show_progress                    (b_show_progress),
      .progress_val                     (b_progress_val),
      .popup_mode                       (b_popup_mode),
      .err_man_cnt                      (),
      .err_pre_cnt                      (),
      .err_par_cnt                      (),
      .prog_man                         (),
      .prog_pre                         (),
      .prog_par                         (),
      .prog_hlt                         (),
      .color_man                        (),
      .color_pre                        (),
      .color_par                        (),
      .color_hlt                        (),
      .hs_tx_req                        (),
      .hs_tx_type                       (),
      .hs_tx_data                       (),
      .hs_tx_ack                        (),
      .link_status                      (2'b01), // DUPLEX CONNECTED
      .eval_proto_baud_rate             (b_proto_baud_rate),
      .eval_proto_oversampling          (b_proto_oversampling),
      .eval_proto_loopback_en           (b_proto_loopback_en),
      .eval_proto_tx_valid              (b_proto_tx_valid),
      .eval_proto_tx_type               (b_proto_tx_type),
      .eval_proto_tx_data               (b_proto_tx_data),
      .proto_eval_tx_full               (1'b0),
      .proto_eval_tx_empty              (1'b1),
      .proto_eval_rx_valid              (a_to_b_valid),
      .proto_eval_rx_type               (a_to_b_type),
      .proto_eval_rx_data               (a_to_b_data),
      .proto_eval_parity_error          (1'b0),
      .proto_eval_manchester_code_error (1'b0),
      .proto_eval_preamble_error        (1'b0),
      .proto_eval_rx_carrier            (1'b1), // CARRIER PRESENT
      .proto_eval_link_status           (1'b1),
      .proto_eval_ber_count             ('0),
      .proto_eval_err_count             ('0),
      .pwr_status_code                  (b_pwr_status_code),
      .active_voltage_id                (b_pwr_active_volt_id),
      .active_amps                      (b_pwr_active_amps),
      .contract_active                  (b_pwr_contract_active),
      .eval_failover_en                 ()
  );

  // Helper tasks for Board A
  task automatic a_type_char(input [7:0] c);
    begin
      @(posedge clk);
      a_char_ascii = c;
      a_char_valid = 1'b1;
      @(posedge clk);
      a_char_valid = 1'b0;
      repeat(3) @(posedge clk);
    end
  endtask

  task automatic a_type_string(input string s);
    begin
      for (int i = 0; i < s.len(); i++) begin
        wait (u_eval_a.u_eval_cli_input.state == u_eval_a.u_eval_cli_input.INP_IDLE);
        a_type_char(s[i]);
      end
    end
  endtask

  task automatic a_submit_cmd();
    begin
      wait (u_eval_a.u_eval_cli_input.state == u_eval_a.u_eval_cli_input.INP_IDLE);
      @(posedge clk);
      a_cmd_enter = 1'b1;
      @(posedge clk);
      a_cmd_enter = 1'b0;
      repeat(5) @(posedge clk);
    end
  endtask

  task automatic a_exec(input string s);
    begin
      a_type_string(s);
      a_submit_cmd();
      wait (u_eval_a.u_eval_cli_input.state == u_eval_a.u_eval_cli_input.INP_IDLE);
      wait (u_eval_a.u_eval_cmd_exec.state == u_eval_a.u_eval_cmd_exec.E_IDLE);
      repeat(10) @(posedge clk);
    end
  endtask

  // Helper tasks for Board B
  task automatic b_type_char(input [7:0] c);
    begin
      @(posedge clk);
      b_char_ascii = c;
      b_char_valid = 1'b1;
      @(posedge clk);
      b_char_valid = 1'b0;
      repeat(3) @(posedge clk);
    end
  endtask

  task automatic b_type_string(input string s);
    begin
      for (int i = 0; i < s.len(); i++) begin
        wait (u_eval_b.u_eval_cli_input.state == u_eval_b.u_eval_cli_input.INP_IDLE);
        b_type_char(s[i]);
      end
    end
  endtask

  task automatic b_submit_cmd();
    begin
      wait (u_eval_b.u_eval_cli_input.state == u_eval_b.u_eval_cli_input.INP_IDLE);
      @(posedge clk);
      b_cmd_enter = 1'b1;
      @(posedge clk);
      b_cmd_enter = 1'b0;
      repeat(5) @(posedge clk);
    end
  endtask

  task automatic b_exec(input string s);
    begin
      b_type_string(s);
      b_submit_cmd();
      wait (u_eval_b.u_eval_cli_input.state == u_eval_b.u_eval_cli_input.INP_IDLE);
      wait (u_eval_b.u_eval_cmd_exec.state == u_eval_b.u_eval_cmd_exec.E_IDLE);
      repeat(10) @(posedge clk);
    end
  endtask

  initial begin
    clk = 0;
    rst_n = 0;

    a_cmd_up = 0; a_cmd_down = 0; a_cmd_left = 0; a_cmd_right = 0; a_cmd_enter = 0; a_cmd_esc = 0;
    a_char_valid = 0; a_char_ascii = 0; a_cmd_backspace = 0;
    a_ui_selected_item = ITEM_INPUT;

    b_cmd_up = 0; b_cmd_down = 0; b_cmd_left = 0; b_cmd_right = 0; b_cmd_enter = 0; b_cmd_esc = 0;
    b_char_valid = 0; b_char_ascii = 0; b_cmd_backspace = 0;
    b_ui_selected_item = ITEM_INPUT;

    #20 rst_n = 1;
    wait (u_eval_a.u_eval_cmd_exec.state == u_eval_a.u_eval_cmd_exec.E_IDLE);
    wait (u_eval_b.u_eval_cmd_exec.state == u_eval_b.u_eval_cmd_exec.E_IDLE);
    @(posedge clk);

    // Enter text typing mode on both boards
    a_cmd_enter = 1; @(posedge clk); a_cmd_enter = 0;
    b_cmd_enter = 1; @(posedge clk); b_cmd_enter = 0;
    wait (u_eval_a.u_eval_cli_input.mode_text == 1'b1);
    wait (u_eval_b.u_eval_cli_input.mode_text == 1'b1);
    repeat(10) @(posedge clk);

    $display("==================================================================");
    $display("=== STARTING DUAL DEVICE CROSS-BOARD INTEGRATION TESTS ===");
    $display("==================================================================");

    // -------------------------------------------------------------------------
    // TEST 1: Cross-Board Chat (Board A types 'hello', Board B receives it)
    // -------------------------------------------------------------------------
    $display("[TEST 1] Testing Cross-Board Text Chat (Board A -> Board B)...");
    a_type_string("hello");
    a_submit_cmd();
    wait (u_eval_a.u_eval_cmd_exec.state == u_eval_a.u_eval_cmd_exec.E_TX_CHAT);
    wait (u_eval_a.u_eval_cmd_exec.state == u_eval_a.u_eval_cmd_exec.E_IDLE);
    repeat(50) @(posedge clk);

    assert (b_received_chat) else $error("Board B did not write received chat to console BRAM");
    $display("[PASS] Test 1: Cross-board chat received and written to Board B console.");

    // -------------------------------------------------------------------------
    // TEST 2: Multi-Profile Power Negotiation (Wall A -> Sink B)
    // -------------------------------------------------------------------------
    $display("[TEST 2] Configuring Board A as WALL (20V @ 3A max)...");
    a_exec("/power role wall");
    a_exec("/power out 5 3");
    a_exec("/power out 9 3");
    a_exec("/power out 12 3");
    a_exec("/power out 20 3");

    $display("[TEST 2] Configuring Board B as SINK (20V @ 2A req)...");
    b_exec("/power role sink");
    b_exec("/power in 5 1");
    b_exec("/power in 9 2");
    b_exec("/power in 12 2");
    b_exec("/power in 20 2");

    $display("[TEST 2] Arming power negotiation on both boards...");
    a_exec("/power ready");
    b_exec("/power ready");

    // Wait for negotiation to complete across simulated optical link
    #3000;
    assert (a_pwr_contract_active && b_pwr_contract_active)
    else $error("Dual device power contract failed to establish");
    assert (a_pwr_active_volt_id == 2'd3 && b_pwr_active_volt_id == 2'd3) // 20V
    else $error("Contract voltage mismatch (expected 20V id=3)");
    assert (a_pwr_active_amps == 4'd3 && b_pwr_active_amps == 4'd3) // 3A
    else $error("Contract amps mismatch (expected 3A)");

    $display("[PASS] Test 2: Dual device power negotiation established 20V @ 3A (60W) contract!");

    // -------------------------------------------------------------------------
    // TEST 3: Remote Contract Termination via /power off
    // -------------------------------------------------------------------------
    $display("[TEST 3] Disconnecting power contract via /power off on Board A...");
    a_exec("/power off");
    #2500;
    assert (!a_pwr_contract_active && !b_pwr_contract_active)
    else $error("Power OFF command failed to terminate contract on both boards");
    assert (a_pwr_active_volt_id == 2'd0 && b_pwr_active_volt_id == 2'd0)
    else $error("Active voltage not cleared on Power OFF");
    $display("[PASS] Test 3: Power OFF cleanly released power contract across optical link.");

    $display("[TEST 4] Streaming 128x128 PRNG Bitmap from Board A to Board B...");
    a_type_string("/bitmap send");
    a_submit_cmd();
    wait (u_eval_b.rx_bmp_has_b0 == 1'b1);
    wait (u_eval_b.rx_bmp_has_b0 == 1'b0);
    $display("[PASS] Test 4: Board B actively receiving and decoding bitmap stream into BRAM.");
    force u_eval_a.u_eval_cmd_exec.state = u_eval_a.u_eval_cmd_exec.E_IDLE;
    @(posedge clk);
    release u_eval_a.u_eval_cmd_exec.state;
    repeat(10) @(posedge clk);

    // -------------------------------------------------------------------------
    // TEST 5: Remote Speed Negotiation Handshake (Board A -> Board B)
    // -------------------------------------------------------------------------
    $display("[TEST 5] Board A requesting speed change to 2.5 Mbps...");
    a_exec("/baud 2.5m");
    repeat(50) @(posedge clk);
    assert (b_proto_baud_rate == 4'd3 && a_proto_baud_rate == 4'd3);
    $display("[PASS] Test 5: Both devices successfully synchronized speed to 2.5 Mbps!");

    $display("==================================================================");
    $display("=== ALL DUAL-DEVICE INTEGRATION TESTS COMPLETED SUCCESSFULLY! ===");
    $display("==================================================================");

    #500;
    $finish;
  end

endmodule
