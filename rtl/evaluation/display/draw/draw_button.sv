/**
* Copyright (C) 2026  AGH University of Science and Technology
* MTM UEC2
* Author: Tomasz Więcławski & Sebastian Zoń
*
* Description:
* Button UI Component.
*/

import font_pkg::*;

module draw_button #(
    parameter int MAX_TEXT_LEN = 16
) (
    input logic        clk,
    input logic        rst_n,
    input logic [10:0] xstart,
    input logic [10:0] ystart,
    input logic [10:0] width,
    input logic [10:0] height,
    input logic [ 7:0] text_data  [0:MAX_TEXT_LEN-1],
    input logic        is_selected,

           vga_if.in        vga_in,
    output logic     [11:0] rgb_out,
    output logic            draw_en_out
);

  logic [11:0] rgb_bg, rgb_text;
  logic en_bg, en_text;

  // Background & Outline
  draw_rect u_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart),
      .ystart(ystart),
      .xend(xstart + width),
      .yend(ystart + height),
      .filled(1'b1),
      .thickness(11'd2),
      .color(is_selected ? 12'hF_F_0 : 12'h4_4_4),  // Yellow outline if selected
      .vga_in(vga_in),
      .rgb_out(rgb_bg),
      .draw_en_out(en_bg)
  );

  // Text Layer
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(MAX_TEXT_LEN),
      .COLOR(12'hF_F_F)
  ) u_text (
      .clk(clk),
      .rst_n(rst_n),
      .vsync(vga_in.vsync),
      .hsync(vga_in.hsync),
      .vga_x(12'(vga_in.hcount)),
      .vga_y(12'(vga_in.vcount)),
      .start_x(12'(xstart) + 12'd10),  // Offset text
      .start_y(12'(ystart) + 12'd10),
      .end_x(12'(xstart + width) - 12'd5),
      .end_y(12'(ystart + height) - 12'd5),
      .string_data(text_data),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(rgb_text),
      .draw_en(en_text)
  );

  // Multiplexer
  always_comb begin
    if (en_text) begin
      rgb_out = rgb_text;
      draw_en_out = 1'b1;
    end else begin
      rgb_out = rgb_bg;
      draw_en_out = en_bg;
    end
  end
endmodule
