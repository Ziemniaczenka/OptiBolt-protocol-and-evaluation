/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Multi-stage pipeline delay register.
 */

module delay #(
    parameter WIDTH   = 8,  // bit width of the input/output data
    parameter CLK_DEL = 1   // number of clock cycles the data is delayed
) (
    input logic clk,
    input logic rst_n,
    input logic [WIDTH-1:0] din,  // data to be delayed
    output logic [WIDTH-1:0] dout  // delayed data
);

  logic [WIDTH-1:0] del_mem[CLK_DEL-1:0];

  assign dout = del_mem[CLK_DEL-1];

  /* -----------------------------------------------------------------------------
 * The first delay stage
 * -------------------------------------------------------------------------- */
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      del_mem[0] <= 0;
    end else begin
      del_mem[0] <= din;
    end
  end

  /* -----------------------------------------------------------------------------
 * All the other delay stages
 * -------------------------------------------------------------------------- */
  genvar i;
  generate
    for (i = 1; i < CLK_DEL; i = i + 1) begin
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          del_mem[i] <= 0;
        end else begin
          del_mem[i] <= del_mem[i-1];
        end
      end
    end
  endgenerate

endmodule
