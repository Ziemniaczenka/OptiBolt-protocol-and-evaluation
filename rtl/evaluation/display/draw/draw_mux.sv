/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Multiplexing many outputs of draw functions.
 */

module draw_mux #(
    parameter int INPUT_COUNT = 2
) (
    input logic                         clk,
    input logic                         rst_n,
    input logic [INPUT_COUNT-1:0][11:0] in_rgb,
    input logic [INPUT_COUNT-1:0]       in_draw_en,

    vga_if.in vga_in,

    output logic [11:0] out_rgb
);

  import vga_pkg::*;

  /**
     * Local variables and signals
     */

  logic [11:0] out_rgb_nxt;

  always_comb begin : mux_comb_blk
    out_rgb_nxt = vga_in.rgb;

    // Priorytetowy multiplekser
    for (int i = INPUT_COUNT - 1; i >= 0; i--) begin
      if (in_draw_en[i]) begin
        out_rgb_nxt = in_rgb[i];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : mux_ff_blk
    if (!rst_n) begin
      out_rgb <= '0;
    end else begin
      out_rgb <= out_rgb_nxt;
    end
  end

endmodule
