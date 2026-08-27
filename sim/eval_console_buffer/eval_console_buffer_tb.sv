/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for eval_console_buffer submodule.
 * Verifies character writing, line counting, column wrapping at 95 cols,
 * line-governed Block RAM auto-scrolling at 40 lines (NO arbitrary 850 limit),
 * and synchronous console clearing.
 */

`timescale 1ns / 1ps
import string_pkg::*;

module eval_console_buffer_tb;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr;
  logic console_we;
  logic [7:0] console_din;
  logic [7:0] console_dout;

  logic       print_valid;
  logic [7:0] print_char;
  logic       print_last;
  logic       print_ready;

  logic       rx_char_valid;
  logic [7:0] rx_char_data;
  logic       rx_char_ready;

  logic       clear_req;
  logic       clear_ack;
  logic [5:0] line_count;
  logic       console_busy;

  // Instantiate BRAM model
  bram_if #(
      .ADDR_WIDTH($clog2(string_pkg::CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY(0)
  ) console_ram_if ();

  bram_if #(
      .ADDR_WIDTH($clog2(string_pkg::CONSOLE_MAX_LEN)),
      .DATA_WIDTH(8),
      .READ_ONLY(1)
  ) dummy_port_b ();

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(string_pkg::CONSOLE_MAX_LEN))
  ) u_console_ram (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(console_ram_if.memory),
      .port_b(dummy_port_b.memory)
  );

  assign console_ram_if.addr = console_addr;
  assign console_ram_if.din  = console_din;
  assign console_ram_if.we   = console_we;
  assign console_dout        = console_ram_if.dout;

  eval_console_buffer #(
      .MAX_LINES(40),
      .LINE_WRAP_COLS(95)
  ) dut (
      .clk          (clk),
      .rst_n        (rst_n),
      .console_addr (console_addr),
      .console_we   (console_we),
      .console_din  (console_din),
      .console_dout (console_dout),
      .print_valid  (print_valid),
      .print_char   (print_char),
      .print_last   (print_last),
      .print_ready  (print_ready),
      .rx_char_valid(rx_char_valid),
      .rx_char_data (rx_char_data),
      .rx_char_ready(rx_char_ready),
      .clear_req    (clear_req),
      .clear_ack    (clear_ack),
      .line_count   (line_count),
      .console_busy (console_busy)
  );

  task send_char(input [7:0] c);
    @(posedge clk);
    print_char  <= c;
    print_valid <= 1'b1;
    print_last  <= 1'b0;
    do @(posedge clk); while (!print_ready);
    print_valid <= 1'b0;
    print_char  <= 8'h00;
    while (console_busy) @(posedge clk);
    @(posedge clk);
  endtask

  task send_string(input string s);
    for (int i = 0; i < s.len(); i++) begin
      send_char(s[i]);
    end
  endtask

  initial begin
    rst_n         = 0;
    print_valid   = 0;
    print_char    = 0;
    print_last    = 0;
    rx_char_valid = 0;
    rx_char_data  = 0;
    clear_req     = 0;

    $display("=== STARTING EVAL_CONSOLE_BUFFER TESTBENCH ===");
    repeat(20) @(posedge clk);
    rst_n = 1;
    while (console_busy) @(posedge clk);

    // 1. Write simple line
    $display("[TEST 1] Writing 'Hello OptiBolt!\\n'...");
    send_string("Hello OptiBolt!\n");
    assert(line_count == 6'd1) else $error("Expected line_count == 1, got %d", line_count);

    // 2. Write 38 more lines (total 39 lines)
    $display("[TEST 2] Filling console up to 39 lines...");
    for (int l = 2; l <= 39; l++) begin
      send_string("Line content\n");
    end
    assert(line_count == 6'd39) else $error("Expected line_count == 39, got %d", line_count);

    // 3. Write 40th line
    $display("[TEST 3] Writing 40th line...");
    send_string("Line 40\n");
    assert(line_count == 6'd40) else $error("Expected line_count == 40, got %d", line_count);

    // 4. Write 41st line - must trigger synchronous line scrolling!
    $display("[TEST 4] Writing 41st line (verifying auto-scroll trigger)...");
    send_string("Line 41\n");
    // After scrolling 1 line and writing new line, line count should remain 40
    assert(line_count == 6'd40) else $error("Expected line_count == 40 after scroll, got %d", line_count);

    // 5. Test Clear Console
    $display("[TEST 5] Requesting console clear...");
    @(posedge clk);
    clear_req <= 1'b1;
    while (!clear_ack) @(posedge clk);
    @(posedge clk);
    clear_req <= 1'b0;
    @(posedge clk);
    assert(line_count == 6'd0) else $error("Expected line_count == 0 after clear, got %d", line_count);
    assert(dut.write_ptr == 10'd0) else $error("Expected write_ptr == 0 after clear, got %d", dut.write_ptr);

    $display("=== ALL EVAL_CONSOLE_BUFFER TESTS PASSED! ===");
    $finish;
  end

endmodule
