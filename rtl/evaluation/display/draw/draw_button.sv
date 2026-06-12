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
    parameter int    MAX_TEXT_LEN = 16,
    parameter int    LEFT_MARGIN  = 10,
    parameter font_t FONT         = FONT_11x7,
    parameter string FONT_PATH    = FONT_11x7_PATH
) (
    input logic               clk,
    input logic               rst_n,
    input logic        [10:0] xstart,
    input logic        [10:0] ystart,
    input logic        [10:0] width,
    input logic        [10:0] height,
          bram_if.read        text_bram,
    input logic               is_selected,

           vga_if.in        vga_in,
    output logic     [11:0] rgb_out,
    output logic            draw_en_out
);

  /**
    * Local variables and signals
    */

  logic [11:0] rgb_bg, rgb_text;
  logic en_bg, en_text;

  /**
    * Submodules instances
    */

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
      .FONT(FONT),
      .FONT_PATH(FONT_PATH),
      .MAX_STRING_LEN(MAX_TEXT_LEN),
      .COLOR(12'hF_F_F)
  ) u_text (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'(xstart) + 12'(LEFT_MARGIN)),
      .start_y(12'(ystart) + 12'((height - FONT.LETTER_HEIGHT) / 2)),
      .end_x(12'(xstart + width) - 12'd5),
      .end_y(12'(ystart + height) - 12'd5),
      .wrap_text(1'b0),
      .char_bram(text_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(rgb_text),
      .draw_en(en_text)
  );

  /**
    * Internal logic
    */

  // Multiplexer
  always_comb begin
    if (en_text) begin
      rgb_out = is_selected ? 12'h0_0_0 : rgb_text;  // Text becomes black when selected
      draw_en_out = 1'b1;
    end else begin
      rgb_out = rgb_bg;
      draw_en_out = en_bg;
    end
  end
endmodule
