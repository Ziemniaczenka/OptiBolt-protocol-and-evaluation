/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Block for storing static and switchable strings.
 * Dynamically switches strings based on link status, baudrate, and oversampling settings.
 */

import string_pkg::*;

module string_rom (
    input logic       clk,
    input logic [1:0] link_status,  // 0=Disconnected, 1=Connected, 2=Loopback
    input logic [3:0] baud_rate,    // Bitrate index
    input logic [3:0] oversampling, // 0=8x, 1=16x

    interface link_bram,
    interface baud_bram,
    interface pwr_bram,
    interface about_btn_bram,
    interface popup_title_bram,
    interface popup_desc_bram,
    interface popup_btn_bram
);

  /**
    * Local variables and signals
    */

  // STATUS: Link
  logic [7:0] link_str_disconn[0:STATUS_LINK_MAX_LEN];
  logic [7:0] link_str_conn[0:STATUS_LINK_MAX_LEN];
  logic [7:0] link_str_loop[0:STATUS_LINK_MAX_LEN];
  `INIT_UNPACKED_STR(link_str_disconn, STATUS_LINK_VAL_DISCONN, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)
  `INIT_UNPACKED_STR(link_str_conn, STATUS_LINK_VAL_CONN, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)
  `INIT_UNPACKED_STR(link_str_loop, STATUS_LINK_VAL_LOOP, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)

  // STATUS: Baudrate
  logic [7:0] baud_str_100k[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_1m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_1dot25m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_2dot5m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_3dot125m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_5m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_6dot25m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_8dot33m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_12dot5m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_25m[0:STATUS_BAUD_LEN];

  `INIT_UNPACKED_STR(baud_str_100k, STATUS_BAUD_VAL_100K, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_1m, STATUS_BAUD_VAL_1M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_1dot25m, STATUS_BAUD_VAL_1dot25M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_2dot5m, STATUS_BAUD_VAL_2dot5M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_3dot125m, STATUS_BAUD_VAL_3dot125M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_5m, STATUS_BAUD_VAL_5M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_6dot25m, STATUS_BAUD_VAL_6dot25M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_8dot33m, STATUS_BAUD_VAL_8dot33M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_12dot5m, STATUS_BAUD_VAL_12dot5M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_25m, STATUS_BAUD_VAL_25M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)

  // STATUS: Power
  logic [7:0] pwr_str[0:STATUS_PWR_LEN];
  `INIT_UNPACKED_STR(pwr_str, STATUS_PWR_VAL, STATUS_PWR_LEN, STATUS_PWR_LEN + 1)

  // About Button
  logic [7:0] btn_about_str[0:BTN_ABOUT_LEN];
  `INIT_UNPACKED_STR(btn_about_str, BTN_ABOUT_VAL, BTN_ABOUT_LEN, BTN_ABOUT_LEN + 1)

  // Popup Text (About)
  logic [7:0] popup_title_str[0:ABOUT_TITLE_LEN];
  `INIT_UNPACKED_STR(popup_title_str, ABOUT_TITLE_VAL, ABOUT_TITLE_LEN, ABOUT_TITLE_LEN + 1)
  logic [7:0] popup_desc_str[0:ABOUT_DESC_LEN];
  `INIT_UNPACKED_STR(popup_desc_str, ABOUT_DESC_VAL, ABOUT_DESC_LEN, ABOUT_DESC_LEN + 1)
  logic [7:0] popup_btn_str[0:BTN_OK_LEN];
  `INIT_UNPACKED_STR(popup_btn_str, BTN_OK_VAL, BTN_OK_LEN, BTN_OK_LEN + 1)

  /**
    * Internal logic
    */

  always_ff @(posedge clk) begin
    if (link_bram.en) begin
      case (link_status)
        2'b00:   link_bram.dout <= link_str_disconn[link_bram.addr];
        2'b01:   link_bram.dout <= link_str_conn[link_bram.addr];
        2'b10:   link_bram.dout <= link_str_loop[link_bram.addr];
        default: link_bram.dout <= link_str_disconn[link_bram.addr];
      endcase
    end

    if (baud_bram.en) begin
      if (oversampling == 4'd1) begin
        // 16x Oversampling
        case (baud_rate)
          4'd1:    baud_bram.dout <= baud_str_1dot25m[baud_bram.addr];
          4'd3:    baud_bram.dout <= baud_str_3dot125m[baud_bram.addr];
          4'd5:    baud_bram.dout <= baud_str_6dot25m[baud_bram.addr];
          default: baud_bram.dout <= baud_str_1dot25m[baud_bram.addr];
        endcase
      end else begin
        // 8x Oversampling (default)
        case (baud_rate)
          4'd0:    baud_bram.dout <= baud_str_100k[baud_bram.addr];
          4'd1:    baud_bram.dout <= baud_str_1m[baud_bram.addr];
          4'd2:    baud_bram.dout <= baud_str_2dot5m[baud_bram.addr];
          4'd3:    baud_bram.dout <= baud_str_3dot125m[baud_bram.addr];
          4'd4:    baud_bram.dout <= baud_str_5m[baud_bram.addr];
          4'd5:    baud_bram.dout <= baud_str_8dot33m[baud_bram.addr];
          4'd6:    baud_bram.dout <= baud_str_12dot5m[baud_bram.addr];
          4'd7:    baud_bram.dout <= baud_str_25m[baud_bram.addr];
          default: baud_bram.dout <= baud_str_1m[baud_bram.addr];
        endcase
      end
    end

    if (pwr_bram.en) pwr_bram.dout <= pwr_str[pwr_bram.addr];
    if (about_btn_bram.en) about_btn_bram.dout <= btn_about_str[about_btn_bram.addr];
    if (popup_title_bram.en) popup_title_bram.dout <= popup_title_str[popup_title_bram.addr];
    if (popup_desc_bram.en) popup_desc_bram.dout <= popup_desc_str[popup_desc_bram.addr];
    if (popup_btn_bram.en) popup_btn_bram.dout <= popup_btn_str[popup_btn_bram.addr];
  end

endmodule
