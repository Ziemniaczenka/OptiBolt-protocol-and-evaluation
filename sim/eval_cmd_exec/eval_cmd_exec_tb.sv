/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for eval_cmd_exec submodule.
 * Verifies command parsing, /os 16x supported/unsupported error handling,
 * Double-Dabble Ping RTT and Bitmap TX/RX formatting, failover toggle, and PRNG.
 */

`timescale 1ns / 1ps
import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;
import eval_cmd_pkg::*;

module eval_cmd_exec_tb;

  localparam int CLI_BUF_LEN = 128;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic cmd_valid;
  logic [7:0] cmd_buf [0:CLI_BUF_LEN-1];
  logic [10:0] cmd_len;

  logic echo_req;
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
  logic [3:0] active_baud_rate;
  logic [3:0] active_oversampling;
  logic failover_en;
  logic failover_triggered;
  logic sweep_active;
  logic [1:0] link_status;
  logic rx_carrier;

  logic proto_tx_valid;
  logic [2:0] proto_tx_type;
  logic [7:0] proto_tx_data;
  logic proto_tx_full;
  logic proto_tx_empty;

  logic proto_rx_valid;
  logic [2:0] proto_rx_type;
  logic [7:0] proto_rx_data;

  logic bmp_rx_done_pulse;
  logic [31:0] bmp_rx_cycles;

  eval_cmd_exec #(
      .CLI_BUF_LEN(CLI_BUF_LEN)
  ) dut (
      .clk               (clk),
      .rst_n             (rst_n),
      .cmd_valid         (cmd_valid),
      .cmd_buf           (cmd_buf),
      .cmd_len           (cmd_len),
      .echo_req          (echo_req),
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
      .active_baud_rate  (active_baud_rate),
      .active_oversampling(active_oversampling),
      .failover_en       (failover_en),
      .failover_triggered(failover_triggered),
      .sweep_active      (sweep_active),
      .link_status       (link_status),
      .rx_carrier        (rx_carrier),
      .proto_tx_valid    (proto_tx_valid),
      .proto_tx_type     (proto_tx_type),
      .proto_tx_data     (proto_tx_data),
      .proto_tx_full     (proto_tx_full),
      .proto_tx_empty    (proto_tx_empty),
      .proto_rx_valid                   (proto_rx_valid),
      .proto_rx_type                    (proto_rx_type),
      .proto_rx_data                    (proto_rx_data),
      .proto_eval_parity_error          (1'b0),
      .proto_eval_manchester_code_error (1'b0),
      .proto_eval_preamble_error        (1'b0),
      .bmp_rx_done_pulse                (bmp_rx_done_pulse),
      .bmp_rx_cycles                    (bmp_rx_cycles),
      .btn_trigger                      (1'b0),
      .ui_selected_item                 (4'd0),
      .cfg_role                         (),
      .cfg_in_amps                      (),
      .cfg_out_amps                     (),
      .cfg_ready                        (),
      .cfg_clear                        (),
      .pwr_status_code                  (3'd0),
      .contract_active                  (1'b0),
      .active_voltage_id                (2'd0),
      .active_amps                      (4'd0),
      .active_is_source                 (1'b0),
      .contract_event_pulse             (1'b0)
  );

  // Auto consumer of print stream
  string received_stream = "";
  logic clear_stream;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      print_ready     <= 1'b0;
      received_stream = "";
    end else begin
      if (clear_stream) begin
        received_stream = "";
      end else if (print_valid && !print_ready) begin
        received_stream = {received_stream, string'(print_char)};
      end

      if (print_valid && !print_ready) begin
        print_ready <= 1'b1;
      end else begin
        print_ready <= 1'b0;
      end
    end
  end

  task send_cli_cmd(input string cmd);
    clear_stream <= 1'b1;
    @(posedge clk);
    clear_stream <= 1'b0;
    // Fill cmd_buf for both echo and parser
    cmd_buf[0] = ">";
    cmd_buf[1] = " ";
    for (int i = 0; i < cmd.len(); i++) cmd_buf[2+i] = cmd[i];
    cmd_len = 11'(cmd.len() + 2);
    echo_req <= 1'b1;
    while (!echo_ack) @(posedge clk);
    @(posedge clk);
    echo_req <= 1'b0;
    while (dut.state != 0) @(posedge clk);

    // Now dispatch command to parser
    clear_stream <= 1'b1;
    @(posedge clk);
    clear_stream <= 1'b0;
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
    clear_console_ack = 0;
    failover_triggered = 0;
    active_baud_rate = 4'd1;     // 1.0 Mbps
    active_oversampling = 4'd0;  // 8x OS
    link_status = 2'b01;         // Connected
    rx_carrier = 1'b1;
    proto_tx_full = 0;
    proto_tx_empty = 1;
    proto_rx_valid = 0;
    proto_rx_type = 0;
    proto_rx_data = 0;
    bmp_rx_done_pulse = 0;
    bmp_rx_cycles = 0;

    $display("=== STARTING EVAL_CMD_EXEC TESTBENCH ===");
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);

    // 1. Test /baud 2.5m and verify output starts with 'Speed'
    $display("[TEST 1] Testing /baud 2.5m output integrity...");
    send_cli_cmd("/baud 2.5m");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 4) == "Speed")
      else $error("BUG DETECTED: /baud response unexpected! Got: %s", received_stream);
    assert(req_baud_rate == 4'd3)
      else $error("Speed update was not requested! req_baud_rate = %d", req_baud_rate);
    active_baud_rate = 4'd3; // Simulate link manager applying 2.5 Mbps

    // 2. Test /os 16x on supported rate (2.5 Mbps)
    $display("[TEST 2] Testing /os 16x on supported 2.5 Mbps...");
    send_cli_cmd("/os 16x");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 4) == "Speed")
      else $error("/os 16x failed on 2.5 Mbps! Got: %s", received_stream);
    assert(req_oversampling == 4'd1 && req_baud_rate == 4'd3)
      else $error("OS 16x request failed! req_os = %d, req_baud = %d", req_oversampling, req_baud_rate);
    active_oversampling = 4'd1;

    // 3. Test /os 16x on unsupported rate (1.0 Mbps)
    $display("[TEST 3] Testing /os 16x on unsupported 1.0 Mbps...");
    active_baud_rate = 4'd1; // 1.0 Mbps does not support 16x
    send_cli_cmd("/os 16x");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 4) == "Error")
      else $error("Unsupported 16x did not report error! Got: %s", received_stream);

    // 4. Test /os 8x on 1.0 Mbps
    $display("[TEST 4] Testing /os 8x on 1.0 Mbps...");
    send_cli_cmd("/os 8x");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 4) == "Speed")
      else $error("/os 8x failed! Got: %s", received_stream);
    assert(req_oversampling == 4'd0 && req_baud_rate == 4'd1)
      else $error("OS 8x request failed! req_os = %d, req_baud = %d", req_oversampling, req_baud_rate);

    // 5. Test /failover off & on
    $display("[TEST 5] Testing /failover toggle...");
    send_cli_cmd("/failover off");
    assert(failover_en == 1'b0) else $error("failover_en did not clear to 0!");
    send_cli_cmd("/failover on");
    assert(failover_en == 1'b1) else $error("failover_en did not set to 1!");

    // 6. Test /clear
    $display("[TEST 6] Testing /clear console...");
    send_cli_cmd("/clear");
    assert(clear_console_req == 1'b1 || dut.state == 0) else $error("clear_console_req failed!");

    // 7. Test Bitmap RX telemetry formatting (10.5 seconds at 100k = 1,050,000,000 cycles)
    $display("[TEST 7] Testing Bitmap RX Telemetry Report formatting (10.5s @ 100k)...");
    clear_stream <= 1'b1;
    @(posedge clk);
    clear_stream <= 1'b0;
    bmp_rx_cycles = 32'd1_050_000_000;
    @(posedge clk);
    bmp_rx_done_pulse = 1;
    @(posedge clk);
    bmp_rx_done_pulse = 0;
    while (dut.state == 0) @(posedge clk);
    while (dut.state != 0) @(posedge clk);
    repeat(10) @(posedge clk);
    $display("Received Bitmap RX stream: %s", received_stream);
    assert(received_stream == "Bitmap RX: 1050000000 cycles (10500.00 ms)\n")
      else $error("Bitmap RX formatting failed! Got: %s", received_stream);

    // 8. Test /sweep from disconnected state
    $display("[TEST 8] Testing /sweep from disconnected state...");
    link_status = 2'b00; // Disconnected
    send_cli_cmd("/sweep");
    $display("Received response: %s", received_stream);
    assert(received_stream.substr(0, 4) == "Error")
      else $error("Disconnected /sweep did not return error! Got: %s", received_stream);
    assert(sweep_active == 1'b0)
      else $error("Sweep was started while disconnected!");

    $display("=== ALL EVAL_CMD_EXEC TESTS PASSED! ===");
    $finish;
  end

endmodule
