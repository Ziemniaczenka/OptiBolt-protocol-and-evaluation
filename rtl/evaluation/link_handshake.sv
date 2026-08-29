/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Link handshake and status detection module.
 * Latches challenge token from free-running PRNG upon detecting light signal on receiver,
 * differentiating between DISCONNECTED, CONNECTED (remote board),
 * and LOOPBACK (own TX connected to RX).
 * Handshake packets are ONLY transmitted upon initial connection detection and
 * when changing speeds.
 */

module link_handshake #(
    parameter int RETRY_TICKS      = 500_000,    // 5ms retry interval while searching for connection
    parameter int HEARTBEAT_TICKS  = 50_000_000,  // 500ms periodic link testing interval
    parameter int LINK_ALIVE_TICKS = 150_000_000, // 1.5s timeout: drop link if no peer ACK received
    parameter logic [15:0] PRNG_SEED = 16'hACE1
) (
    input logic clk,
    input logic rst_n,

    // Protocol RX inputs
    input logic       proto_eval_rx_valid,
    input logic [2:0] proto_eval_rx_type,
    input logic [7:0] proto_eval_rx_data,
    input logic       proto_eval_preamble_error,
    input logic       proto_eval_manchester_code_error,
    input logic       proto_eval_rx_carrier,             // Optical light activity on receiver pin

    // Speed update pulse from link manager
    input logic speed_updated_pulse,

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
  pixel_prng #(
      .SEED(PRNG_SEED)
  ) u_hs_prng (
      .clk(clk),
      .rst_n(rst_n),
      .next_pixel(1'b1),  // Advances every clock cycle
      .pixel_rgb(),
      .pixel_byte(prng_byte)
  );

  // Timers
  logic [$clog2(RETRY_TICKS+1)-1:0]      retry_cnt;
  logic [$clog2(HEARTBEAT_TICKS+1)-1:0]  heartbeat_cnt;
  logic [$clog2(LINK_ALIVE_TICKS+1)-1:0] link_alive_cnt;

  logic [ 7:0] my_challenge;
  logic        challenge_latched;
  logic        pending_challenge_tx;
  logic        pending_ack_tx;
  logic [ 7:0] peer_challenge_to_ack;
  logic        rx_carrier_d1;
  logic [15:0] man_err_burst_cnt;

  wire rx_carrier_rose = proto_eval_rx_carrier && !rx_carrier_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      link_status           <= LINK_DISCONNECTED;
      retry_cnt             <= '0;
      heartbeat_cnt         <= '0;
      link_alive_cnt        <= '0;
      my_challenge          <= 8'hA5;
      challenge_latched     <= 1'b0;
      pending_challenge_tx  <= 1'b0;
      pending_ack_tx        <= 1'b0;
      peer_challenge_to_ack <= 8'h00;
      hs_tx_req             <= 1'b0;
      hs_tx_type            <= MSG_CAPABILITIES;
      hs_tx_data            <= 8'h00;
      rx_carrier_d1         <= 1'b0;
      man_err_burst_cnt     <= 16'd0;
    end else begin
      rx_carrier_d1 <= proto_eval_rx_carrier;

      // ---------------------------------------------------------------------
      // 1. Connection Startup: latch new token and send challenge packet
      // ---------------------------------------------------------------------
      if (rx_carrier_rose || (!challenge_latched && proto_eval_rx_carrier)) begin
        my_challenge         <= (prng_byte == 8'h00) ? 8'h5A : prng_byte;
        challenge_latched    <= 1'b1;
        pending_challenge_tx <= 1'b1;
        retry_cnt            <= '0;
        heartbeat_cnt        <= '0;
        link_alive_cnt       <= '0;
        man_err_burst_cnt    <= 16'd0;
      end else if (!proto_eval_rx_carrier) begin
        challenge_latched <= 1'b0;
      end

      // ---------------------------------------------------------------------
      // 2. Speed Change: drop link status until link is verified at new rate
      // ---------------------------------------------------------------------
      if (speed_updated_pulse && proto_eval_rx_carrier) begin
        my_challenge         <= (prng_byte == 8'h00) ? 8'h5A : prng_byte;
        pending_challenge_tx <= 1'b1;
        retry_cnt            <= '0;
        heartbeat_cnt        <= '0;
        link_alive_cnt       <= '0;
        link_status          <= LINK_DISCONNECTED;
        pending_ack_tx       <= 1'b0;
        man_err_burst_cnt    <= 16'd0;
      end

      // ---------------------------------------------------------------------
      // 3. Periodic Challenge Transmit & Link Alive Watchdog
      // ---------------------------------------------------------------------
      if (proto_eval_rx_carrier && link_status == LINK_DISCONNECTED) begin
        heartbeat_cnt  <= '0;
        link_alive_cnt <= '0;
        if (retry_cnt >= RETRY_TICKS - 1) begin
          retry_cnt            <= '0;
          pending_challenge_tx <= 1'b1;
        end else begin
          retry_cnt <= retry_cnt + 1;
        end
      end else if (proto_eval_rx_carrier && link_status != LINK_DISCONNECTED) begin
        retry_cnt <= '0;
        // Heartbeat periodic challenge sender
        if (heartbeat_cnt >= HEARTBEAT_TICKS - 1) begin
          heartbeat_cnt        <= '0;
          pending_challenge_tx <= 1'b1;
        end else begin
          heartbeat_cnt <= heartbeat_cnt + 1;
        end

        // Duplex Link Alive Watchdog: must receive peer ACKs to remain CONNECTED
        if (link_status == LINK_CONNECTED) begin
          if (link_alive_cnt >= LINK_ALIVE_TICKS - 1) begin
            link_status    <= LINK_DISCONNECTED;
            link_alive_cnt <= '0;
          end else begin
            link_alive_cnt <= link_alive_cnt + 1;
          end
        end else begin
          link_alive_cnt <= '0;
        end
      end else begin
        retry_cnt      <= '0;
        heartbeat_cnt  <= '0;
        link_alive_cnt <= '0;
      end

      // ---------------------------------------------------------------------
      // 4. Manchester Code Error Burst Monitor
      // ---------------------------------------------------------------------
      if (proto_eval_manchester_code_error) begin
        if (man_err_burst_cnt < 16'd50_000) begin
          man_err_burst_cnt <= man_err_burst_cnt + 16'd1;
        end
        if (man_err_burst_cnt >= 16'd1_000) begin
          link_status          <= LINK_DISCONNECTED;
          pending_challenge_tx <= 1'b1;
          retry_cnt            <= '0;
          link_alive_cnt       <= '0;
        end
      end

      // ---------------------------------------------------------------------
      // 5. TX Request Arbiter Handshake (ACKs have priority over Challenges)
      // ---------------------------------------------------------------------
      if (hs_tx_ack) begin
        if (pending_ack_tx) begin
          pending_ack_tx <= 1'b0;
        end else if (pending_challenge_tx) begin
          pending_challenge_tx <= 1'b0;
        end
        hs_tx_req <= 1'b0;
      end else if (pending_ack_tx) begin
        hs_tx_req  <= 1'b1;
        hs_tx_type <= MSG_ACCEPT;          // Type 2: Handshake Response ACK
        hs_tx_data <= peer_challenge_to_ack;
      end else if (pending_challenge_tx) begin
        hs_tx_req  <= 1'b1;
        hs_tx_type <= MSG_CAPABILITIES;    // Type 1: Handshake Challenge
        hs_tx_data <= my_challenge;
      end else begin
        hs_tx_req <= 1'b0;
      end

      // ---------------------------------------------------------------------
      // 6. RX Packet Processing & 2-Way Handshake Validation
      // ---------------------------------------------------------------------
      if (!proto_eval_rx_carrier) begin
        // Optical signal physically lost -> immediate disconnect
        link_status           <= LINK_DISCONNECTED;
        pending_ack_tx        <= 1'b0;
        link_alive_cnt        <= '0;
        man_err_burst_cnt     <= 16'd0;
      end else if (proto_eval_rx_valid) begin
        man_err_burst_cnt <= 16'd0;

        if (proto_eval_rx_type == MSG_CAPABILITIES) begin
          // Message 1 (Challenge):
          if (proto_eval_rx_data == my_challenge) begin
            /* Own token received with Type 1 header -> confirmed LOOPBACK */
            link_status    <= LINK_LOOPBACK;
            pending_ack_tx <= 1'b0;
          end else begin
            /* Peer board token received -> schedule Type 2 ACK with peer's ID */
            pending_ack_tx        <= 1'b1;
            peer_challenge_to_ack <= proto_eval_rx_data;
          end
        end else if (proto_eval_rx_type == MSG_ACCEPT) begin
          // Message 2 (Response / ACK):
          if (proto_eval_rx_data == my_challenge && link_status != LINK_LOOPBACK) begin
            /* Peer acknowledged our challenge token -> DUPLEX CONNECTED confirmed! */
            link_status    <= LINK_CONNECTED;
            link_alive_cnt <= '0;  // Refresh keepalive watchdog
          end
        end
      end
    end
  end

endmodule
