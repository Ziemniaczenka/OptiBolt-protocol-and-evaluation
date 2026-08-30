/**
* Copyright (C) 2026  AGH University of Science and Technology
* MTM UEC2
* Author: Tomasz Więcławski & Sebastian Zoń
*
* Description:
* Progress bar UI Component.
*/

module draw_progress_bar #(
    parameter [11:0] BAR_COLOR = 12'h0_F_8
) (
    input  logic            clk,
    input  logic            rst_n,
    input  logic     [10:0] xstart,
    input  logic     [10:0] ystart,
    input  logic     [10:0] width,
    input  logic     [10:0] height,
    input  logic     [ 7:0] progress,       // 0-255
    input  logic     [11:0] dynamic_color,
           vga_if.in        vga_in,
    output logic     [11:0] rgb_out,
    output logic            draw_en_out
);

  /**
    * Local variables and signals
    */

  logic [11:0] rgb_bg;
  logic en_bg, en_fill;
  logic [10:0] fill_width;
  logic [11:0] active_fill_color;
  assign active_fill_color = (dynamic_color != 12'h000) ? dynamic_color : BAR_COLOR;

  /**
    * Internal logic
    */

  assign fill_width = 11'((20'(width - 11'd1) * progress) >> 8);  // Scale 0-255 to width

  /**
    * Submodules instances
    */

  draw_rect u_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart),
      .ystart(ystart),
      .xend(xstart + width),
      .yend(ystart + height),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h8_8_8),
      .vga_in(vga_in),
      .rgb_out(rgb_bg),
      .draw_en_out(en_bg)
  );

  draw_rect u_fill (
      .clk        (clk),
      .rst_n      (rst_n),
      .xstart     (xstart + 11'd1),
      .ystart     (ystart + 11'd2),
      .xend       (xstart + 11'd1 + fill_width),
      .yend       (ystart + height - 11'd2),
      .filled     (1'b1),
      .thickness  (11'd0),
      .color      (active_fill_color),
      .vga_in     (vga_in),
      .rgb_out    (),
      .draw_en_out(en_fill)
  );

  always_comb begin
    if (en_bg) begin
      rgb_out     = rgb_bg;
      draw_en_out = 1'b1;
    end else if (en_fill) begin
      rgb_out     = active_fill_color;
      draw_en_out = 1'b1;
    end else begin
      rgb_out     = 12'h0;
      draw_en_out = 1'b0;
    end
  end

endmodule
