/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * True Dual-Port BRAM
 */

module bram_tdp #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
) (
    input  logic                  clk_a,
    input  logic                  we_a,    // write enable
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic [DATA_WIDTH-1:0] din_a,
    output logic [DATA_WIDTH-1:0] dout_a,

    input  logic                  clk_b,
    input  logic                  we_b,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic [DATA_WIDTH-1:0] din_b,
    output logic [DATA_WIDTH-1:0] dout_b
);

  /**
    * Local variables and signals
    */

  logic [DATA_WIDTH-1:0] ram[0:(1<<ADDR_WIDTH)-1]; // bram

  /**
    * Internal logic
    */

  always_ff @(posedge clk_a) begin
    if (we_a) ram[addr_a] <= din_a;
    dout_a <= ram[addr_a];
  end

  always_ff @(posedge clk_b) begin
    if (we_b) ram[addr_b] <= din_b;
    dout_b <= ram[addr_b];
  end

endmodule
