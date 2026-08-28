/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Comprehensive unit testbench for power_negotiator.sv.
 * Tests:
 * 1. Loopback mode inhibition.
 * 2. Successful Wall (Source) -> Sink 20V@5A negotiation.
 * 3. Incompatible current requirements rejection.
 * 4. Role conflict handling (WALL <-> WALL).
 */

`timescale 1ns / 1ps

module power_negotiator_tb;

  import protocol_pkg::*;

  logic clk;
  logic rst_n;

  // Board A signals (Source / Wall)
  logic [1:0] a_link_status;
  logic [1:0] a_cfg_role;
  logic [3:0] a_cfg_in_amps[4];
  logic [3:0] a_cfg_out_amps[4];
  logic       a_cfg_ready;
  logic       a_cfg_clear;
  logic [2:0] a_pwr_status;
  logic       a_contract_active;
  logic       a_contract_error;
  logic [1:0] a_active_volt_id;
  logic [3:0] a_active_amps;
  logic       a_active_is_source;
  logic       a_event_pulse;
  logic       a_tx_valid;
  logic [2:0] a_tx_type;
  logic [7:0] a_tx_data;

  // Board B signals (Sink)
  logic [1:0] b_link_status;
  logic [1:0] b_cfg_role;
  logic [3:0] b_cfg_in_amps[4];
  logic [3:0] b_cfg_out_amps[4];
  logic       b_cfg_ready;
  logic       b_cfg_clear;
  logic [2:0] b_pwr_status;
  logic       b_contract_active;
  logic       b_contract_error;
  logic [1:0] b_active_volt_id;
  logic [3:0] b_active_amps;
  logic       b_active_is_source;
  logic       b_event_pulse;
  logic       b_tx_valid;
  logic [2:0] b_tx_type;
  logic [7:0] b_tx_data;

  // Cross-connected channel registers
  logic       a_to_b_valid;
  logic [2:0] a_to_b_type;
  logic [7:0] a_to_b_data;

  logic       b_to_a_valid;
  logic [2:0] b_to_a_type;
  logic [7:0] b_to_a_data;

  logic       inject_b_valid;
  logic [2:0] inject_b_type;
  logic [7:0] inject_b_data;

  // DUT A: Wall
  power_negotiator #(
      .RETRY_TICKS(100)
  ) dut_a (
      .clk                 (clk),
      .rst_n               (rst_n),
      .link_status         (a_link_status),
      .cfg_role            (a_cfg_role),
      .cfg_in_amps         (a_cfg_in_amps),
      .cfg_out_amps        (a_cfg_out_amps),
      .cfg_ready           (a_cfg_ready),
      .cfg_clear           (a_cfg_clear),
      .pwr_status_code     (a_pwr_status),
      .contract_active     (a_contract_active),
      .contract_error      (a_contract_error),
      .active_voltage_id   (a_active_volt_id),
      .active_amps         (a_active_amps),
      .active_is_source    (a_active_is_source),
      .contract_event_pulse(a_event_pulse),
      .pwr_tx_valid        (a_tx_valid),
      .pwr_tx_type         (a_tx_type),
      .pwr_tx_data         (a_tx_data),
      .pwr_tx_ready        (1'b1),
      .proto_rx_valid      (b_to_a_valid),
      .proto_rx_type       (b_to_a_type),
      .proto_rx_data       (b_to_a_data)
  );

  // DUT B: Sink
  power_negotiator #(
      .RETRY_TICKS(100)
  ) dut_b (
      .clk                 (clk),
      .rst_n               (rst_n),
      .link_status         (b_link_status),
      .cfg_role            (b_cfg_role),
      .cfg_in_amps         (b_cfg_in_amps),
      .cfg_out_amps        (b_cfg_out_amps),
      .cfg_ready           (b_cfg_ready),
      .cfg_clear           (b_cfg_clear),
      .pwr_status_code     (b_pwr_status),
      .contract_active     (b_contract_active),
      .contract_error      (b_contract_error),
      .active_voltage_id   (b_active_volt_id),
      .active_amps         (b_active_amps),
      .active_is_source    (b_active_is_source),
      .contract_event_pulse(b_event_pulse),
      .pwr_tx_valid        (b_tx_valid),
      .pwr_tx_type         (b_tx_type),
      .pwr_tx_data         (b_tx_data),
      .pwr_tx_ready        (1'b1),
      .proto_rx_valid      (a_to_b_valid),
      .proto_rx_type       (a_to_b_type),
      .proto_rx_data       (a_to_b_data)
  );

  // Optical channel transfer with 1-cycle latency
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_to_b_valid <= 1'b0;
      b_to_a_valid <= 1'b0;
      a_to_b_type  <= '0;
      b_to_a_type  <= '0;
      a_to_b_data  <= '0;
      b_to_a_data  <= '0;
    end else begin
      a_to_b_valid <= a_tx_valid | inject_b_valid;
      a_to_b_type  <= inject_b_valid ? inject_b_type : a_tx_type;
      a_to_b_data  <= inject_b_valid ? inject_b_data : a_tx_data;

      b_to_a_valid <= b_tx_valid;
      b_to_a_type  <= b_tx_type;
      b_to_a_data  <= b_tx_data;
    end
  end

  // Clock generation: 100MHz (10ns period)
  always #5 clk = ~clk;

  initial begin
    clk   = 0;
    rst_n = 0;
    inject_b_valid = 0;
    inject_b_type  = '0;
    inject_b_data  = '0;

    a_link_status = 2'b00;
    a_cfg_role    = 2'd0;
    a_cfg_ready   = 0;
    a_cfg_clear   = 0;
    for (int i = 0; i < 4; i++) begin
      a_cfg_in_amps[i]  = 4'd0;
      a_cfg_out_amps[i] = 4'd0;
    end

    b_link_status = 2'b00;
    b_cfg_role    = 2'd0;
    b_cfg_ready   = 0;
    b_cfg_clear   = 0;
    for (int i = 0; i < 4; i++) begin
      b_cfg_in_amps[i]  = 4'd0;
      b_cfg_out_amps[i] = 4'd0;
    end

    #100;
    rst_n = 1;
    #100;

    $display("==================================================================");
    $display("Starting OptiBolt Power Negotiation Unit Tests...");
    $display("==================================================================");

    // -------------------------------------------------------------------------
    // Test 1: Loopback Mode Inhibition
    // -------------------------------------------------------------------------
    a_link_status = 2'b10; // Loopback
    a_cfg_role    = 2'd1;  // Wall
    a_cfg_ready   = 1;
    #100;
    assert (a_pwr_status == 3'd6) // STAT_LOOPBACK
    else $error("DUT A failed to report LOOPBACK status (code 6)");
    assert (!a_contract_active)
    else $error("Power contract must not become active in loopback");
    $display("[PASS] Test 1: Loopback mode strictly inhibits power negotiation.");

    // -------------------------------------------------------------------------
    // Test 2: Standard 2-Board Negotiation (Wall -> Sink 20V @ 5A)
    // -------------------------------------------------------------------------
    a_cfg_ready = 0;
    b_cfg_ready = 0;
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;

    // Both boards connected in standard duplex
    a_link_status = 2'b01;
    b_link_status = 2'b01;

    // Board A is WALL: can supply 5V@3A and 20V@5A
    a_cfg_role        = 2'd1; // ROLE_WALL
    a_cfg_out_amps[0] = 4'd3; // 5V @ 3A
    a_cfg_out_amps[1] = 4'd0;
    a_cfg_out_amps[2] = 4'd0;
    a_cfg_out_amps[3] = 4'd5; // 20V @ 5A

    // Board B is SINK: requires min 5V@1A or 20V@3A
    b_cfg_role       = 2'd3; // ROLE_SINK
    b_cfg_in_amps[0] = 4'd1; // 5V @ 1A
    b_cfg_in_amps[1] = 4'd0;
    b_cfg_in_amps[2] = 4'd0;
    b_cfg_in_amps[3] = 4'd3; // 20V @ 3A

    // Both boards arm negotiation simultaneously
    a_cfg_ready = 1;
    b_cfg_ready = 1;

    // Wait for handshake to complete
    #500;

    assert (a_contract_active && b_contract_active)
    else $error("Power contract negotiation failed to lock active contract");
    assert (a_active_volt_id == 2'd3 && b_active_volt_id == 2'd3)
    else $error("Negotiated voltage mismatch: expected 20V (id 3)");
    assert (a_active_amps == 4'd5 && b_active_amps == 4'd5)
    else $error("Negotiated amperage mismatch: expected 5A");
    assert (a_active_is_source == 1'b1 && b_active_is_source == 1'b0)
    else $error("Directionality mismatch: Wall must be Source, Sink must be Sink");

    $display("[PASS] Test 2: Wall <-> Sink negotiated highest mutual contract: 20V @ 5A (100W).");

    // -------------------------------------------------------------------------
    // Test 3: Incompatible Current Rejection
    // -------------------------------------------------------------------------
    a_cfg_ready = 0;
    b_cfg_ready = 0;
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;

    a_link_status = 2'b01;
    b_link_status = 2'b01;

    // Board A supplies only 5V @ 1A
    a_cfg_role        = 2'd1; // ROLE_WALL
    a_cfg_out_amps[0] = 4'd1;
    a_cfg_out_amps[1] = 4'd0;
    a_cfg_out_amps[2] = 4'd0;
    a_cfg_out_amps[3] = 4'd0;

    // Board B requires 5V @ 3A minimum
    b_cfg_role       = 2'd3; // ROLE_SINK
    b_cfg_in_amps[0] = 4'd3;
    b_cfg_in_amps[1] = 4'd0;
    b_cfg_in_amps[2] = 4'd0;
    b_cfg_in_amps[3] = 4'd0;

    a_cfg_ready = 1;
    b_cfg_ready = 1;

    #500;

    assert (a_contract_error || b_contract_error)
    else $error("Incompatible current must trigger contract error/rejection");
    assert (a_pwr_status == 3'd5 && b_pwr_status == 3'd5) // STAT_ERROR
    else $error("Status code must be STAT_ERROR (5)");

    $display("[PASS] Test 3: Incompatible current requirements properly rejected (STAT_ERROR).");

    // -------------------------------------------------------------------------
    // Test 4: Role Conflict (WALL <-> WALL)
    // -------------------------------------------------------------------------
    a_cfg_ready = 0;
    b_cfg_ready = 0;
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;

    a_link_status = 2'b01;
    b_link_status = 2'b01;

    a_cfg_role = 2'd1; // WALL
    b_cfg_role = 2'd1; // WALL

    a_cfg_ready = 1;
    b_cfg_ready = 1;

    #500;

    assert (a_contract_error && b_contract_error)
    else $error("Wall <-> Wall role conflict failed to assert error");

    $display("[PASS] Test 4: Role conflict (WALL <-> WALL) immediately detected and flagged.");

    // -------------------------------------------------------------------------
    // Test 5: Power OFF / Contract Disconnect (8'hFE or !cfg_ready)
    // -------------------------------------------------------------------------
    // Re-establish a valid contract first (WALL -> SINK 5V @ 2A)
    a_cfg_ready = 0; b_cfg_ready = 0;
    rst_n = 0; #50; rst_n = 1; #50;
    a_cfg_role = 2'd1; a_cfg_out_amps[0] = 4'd2;
    b_cfg_role = 2'd3; b_cfg_in_amps[0]  = 4'd2;
    a_cfg_ready = 1; b_cfg_ready = 1;
    #500;
    assert (a_contract_active && b_contract_active) else $error("Contract failed to establish");

    // Board A turns power OFF (a_cfg_ready = 0) and sends 8'hFE to Board B
    a_cfg_ready = 0;
    inject_b_valid = 1'b1;
    inject_b_type  = MSG_POWER;
    inject_b_data  = 8'hFE;
    @(posedge clk);
    inject_b_valid = 1'b0;
    #100;
    assert (!a_contract_active && !b_contract_active)
    else $error("Power OFF failed to disconnect contract");
    assert (a_active_volt_id == 2'd0 && b_active_volt_id == 2'd0)
    else $error("Active voltage not cleared on Power OFF");
    $display("[PASS] Test 5: Power OFF contract termination verified.");

    $display("==================================================================");
    $display("=== All Power Negotiator Unit Tests PASSED successfully! ===");
    $display("==================================================================");

    #500;
    $finish;
  end

endmodule
