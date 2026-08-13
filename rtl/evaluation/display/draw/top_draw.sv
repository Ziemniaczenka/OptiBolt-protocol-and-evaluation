/**
* Copyright (C) 2026  AGH University of Science and Technology
* MTM UEC2
* Author: Tomasz Więcławski & Sebastian Zoń
*
* Description:
* Module with multiple draw functions.
* TODO: Work on ui_selected_item logic
* TODO: Finish layout
* TODO: Adjust colors
* TODO: Add final bitmaps
*/

module top_draw (
    input logic clk,
    input logic rst_n,

    // UI Control inputs from evaluation controller
    input logic [3:0] ui_selected_item,
    input logic       mode_text,
    input logic       show_popup,
    input logic       show_progress,
    input logic [7:0] progress_val,

    // BRAM Interfaces for Dynamic Texts & Bitmap
    bram_if.read console_bram,
    bram_if.read input_bram,
    bram_if.read dyn_bmp_bram,

    vga_if.in  vga_in,
    vga_if.out vga_out
);

  import vga_pkg::*;
  import font_pkg::*;
  import string_pkg::*;
  import bitmap_pkg::*;
  import ui_pkg::*;

  /**
    * Local variables and signals
    */

  // Logo BRAM (Dummy interface for ROM fallback)
  bram_if #(
      .ADDR_WIDTH(1),
      .DATA_WIDTH(12),
      .READ_ONLY (1)
  ) logo_bram ();

  // String ROM BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(STATUS_LINK_MAX_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) link_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(STATUS_BAUD_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) baud_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(STATUS_PWR_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) pwr_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_ABOUT_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) about_btn_bram ();

  // Popup ROM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(ABOUT_TITLE_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) popup_title_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(ABOUT_DESC_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) popup_desc_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_OK_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) popup_btn_bram ();


  // Demo (switch every few frames)
  logic       select_sig;
  logic [5:0] frame_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      select_sig <= 0;
      frame_cnt  <= 0;
    end else if (vga_in.vcount == 0 && vga_in.hcount == 0) begin
      if (frame_cnt == 2) begin
        frame_cnt  <= 0;
        select_sig <= ~select_sig;
      end else begin
        frame_cnt <= frame_cnt + 1;
      end
    end
  end

  // String ROM Instantiation
  string_rom u_string_rom (
      .clk(clk),
      .link_connected(select_sig),
      .link_bram(link_bram),
      .baud_bram(baud_bram),
      .pwr_bram(pwr_bram),
      .about_btn_bram(about_btn_bram),
      .popup_title_bram(popup_title_bram),
      .popup_desc_bram(popup_desc_bram),
      .popup_btn_bram(popup_btn_bram)
  );

  // =========================================================================

  logic [11:0][11:0] draw_rgb;
  logic [11:0]       draw_en;

  // Delayed interface
  vga_if vga_in_d1 ();

  /**
    * Internal logic
    */

  // [0] Logo (Bitmap)
  draw_bitmap #(
      .BITMAP(BITMAP_TEST_128x64),
      .BITMAP_PATH(BITMAP_TEST_128x64_PATH),
      .USE_RAM(1'b0)
  ) u_draw_logo (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(12'd20),
      .ystart(12'd10),
      .vga_in(vga_in),
      .bmp_bram(logo_bram),
      .rgb_out(draw_rgb[0]),
      .draw_en_out(draw_en[0])
  );

  // [1] About Button
  draw_button #(
      .MAX_TEXT_LEN(BTN_ABOUT_LEN)
  ) u_about_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd1150),
      .ystart(11'd25),
      .width(11'd80),
      .height(11'd30),
      .text_bram(about_btn_bram),
      .is_selected(ui_selected_item == ITEM_ABOUT_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[1]),
      .draw_en_out(draw_en[1])
  );

  // [2] Divider Line
  draw_rect u_draw_divider (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd85),
      .xend(11'd1260),
      .yend(11'd87),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h8_8_8),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[2]),
      .draw_en_out(draw_en[2])
  );

  // [3] Status: Link
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_LINK_MAX_LEN + 1),
      .COLOR(COLOR_STATUS_LINK)
  ) u_draw_status_link (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd20),
      .start_y(12'd100),
      .end_x(12'd1260),
      .end_y(12'd115),
      .wrap_text(1'b0),
      .char_bram(link_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[3]),
      .draw_en(draw_en[3])
  );

  // [4] Status: Baudrate
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_BAUD_LEN + 1),
      .COLOR(COLOR_STATUS_BAUD)
  ) u_draw_status_baud (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd20),
      .start_y(12'd120),
      .end_x(12'd1260),
      .end_y(12'd135),
      .wrap_text(1'b0),
      .char_bram(baud_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[4]),
      .draw_en(draw_en[4])
  );

  // [5] Status: Power
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_PWR_LEN + 1),
      .COLOR(COLOR_STATUS_PWR)
  ) u_draw_status_pwr (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd20),
      .start_y(12'd140),
      .end_x(12'd1260),
      .end_y(12'd155),
      .wrap_text(1'b0),
      .char_bram(pwr_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[5]),
      .draw_en(draw_en[5])
  );

  // [6] Console Frame
  draw_rect u_draw_console_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd180),
      .xend(11'd850),
      .yend(11'd650),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h5_5_5),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[6]),
      .draw_en_out(draw_en[6])
  );

  // [7] Console Text
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(CONSOLE_MAX_LEN),
      .COLOR(COLOR_CONSOLE)
  ) u_draw_console_txt (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd30),
      .start_y(12'd190),
      .end_x(12'd840),
      .end_y(12'd640),
      .wrap_text(1'b1),
      .char_bram(console_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[7]),
      .draw_en(draw_en[7])
  );

  // [8] Input Frame
  draw_rect u_draw_input_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd670),
      .xend(11'd850),
      .yend(11'd700),
      .filled(1'b0),
      .thickness((ui_selected_item == ITEM_INPUT) ? 11'd4 : 11'd2),  // Thicker outline if selected
      .color((ui_selected_item == ITEM_INPUT) ? 12'hF_F_0 : 12'h5_A_5), // Yellow highlight if selected
      .vga_in(vga_in),
      .rgb_out(draw_rgb[8]),
      .draw_en_out(draw_en[8])
  );

  logic [11:0] raw_input_txt_rgb;

  // [9] Input Text
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(INPUT_MAX_LEN),
      .COLOR(12'hFFF)
  ) u_draw_input_txt (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd30),
      .start_y(12'd675),
      .end_x(12'd840),
      .end_y(12'd695),
      .wrap_text(1'b0),
      .char_bram(input_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(raw_input_txt_rgb),
      .draw_en(draw_en[9])
  );

  assign draw_rgb[9] = draw_en[9] ? (mode_text ? 12'h0_F_0 : COLOR_INPUT) : 12'h000;

  // [10] Dynamic Bitmap (np. 64x64)
  draw_bitmap #(
      .BITMAP (BITMAP_DYN_64x64),
      .USE_RAM(1'b1)
  ) u_draw_dyn_bitmap (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(12'd900),
      .ystart(12'd180),
      .vga_in(vga_in),
      .bmp_bram(dyn_bmp_bram),
      .rgb_out(draw_rgb[10]),
      .draw_en_out(draw_en[10])
  );

  // [11] Popup Window (Informacje)
  logic popup_raw_en;
  draw_popup #(
      .TITLE_LEN(ABOUT_TITLE_LEN),
      .DESC_LEN(ABOUT_DESC_LEN),
      .BTN1_LEN(BTN_OK_LEN),
      .BTN2_LEN(BTN_OK_LEN),
      .TWO_BUTTONS(0)
  ) u_draw_popup (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd900),
      .ystart(11'd260),
      .width(11'd300),
      .height(11'd150),
      .title_bram(popup_title_bram),
      .desc_bram(popup_desc_bram),
      .btn1_bram(popup_btn_bram),
      .btn2_bram(popup_btn_bram),  // Unused in 1-button mode
      .show_progress(show_progress),
      .progress_val(progress_val),
      .btn1_selected(ui_selected_item == ITEM_POPUP_BTN),
      .btn2_selected(1'b0),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[11]),
      .draw_en_out(popup_raw_en)
  );
  assign draw_en[11] = popup_raw_en & show_popup;  // Renders on top only when shown

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vga_in_d1.rgb <= '0;
    end else begin
      vga_in_d1.rgb <= vga_in.rgb;
    end
  end

  delay #(
      .WIDTH  (26),
      .CLK_DEL(1)
  ) u_delay_1 (
      .clk(clk),
      .rst_n(rst_n),
      .din({vga_in.vcount, vga_in.vsync, vga_in.vblnk, vga_in.hcount, vga_in.hsync, vga_in.hblnk}),
      .dout({
        vga_in_d1.vcount,
        vga_in_d1.vsync,
        vga_in_d1.vblnk,
        vga_in_d1.hcount,
        vga_in_d1.hsync,
        vga_in_d1.hblnk
      })
  );

  draw_mux #(
      .INPUT_COUNT(12)
  ) u_draw_mux (
      .clk(clk),
      .rst_n(rst_n),
      .in_rgb(draw_rgb),
      .in_draw_en(draw_en),
      .vga_in(vga_in_d1),
      .out_rgb(vga_out.rgb)
  );

  delay #(
      .WIDTH  (26),
      .CLK_DEL(1)
  ) u_delay_2 (
      .clk(clk),
      .rst_n(rst_n),
      .din({
        vga_in_d1.vcount,
        vga_in_d1.vsync,
        vga_in_d1.vblnk,
        vga_in_d1.hcount,
        vga_in_d1.hsync,
        vga_in_d1.hblnk
      }),
      .dout({
        vga_out.vcount, vga_out.vsync, vga_out.vblnk, vga_out.hcount, vga_out.hsync, vga_out.hblnk
      })
  );

endmodule
