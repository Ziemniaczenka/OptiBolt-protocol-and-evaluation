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

    //OptiBolt
    input  logic OptiBolt_rx,
    output logic OptiBolt_tx
);

  /**
    * Local variables and signals
    */

  // TODO signal assigments between Eval and OptiBolt

  /**
    * Signals assignments
    */

  // dummy assigment for now
  assign OptiBolt_tx = 1'b0;


  /**
    * FPGA submodules placement
    */

optibolt_controller u_optibolt_controller (


);
  //   top_protocol u_top_protocol(
  //   );

endmodule
