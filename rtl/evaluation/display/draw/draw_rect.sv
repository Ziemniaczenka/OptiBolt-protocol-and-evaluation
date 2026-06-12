/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw rectangle.
 */

module draw_rect (
    input logic        clk,
    input logic        rst_n,
    input logic [10:0] xstart,
    input logic [10:0] ystart,
    input logic [10:0] xend,
    input logic [10:0] yend,
    input logic        filled,
    input logic [10:0] thickness,
    input logic [11:0] color,

    vga_if.in vga_in,

    output logic [11:0] rgb_out,
    output logic        draw_en_out
);

  import vga_pkg::*;

  /**
     * Local variables and signals
     */
  logic [11:0] rgb_nxt;
  logic        draw_en_nxt;
  logic        in_outer;
  logic        in_inner;
  logic        draw_en;

  /*
    * Internal logic
    */

  always_comb begin : rect_bounds_blk
    in_outer = (vga_in.hcount >= xstart) && (vga_in.hcount <= xend) &&
                   (vga_in.vcount >= ystart) && (vga_in.vcount <= yend);

    in_inner = (vga_in.hcount >= (xstart + thickness)) && ((vga_in.hcount + thickness) <= xend) &&
                   (vga_in.vcount >= (ystart + thickness)) && ((vga_in.vcount + thickness) <= yend);

    draw_en = in_outer && (filled || !in_inner);
  end

  always_ff @(posedge clk or negedge rst_n) begin : rect_ff_blk
    if (!rst_n) begin
      rgb_out <= '0;
      draw_en_out <= 1'b0;
    end else begin
      rgb_out <= rgb_nxt;
      draw_en_out <= draw_en_nxt;
    end
  end

  always_comb begin : rect_comb_blk
    if (vga_in.vblnk || vga_in.hblnk) begin
      rgb_nxt = 12'h0_0_0;
      draw_en_nxt = 1'b0;
    end else if (draw_en) begin
      rgb_nxt = color;
      draw_en_nxt = 1'b1;
    end else begin
      rgb_nxt = vga_in.rgb;
      draw_en_nxt = 1'b0;
    end
  end

endmodule
