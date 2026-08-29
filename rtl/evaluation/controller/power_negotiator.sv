/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Power Negotiation Engine for OptiBolt.
 * Manages power roles (Wall, Battery, Sink) and multi-voltage / multi-current
 * power contracts over the optical channel.
 * In loopback mode, negotiation is inhibited as per system specification.
 */

`timescale 1ns / 1ps

module power_negotiator #(
    parameter int RETRY_TICKS = 10_000_000  // 100ms at 100MHz
) (
    input logic clk,
    input logic rst_n,

    // Link status from link_handshake (00=DISCONN, 01=CONN, 10=LOOPBACK)
    input logic [1:0] link_status,

    // Configuration from eval_cmd_exec
    input logic [1:0] cfg_role,         // 0=NONE, 1=WALL, 2=BATTERY, 3=SINK
    input logic [3:0] cfg_in_amps [4],  // Minimum required amps: 0=5V, 1=9V, 2=12V, 3=20V
    input logic [3:0] cfg_out_amps[4],  // Maximum supplied amps: 0=5V, 1=9V, 2=12V, 3=20V
    input logic       cfg_ready,        // Device ready to negotiate
    input logic       cfg_clear,        // Clear tables pulse

    // Status outputs to UI and controller
    output logic [2:0] pwr_status_code,   // 0=NOT_READY, 1=READY, 2=SENDING, 3=RECEIVING, 4=ACTIVE, 5=ERROR, 6=LOOPBACK
    output logic contract_active,
    output logic contract_error,
    output logic [1:0] active_voltage_id,  // 0=5V, 1=9V, 2=12V, 3=20V
    output logic [3:0] active_amps,
    output logic active_is_source,  // 1 if this board is providing power
    output logic contract_event_pulse,

    // Packet TX interface (to evaluation_controller multiplexer)
    output logic       pwr_tx_valid,
    output logic [2:0] pwr_tx_type,   // MSG_POWER (3'b110)
    output logic [7:0] pwr_tx_data,
    input  logic       pwr_tx_ready,

    // Packet RX interface
    input logic       proto_rx_valid,
    input logic [2:0] proto_rx_type,
    input logic [7:0] proto_rx_data
);

  import protocol_pkg::*;

  // Status Codes
  localparam logic [2:0] STAT_NOT_READY = 3'd0;
  localparam logic [2:0] STAT_READY = 3'd1;
  localparam logic [2:0] STAT_SENDING = 3'd2;
  localparam logic [2:0] STAT_RECEIVING = 3'd3;
  localparam logic [2:0] STAT_ACTIVE = 3'd4;
  localparam logic [2:0] STAT_ERROR = 3'd5;
  localparam logic [2:0] STAT_LOOPBACK = 3'd6;

  // Roles
  localparam logic [1:0] ROLE_NONE = 2'd0;
  localparam logic [1:0] ROLE_WALL = 2'd1;
  localparam logic [1:0] ROLE_BATTERY = 2'd2;
  localparam logic [1:0] ROLE_SINK = 2'd3;

  typedef enum logic [3:0] {
    S_IDLE,
    S_DISCOVER_SEND,
    S_DISCOVER_WAIT,
    S_SRC_SEND_PDOS,
    S_SNK_WAIT_PDOS,
    S_SNK_SEND_REQ,
    S_SRC_WAIT_REQ,
    S_SRC_SEND_RESP,
    S_SNK_WAIT_RESP,
    S_ACTIVE,
    S_ERROR
  } pwr_state_t;

  pwr_state_t        state;

  logic       [ 1:0] peer_role;
  logic       [ 3:0] peer_out_amps  [4];
  logic       [ 2:0] pdo_idx;
  logic       [ 1:0] chosen_volt_id;
  logic       [ 3:0] chosen_amps;
  logic              chosen_valid;
  logic       [31:0] timer;

  // Packet assembly
  logic              tx_req;
  logic       [ 7:0] tx_byte;

  assign pwr_tx_type  = MSG_POWER;
  assign pwr_tx_valid = tx_req;
  assign pwr_tx_data  = tx_byte;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                <= S_IDLE;
      pwr_status_code      <= STAT_NOT_READY;
      contract_active      <= 1'b0;
      contract_error       <= 1'b0;
      active_voltage_id    <= 2'd0;
      active_amps          <= 4'd0;
      active_is_source     <= 1'b0;
      contract_event_pulse <= 1'b0;
      peer_role            <= ROLE_NONE;
      for (int i = 0; i < 4; i++) peer_out_amps[i] <= 4'd0;
      pdo_idx        <= 3'd0;
      chosen_volt_id <= 2'd0;
      chosen_amps    <= 4'd0;
      chosen_valid   <= 1'b0;
      timer          <= '0;
      tx_req         <= 1'b0;
      tx_byte        <= 8'h00;
    end else if (cfg_clear || !cfg_ready) begin
      state                <= S_IDLE;
      pwr_status_code      <= STAT_NOT_READY;
      contract_active      <= 1'b0;
      contract_error       <= 1'b0;
      active_voltage_id    <= 2'd0;
      active_amps          <= 4'd0;
      active_is_source     <= 1'b0;
      contract_event_pulse <= contract_active;
      peer_role            <= ROLE_NONE;
      for (int i = 0; i < 4; i++) peer_out_amps[i] <= 4'd0;
      pdo_idx        <= 3'd0;
      chosen_volt_id <= 2'd0;
      chosen_amps    <= 4'd0;
      chosen_valid   <= 1'b0;
      timer          <= '0;
      tx_req         <= 1'b0;
      tx_byte        <= 8'h00;
    end else begin
      contract_event_pulse <= 1'b0;

      // Handle TX handshake
      if (tx_req && pwr_tx_ready) begin
        tx_req <= 1'b0;
      end

      // Remote peer sent Power OFF / Disconnect:
      if (proto_rx_valid && proto_rx_type == MSG_POWER && proto_rx_data == 8'hFE) begin
        state                <= S_IDLE;
        pwr_status_code      <= STAT_READY;
        contract_active      <= 1'b0;
        contract_error       <= 1'b0;
        active_voltage_id    <= 2'd0;
        active_amps          <= 4'd0;
        active_is_source     <= 1'b0;
        contract_event_pulse <= 1'b1;
      end else
      // In loopback mode, power negotiation is prohibited
      if (link_status == 2'b10) begin
        state           <= S_IDLE;
        pwr_status_code <= STAT_LOOPBACK;
        contract_active <= 1'b0;
        contract_error  <= 1'b0;
        tx_req          <= 1'b0;
      end else if (link_status == 2'b00) begin
        // Disconnected
        state           <= S_IDLE;
        pwr_status_code <= cfg_ready ? STAT_READY : STAT_NOT_READY;
        contract_active <= 1'b0;
        contract_error  <= 1'b0;
        tx_req          <= 1'b0;
      end else begin
        // Connected (duplex between 2 devices)
        case (state)
          S_IDLE: begin
            if (cfg_ready && cfg_role != ROLE_NONE) begin
              pwr_status_code <= STAT_READY;
              timer           <= '0;
              state           <= S_DISCOVER_SEND;
            end else begin
              pwr_status_code <= STAT_NOT_READY;
            end
          end

          // Send Role Advertisement: 0x0_ | cfg_role
          S_DISCOVER_SEND: begin
            pwr_status_code <= STAT_SENDING;
            if (!tx_req) begin
              tx_req  <= 1'b1;
              tx_byte <= {4'h0, 2'b00, cfg_role};
              timer   <= '0;
              state   <= S_DISCOVER_WAIT;
            end
          end

          S_DISCOVER_WAIT: begin
            pwr_status_code <= STAT_RECEIVING;
            timer <= timer + 32'd1;

            // Check if peer role packet arrived
            if (proto_rx_valid && proto_rx_type == MSG_POWER && proto_rx_data[7:4] == 4'h0) begin
              peer_role <= proto_rx_data[1:0];

              // Check for role conflicts
              if ((cfg_role == ROLE_WALL && proto_rx_data[1:0] == ROLE_WALL) ||
                  (cfg_role == ROLE_SINK && proto_rx_data[1:0] == ROLE_SINK)) begin
                contract_error  <= 1'b1;
                pwr_status_code <= STAT_ERROR;
                state           <= S_ERROR;
              end else begin
                // Determine directionality
                if (cfg_role == ROLE_WALL) begin
                  active_is_source <= 1'b1;
                  pdo_idx          <= 3'd0;
                  state            <= S_SRC_SEND_PDOS;
                end else if (cfg_role == ROLE_SINK) begin
                  active_is_source <= 1'b0;
                  for (int i = 0; i < 4; i++) peer_out_amps[i] <= 4'd0;
                  state <= S_SNK_WAIT_PDOS;
                end else begin
                  // Battery: If peer is WALL, Battery is Sink. If peer is SINK, Battery is Source.
                  if (proto_rx_data[1:0] == ROLE_WALL) begin
                    active_is_source <= 1'b0;
                    for (int i = 0; i < 4; i++) peer_out_amps[i] <= 4'd0;
                    state <= S_SNK_WAIT_PDOS;
                  end else begin
                    active_is_source <= 1'b1;
                    pdo_idx          <= 3'd0;
                    state            <= S_SRC_SEND_PDOS;
                  end
                end
              end
            end else if (proto_rx_valid && proto_rx_type == MSG_POWER && proto_rx_data[7:6] == 2'b01) begin
              // Peer already acting as Source and sending PDOs
              peer_role        <= ROLE_WALL;
              active_is_source <= 1'b0;
              for (int i = 0; i < 4; i++) peer_out_amps[i] <= 4'd0;
              if (proto_rx_data != 8'h7F) begin
                peer_out_amps[proto_rx_data[5:4]] <= proto_rx_data[3:0];
              end
              state <= S_SNK_WAIT_PDOS;
            end else if (timer >= RETRY_TICKS) begin
              // Retry discovery packet
              state <= S_DISCOVER_SEND;
            end
          end

          // Source: Send available PDOs (0x40 | {volt_id, amps}), then End marker (0x7F)
          S_SRC_SEND_PDOS: begin
            pwr_status_code <= STAT_SENDING;
            if (!tx_req) begin
              if (pdo_idx < 3'd4) begin
                if (cfg_out_amps[pdo_idx[1:0]] > 4'd0) begin
                  tx_req  <= 1'b1;
                  tx_byte <= {2'b01, pdo_idx[1:0], cfg_out_amps[pdo_idx[1:0]]};
                end
                pdo_idx <= pdo_idx + 3'd1;
              end else begin
                // End of PDO list marker
                tx_req  <= 1'b1;
                tx_byte <= 8'h7F;
                timer   <= '0;
                state   <= S_SRC_WAIT_REQ;
              end
            end
          end

          // Sink: Receive PDOs until 0x7F
          S_SNK_WAIT_PDOS: begin
            pwr_status_code <= STAT_RECEIVING;
            if (proto_rx_valid && proto_rx_type == MSG_POWER) begin
              if (proto_rx_data == 8'h7F) begin
                // Source finished sending PDOs -> evaluate matching requirements
                state <= S_SNK_SEND_REQ;
              end else if (proto_rx_data[7:6] == 2'b01) begin
                // Store Source PDO
                peer_out_amps[proto_rx_data[5:4]] <= proto_rx_data[3:0];
              end
            end
          end

          // Sink: Evaluate and send Request (0x80 | {volt_id, amps}) or Reject (0xFF)
          S_SNK_SEND_REQ: begin
            pwr_status_code <= STAT_SENDING;
            if (!tx_req) begin
              // Select highest matching voltage: 20V (3), 12V (2), 9V (1), 5V (0)
              if (cfg_in_amps[3] > 4'd0 && peer_out_amps[3] >= cfg_in_amps[3]) begin
                tx_req         <= 1'b1;
                tx_byte        <= {2'b10, 2'd3, peer_out_amps[3]};
                chosen_volt_id <= 2'd3;
                chosen_amps    <= peer_out_amps[3];
                chosen_valid   <= 1'b1;
                timer          <= '0;
                state          <= S_SNK_WAIT_RESP;
              end else if (cfg_in_amps[2] > 4'd0 && peer_out_amps[2] >= cfg_in_amps[2]) begin
                tx_req         <= 1'b1;
                tx_byte        <= {2'b10, 2'd2, peer_out_amps[2]};
                chosen_volt_id <= 2'd2;
                chosen_amps    <= peer_out_amps[2];
                chosen_valid   <= 1'b1;
                timer          <= '0;
                state          <= S_SNK_WAIT_RESP;
              end else if (cfg_in_amps[1] > 4'd0 && peer_out_amps[1] >= cfg_in_amps[1]) begin
                tx_req         <= 1'b1;
                tx_byte        <= {2'b10, 2'd1, peer_out_amps[1]};
                chosen_volt_id <= 2'd1;
                chosen_amps    <= peer_out_amps[1];
                chosen_valid   <= 1'b1;
                timer          <= '0;
                state          <= S_SNK_WAIT_RESP;
              end else if (cfg_in_amps[0] > 4'd0 && peer_out_amps[0] >= cfg_in_amps[0]) begin
                tx_req         <= 1'b1;
                tx_byte        <= {2'b10, 2'd0, peer_out_amps[0]};
                chosen_volt_id <= 2'd0;
                chosen_amps    <= peer_out_amps[0];
                chosen_valid   <= 1'b1;
                timer          <= '0;
                state          <= S_SNK_WAIT_RESP;
              end else begin
                // No match possible: send reject
                tx_req          <= 1'b1;
                tx_byte         <= 8'hFF;
                contract_error  <= 1'b1;
                pwr_status_code <= STAT_ERROR;
                state           <= S_ERROR;
              end
            end
          end

          // Source: Wait for Request
          S_SRC_WAIT_REQ: begin
            pwr_status_code <= STAT_RECEIVING;
            timer <= timer + 32'd1;
            if (proto_rx_valid && proto_rx_type == MSG_POWER) begin
              if (proto_rx_data[7:6] == 2'b10) begin
                // Request received
                chosen_volt_id <= proto_rx_data[5:4];
                chosen_amps    <= proto_rx_data[3:0];
                state          <= S_SRC_SEND_RESP;
              end else if (proto_rx_data[7:4] == 4'h0) begin
                // Sink re-advertised role: retransmit PDOs immediately!
                pdo_idx <= 3'd0;
                timer   <= '0;
                state   <= S_SRC_SEND_PDOS;
              end else if (proto_rx_data == 8'hFF) begin
                contract_error  <= 1'b1;
                pwr_status_code <= STAT_ERROR;
                state           <= S_ERROR;
              end
            end else if (timer >= RETRY_TICKS) begin
              // Retry sending PDOs
              pdo_idx <= 3'd0;
              state   <= S_SRC_SEND_PDOS;
            end
          end

          // Source: Send ACCEPT (0xC0 | {volt_id, amps})
          S_SRC_SEND_RESP: begin
            pwr_status_code <= STAT_SENDING;
            if (!tx_req) begin
              tx_req               <= 1'b1;
              tx_byte              <= {2'b11, chosen_volt_id, chosen_amps};
              contract_active      <= 1'b1;
              active_voltage_id    <= chosen_volt_id;
              active_amps          <= chosen_amps;
              contract_event_pulse <= 1'b1;
              pwr_status_code      <= STAT_ACTIVE;
              state                <= S_ACTIVE;
            end
          end

          // Sink: Wait for ACCEPT
          S_SNK_WAIT_RESP: begin
            pwr_status_code <= STAT_RECEIVING;
            if (proto_rx_valid && proto_rx_type == MSG_POWER) begin
              if (proto_rx_data[7:6] == 2'b11) begin
                contract_active      <= 1'b1;
                active_voltage_id    <= proto_rx_data[5:4];
                active_amps          <= proto_rx_data[3:0];
                contract_event_pulse <= 1'b1;
                pwr_status_code      <= STAT_ACTIVE;
                state                <= S_ACTIVE;
              end else if (proto_rx_data == 8'hFF) begin
                contract_error  <= 1'b1;
                pwr_status_code <= STAT_ERROR;
                state           <= S_ERROR;
              end
            end
          end

          S_ACTIVE: begin
            pwr_status_code <= STAT_ACTIVE;
            // Contract locked. Remains active until disconnect or clear.
          end

          S_ERROR: begin
            pwr_status_code <= STAT_ERROR;
            // Error locked until clear or reconnect.
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

endmodule
