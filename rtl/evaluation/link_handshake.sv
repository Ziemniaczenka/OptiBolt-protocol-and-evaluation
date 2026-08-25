/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Link handshake and status detection module.
 * Latches challenge token from free-running PRNG upon detecting light signal on receiver,
 * automatically differentiating between DISCONNECTED, CONNECTED (remote board),
 * and LOOPBACK (own TX connected to RX).
 */

module link_handshake #(
    parameter int HEARTBEAT_TICKS = 2_500_000, // 25ms at 100MHz
    parameter int TIMEOUT_TICKS   = 7_500_000  // 75ms at 100MHz (3 missed heartbeats)
) (
    input logic clk,
    input logic rst_n,

    // Protocol RX inputs
    input logic       proto_eval_rx_valid,
    input logic [2:0] proto_eval_rx_type,
    input logic [7:0] proto_eval_rx_data,
    input logic       proto_eval_preamble_error,
    input logic       proto_eval_rx_carrier, // Optical light activity on receiver pin

    // Protocol TX request interface (to evaluation controller / arbiter)
    output logic       hs_tx_req,
    output logic [2:0] hs_tx_type,
    output logic [7:0] hs_tx_data,
    input  logic       hs_tx_ack,

    // Link Status Output: 2'b00=DISCONNECTED, 2'b01=CONNECTED, 2'b10=LOOPBACK
    output logic [1:0] link_status
);

  import protocol_pkg::*;

  localparam logic [1:0] LINK_DISCONNECTED = 2'b00;
  localparam logic [1:0] LINK_CONNECTED    = 2'b01;
  localparam logic [1:0] LINK_LOOPBACK     = 2'b10;

  // PRNG Instantiation using pixel_prng module (free-running on clk)
  logic [7:0] prng_byte;
  pixel_prng u_hs_prng (
      .clk(clk),
      .rst_n(rst_n),
      .next_pixel(1'b1), // Advances every clock cycle
      .pixel_rgb(),
      .pixel_byte(prng_byte)
  );

  // Heartbeat & Timeout Timers
  logic [$clog2(HEARTBEAT_TICKS+1)-1:0] heartbeat_cnt;
  logic [$clog2(TIMEOUT_TICKS+1)-1:0]   timeout_cnt;

  logic [7:0] my_challenge;
  logic       challenge_latched;
  logic       pending_challenge_tx;
  logic       pending_ack_tx;
  logic [7:0] ack_payload;
  logic       rx_carrier_d1;

  wire rx_carrier_rose = proto_eval_rx_carrier && !rx_carrier_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      link_status          <= LINK_DISCONNECTED;
      heartbeat_cnt        <= '0;
      timeout_cnt          <= '0;
      my_challenge         <= 8'hA5;
      challenge_latched    <= 1'b0;
      pending_challenge_tx <= 1'b0;
      pending_ack_tx       <= 1'b0;
      ack_payload          <= 8'h00;
      hs_tx_req            <= 1'b0;
      hs_tx_type           <= MSG_CAPABILITIES;
      hs_tx_data           <= 8'h00;
      rx_carrier_d1        <= 1'b0;
    end else begin
      rx_carrier_d1 <= proto_eval_rx_carrier;

      // ---------------------------------------------------------------------
      // Latch challenge from PRNG upon detecting light signal on the receiver
      // ---------------------------------------------------------------------
      if (rx_carrier_rose || (!challenge_latched && proto_eval_rx_carrier)) begin
        my_challenge         <= (prng_byte == 8'h00) ? 8'h5A : prng_byte;
        challenge_latched    <= 1'b1;
        pending_challenge_tx <= 1'b1; // Immediately transmit challenge packet
        heartbeat_cnt        <= '0;
      end else if (!proto_eval_rx_carrier) begin
        challenge_latched <= 1'b0;
      end

      // Heartbeat pulse generation (every 25ms while link has optical carrier)
      if (proto_eval_rx_carrier) begin
        if (heartbeat_cnt >= HEARTBEAT_TICKS - 1) begin
          heartbeat_cnt        <= '0;
          pending_challenge_tx <= 1'b1;
        end else begin
          heartbeat_cnt <= heartbeat_cnt + 1;
        end
      end else begin
        heartbeat_cnt <= '0;
      end

      // TX Request Arbiter outputs
      if (hs_tx_ack) begin
        if (pending_ack_tx) begin
          pending_ack_tx <= 1'b0;
        end else if (pending_challenge_tx) begin
          pending_challenge_tx <= 1'b0;
        end
        hs_tx_req <= 1'b0;
      end else if (pending_ack_tx) begin
        hs_tx_req  <= 1'b1;
        hs_tx_type <= MSG_ACCEPT;
        hs_tx_data <= ack_payload;
      end else if (pending_challenge_tx) begin
        hs_tx_req  <= 1'b1;
        hs_tx_type <= MSG_CAPABILITIES;
        hs_tx_data <= my_challenge;
      end else begin
        hs_tx_req <= 1'b0;
      end

      // RX Packet Processing & Classification
      if (proto_eval_rx_valid) begin
        timeout_cnt <= '0; // Reset watchdog timer on any valid packet
        if (proto_eval_rx_type == MSG_CAPABILITIES) begin
          if (proto_eval_rx_data == my_challenge) begin
            // Own token received back -> rock-solid LOOPBACK
            link_status    <= LINK_LOOPBACK;
            pending_ack_tx <= 1'b0; // Suppress ACK to self in loopback
          end else begin
            // Different token received from another board -> CONNECTED
            link_status    <= LINK_CONNECTED;
            pending_ack_tx <= 1'b1;
            ack_payload    <= proto_eval_rx_data + 8'h01;
          end
        end else if (proto_eval_rx_type == MSG_ACCEPT) begin
          // Remote board acknowledged our token -> CONNECTED (unless in confirmed loopback)
          if (link_status != LINK_LOOPBACK) begin
            link_status <= LINK_CONNECTED;
          end
        end
      end else begin
        // Timeout / Disconnect tracking
        if (!proto_eval_rx_carrier || proto_eval_preamble_error) begin
          link_status <= LINK_DISCONNECTED;
          timeout_cnt <= TIMEOUT_TICKS;
        end else if (timeout_cnt >= TIMEOUT_TICKS - 1) begin
          link_status <= LINK_DISCONNECTED;
        end else begin
          timeout_cnt <= timeout_cnt + 1;
        end
      end
    end
  end

endmodule
