/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Clock Domain Crossing (CDC) Bridge between Evaluation (100 MHz) and OptiBolt (200 MHz).
 */

`timescale 1ns / 1ps

module optibolt_cdc_bridge (
    /* Evaluation domain (100 MHz) */
    input  logic       clk100,
    input  logic       rst_n,
    input  logic [3:0] eval_proto_baud_rate,
    input  logic [3:0] eval_proto_oversampling,
    input  logic       eval_proto_tx_valid,
    input  logic [2:0] eval_proto_tx_type,
    input  logic [7:0] eval_proto_tx_data,
    output logic       proto_eval_tx_full,
    output logic       proto_eval_tx_empty,
    output logic       proto_eval_rx_valid,
    output logic [2:0] proto_eval_rx_type,
    output logic [7:0] proto_eval_rx_data,
    output logic       proto_eval_parity_error,
    output logic       proto_eval_manchester_code_error,
    output logic       proto_eval_preamble_error,

    /* OptiBolt domain (200 MHz) */
    input  logic       clk200,
    output logic [3:0] baud_rate_200,
    output logic [3:0] oversampling_200,
    input  logic       tx_full_200,
    input  logic       tx_idle_200,
    output logic       tx_enable_200,
    output logic [2:0] tx_type_200,
    output logic [7:0] tx_data_200,
    input  logic       rx_empty_200,
    output logic       rx_enable_200,
    input  logic [2:0] rx_type_200,
    input  logic [7:0] rx_data_200,
    input  logic       parity_error_200,
    input  logic       manchester_error_200,
    input  logic       preamble_error_200
);

  always_ff @(posedge clk200 or negedge rst_n) begin
    if (!rst_n) begin
      baud_rate_200    <= 4'd1;
      oversampling_200 <= 4'd0;
    end else begin
      baud_rate_200    <= eval_proto_baud_rate;
      oversampling_200 <= eval_proto_oversampling;
    end
  end

  /* 2. Transmit Asynchronous FIFO (clk100 -> clk200, depth 32) */
  logic [10:0] tx_async_dout_200;
  logic        tx_async_empty_200;
  logic        tx_async_empty_100;
  logic        tx_idle_100;

  assign tx_enable_200 = !tx_async_empty_200 && !tx_full_200;
  assign tx_type_200   = tx_async_dout_200[10:8];
  assign tx_data_200   = tx_async_dout_200[7:0];


  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) tx_idle_100 <= 1'b1;
    else tx_idle_100 <= tx_idle_200;
  end

  assign proto_eval_tx_empty = tx_async_empty_100 && tx_idle_100;

  async_fifo #(
      .DATA_WIDTH(11),
      .ADDR_WIDTH(5)
  ) u_tx_async_fifo (
      .clk_wr  (clk100),
      .rst_wr_n(rst_n),
      .wr_en   (eval_proto_tx_valid),
      .din     ({eval_proto_tx_type, eval_proto_tx_data}),
      .full    (proto_eval_tx_full),
      .empty_wr(tx_async_empty_100),

      .clk_rd  (clk200),
      .rst_rd_n(rst_n),
      .rd_en   (tx_enable_200),
      .dout    (tx_async_dout_200),
      .empty   (tx_async_empty_200)
  );

  /* 3. Receive Asynchronous FIFO (clk200 -> clk100, depth 32) */
  logic [10:0] rx_async_dout_100;
  logic        rx_async_empty_100;
  logic        rx_async_full_200;

  assign rx_enable_200 = !rx_empty_200 && !rx_async_full_200;

  async_fifo #(
      .DATA_WIDTH(11),
      .ADDR_WIDTH(5)
  ) u_rx_async_fifo (
      .clk_wr  (clk200),
      .rst_wr_n(rst_n),
      .wr_en   (rx_enable_200),
      .din     ({rx_type_200, rx_data_200}),
      .full    (rx_async_full_200),
      .empty_wr(),

      .clk_rd  (clk100),
      .rst_rd_n(rst_n),
      .rd_en   (!rx_async_empty_100),
      .dout    (rx_async_dout_100),
      .empty   (rx_async_empty_100)
  );

  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) begin
      proto_eval_rx_valid <= 1'b0;
      proto_eval_rx_type  <= 3'd0;
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

  // 4. Error synchronization (pulse stretching)

  logic man_err_d1;  // delayed by 1 cycle
  logic par_err_d1;
  logic pre_err_d1;

  always_ff @(posedge clk200 or negedge rst_n) begin
    if (!rst_n) begin
      man_err_d1 <= 1'b0;
      par_err_d1 <= 1'b0;
      pre_err_d1 <= 1'b0;
    end else begin
      man_err_d1 <= manchester_error_200;
      par_err_d1 <= parity_error_200;
      pre_err_d1 <= preamble_error_200;
    end
  end
  wire man_err_wide = manchester_error_200 || man_err_d1;
  wire par_err_wide = parity_error_200 || par_err_d1;
  wire pre_err_wide = preamble_error_200 || pre_err_d1;

  always_ff @(posedge clk100 or negedge rst_n) begin
    if (!rst_n) begin
      proto_eval_manchester_code_error <= 1'b0;
      proto_eval_parity_error <= 1'b0;
      proto_eval_preamble_error <= 1'b0;
    end else begin
      proto_eval_manchester_code_error <= man_err_wide;
      proto_eval_parity_error <= par_err_wide;
      proto_eval_preamble_error <= pre_err_wide;
    end
  end

endmodule
