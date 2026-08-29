/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * OptiBolt Protocol Link Management & Speed Negotiation Module.
 * Handles baudrate and oversampling configuration, speed negotiation packets,
 * and automatic link failover.
 */

import protocol_pkg::*;

module optibolt_link_manager #(
    parameter logic [3:0] DEFAULT_BAUD_RATE    = 4'd1,
    parameter logic [3:0] DEFAULT_OVERSAMPLING = 4'd0
) (
    input logic clk,
    input logic rst_n,

    // Link telemetry inputs
    input logic [1:0] link_status,
    input logic       rx_carrier,
    input logic       proto_eval_parity_error,
    input logic       proto_eval_manchester_code_error,
    input logic       proto_eval_preamble_error,

    // User configuration & commands
    input logic       failover_en,
    input logic       sweep_active,
    input logic       set_speed_req,
    input logic [3:0] req_baud_rate,
    input logic [3:0] req_oversampling,
    input logic       set_loopback_req,
    input logic       req_loopback_en,

    // Speed negotiation packet interface
    input  logic       proto_rx_valid,
    input  logic [2:0] proto_rx_type,
    input  logic [7:0] proto_rx_data,
    output logic       nego_tx_valid,
    output logic [2:0] nego_tx_type,
    output logic [7:0] nego_tx_data,

    // Current active protocol configuration
    output logic [3:0] active_baud_rate,
    output logic [3:0] active_oversampling,
    output logic       active_loopback_en,

    // Alerts & status
    output logic failover_triggered,
    output logic speed_nego_in_progress,
    output logic speed_updated_pulse
);

  // Default speed constants
  localparam logic [7:0] NEGO_REQ_HEADER = 8'hB0;
  localparam logic [7:0] NEGO_ACK_HEADER = 8'hB1;

  logic [3:0] current_baud;
  logic [3:0] current_os;
  logic       current_loopback;

  assign active_baud_rate    = current_baud;
  assign active_oversampling = current_os;
  assign active_loopback_en  = current_loopback;

  // 100ms sliding error monitoring window (10,000,000 cycles at 100MHz)
  logic [23:0] err_monitor_timer;
  logic [15:0] window_error_count;
  logic [19:0] carrier_loss_timer;
  logic man_d1, pre_d1, par_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_baud           <= DEFAULT_BAUD_RATE;
      current_os             <= DEFAULT_OVERSAMPLING;
      current_loopback       <= 1'b0;
      failover_triggered     <= 1'b0;
      speed_nego_in_progress <= 1'b0;
      speed_updated_pulse    <= 1'b0;
      nego_tx_valid          <= 1'b0;
      nego_tx_type           <= 3'b000;
      nego_tx_data           <= 8'h00;
      err_monitor_timer      <= '0;
      carrier_loss_timer     <= '0;
      window_error_count     <= '0;
      man_d1                 <= 1'b0;
      pre_d1                 <= 1'b0;
      par_d1                 <= 1'b0;
    end else begin
      failover_triggered  <= 1'b0;
      speed_updated_pulse <= 1'b0;
      nego_tx_valid       <= 1'b0;

      man_d1              <= proto_eval_manchester_code_error;
      pre_d1              <= proto_eval_preamble_error;
      par_d1              <= proto_eval_parity_error;

      // ---------------------------------------------------------------------
      // Error Accumulator in 100ms window
      // ---------------------------------------------------------------------
      if (err_monitor_timer >= 24'd10_000_000) begin
        err_monitor_timer  <= '0;
        window_error_count <= '0;
      end else begin
        err_monitor_timer <= err_monitor_timer + 24'd1;
        if (proto_eval_manchester_code_error && !man_d1 && window_error_count != 16'hFFFF)
          window_error_count <= window_error_count + 16'd1;
        if (proto_eval_preamble_error && !pre_d1 && window_error_count != 16'hFFFF)
          window_error_count <= window_error_count + 16'd1;
        if (proto_eval_parity_error && !par_d1 && window_error_count != 16'hFFFF)
          window_error_count <= window_error_count + 16'd1;
      end

      // ---------------------------------------------------------------------
      // Automatic Link Failover
      // ---------------------------------------------------------------------
      if (!rx_carrier || link_status == 2'b00) begin
        if (carrier_loss_timer < 20'd1_000_000) carrier_loss_timer <= carrier_loss_timer + 20'd1;
      end else begin
        carrier_loss_timer <= '0;
      end

      if (failover_en && !sweep_active && (current_baud != DEFAULT_BAUD_RATE || current_os != DEFAULT_OVERSAMPLING)) begin
        if (window_error_count >= 16'd200 || carrier_loss_timer >= 20'd1_000_000) begin
          current_baud       <= DEFAULT_BAUD_RATE;
          current_os         <= DEFAULT_OVERSAMPLING;
          window_error_count <= '0;
          carrier_loss_timer <= '0;
          failover_triggered <= 1'b1;
        end
      end

      // ---------------------------------------------------------------------
      // User Speed Setting Request
      // ---------------------------------------------------------------------
      if (set_speed_req) begin
        if (link_status == 2'b01) begin  // Remote connected: initiate negotiation
          nego_tx_valid          <= 1'b1;
          nego_tx_type           <= MSG_REQUEST;
          nego_tx_data           <= {req_oversampling, req_baud_rate};
          speed_nego_in_progress <= 1'b1;
        end else begin  // Disconnected or Loopback: apply immediately
          current_baud        <= req_baud_rate;
          current_os          <= req_oversampling;
          speed_updated_pulse <= 1'b1;
        end
      end

      if (set_loopback_req) begin
        current_loopback <= req_loopback_en;
      end


      // ---------------------------------------------------------------------
      // Incoming Speed Negotiation Packets (Only from remote partner, NOT loopback)
      // ---------------------------------------------------------------------
      if (link_status == 2'b01) begin
        if (proto_rx_valid && proto_rx_type == MSG_REQUEST &&
            proto_rx_data[7:4] != 4'hA && proto_rx_data[7:4] != 4'h5 &&
            proto_rx_data[7:4] <= 4'd1 && proto_rx_data[3:0] <= 4'd9) begin
          // Remote peer requested speed change: apply and acknowledge
          current_baud           <= proto_rx_data[3:0];
          current_os             <= proto_rx_data[7:4];
          speed_updated_pulse    <= 1'b1;
          speed_nego_in_progress <= 1'b0;
          nego_tx_valid          <= 1'b1;
          nego_tx_type           <= MSG_ACCEPT;
          nego_tx_data           <= NEGO_ACK_HEADER;
        end else if (speed_nego_in_progress && proto_rx_valid && proto_rx_type == MSG_ACCEPT && proto_rx_data == NEGO_ACK_HEADER) begin
          // Remote peer accepted our speed change request: apply requested speed
          current_baud           <= req_baud_rate;
          current_os             <= req_oversampling;
          speed_updated_pulse    <= 1'b1;
          speed_nego_in_progress <= 1'b0;
        end
      end
    end
  end

endmodule
