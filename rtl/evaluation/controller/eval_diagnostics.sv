/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Dedicated diagnostics and error metrics processing module.
 * Tracks hardware Manchester, preamble, and parity errors with edge detection.
 * Updates display counters periodically (0.5s window) and maps counts to
 * logarithmic progress bar levels (0..255) and severity gradient colors.
 */

module eval_diagnostics #(
    parameter int WINDOW_CYCLES = 50_000_000
) (
    input  logic        clk,
    input  logic        rst_n,

    // Error strobe inputs from receiver
    input  logic        proto_eval_manchester_code_error,
    input  logic        proto_eval_preamble_error,
    input  logic        proto_eval_parity_error,
    input  logic [ 1:0] link_status,

    // Output telemetry to display
    output logic [15:0] err_man_cnt,
    output logic [15:0] err_pre_cnt,
    output logic [15:0] err_par_cnt,
    output logic [ 7:0] prog_man,
    output logic [ 7:0] prog_pre,
    output logic [ 7:0] prog_par,
    output logic [ 7:0] prog_hlt,
    output logic [11:0] color_man,
    output logic [11:0] color_pre,
    output logic [11:0] color_par,
    output logic [11:0] color_hlt
);

  // Periodic 0.5s Error Metric Window Registers
  logic [15:0] err_man_acc, err_pre_acc, err_par_acc;

  // Periodic window decay timer instantiated using counter.sv
  logic err_window_tick;
  counter #(
      .VALUE_MAX(WINDOW_CYCLES - 1)
  ) u_err_window_counter (
      .clk     (clk),
      .rst_n   (rst_n),
      .enabled (1'b1),
      .value   (),
      .overflow(err_window_tick)
  );

  // Edge detectors and accumulator logic
  logic man_err_d1, pre_err_d1, par_err_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      man_err_d1  <= 1'b0;
      pre_err_d1  <= 1'b0;
      par_err_d1  <= 1'b0;
      err_man_acc <= 16'd0;
      err_pre_acc <= 16'd0;
      err_par_acc <= 16'd0;
      err_man_cnt <= 16'd0;
      err_pre_cnt <= 16'd0;
      err_par_cnt <= 16'd0;
    end else begin
      man_err_d1 <= proto_eval_manchester_code_error;
      pre_err_d1 <= proto_eval_preamble_error;
      par_err_d1 <= proto_eval_parity_error;

      if (proto_eval_manchester_code_error && !man_err_d1) begin
        if (err_man_acc != 16'hFFFF) err_man_acc <= err_man_acc + 16'd1;
      end
      if (proto_eval_preamble_error && !pre_err_d1) begin
        if (err_pre_acc != 16'hFFFF) err_pre_acc <= err_pre_acc + 16'd1;
      end
      if (proto_eval_parity_error && !par_err_d1) begin
        if (err_par_acc != 16'hFFFF) err_par_acc <= err_par_acc + 16'd1;
      end

      // Latch counts to display registers and reset accumulator every 0.5s
      if (err_window_tick) begin
        err_man_cnt <= err_man_acc;
        err_pre_cnt <= err_pre_acc;
        err_par_cnt <= err_par_acc;
        err_man_acc <= 16'd0;
        err_pre_acc <= 16'd0;
        err_par_acc <= 16'd0;
      end
    end
  end

  // Synthesizable Log-Scale Mapping Function for Real-Time Error Progress Bars
  function automatic logic [7:0] log_scale_progress(input [15:0] cnt);
    if (cnt == 16'd0)        return 8'd0;
    else if (cnt < 16'd5)    return 8'd25;
    else if (cnt < 16'd20)   return 8'd60;
    else if (cnt < 16'd100)  return 8'd120;
    else if (cnt < 16'd500)  return 8'd180;
    else if (cnt < 16'd2000) return 8'd220;
    else                     return 8'd255;
  endfunction

  // Synthesizable 4-Color Gradient Function based on Error Severity
  function automatic logic [11:0] error_color(input [7:0] prog);
    if (prog < 8'd40)        return 12'h3C5; // Green
    else if (prog < 8'd120)  return 12'hEE3; // Yellow
    else if (prog < 8'd200)  return 12'hFA2; // Orange
    else                     return 12'hF33; // Red
  endfunction

  // Dynamic Health Rating Calculator (100% minus aggregate error penalties)
  function automatic logic [7:0] calc_health(input [15:0] man, input [15:0] pre, input [15:0] par, input [1:0] link);
    logic [17:0] penalty;
    if (link == 2'b00) return 8'd0; // Disconnected = 0% health
    penalty = (man * 18'd5) + (pre * 18'd3) + (par * 18'd8);
    if (penalty >= 18'd255) return 8'd10; // Floor at 10 (critical)
    else return 8'(18'd255 - penalty);
  endfunction

  function automatic logic [11:0] health_color(input [7:0] hlt);
    if (hlt >= 8'd200)       return 12'h3C5; // Green
    else if (hlt >= 8'd140)  return 12'hEE3; // Yellow
    else if (hlt >= 8'd70)   return 12'hFA2; // Orange
    else                     return 12'hF33; // Red
  endfunction

  assign prog_man  = log_scale_progress(err_man_cnt);
  assign prog_pre  = log_scale_progress(err_pre_cnt);
  assign prog_par  = log_scale_progress(err_par_cnt);
  assign prog_hlt  = calc_health(err_man_cnt, err_pre_cnt, err_par_cnt, link_status);

  assign color_man = error_color(prog_man);
  assign color_pre = error_color(prog_pre);
  assign color_par = error_color(prog_par);
  assign color_hlt = health_color(prog_hlt);

endmodule
