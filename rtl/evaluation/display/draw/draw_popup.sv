/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Popup window UI component with text, progress bar and buttons.
 */
import font_pkg::*;

module draw_popup #(
    parameter int TITLE_LEN = 16,
    parameter int DESC_LEN = 64,
    parameter int BTN1_LEN = 8,
    parameter int BTN2_LEN = 8,
    parameter int TWO_BUTTONS = 0
) (
    input logic        clk,
    input logic        rst_n,
    input logic [10:0] xstart,
    input logic [10:0] ystart,
    input logic [10:0] width,
    input logic [10:0] height,

    bram_if.read title_bram,
    bram_if.read desc_bram,
    bram_if.read btn1_bram,
    bram_if.read btn2_bram,

    input logic       show_progress,
    input logic [7:0] progress_val,

    input logic btn1_selected,
    input logic btn2_selected,

           vga_if.in        vga_in,
    output logic     [11:0] rgb_out,
    output logic            draw_en_out
);

  /**
    * Local variables and signals
    */

  logic [11:0] rgb_bg, rgb_border, rgb_title, rgb_desc, rgb_prog, rgb_btn1, rgb_btn2;
  logic en_bg, en_border, en_title, en_desc, en_prog, en_btn1, en_btn2;

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
      .thickness(11'd0),
      .color(12'h2_2_3),
      .vga_in(vga_in),
      .rgb_out(rgb_bg),
      .draw_en_out(en_bg)
  );

  draw_rect u_border (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart),
      .ystart(ystart),
      .xend(xstart + width),
      .yend(ystart + height),
      .filled(1'b0),
      .thickness(11'd3),
      .color(12'hA_A_A),
      .vga_in(vga_in),
      .rgb_out(rgb_border),
      .draw_en_out(en_border)
  );

  // Texts
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(TITLE_LEN),
      .COLOR(12'hF_F_8)
  ) u_title (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'(xstart) + 12'd20),
      .start_y(12'(ystart) + 12'd20),
      .end_x(12'(xstart + width) - 12'd20),
      .end_y(12'(ystart) + 12'd40),
      .wrap_text(1'b0),
      .char_bram(title_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(rgb_title),
      .draw_en(en_title)
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DESC_LEN),
      .COLOR(12'hD_D_D)
  ) u_desc (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'(xstart) + 12'd20),
      .start_y(12'(ystart) + 12'd50),
      .end_x(12'(xstart + width) - 12'd20),
      .end_y(12'(ystart) + 12'd100),
      .wrap_text(1'b1),
      .char_bram(desc_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(rgb_desc),
      .draw_en(en_desc)
  );

  // Conditional Progress Bar
  draw_progress_bar u_prog (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart + 11'd20),
      .ystart(ystart + height - 11'd70),
      .width(width - 11'd40),
      .height(11'd15),
      .progress(progress_val),
      .dynamic_color(12'h0_F_8),
      .vga_in(vga_in),
      .rgb_out(rgb_prog),
      .draw_en_out(en_prog)
  );

  // Button 1
  draw_button #(
      .MAX_TEXT_LEN(BTN1_LEN),
      .LEFT_MARGIN (11)
  ) u_btn1 (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(TWO_BUTTONS ? (xstart + (width >> 2) - 11'd40) : (xstart + (width >> 1) - 11'd40)),
      .ystart(ystart + height - 11'd40),
      .width(11'd80),
      .height(11'd25),
      .text_bram(btn1_bram),
      .is_selected(btn1_selected),
      .vga_in(vga_in),
      .rgb_out(rgb_btn1),
      .draw_en_out(en_btn1)
  );

  // Button 2
  generate
    if (TWO_BUTTONS) begin : gen_btn2
      draw_button #(
          .MAX_TEXT_LEN(BTN2_LEN),
          .LEFT_MARGIN (11)
      ) u_btn2 (
          .clk(clk),
          .rst_n(rst_n),
          .xstart(xstart + 11'((width * 3) / 4) - 11'd40),
          .ystart(ystart + height - 11'd40),
          .width(11'd80),
          .height(11'd25),
          .text_bram(btn2_bram),
          .is_selected(btn2_selected),
          .vga_in(vga_in),
          .rgb_out(rgb_btn2),
          .draw_en_out(en_btn2)
      );
    end else begin : gen_no_btn2
      assign en_btn2  = 1'b0;
      assign rgb_btn2 = 12'h0;
    end
  endgenerate

  /**
    * Internal logic
    */

  // Combinational multiplexing (top to bottom overlay)
  always_comb begin
    draw_en_out = 1'b0;
    rgb_out = 12'h0;

    if (en_btn1) begin
      rgb_out = rgb_btn1;
      draw_en_out = 1'b1;
    end else if (en_btn2) begin
      rgb_out = rgb_btn2;
      draw_en_out = 1'b1;
    end else if (show_progress && en_prog) begin
      rgb_out = rgb_prog;
      draw_en_out = 1'b1;
    end else if (en_title) begin
      rgb_out = rgb_title;
      draw_en_out = 1'b1;
    end else if (en_desc) begin
      rgb_out = rgb_desc;
      draw_en_out = 1'b1;
    end else if (en_border) begin
      rgb_out = rgb_border;
      draw_en_out = 1'b1;
    end else if (en_bg) begin
      rgb_out = rgb_bg;
      draw_en_out = 1'b1;
    end
  end

endmodule
