/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Edge detector for rising and falling edges.
 */

module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic in,
    output logic rise,
    output logic fall
);

  /**
    * Local variables and signals
    */

  logic in_prev;

  /**
    * Internal logic
    */

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) in_prev <= 1'b0;
    else in_prev <= in;
  end

  assign rise = in && !in_prev;
  assign fall = !in && in_prev;

endmodule
