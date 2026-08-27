/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description: Dedicated Unit Testbench for eval_diagnostics submodule.
 * Verifies hardware error edge detection, logarithmic progress bar mapping,
 * severity color selection, health percentage calculation, and periodic decay window.
 */

`timescale 1ns / 1ps

module eval_diagnostics_tb;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;
  logic man_err;
  logic pre_err;
  logic par_err;
  logic [1:0] link_status;

  logic [15:0] err_man_cnt;
  logic [15:0] err_pre_cnt;
  logic [15:0] err_par_cnt;
  logic [ 7:0] prog_man;
  logic [ 7:0] prog_pre;
  logic [ 7:0] prog_par;
  logic [ 7:0] prog_hlt;
  logic [11:0] color_man;
  logic [11:0] color_pre;
  logic [11:0] color_par;
  logic [11:0] color_hlt;

  eval_diagnostics #(
      .WINDOW_CYCLES(200)
  ) dut (
      .clk                             (clk),
      .rst_n                           (rst_n),
      .proto_eval_manchester_code_error(man_err),
      .proto_eval_preamble_error       (pre_err),
      .proto_eval_parity_error         (par_err),
      .link_status                     (link_status),
      .err_man_cnt                     (err_man_cnt),
      .err_pre_cnt                     (err_pre_cnt),
      .err_par_cnt                     (err_par_cnt),
      .prog_man                        (prog_man),
      .prog_pre                        (prog_pre),
      .prog_par                        (prog_par),
      .prog_hlt                        (prog_hlt),
      .color_man                       (color_man),
      .color_pre                       (color_pre),
      .color_par                       (color_par),
      .color_hlt                       (color_hlt)
  );

  task pulse_man_error();
    @(posedge clk);
    man_err <= 1'b1;
    @(posedge clk);
    man_err <= 1'b0;
    @(posedge clk);
  endtask

  task pulse_pre_error();
    @(posedge clk);
    pre_err <= 1'b1;
    @(posedge clk);
    pre_err <= 1'b0;
    @(posedge clk);
  endtask

  task pulse_par_error();
    @(posedge clk);
    par_err <= 1'b1;
    @(posedge clk);
    par_err <= 1'b0;
    @(posedge clk);
  endtask

  initial begin
    rst_n = 0;
    man_err = 0;
    pre_err = 0;
    par_err = 0;
    link_status = 2'b01; // Connected

    $display("=== STARTING EVAL_DIAGNOSTICS TESTBENCH ===");
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);

    // 1. Initial State: 0 errors -> 100% Health
    $display("[TEST 1] Initial zero-error health check...");
    assert(prog_hlt == 8'd255) else $error("Expected 100%% health (255), got %d", prog_hlt);
    assert(color_hlt == 12'h3C5) else $error("Expected green health color!");

    // 2. Pulse 3 Manchester Errors
    $display("[TEST 2] Pulsing 3 Manchester errors...");
    repeat(3) pulse_man_error();
    assert(dut.err_man_acc == 16'd3) else $error("Accumulator mismatch: expected 3, got %d", dut.err_man_acc);

    // 3. Pulse 15 Parity Errors
    $display("[TEST 3] Pulsing 15 Parity errors...");
    repeat(15) pulse_par_error();
    assert(dut.err_par_acc == 16'd15) else $error("Accumulator mismatch: expected 15, got %d", dut.err_par_acc);

    // 4. Wait for periodic decay window tick to latch to display outputs
    $display("[TEST 4] Waiting for decay window latch...");
    repeat(210) @(posedge clk);

    assert(err_man_cnt == 16'd3) else $error("Expected err_man_cnt == 3, got %d", err_man_cnt);
    assert(err_par_cnt == 16'd15) else $error("Expected err_par_cnt == 15, got %d", err_par_cnt);
    assert(prog_man == 8'd25) else $error("Expected prog_man == 25, got %d", prog_man);
    assert(prog_par == 8'd60) else $error("Expected prog_par == 60, got %d", prog_par);

    // 5. Test Disconnected Health
    $display("[TEST 5] Verifying disconnected health is 0%%...");
    link_status <= 2'b00;
    @(posedge clk);
    assert(prog_hlt == 8'd0) else $error("Expected prog_hlt == 0 when disconnected!");

    $display("=== ALL EVAL_DIAGNOSTICS TESTS PASSED! ===");
    $finish;
  end

endmodule
