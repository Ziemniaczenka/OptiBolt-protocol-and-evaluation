/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for optibolt_link_manager submodule.
 * Verifies baudrate configuration, negotiation packets, toggleable failover,
 * and automatic fallback to default speed (1.0 Mbps, 16x OS) on excessive errors.
 */

`timescale 1ns / 1ps
import protocol_pkg::*;

module optibolt_link_manager_tb;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic [1:0] link_status;
  logic       rx_carrier;
  logic       par_err;
  logic       man_err;
  logic       pre_err;

  logic       failover_en;
  logic       set_speed_req;
  logic [3:0] req_baud_rate;
  logic [3:0] req_oversampling;
  logic       set_loopback_req;
  logic       req_loopback_en;

  logic       proto_rx_valid;
  logic [2:0] proto_rx_type;
  logic [7:0] proto_rx_data;
  logic       nego_tx_valid;
  logic [2:0] nego_tx_type;
  logic [7:0] nego_tx_data;

  logic [3:0] active_baud_rate;
  logic [3:0] active_oversampling;
  logic       active_loopback_en;
  logic       failover_triggered;
  logic       speed_nego_in_progress;
  logic       speed_updated_pulse;

  logic proto_eval_tx_empty;

  optibolt_link_manager #(
      .DEFAULT_BAUD_RATE   (4'd1), // 1.0 Mbps
      .DEFAULT_OVERSAMPLING(4'd0)  // 8x OS
  ) dut (
      .clk                             (clk),
      .rst_n                           (rst_n),
      .link_status                     (link_status),
      .rx_carrier                      (rx_carrier),
      .proto_eval_parity_error         (par_err),
      .proto_eval_manchester_code_error(man_err),
      .proto_eval_preamble_error       (pre_err),
      .failover_en                     (failover_en),
      .sweep_active                    (1'b0),
      .set_speed_req                   (set_speed_req),
      .req_baud_rate                   (req_baud_rate),
      .req_oversampling                (req_oversampling),
      .set_loopback_req                (set_loopback_req),
      .req_loopback_en                 (req_loopback_en),
      .proto_rx_valid                  (proto_rx_valid),
      .proto_rx_type                   (proto_rx_type),
      .proto_rx_data                   (proto_rx_data),
      .nego_tx_valid                   (nego_tx_valid),
      .nego_tx_type                    (nego_tx_type),
      .nego_tx_data                    (nego_tx_data),
      .active_baud_rate                (active_baud_rate),
      .active_oversampling             (active_oversampling),
      .active_loopback_en              (active_loopback_en),
      .failover_triggered              (failover_triggered),
      .speed_nego_in_progress          (speed_nego_in_progress),
      .speed_updated_pulse             (speed_updated_pulse),
      .proto_eval_tx_empty             (proto_eval_tx_empty)
  );

  logic failover_seen;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) failover_seen <= 1'b0;
    else if (failover_triggered) failover_seen <= 1'b1;
  end

  initial begin
    rst_n = 0;
    link_status = 2'b01; // Connected
    rx_carrier = 1'b1;
    par_err = 0;
    man_err = 0;
    pre_err = 0;
    failover_en = 1'b1;
    set_speed_req = 0;
    req_baud_rate = 4'd1;
    req_oversampling = 4'd0;
    set_loopback_req = 0;
    req_loopback_en = 0;
    proto_rx_valid = 0;
    proto_rx_type = 0;
    proto_rx_data = 0;
    proto_eval_tx_empty = 1'b1;

    $display("=== STARTING OPTIBOLT_LINK_MANAGER TESTBENCH ===");
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);

    // 1. Initial State: Default speed 1.0 Mbps (index 1)
    $display("[TEST 1] Verifying default speed...");
    assert(active_baud_rate == 4'd1) else $error("Expected default baud 1, got %d", active_baud_rate);
    assert(active_oversampling == 4'd0) else $error("Expected default os 0, got %d", active_oversampling);

    // 2. Request speed change to 2.5 Mbps (index 2) while connected
    $display("[TEST 2] Requesting speed negotiation to 2.5 Mbps...");
    @(posedge clk);
    req_baud_rate    <= 4'd2;
    req_oversampling <= 4'd0;
    set_speed_req    <= 1'b1;
    @(posedge clk);
    #1;
    assert(nego_tx_valid == 1'b1 && nego_tx_type == MSG_REQUEST)
      else $error("Expected negotiation TX packet!");
    set_speed_req <= 1'b0;

    // Simulate remote acknowledge (MSG_REQUEST with CMD_SPEED_ACK)
    @(posedge clk);
    proto_rx_valid <= 1'b1;
    proto_rx_type  <= MSG_REQUEST;
    proto_rx_data  <= CMD_SPEED_ACK;
    @(posedge clk);
    proto_rx_valid <= 1'b0;
    repeat(2) @(posedge clk);

    assert(active_baud_rate == 4'd2) else $error("Expected active baud 2, got %d", active_baud_rate);

    // 3. Inject excessive errors with failover_en == 1
    $display("[TEST 3] Injecting excessive errors to trigger failover...");
    repeat(205) begin
      @(posedge clk);
      par_err <= 1'b1;
      @(posedge clk);
      par_err <= 1'b0;
    end
    @(posedge clk);

    assert(failover_seen == 1'b1) else $error("Failover alert pulse was not triggered!");
    assert(active_baud_rate == 4'd1) else $error("Expected baud rate to drop to default 1.0 Mbps (1), got %d", active_baud_rate);

    // 4. Test Disable Failover
    $display("[TEST 4] Disabling failover and verifying no speed drop...");
    failover_en <= 1'b0;
    // Set to 2.5 Mbps directly in loopback
    link_status <= 2'b10;
    @(posedge clk);
    req_baud_rate <= 4'd2;
    set_speed_req <= 1'b1;
    @(posedge clk);
    set_speed_req <= 1'b0;
    @(posedge clk);
    assert(active_baud_rate == 4'd2) else $error("Failed to set 2.5 Mbps in loopback");

    // Inject errors again
    repeat(205) begin
      @(posedge clk);
      par_err <= 1'b1;
      @(posedge clk);
      par_err <= 1'b0;
    end
    @(posedge clk);

    assert(active_baud_rate == 4'd2) else $error("Speed dropped despite failover disabled!");

    $display("=== ALL OPTIBOLT_LINK_MANAGER TESTS PASSED! ===");
    $finish;
  end

endmodule
