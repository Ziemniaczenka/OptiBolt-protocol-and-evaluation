/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Top-level structural module connecting Evaluation (100 MHz / 74.25 MHz),
 * OptiBolt Core (200 MHz), Clock Domain Crossing Bridge, and Optical Carrier Detector.
 */

`timescale 1ns / 1ps

module top #(
    parameter int CARRIER_HOLD_CYCLES = 1_000_000
) (
    /* Clocks and Reset */
    input  logic       clk74p25,
    input  logic       clk100,
    input  logic       clk200,
    input  logic       rst_n,

    /* Evaluation UI Ports */
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

    /* Optical Channel Interface */
    input  logic       OptiBolt_rx,
    output logic       OptiBolt_tx
);

  /* Evaluation domain signals (100 MHz) */
  logic [3:0] eval_proto_baud_rate;
  logic [3:0] eval_proto_oversampling;
  logic       eval_proto_loopback_en;
  logic       eval_proto_tx_valid;
  logic [2:0] eval_proto_tx_type;
  logic [7:0] eval_proto_tx_data;
  logic       proto_eval_tx_full;
  logic       proto_eval_rx_valid;
  logic [2:0] proto_eval_rx_type;
  logic [7:0] proto_eval_rx_data;
  logic       proto_eval_parity_error;
  logic       proto_eval_manchester_code_error;
  logic       proto_eval_preamble_error;
  logic       proto_eval_rx_carrier;
  logic       proto_eval_tx_empty;
  logic       tx_idle_200;
  logic [1:0] link_status;
  logic       contract_active;
  logic [1:0] active_voltage_id;
  logic [3:0] active_amps;
  logic       active_is_source;
  logic [2:0] pwr_status_code;

  /* OptiBolt domain signals (200 MHz) */
  logic [3:0] baud_rate_200;
  logic [3:0] oversampling_200;
  logic       tx_enable_200;
  logic       tx_full_200;
  logic       tx_empty_200;
  logic [2:0] tx_type_200;
  logic [7:0] tx_data_200;
  logic       rx_enable_200;
  logic       rx_empty_200;
  logic       rx_full_200;
  logic [2:0] rx_type_200;
  logic [7:0] rx_data_200;
  logic       parity_error_200;
  logic       manchester_error_200;
  logic       preamble_error_200;

  /* 1. Optical Carrier Detector (100 MHz) */
  optical_carrier_detector #(
      .HOLD_CYCLES(CARRIER_HOLD_CYCLES)
  ) u_optical_carrier_detector (
      .clk             (clk100),
      .rst_n           (rst_n),
      .rx_pin          (OptiBolt_rx),
      .carrier_detected(proto_eval_rx_carrier)
  );

  /* 2. Clock Domain Crossing Bridge (100 MHz <-> 200 MHz) */
  optibolt_cdc_bridge u_optibolt_cdc_bridge (
      /* Evaluation domain */
      .clk100                          (clk100),
      .rst_n                           (rst_n),
      .eval_proto_baud_rate            (eval_proto_baud_rate),
      .eval_proto_oversampling         (eval_proto_oversampling),
      .eval_proto_tx_valid             (eval_proto_tx_valid),
      .eval_proto_tx_type              (eval_proto_tx_type),
      .eval_proto_tx_data              (eval_proto_tx_data),
      .proto_eval_tx_full              (proto_eval_tx_full),
      .proto_eval_tx_empty             (proto_eval_tx_empty),
      .proto_eval_rx_valid             (proto_eval_rx_valid),
      .proto_eval_rx_type              (proto_eval_rx_type),
      .proto_eval_rx_data              (proto_eval_rx_data),
      .proto_eval_parity_error         (proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error       (proto_eval_preamble_error),

      /* OptiBolt domain */
      .clk200                          (clk200),
      .baud_rate_200                   (baud_rate_200),
      .oversampling_200                (oversampling_200),
      .tx_full_200                     (tx_full_200),
      .tx_idle_200                     (tx_idle_200),
      .tx_enable_200                   (tx_enable_200),
      .tx_type_200                     (tx_type_200),
      .tx_data_200                     (tx_data_200),
      .rx_empty_200                    (rx_empty_200),
      .rx_enable_200                   (rx_enable_200),
      .rx_type_200                     (rx_type_200),
      .rx_data_200                     (rx_data_200),
      .parity_error_200                (parity_error_200),
      .manchester_error_200            (manchester_error_200),
      .preamble_error_200              (preamble_error_200)
  );

  /* 3. Evaluation Subsystem */
  top_evaluation u_top_evaluation (
      .clk74p25                        (clk74p25),
      .clk100                          (clk100),
      .rst_n                           (rst_n),
      .vs                              (vs),
      .hs                              (hs),
      .r                               (r),
      .g                               (g),
      .b                               (b),
      .ps2_clk                         (ps2_clk),
      .ps2_data                        (ps2_data),
      .an                              (an),
      .seg                             (seg),
      .dp                              (dp),
      .eval_proto_baud_rate            (eval_proto_baud_rate),
      .eval_proto_oversampling         (eval_proto_oversampling),
      .eval_proto_loopback_en          (eval_proto_loopback_en),
      .eval_proto_tx_valid             (eval_proto_tx_valid),
      .eval_proto_tx_type              (eval_proto_tx_type),
      .eval_proto_tx_data              (eval_proto_tx_data),
      .proto_eval_tx_full              (proto_eval_tx_full),
      .proto_eval_tx_empty             (proto_eval_tx_empty),
      .proto_eval_rx_valid             (proto_eval_rx_valid),
      .proto_eval_rx_type              (proto_eval_rx_type),
      .proto_eval_rx_data              (proto_eval_rx_data),
      .proto_eval_parity_error         (proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error       (proto_eval_preamble_error),
      .proto_eval_rx_carrier           (proto_eval_rx_carrier),
      .proto_eval_link_status          (),
      .proto_eval_ber_count            (),
      .proto_eval_err_count            ()
  );

  /* 4. OptiBolt Protocol Controller */
  optibolt_controller u_optibolt_controller (
      .clk200               (clk200),
      .rst_n                (rst_n),
      .rx_manchester        (OptiBolt_rx),
      .bit_rate             (baud_rate_200),
      .oversampling         (oversampling_200),
      .tx_enable            (tx_enable_200),
      .tx_msg_type          (tx_type_200),
      .tx_data              (tx_data_200),
      .rx_enable            (rx_enable_200),
      .tx_manchester        (OptiBolt_tx),
      .tx_empty             (tx_empty_200),
      .tx_full              (tx_full_200),
      .tx_idle              (tx_idle_200),
      .rx_empty             (rx_empty_200),
      .rx_full              (rx_full_200),
      .msg_type_out         (rx_type_200),
      .data_out             (rx_data_200),
      .parity_error         (parity_error_200),
      .manchester_code_error(manchester_error_200),
      .preamble_error       (preamble_error_200)
  );

endmodule
