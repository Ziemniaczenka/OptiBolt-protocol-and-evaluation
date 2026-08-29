/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Optibolt transciever top module
 */

module optibolt_controller (
    input logic clk200,
    input logic rst_n,
    input logic [3:0] oversampling,
    input logic [3:0] bit_rate,

    /* Physical lines */
    input  logic rx_manchester,
    output logic tx_manchester,

    /* RX FIFO Interface */
    input logic rx_enable,
    output logic rx_empty,
    output logic rx_full,
    output logic [7:0] data_out,
    output logic [2:0] msg_type_out,

    output logic parity_error,
    output logic manchester_code_error,
    output logic preamble_error,

    /* TX FIFO Interface */
    input logic tx_enable,
    input logic [2:0] tx_msg_type,
    input logic [7:0] tx_data,
    output logic tx_empty,
    output logic tx_full

);

  import protocol_pkg::*;

  logic tick;

  /* Internal RX signals */
  logic decode_error, bit_valid, rx_binary, data_ready, rx_parity;
  logic [7:0] rx_data;
  logic [2:0] rx_msg_type;
  logic [11:0] rx_fifo_in, rx_fifo_out;

  //tx wires
  logic tx_binary, bit_out, tx_busy, transmit_start;
  logic [10:0] tx_fifo_in, tx_fifo_out;


  sampling_tick_generator u_sampling_tick_generator (
      .clk200,
      .rst_n,
      .oversampling,
      .bit_rate,
      .tick
  );

  //rx logic

  manchester_decoder u_manchester_decoder (
      .clk200,
      .rst_n,
      .tick,
      .rx_manchester,
      .oversampling,
      .rx_binary,
      .bit_valid,
      .decode_error
  );

  optibolt_receiver u_optibolt_receiver (
      .clk200,
      .rst_n,
      .rx_binary,
      .bit_valid,
      .decode_error,
      .data(rx_data),
      .data_ready,
      .msg_type(rx_msg_type),
      .parity(rx_parity),
      .manchester_code_error,
      .preamble_error
  );

  logic rx_calc_parity;
  logic rx_parity_err;

  assign rx_calc_parity = ^{rx_msg_type, rx_data};
  assign rx_parity_err  = data_ready && (rx_parity != rx_calc_parity);

  assign rx_fifo_in = {rx_msg_type, rx_data, rx_parity};

  fifo #(
      .B(12),
      .W(4)
  ) u_rx_fifo (
      .clk(clk200),
      .reset(!rst_n),
      .wr(data_ready && !rx_parity_err),
      .w_data(rx_fifo_in),
      .rd(rx_enable),
      .r_data(rx_fifo_out),
      .empty(rx_empty),
      .full(rx_full)
  );

  //tx logic
  manchester_coder u_manchester_coder (
      .clk200,
      .rst_n,
      .tick,
      .oversampling,
      .tx_binary,
      .tx_manchester,
      .bit_out
  );

  assign tx_fifo_in = {tx_msg_type, tx_data};

  fifo #(
      .B(11),
      .W(4)
  ) u_tx_fifo (
      .clk(clk200),
      .reset(!rst_n),
      .wr(tx_enable),
      .w_data(tx_fifo_in),
      .rd(transmit_start),
      .r_data(tx_fifo_out),
      .empty(tx_empty),
      .full(tx_full)
  );

  assign transmit_start = ~tx_empty & ~tx_busy;

  optibolt_transmitter u_optibolt_transmitter (
      .clk200,
      .rst_n,
      .header(tx_fifo_out[10:8]),
      .data  (tx_fifo_out[7:0]),
      .transmit_start,
      .bit_out,
      .tx_binary,
      .tx_busy
  );


  logic [2:0] fifo_msg_type;
  logic [7:0] fifo_data;
  logic fifo_parity;
  logic calc_parity;

  assign fifo_msg_type = rx_fifo_out[11:9];
  assign fifo_data     = rx_fifo_out[8:1];
  assign fifo_parity   = rx_fifo_out[0];

  assign calc_parity   = ^{fifo_msg_type, fifo_data};

  assign data_out      = fifo_data;
  assign msg_type_out  = fifo_msg_type;
  assign parity_error  = rx_parity_err;

endmodule
