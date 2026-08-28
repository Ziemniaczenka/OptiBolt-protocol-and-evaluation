/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Top module connecting Evaluation (100MHz / 74.25MHz) and OptiBolt (200MHz)
 * with robust Clock Domain Crossing (CDC) synchronizers and optical carrier detection.
 */

module top (
    // Common
    input logic clk74p25,
    input logic clk100,
    input logic clk200,
    input logic rst_n,

    // Evaluation
    output logic       vs,
    output logic       hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    output logic [3:0] an,
    output logic [6:0] seg,
    output logic       dp,

    // OptiBolt
    input  logic OptiBolt_rx,
    output logic OptiBolt_tx
);

  /**
    * Local variables and signals (Evaluation domain - clk100)
    */

  // Control & Settings (clk100)
  logic [ 3:0] eval_proto_baud_rate;
  logic [ 3:0] eval_proto_oversampling;
  logic        eval_proto_loopback_en;

  // TX Interface (clk100)
  logic        eval_proto_tx_valid;
  logic [ 2:0] eval_proto_tx_type;
  logic [ 7:0] eval_proto_tx_data;
  logic        proto_eval_tx_full;
  logic        proto_eval_tx_empty;

  // RX Interface (clk100)
  logic        proto_eval_rx_valid;
  logic [ 2:0] proto_eval_rx_type;
  logic [ 7:0] proto_eval_rx_data;
  logic        proto_eval_parity_error;
  logic        proto_eval_manchester_code_error;
  logic        proto_eval_preamble_error;
  logic        proto_eval_rx_carrier;

  // Telemetry & Status (clk100)
  logic        proto_eval_link_status;
  logic [31:0] proto_eval_ber_count;
  logic [15:0] proto_eval_err_count;

  assign proto_eval_link_status = ~proto_eval_preamble_error;

  /**
    * Local variables (OptiBolt domain - clk200)
    */

  logic [3:0] baud_rate_200;
  logic [3:0] oversampling_200;

  logic tx_manchester_sig;
  logic rx_manchester_sig;

  logic tx_empty_200;
  logic tx_full_200;

  logic rx_enable_200;
  logic rx_empty_200;
  logic rx_full_200;
  logic [7:0] rx_data_200;
  logic [2:0] rx_type_200;
  logic parity_error_200;
  logic manchester_error_200;
  logic preamble_error_200;

  assign OptiBolt_tx = tx_manchester_sig;
  assign rx_manchester_sig = OptiBolt_rx;

  // =========================================================================
  // Optical Light / Carrier Activity Detector on OptiBolt_rx (clk100)
  // =========================================================================
  logic rx_pin_sync0, rx_pin_sync1, rx_pin_d1;
  logic [19:0] rx_carrier_timer;

  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) begin
      rx_pin_sync0          <= 1'b0;
      rx_pin_sync1          <= 1'b0;
      rx_pin_d1             <= 1'b0;
      rx_carrier_timer      <= '0;
      proto_eval_rx_carrier <= 1'b0;
    end else begin
      rx_pin_sync0 <= OptiBolt_rx;
      rx_pin_sync1 <= rx_pin_sync0;
      rx_pin_d1    <= rx_pin_sync1;

      if (rx_pin_sync1 ^ rx_pin_d1) begin
        // Optical Manchester transitions detected (idle 101010 pattern or data)
        rx_carrier_timer      <= 20'd1_000_000;  // Hold active for 10ms after last edge
        proto_eval_rx_carrier <= 1'b1;
      end else if (rx_carrier_timer > 0) begin
        rx_carrier_timer <= rx_carrier_timer - 20'd1;
      end else begin
        proto_eval_rx_carrier <= 1'b0;
      end
    end
  end

  // =========================================================================
  // Clock Domain Crossing (CDC): clk100 <-> clk200
  // =========================================================================

  // 1. Settings (clk100 -> clk200)
  cdc_sync #(
      .WIDTH(8)
  ) u_cdc_settings (
      .clk_dst(clk200),
      .rst_n(rst_n),
      .d_in({eval_proto_baud_rate, eval_proto_oversampling}),
      .d_out({baud_rate_200, oversampling_200})
  );

  // 2. TX Asynchronous FIFO (clk100 -> clk200)
  logic [10:0] tx_async_dout_200;
  logic        tx_async_empty_200;
  logic        tx_async_rd_200;
  logic        tx_enable_200;

  async_fifo #(
      .DATA_WIDTH(11),  // 3-bit msg_type + 8-bit data
      .ADDR_WIDTH(5)    // Depth = 32 words
  ) u_tx_async_fifo (
      .clk_wr(clk100),
      .rst_wr_n(rst_n),
      .wr_en(eval_proto_tx_valid),
      .din({eval_proto_tx_type, eval_proto_tx_data}),
      .full(proto_eval_tx_full),

      .clk_rd(clk200),
      .rst_rd_n(rst_n),
      .rd_en(tx_async_rd_200),
      .dout(tx_async_dout_200),
      .empty(tx_async_empty_200)
  );

  assign proto_eval_tx_empty = 1'b0;

  // Transfer from TX async_fifo into optibolt_controller tx_fifo
  assign tx_enable_200 = !tx_async_empty_200 && !tx_full_200;
  assign tx_async_rd_200 = tx_enable_200;

  // 3. RX Asynchronous FIFO (clk200 -> clk100)
  logic [10:0] rx_async_dout_100;
  logic        rx_async_empty_100;
  logic        rx_async_full_200;
  logic        rx_async_wr_200;

  assign rx_enable_200   = !rx_empty_200 && !rx_async_full_200;
  assign rx_async_wr_200 = rx_enable_200;

  async_fifo #(
      .DATA_WIDTH(11),  // 3-bit msg_type + 8-bit data
      .ADDR_WIDTH(5)    // Depth = 32 words
  ) u_rx_async_fifo (
      .clk_wr(clk200),
      .rst_wr_n(rst_n),
      .wr_en(rx_async_wr_200),
      .din({rx_type_200, rx_data_200}),
      .full(rx_async_full_200),

      .clk_rd(clk100),
      .rst_rd_n(rst_n),
      .rd_en(!rx_async_empty_100),
      .dout(rx_async_dout_100),
      .empty(rx_async_empty_100)
  );

  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) begin
      proto_eval_rx_valid <= 1'b0;
      proto_eval_rx_type  <= 3'b000;
      proto_eval_rx_data  <= 8'h00;
    end else begin
      if (!rx_async_empty_100) begin
        proto_eval_rx_valid <= 1'b1;
        proto_eval_rx_type  <= rx_async_dout_100[10:8];
        proto_eval_rx_data  <= rx_async_dout_100[7:0];
      end else begin
        proto_eval_rx_valid <= 1'b0;
      end
    end
  end

  // Error Status Synchronizers (clk200 -> clk100)
  cdc_sync #(
      .WIDTH(3)
  ) u_cdc_rx_err (
      .clk_dst(clk100),
      .rst_n(rst_n),
      .d_in({preamble_error_200, parity_error_200, manchester_error_200}),
      .d_out({proto_eval_preamble_error, proto_eval_parity_error, proto_eval_manchester_code_error})
  );

  /**
    *  Submodules instances
    */

  top_evaluation u_top_evaluation (
      .clk74p25(clk74p25),
      .clk100(clk100),
      .rst_n(rst_n),
      .vs(vs),
      .hs(hs),
      .r(r),
      .g(g),
      .b(b),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .an(an),
      .seg(seg),
      .dp(dp),

      // OptiBolt Protocol Interface (clk100)
      .eval_proto_baud_rate(eval_proto_baud_rate),
      .eval_proto_oversampling(eval_proto_oversampling),
      .eval_proto_loopback_en(eval_proto_loopback_en),
      .eval_proto_tx_valid(eval_proto_tx_valid),
      .eval_proto_tx_type(eval_proto_tx_type),
      .eval_proto_tx_data(eval_proto_tx_data),
      .proto_eval_tx_full(proto_eval_tx_full),
      .proto_eval_tx_empty(proto_eval_tx_empty),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_parity_error(proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error(proto_eval_preamble_error),
      .proto_eval_rx_carrier(proto_eval_rx_carrier),
      .proto_eval_link_status(proto_eval_link_status),
      .proto_eval_ber_count(proto_eval_ber_count),
      .proto_eval_err_count(proto_eval_err_count)
  );

  optibolt_controller u_optibolt_controller (
      .clk200(clk200),
      .rst_n(rst_n),
      .oversampling(oversampling_200),
      .bit_rate(baud_rate_200),

      .rx_manchester(rx_manchester_sig),
      .tx_manchester(tx_manchester_sig),

      .rx_enable(rx_enable_200),
      .rx_empty(rx_empty_200),
      .rx_full(rx_full_200),
      .data_out(rx_data_200),
      .msg_type_out(rx_type_200),
      .parity_error(parity_error_200),
      .manchester_code_error(manchester_error_200),
      .preamble_error(preamble_error_200),

      .tx_enable(tx_enable_200),
      .tx_msg_type(tx_async_dout_200[10:8]),
      .tx_data(tx_async_dout_200[7:0]),
      .tx_empty(tx_empty_200),
      .tx_full(tx_full_200)
  );

endmodule
