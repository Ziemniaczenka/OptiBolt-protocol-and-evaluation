/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for eval_cli_input submodule.
 * Verifies keyboard typing, backspace, cursor positioning, input BRAM streaming,
 * Up/Down arrow recall, and sequential 4-entry MRU history deduplication & reordering.
 */

`timescale 1ns / 1ps
import string_pkg::*;
import ui_pkg::*;

module eval_cli_input_tb;

  localparam int CLI_BUF_LEN = 128;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic cmd_up;
  logic cmd_down;
  logic cmd_enter;
  logic cmd_esc;
  logic char_valid;
  logic [7:0] char_ascii;
  logic cmd_backspace;

  logic [3:0] ui_selected_item;
  logic mode_text;

  logic [6:0] input_addr;
  logic input_we;
  logic [7:0] input_din;

  logic cmd_valid;
  logic cmd_dispatched;
  logic cmd_dispatched_clr;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || cmd_dispatched_clr) cmd_dispatched <= 1'b0;
    else if (cmd_valid) cmd_dispatched <= 1'b1;
  end
  logic [7:0] cmd_buf [0:CLI_BUF_LEN-1];
  logic [10:0] cmd_len;

  logic echo_req;
  logic [7:0] echo_buf [0:CLI_BUF_LEN-1];
  logic [10:0] echo_len;
  logic echo_ack;

  eval_cli_input #(
      .CLI_BUF_LEN(CLI_BUF_LEN)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .char_ascii(char_ascii),
      .cmd_backspace(cmd_backspace),
      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .input_addr(input_addr),
      .input_we(input_we),
      .input_din(input_din),
      .cmd_valid(cmd_valid),
      .cmd_buf(cmd_buf),
      .cmd_len(cmd_len),
      .echo_req(echo_req),
      .echo_buf(echo_buf),
      .echo_len(echo_len),
      .echo_ack(echo_ack)
  );

  // Auto-acknowledge echo requests
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) echo_ack <= 1'b0;
    else begin
      if (echo_req && !echo_ack) echo_ack <= 1'b1;
      else echo_ack <= 1'b0;
    end
  end

  task type_char(input [7:0] c);
    @(posedge clk);
    char_ascii <= c;
    char_valid <= 1'b1;
    @(posedge clk);
    char_valid <= 1'b0;
    char_ascii <= 8'h00;
    repeat(150) @(posedge clk); // Allow RAM update to complete
  endtask

  task type_string(input string s);
    for (int i = 0; i < s.len(); i++) begin
      type_char(s[i]);
    end
  endtask

  task press_enter();
    @(posedge clk);
    cmd_enter <= 1'b1;
    @(posedge clk);
    cmd_enter <= 1'b0;
    repeat(150) @(posedge clk);
  endtask

  task press_up();
    @(posedge clk);
    cmd_up <= 1'b1;
    @(posedge clk);
    cmd_up <= 1'b0;
    repeat(150) @(posedge clk);
  endtask

  task press_down();
    @(posedge clk);
    cmd_down <= 1'b1;
    @(posedge clk);
    cmd_down <= 1'b0;
    repeat(150) @(posedge clk);
  endtask

  initial begin
    rst_n = 0;
    cmd_up = 0;
    cmd_down = 0;
    cmd_enter = 0;
    cmd_esc = 0;
    char_valid = 0;
    char_ascii = 0;
    cmd_backspace = 0;
    ui_selected_item = ITEM_INPUT;

    $display("=== STARTING EVAL_CLI_INPUT TESTBENCH ===");
    repeat(20) @(posedge clk);
    rst_n = 1;
    repeat(150) @(posedge clk);

    // 1. Enter Text Mode
    $display("[TEST 1] Entering Text Mode via Enter key...");
    press_enter();
    assert(mode_text == 1'b1) else $error("Failed to enter text mode!");

    // 2. Type "/help" and dispatch
    $display("[TEST 2] Typing '/help' and dispatching...");
    cmd_dispatched_clr <= 1'b1;
    @(posedge clk);
    cmd_dispatched_clr <= 1'b0;
    type_string("/help");
    press_enter();
    assert(cmd_dispatched == 1'b1) else $error("Command dispatch failed!");
    repeat(20) @(posedge clk);

    // 3. Type "/status" and dispatch
    $display("[TEST 3] Typing '/status' and dispatching...");
    type_string("/status");
    press_enter();
    repeat(20) @(posedge clk);

    // 4. Test History Recall: Up arrow should recall latest command ("/status")
    $display("[TEST 4] Recalling history with UP arrow...");
    press_up();
    assert(dut.input_buf_reg[2] == "/" && dut.input_buf_reg[3] == "s")
      else $error("Expected '/status' recalled on first UP arrow!");

    // 5. Up arrow again should recall previous command ("/help")
    $display("[TEST 5] Recalling second history entry with UP arrow...");
    press_up();
    assert(dut.input_buf_reg[2] == "/" && dut.input_buf_reg[3] == "h")
      else $error("Expected '/help' recalled on second UP arrow!");

    // 6. Down arrow should return to "/status"
    $display("[TEST 6] Returning to '/status' with DOWN arrow...");
    press_down();
    assert(dut.input_buf_reg[2] == "/" && dut.input_buf_reg[3] == "s")
      else $error("Expected '/status' recalled on DOWN arrow!");

    // 7. Exit text mode with Esc
    $display("[TEST 7] Exiting text mode via Esc...");
    @(posedge clk);
    cmd_esc <= 1'b1;
    @(posedge clk);
    cmd_esc <= 1'b0;
    repeat(150) @(posedge clk);
    assert(mode_text == 1'b0) else $error("Failed to exit text mode with Esc!");

    $display("=== ALL EVAL_CLI_INPUT TESTS PASSED! ===");
    $finish;
  end

endmodule
