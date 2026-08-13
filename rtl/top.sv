/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Top module connecting Evaluation and OptiBolt
 */

module top (
    // Common
    input logic clk74p25,
    input logic clk100,
    input logic clk400,
    input logic rst_n,

    // Evaluation
    output logic       vs,
    output logic       hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    output logic [ 3:0] an,
    output logic [ 6:0] seg,
    output logic        dp,

    // OptiBolt
    input  logic OptiBolt_rx,
    output logic OptiBolt_tx
);

  /**
    * Local variables and signals
    */

  // Control & Settings
  logic [3:0] eval_proto_baud_rate;
  logic [3:0] eval_proto_oversampling;
  logic       eval_proto_loopback_en;

  // TX Interface
  logic       eval_proto_tx_valid;
  logic [2:0] eval_proto_tx_type;
  logic [7:0] eval_proto_tx_data;
  logic       proto_eval_tx_full;
  logic       proto_eval_tx_empty;

  // RX Interface
  logic       proto_eval_rx_valid;
  logic [2:0] proto_eval_rx_type;
  logic [7:0] proto_eval_rx_data;
  logic       proto_eval_parity_error;
  logic       proto_eval_manchester_code_error;
  logic       proto_eval_preamble_error;

  // Telemetry & Status
  logic        proto_eval_link_status;
  logic [31:0] proto_eval_ber_count;
  logic [15:0] proto_eval_err_count;

  // OptiBolt Physical Signals (Physical TOSLINK cable connection: TX -> RX)
  logic tx_manchester_sig;
  logic rx_manchester_sig;

  assign OptiBolt_tx = tx_manchester_sig;
  assign rx_manchester_sig = OptiBolt_rx;
  assign proto_eval_link_status = ~proto_eval_preamble_error;

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

      // OptiBolt Protocol Interface
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
      .proto_eval_link_status(proto_eval_link_status),
      .proto_eval_ber_count(proto_eval_ber_count),
      .proto_eval_err_count(proto_eval_err_count)
  );

  optibolt_controller u_optibolt_controller (
      .clk400(clk400),
      .rst_n(rst_n),
      .oversampling(eval_proto_oversampling),
      .bit_rate(eval_proto_baud_rate),

      .rx_manchester(rx_manchester_sig),
      .tx_manchester(tx_manchester_sig),

      .rx_enable(~proto_eval_rx_valid),
      .rx_empty(),
      .rx_full(),
      .data_out(proto_eval_rx_data),
      .msg_type_out(proto_eval_rx_type),
      .parity_error(proto_eval_parity_error),
      .manchester_code_error(proto_eval_manchester_code_error),
      .preamble_error(proto_eval_preamble_error),

      .tx_enable(eval_proto_tx_valid),
      .tx_msg_type(eval_proto_tx_type),
      .tx_data(eval_proto_tx_data),
      .tx_empty(proto_eval_tx_empty),
      .tx_full(proto_eval_tx_full)
  );

endmodule

