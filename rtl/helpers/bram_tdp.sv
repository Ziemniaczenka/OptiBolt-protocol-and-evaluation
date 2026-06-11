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
    input  logic                  clk_b,
    bram_if.memory                port_a,
    bram_if.memory                port_b
);

  /**
    * Local variables and signals
    */

  logic [DATA_WIDTH-1:0] ram[0:(1<<ADDR_WIDTH)-1]; // bram

  /**
    * Internal logic
    */

  always_ff @(posedge clk_a) begin
    if (port_a.en) begin
      if (port_a.we) ram[port_a.addr] <= port_a.din;
      port_a.dout <= ram[port_a.addr];
    end
  end

  always_ff @(posedge clk_b) begin
    if (port_b.en) begin
      if (port_b.we) ram[port_b.addr] <= port_b.din;
      port_b.dout <= ram[port_b.addr];
    end
  end

endmodule
