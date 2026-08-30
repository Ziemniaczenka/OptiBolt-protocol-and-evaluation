/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for link_handshake module.
 * Tests Disconnected, Loopback, and Connected (remote board) handshake flows with optical carrier detection.
 */

`timescale 1ns / 1ps

import protocol_pkg::*;

module link_handshake_tb;

  logic clk;
  logic rst_n;

  // Protocol RX signals
  logic       proto_eval_rx_valid;
  logic [2:0] proto_eval_rx_type;
  logic [7:0] proto_eval_rx_data;
  logic       proto_eval_preamble_error;
  logic       proto_eval_rx_carrier;

  // Handshake TX signals
  logic       hs_tx_req;
  logic [2:0] hs_tx_type;
  logic [7:0] hs_tx_data;
  logic       hs_tx_ack;

  // Link status output
  logic [1:0] link_status;

  // 100 MHz Clock (10ns period)
  always #5 clk = ~clk;

  link_handshake #(
      .RETRY_TICKS(20)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_manchester_code_error(1'b0),
      .proto_eval_preamble_error(proto_eval_preamble_error),
      .proto_eval_rx_carrier(proto_eval_rx_carrier),
      .speed_updated_pulse(1'b0),
      .hs_tx_req(hs_tx_req),
      .hs_tx_type(hs_tx_type),
      .hs_tx_data(hs_tx_data),
      .hs_tx_ack(hs_tx_ack),
      .link_status(link_status)
  );

  logic [7:0] captured_challenge;

  initial begin
    clk = 0;
    rst_n = 0;
    proto_eval_rx_valid = 0;
    proto_eval_rx_type = 3'b000;
    proto_eval_rx_data = 8'h00;
    proto_eval_preamble_error = 0;
    proto_eval_rx_carrier = 0;
    hs_tx_ack = 0;

    #20 rst_n = 1;
    #10;

    // Test 1: Verify Initial Boot state is DISCONNECTED (2'b00)
    assert (link_status == 2'b00) else $error("Test 1 Failed: Expected DISCONNECTED");
    $display("[PASS] Test 1: Initial state is DISCONNECTED (link_status=%b)", link_status);

    // Simulate optical cable plugged in -> light carrier detected on receiver
    #30;
    @(posedge clk);
    proto_eval_rx_carrier = 1'b1;

    // Wait for challenge packet request triggered by carrier detection
    wait (hs_tx_req == 1'b1);
    captured_challenge = hs_tx_data;
    $display("Optical carrier detected -> challenge token latched: 0x%02X", captured_challenge);
    @(posedge clk);
    hs_tx_ack = 1'b1;
    @(posedge clk);
    hs_tx_ack = 1'b0;

    // Test 2: Simulate LOOPBACK (send back our own challenge token)
    #30;
    @(posedge clk);
    proto_eval_rx_valid = 1'b1;
    proto_eval_rx_type  = MSG_CAPABILITIES;
    proto_eval_rx_data  = captured_challenge; // Same token
    @(posedge clk);
    proto_eval_rx_valid = 1'b0;
    #10;
    assert (link_status == 2'b10) else $error("Test 2 Failed: Expected LOOPBACK (2'b10)");
    $display("[PASS] Test 2: Own token returned -> LOOPBACK detected (link_status=%b)", link_status);

    // Test 3: Simulate CONNECTED to Remote Board (remote board sends different token)
    #50;
    // Reset from loopback first so test can verify duplex transition
    @(posedge clk);
    proto_eval_rx_carrier = 1'b0;
    #10;
    proto_eval_rx_carrier = 1'b1;
    wait (hs_tx_req == 1'b1);
    captured_challenge = hs_tx_data;
    @(posedge clk);
    hs_tx_ack = 1'b1;
    @(posedge clk);
    hs_tx_ack = 1'b0;

    @(posedge clk);
    proto_eval_rx_valid = 1'b1;
    proto_eval_rx_type  = MSG_CAPABILITIES;
    proto_eval_rx_data  = 8'h77; // Different token from another board
    @(posedge clk);
    proto_eval_rx_valid = 1'b0;

    // Verify module requested ACK transmission
    wait (hs_tx_req == 1'b1);
    assert (hs_tx_type == MSG_ACCEPT && hs_tx_data == 8'h77) else $error("Test 3 Failed: Expected MSG_ACCEPT request");
    $display("[PASS] Test 3a: Response MSG_ACCEPT requested with payload 0x%02X", hs_tx_data);
    @(posedge clk);
    hs_tx_ack = 1'b1;
    @(posedge clk);
    hs_tx_ack = 1'b0;

    // Remote board also ACKs our token to establish 2-way duplex link
    @(posedge clk);
    proto_eval_rx_valid = 1'b1;
    proto_eval_rx_type  = MSG_ACCEPT;
    proto_eval_rx_data  = captured_challenge;
    @(posedge clk);
    proto_eval_rx_valid = 1'b0;
    #10;
    assert (link_status == 2'b01) else $error("Test 3 Failed: Expected CONNECTED (2'b01)");
    $display("[PASS] Test 3b: Remote ACK received -> CONNECTED detected (link_status=%b)", link_status);

    // Test 4: Simulate DISCONNECT (Unplug optical cable -> carrier drops)
    $display("Unplugging optical cable (carrier drops to 0)...");
    @(posedge clk);
    proto_eval_rx_carrier = 1'b0;
    #10;
    assert (link_status == 2'b00) else $error("Test 4 Failed: Expected DISCONNECTED (2'b00)");
    $display("[PASS] Test 4: Optical carrier loss -> DISCONNECTED detected (link_status=%b)", link_status);

    $display("All link_handshake tests completed successfully!");
    $finish;
  end

endmodule
