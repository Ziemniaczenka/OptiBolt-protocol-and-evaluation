/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Master Top Draw Compositor module.
 * Instantiates all UI components, 400x102 OptiBolt Logo, toolbar buttons,
 * status text next to dynamic bitmap, dynamic bitmap label, terminal console,
 * real-time diagnostics meters aligned with the input field bottom,
 * and background panels using modular draw_rect instances via draw_mux.
 */

module top_draw (
    input logic clk,
    input logic rst_n,

    // Telemetry & Status inputs
    input logic [1:0] link_status,
    input logic [3:0] baud_rate,
    input logic [3:0] oversampling,

    // UI Control inputs from evaluation controller
    input logic [3:0] ui_selected_item,
    input logic       mode_text,
    input logic       show_popup,
    input logic       show_progress,
    input logic [7:0] progress_val,
    input logic [1:0] popup_mode,

    // Error & Diagnostics inputs
    input logic [ 7:0] prog_man,
    input logic [ 7:0] prog_pre,
    input logic [ 7:0] prog_par,
    input logic [ 7:0] prog_hlt,
    input logic [11:0] color_man,
    input logic [11:0] color_pre,
    input logic [11:0] color_par,
    input logic [11:0] color_hlt,

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

  // Toolbar BRAM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_HELP_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) help_btn_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_PING_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) ping_btn_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_SWEEP_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) sweep_btn_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_SNDBMP_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) sndbmp_btn_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_CLRBMP_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) clrbmp_btn_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(BTN_CLRCON_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) clrcon_btn_bram ();
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

  // Diagnostics ROM Interfaces
  bram_if #(
      .ADDR_WIDTH($clog2(DIAG_TITLE_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) diag_title_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(DIAG_MAN_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) diag_man_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(DIAG_PRE_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) diag_pre_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(DIAG_PAR_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) diag_par_bram ();
  bram_if #(
      .ADDR_WIDTH($clog2(DIAG_HLT_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) diag_hlt_bram ();

  // Dynamic Bitmap Label ROM Interface
  bram_if #(
      .ADDR_WIDTH($clog2(BITMAP_DYN_LBL_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) bmp_lbl_bram ();

  // String ROM Instantiation
  string_rom u_string_rom (
      .clk(clk),
      .link_status(link_status),
      .baud_rate(baud_rate),
      .oversampling(oversampling),
      .popup_mode(popup_mode),

      .link_bram(link_bram),
      .baud_bram(baud_bram),
      .pwr_bram (pwr_bram),

      .help_btn_bram  (help_btn_bram),
      .ping_btn_bram  (ping_btn_bram),
      .sweep_btn_bram (sweep_btn_bram),
      .sndbmp_btn_bram(sndbmp_btn_bram),
      .clrbmp_btn_bram(clrbmp_btn_bram),
      .clrcon_btn_bram(clrcon_btn_bram),
      .about_btn_bram (about_btn_bram),

      .popup_title_bram(popup_title_bram),
      .popup_desc_bram (popup_desc_bram),
      .popup_btn_bram  (popup_btn_bram),

      .diag_title_bram(diag_title_bram),
      .diag_man_bram  (diag_man_bram),
      .diag_pre_bram  (diag_pre_bram),
      .diag_par_bram  (diag_par_bram),
      .diag_hlt_bram  (diag_hlt_bram),

      .bmp_lbl_bram(bmp_lbl_bram)
  );

  // =========================================================================
  // Total UI Layer Multiplexing: 39 Layers
  // Index 0: Popup (Highest Priority)
  // Indices 1..24: Foreground Content & UI Controls
  // Indices 25..38: Frames, Borders, and Background Panels (Lower Priority)
  // =========================================================================
  localparam int NUM_DRAW_ELEMENTS = 39;

  logic [NUM_DRAW_ELEMENTS-1:0][11:0] draw_rgb;
  logic [NUM_DRAW_ELEMENTS-1:0]       draw_en;

  // Delayed interface for draw_mux pipeline matching
  vga_if vga_in_d1 ();

  /**
    * Submodules Instances
    */

  // =========================================================================
  // [0] POPUP WINDOW OVERLAY (Highest priority)
  // =========================================================================
  logic [11:0] popup_rgb;
  logic        popup_raw_en;

  draw_popup #(
      .TITLE_LEN(ABOUT_TITLE_LEN),
      .DESC_LEN(ABOUT_DESC_LEN),
      .BTN1_LEN(BTN_OK_LEN),
      .BTN2_LEN(BTN_OK_LEN),
      .TWO_BUTTONS(0)
  ) u_draw_popup (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd890),
      .ystart(11'd280),
      .width(11'd350),
      .height(11'd160),
      .title_bram(popup_title_bram),
      .desc_bram(popup_desc_bram),
      .btn1_bram(popup_btn_bram),
      .btn2_bram(popup_btn_bram),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .btn1_selected(ui_selected_item == ITEM_POPUP_BTN),
      .btn2_selected(1'b0),
      .vga_in(vga_in),
      .rgb_out(popup_rgb),
      .draw_en_out(popup_raw_en)
  );
  assign draw_rgb[0] = popup_rgb;
  assign draw_en[0]  = popup_raw_en & show_popup;

  // =========================================================================
  // [1] CONSOLE TEXT
  // =========================================================================
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
      .start_y(12'd145),
      .end_x(12'd840),
      .end_y(12'd640),
      .wrap_text(1'b1),
      .char_bram(console_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[1]),
      .draw_en(draw_en[1])
  );

  // =========================================================================
  // [2] INPUT TEXT
  // =========================================================================
  logic [11:0] raw_input_txt_rgb;
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
      .draw_en(draw_en[2])
  );
  assign draw_rgb[2] = draw_en[2] ? (mode_text ? 12'h0_F_0 : COLOR_INPUT) : 12'h000;

  // =========================================================================
  // [3] DYNAMIC BITMAP (128x128 pixels, located at x=880, y=155)
  // =========================================================================
  draw_bitmap #(
      .BITMAP (BITMAP_DYN_128x128),
      .USE_RAM(1'b1)
  ) u_draw_dyn_bitmap (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(12'd880),
      .ystart(12'd155),
      .vga_in(vga_in),
      .bmp_bram(dyn_bmp_bram),
      .rgb_out(draw_rgb[3]),
      .draw_en_out(draw_en[3])
  );

  // =========================================================================
  // [4] LOGO BITMAP (OptiBolt 400x102 pixels in top left)
  // =========================================================================
  draw_bitmap #(
      .BITMAP(BITMAP_OPTIBOLT_400x102),
      .BITMAP_PATH(BITMAP_OPTIBOLT_400x102_PALETTE_PATH),
      .TRANSPARENT_COLOR(12'hF_F_F),
      .USE_TRANSPARENCY(1'b1),
      .USE_RAM(1'b0),
      .USE_PALETTE(1'b1),
      .PALETTE_BITS(2),
      .PALETTE(PALETTE_OPTIBOLT_400x102)
  ) u_draw_logo (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(12'd20),
      .ystart(12'd10),
      .vga_in(vga_in),
      .bmp_bram(logo_bram),
      .rgb_out(draw_rgb[4]),
      .draw_en_out(draw_en[4])
  );

  // =========================================================================
  // [5..11] TOOLBAR BUTTONS
  // =========================================================================
  draw_button #(
      .MAX_TEXT_LEN(BTN_HELP_LEN)
  ) u_help_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd450),
      .ystart(11'd45),
      .width(11'd70),
      .height(11'd32),
      .text_bram(help_btn_bram),
      .is_selected(ui_selected_item == ITEM_HELP_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[5]),
      .draw_en_out(draw_en[5])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_PING_LEN)
  ) u_ping_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd530),
      .ystart(11'd45),
      .width(11'd70),
      .height(11'd32),
      .text_bram(ping_btn_bram),
      .is_selected(ui_selected_item == ITEM_PING_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[6]),
      .draw_en_out(draw_en[6])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_SWEEP_LEN)
  ) u_sweep_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd610),
      .ystart(11'd45),
      .width(11'd80),
      .height(11'd32),
      .text_bram(sweep_btn_bram),
      .is_selected(ui_selected_item == ITEM_SWEEP_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[7]),
      .draw_en_out(draw_en[7])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_SNDBMP_LEN)
  ) u_sndbmp_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd700),
      .ystart(11'd45),
      .width(11'd95),
      .height(11'd32),
      .text_bram(sndbmp_btn_bram),
      .is_selected(ui_selected_item == ITEM_SNDBMP_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[8]),
      .draw_en_out(draw_en[8])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_CLRBMP_LEN)
  ) u_clrbmp_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd805),
      .ystart(11'd45),
      .width(11'd90),
      .height(11'd32),
      .text_bram(clrbmp_btn_bram),
      .is_selected(ui_selected_item == ITEM_CLRBMP_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[9]),
      .draw_en_out(draw_en[9])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_CLRCON_LEN)
  ) u_clrcon_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd905),
      .ystart(11'd45),
      .width(11'd90),
      .height(11'd32),
      .text_bram(clrcon_btn_bram),
      .is_selected(ui_selected_item == ITEM_CLRCON_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[10]),
      .draw_en_out(draw_en[10])
  );

  draw_button #(
      .MAX_TEXT_LEN(BTN_ABOUT_LEN)
  ) u_about_btn (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd1170),
      .ystart(11'd45),
      .width(11'd80),
      .height(11'd32),
      .text_bram(about_btn_bram),
      .is_selected(ui_selected_item == ITEM_ABOUT_BTN),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[11]),
      .draw_en_out(draw_en[11])
  );

  // =========================================================================
  // [12..14] STATUS STRINGS
  // =========================================================================
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_LINK_MAX_LEN + 1),
      .COLOR(COLOR_STATUS_LINK_DISCONN)
  ) u_draw_status_link (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd1035),
      .start_y(12'd175),
      .end_x(12'd1250),
      .end_y(12'd190),
      .wrap_text(1'b0),
      .char_bram(link_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(),
      .draw_en(draw_en[12])
  );
  assign draw_rgb[12] = (link_status == 2'b01) ? COLOR_STATUS_LINK_CONN :
                        (link_status == 2'b10) ? COLOR_STATUS_LINK_LOOP :
                                                 COLOR_STATUS_LINK_DISCONN;

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_BAUD_LEN + 1),
      .COLOR(COLOR_STATUS_BAUD)
  ) u_draw_status_baud (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd1035),
      .start_y(12'd210),
      .end_x(12'd1250),
      .end_y(12'd225),
      .wrap_text(1'b0),
      .char_bram(baud_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[13]),
      .draw_en(draw_en[13])
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(STATUS_PWR_LEN + 1),
      .COLOR(COLOR_STATUS_PWR)
  ) u_draw_status_pwr (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd1035),
      .start_y(12'd245),
      .end_x(12'd1250),
      .end_y(12'd260),
      .wrap_text(1'b0),
      .char_bram(pwr_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[14]),
      .draw_en(draw_en[14])
  );

  // =========================================================================
  // [15..23] DIAGNOSTICS LABELS & METERS
  // =========================================================================
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DIAG_TITLE_LEN),
      .COLOR(12'hF_F_8)
  ) u_draw_diag_title (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd890),
      .start_y(12'd320),
      .end_x(12'd1240),
      .end_y(12'd335),
      .wrap_text(1'b0),
      .char_bram(diag_title_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[15]),
      .draw_en(draw_en[15])
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DIAG_MAN_LEN),
      .COLOR(12'hD_D_D)
  ) u_draw_diag_man_lbl (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd890),
      .start_y(12'd355),
      .end_x(12'd1240),
      .end_y(12'd370),
      .wrap_text(1'b0),
      .char_bram(diag_man_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[16]),
      .draw_en(draw_en[16])
  );

  draw_progress_bar u_meter_man (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd890),
      .ystart(11'd375),
      .width(11'd350),
      .height(11'd18),
      .progress(prog_man),
      .dynamic_color(color_man),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[17]),
      .draw_en_out(draw_en[17])
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DIAG_PRE_LEN),
      .COLOR(12'hD_D_D)
  ) u_draw_diag_pre_lbl (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd890),
      .start_y(12'd415),
      .end_x(12'd1240),
      .end_y(12'd430),
      .wrap_text(1'b0),
      .char_bram(diag_pre_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[18]),
      .draw_en(draw_en[18])
  );

  draw_progress_bar u_meter_pre (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd890),
      .ystart(11'd435),
      .width(11'd350),
      .height(11'd18),
      .progress(prog_pre),
      .dynamic_color(color_pre),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[19]),
      .draw_en_out(draw_en[19])
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DIAG_PAR_LEN),
      .COLOR(12'hD_D_D)
  ) u_draw_diag_par_lbl (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd890),
      .start_y(12'd475),
      .end_x(12'd1240),
      .end_y(12'd490),
      .wrap_text(1'b0),
      .char_bram(diag_par_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[20]),
      .draw_en(draw_en[20])
  );

  draw_progress_bar u_meter_par (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd890),
      .ystart(11'd495),
      .width(11'd350),
      .height(11'd18),
      .progress(prog_par),
      .dynamic_color(color_par),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[21]),
      .draw_en_out(draw_en[21])
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(DIAG_HLT_LEN),
      .COLOR(12'hD_D_D)
  ) u_draw_diag_hlt_lbl (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd890),
      .start_y(12'd535),
      .end_x(12'd1240),
      .end_y(12'd550),
      .wrap_text(1'b0),
      .char_bram(diag_hlt_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[22]),
      .draw_en(draw_en[22])
  );

  draw_progress_bar u_meter_hlt (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd890),
      .ystart(11'd555),
      .width(11'd350),
      .height(11'd22),
      .progress(prog_hlt),
      .dynamic_color(color_hlt),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[23]),
      .draw_en_out(draw_en[23])
  );

  // =========================================================================
  // [24] DYNAMIC BITMAP LABEL
  // =========================================================================
  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(BITMAP_DYN_LBL_LEN),
      .COLOR(12'hF_F_8)
  ) u_draw_bmp_lbl (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(vga_in),
      .start_x(12'd880),
      .start_y(12'd135),
      .end_x(12'd1100),
      .end_y(12'd150),
      .wrap_text(1'b0),
      .char_bram(bmp_lbl_bram),
      .letter_spacing(8'd1),
      .row_spacing(8'd1),
      .pixel_color(draw_rgb[24]),
      .draw_en(draw_en[24])
  );

  // =========================================================================
  // [25] TOOLBAR DIVIDER LINE
  // =========================================================================
  draw_rect u_draw_divider (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd0),
      .ystart(11'd120),
      .xend(11'd1280),
      .yend(11'd122),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h2_5_8),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[25]),
      .draw_en_out(draw_en[25])
  );

  // =========================================================================
  // [26..27] CONSOLE FRAME & SOLID BACKGROUND
  // =========================================================================
  draw_rect u_draw_console_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd135),
      .xend(11'd850),
      .yend(11'd650),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h3_5_7),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[26]),
      .draw_en_out(draw_en[26])
  );

  draw_rect u_draw_console_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd135),
      .xend(11'd850),
      .yend(11'd650),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h0_0_1),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[27]),
      .draw_en_out(draw_en[27])
  );

  // =========================================================================
  // [28..29] INPUT FRAME & BACKGROUND
  // =========================================================================
  draw_rect u_draw_input_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd660),
      .xend(11'd850),
      .yend(11'd700),
      .filled(1'b0),
      .thickness((mode_text || ui_selected_item == ITEM_INPUT) ? 11'd3 : 11'd2),
      .color(mode_text ? 12'h0_F_8 : (ui_selected_item == ITEM_INPUT ? 12'hF_B_0 : 12'h3_5_7)),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[28]),
      .draw_en_out(draw_en[28])
  );

  draw_rect u_draw_input_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd20),
      .ystart(11'd660),
      .xend(11'd850),
      .yend(11'd700),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h0_1_2),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[29]),
      .draw_en_out(draw_en[29])
  );

  // =========================================================================
  // [30..31] DYNAMIC BITMAP FRAME & CANVAS BACKGROUND
  // =========================================================================
  draw_rect u_draw_bmp_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd878),
      .ystart(11'd153),
      .xend(11'd1010),
      .yend(11'd285),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h2_4_6),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[30]),
      .draw_en_out(draw_en[30])
  );

  draw_rect u_draw_bmp_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd880),
      .ystart(11'd155),
      .xend(11'd1008),
      .yend(11'd283),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h0_0_0),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[31]),
      .draw_en_out(draw_en[31])
  );

  // =========================================================================
  // [32..33] STATUS CARD FRAME & BACKGROUND
  // =========================================================================
  draw_rect u_draw_status_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd1025),
      .ystart(11'd153),
      .xend(11'd1255),
      .yend(11'd285),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h2_4_6),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[32]),
      .draw_en_out(draw_en[32])
  );

  draw_rect u_draw_status_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd1025),
      .ystart(11'd153),
      .xend(11'd1255),
      .yend(11'd285),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h0_1_2),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[33]),
      .draw_en_out(draw_en[33])
  );

  // =========================================================================
  // [34..35] DIAGNOSTICS CARD FRAME & BACKGROUND
  // =========================================================================
  draw_rect u_draw_diag_frame (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd875),
      .ystart(11'd305),
      .xend(11'd1255),
      .yend(11'd700),
      .filled(1'b0),
      .thickness(11'd2),
      .color(12'h3_5_7),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[34]),
      .draw_en_out(draw_en[34])
  );

  draw_rect u_draw_diag_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd875),
      .ystart(11'd305),
      .xend(11'd1255),
      .yend(11'd700),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h0_1_2),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[35]),
      .draw_en_out(draw_en[35])
  );

  // =========================================================================
  // [36..37] TOP HEADER BAR BORDER & BACKGROUND
  // =========================================================================
  draw_rect u_draw_header_border (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd0),
      .ystart(11'd120),
      .xend(11'd1280),
      .yend(11'd122),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h2_4_6),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[36]),
      .draw_en_out(draw_en[36])
  );

  draw_rect u_draw_header_bg (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd0),
      .ystart(11'd0),
      .xend(11'd1280),
      .yend(11'd120),
      .filled(1'b1),
      .thickness(11'd0),
      .color(12'h9_A_B),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[37]),
      .draw_en_out(draw_en[37])
  );

  // =========================================================================
  // [38] SCREEN PERIMETER BORDER
  // =========================================================================
  draw_rect u_draw_screen_border (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(11'd0),
      .ystart(11'd0),
      .xend(11'd1280),
      .yend(11'd720),
      .filled(1'b0),
      .thickness(11'd1),
      .color(12'h2_3_4),
      .vga_in(vga_in),
      .rgb_out(draw_rgb[38]),
      .draw_en_out(draw_en[38])
  );

  // =========================================================================
  // VGA Timing Delay Pipelines & Multiplexing
  // =========================================================================

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
      .INPUT_COUNT(NUM_DRAW_ELEMENTS)
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
