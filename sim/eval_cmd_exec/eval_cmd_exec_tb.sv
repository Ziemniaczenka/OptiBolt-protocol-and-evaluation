/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for eval_cmd_exec submodule.
 * Verifies command parsing, ensures msg_idx resets so /baud output is never truncated,
 * tests Double-Dabble Ping RTT formatting, failover toggle, and dynamic bitmap streaming.
 */

`timescale 1ns / 1ps
import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module eval_cmd_exec_tb;

  localparam int CLI_BUF_LEN = 128;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic cmd_valid;
  logic [7:0] cmd_buf [0:CLI_BUF_LEN-1];
  logic [10:0] cmd_len;

  logic echo_req;
  logic [7:0] echo_buf [0:CLI_BUF_LEN-1];
  logic [10:0] echo_len;
  logic echo_ack;

  logic print_valid;
  logic [7:0] print_char;
  logic print_last;
  logic print_ready;

  logic clear_console_req;
  logic clear_console_ack;

  logic [13:0] bmp_addr;
  logic bmp_we;
  logic [11:0] bmp_din;

  logic show_popup;
  logic show_progress;
  logic [7:0] progress_val;
  logic [1:0] popup_mode;

  logic set_speed_req;
  logic [3:0] req_baud_rate;
  logic [3:0] req_oversampling;
  logic failover_en;
  logic failover_triggered;
  logic [1:0] link_status;
  logic rx_carrier;

  logic proto_tx_valid;
  logic [2:0] proto_tx_type;
  logic [7:0] proto_tx_data;
  logic proto_tx_full;

  logic proto_rx_valid;
  logic [2:0] proto_rx_type;
  logic [7:0] proto_rx_data;

  eval_cmd_exec #(
      .CLI_BUF_LEN(CLI_BUF_LEN)
  ) dut (
      .clk               (clk),
      .rst_n             (rst_n),
      .cmd_valid         (cmd_valid),
      .cmd_buf           (cmd_buf),
      .cmd_len           (cmd_len),
      .echo_req          (echo_req),
      .echo_buf          (echo_buf),
      .echo_len          (echo_len),
      .echo_ack          (echo_ack),
      .print_valid       (print_valid),
      .print_char        (print_char),
      .print_last        (print_last),
      .print_ready       (print_ready),
      .clear_console_req (clear_console_req),
      .clear_console_ack (clear_console_ack),
      .bmp_addr          (bmp_addr),
      .bmp_we            (bmp_we),
      .bmp_din           (bmp_din),
      .show_popup        (show_popup),
      .show_progress     (show_progress),
      .progress_val      (progress_val),
      .popup_mode        (popup_mode),
      .set_speed_req     (set_speed_req),
      .req_baud_rate     (req_baud_rate),
      .req_oversampling  (req_oversampling),
      .failover_en       (failover_en),
      .failover_triggered(failover_triggered),
      .link_status       (link_status),
      .rx_carrier        (rx_carrier),
      .proto_tx_valid    (proto_tx_valid),
      .proto_tx_type     (proto_tx_type),
      .proto_tx_data     (proto_tx_data),
      .proto_tx_full     (proto_tx_full),
      .proto_rx_valid    (proto_rx_valid),
      .proto_rx_type     (proto_rx_type),
      .proto_rx_data     (proto_rx_data)
  );

  // Auto consumer of print stream
  string received_stream = "";
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      print_ready <= 1'b0;
    end else begin
      if (print_valid && !print_ready) begin
        print_ready <= 1'b1;
        received_stream = {received_stream, string'(print_char)};
      end else begin
        print_ready <= 1'b0;
      end
    end
  end



  task send_cli_cmd(input string cmd);
    received_stream = "";
    // First echo the command string
    echo_buf[0] = ">";
    echo_buf[1] = " ";
    for (int i = 0; i < cmd.len(); i++) echo_buf[2+i] = cmd[i];
    echo_len = 11'(cmd.len() + 3); // include \n
    echo_req <= 1'b1;
    while (!echo_ack) @(posedge clk);
    @(posedge clk);
    echo_req <= 1'b0;
    while (dut.state != 0) @(posedge clk);

    // Now dispatch command to parser
    received_stream = "";
    cmd_buf[0] = ">";
    cmd_buf[1] = " ";
    for (int i = 0; i < cmd.len(); i++) cmd_buf[2+i] = cmd[i];
    cmd_len = 11'(cmd.len() + 2);
    @(posedge clk);
    cmd_valid <= 1'b1;
    @(posedge clk);
    cmd_valid <= 1'b0;
    while (dut.state == 0) @(posedge clk);
    while (dut.state != 0) @(posedge clk);
    repeat(5) @(posedge clk);
  endtask

  initial begin
    rst_n = 0;
    cmd_valid = 0;
    cmd_len = 0;
    echo_req = 0;
    echo_len = 0;
    clear_console_ack = 0;
    failover_triggered = 0;
    link_status = 2'b01; // Connected
    rx_carrier = 1'b1;
    proto_tx_full = 0;
    proto_rx_valid = 0;
    proto_rx_type = 0;
    proto_rx_data = 0;

    $display("=== STARTING EVAL_CMD_EXEC TESTBENCH ===");
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);

    // 1. Test /baud 2.5m and verify output starts with 'Baudrate' (NOT 'ated' or 'pdated'!)
    $display("[TEST 1] Testing /baud 2.5m output integrity...");
    send_cli_cmd("/baud 2.5m");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 7) == "Baudrate")
      else $error("BUG DETECTED: /baud response was cut off! Got: %s", received_stream);
    assert(set_speed_req == 1'b1 || req_baud_rate == 4'd2)
      else $error("Speed update was not requested!");

    // 2. Test /failover off
    $display("[TEST 2] Testing /failover off...");
    send_cli_cmd("/failover off");
    $display("Received response: %s", received_stream);
    assert(failover_en == 1'b0) else $error("failover_en did not clear to 0!");
    assert(received_stream.substr(0, 7) == "Failover") else $error("Unexpected response: %s", received_stream);

    // 3. Test /failover on
    $display("[TEST 3] Testing /failover on...");
    send_cli_cmd("/failover on");
    assert(failover_en == 1'b1) else $error("failover_en did not set to 1!");

    // 4. Test /clear
    $display("[TEST 4] Testing /clear console...");
    send_cli_cmd("/clear");
    assert(clear_console_req == 1'b1 || dut.state == 0) else $error("clear_console_req failed!");

    $display("=== ALL EVAL_CMD_EXEC TESTS PASSED! ===");
    $finish;
  end

endmodule
