/**
* Copyright (C) 2026  AGH University of Science and Technology
* MTM UEC2
* Author: Tomasz Więcławski & Sebastian Zoń
*
* Description:
* Block for storing static and switchable strings It has:
* - memory definitions and interfaces
* - switches connected string based on inputs (for example connected/disconnected based on string1 input)
*/

import string_pkg::*;

module string_rom (
    input logic       clk,
    input logic       link_connected, // Switch signal (e.g. 1 = connected)
    input logic [3:0] baud_rate,      // Active baudrate mode (0=100k, 1=1M, 2=2M, 4=10M)

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
  logic [7:0] link_str_a[0:STATUS_LINK_MAX_LEN];
  logic [7:0] link_str_b[0:STATUS_LINK_MAX_LEN];
  `INIT_UNPACKED_STR(link_str_a, STATUS_LINK_VAL_A, STATUS_LINK_LEN_A, STATUS_LINK_MAX_LEN + 1)
  `INIT_UNPACKED_STR(link_str_b, STATUS_LINK_VAL_B, STATUS_LINK_LEN_B, STATUS_LINK_MAX_LEN + 1)

  // STATUS: Baudrate
  logic [7:0] baud_str_100k[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_1m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_2m[0:STATUS_BAUD_LEN];
  logic [7:0] baud_str_10m[0:STATUS_BAUD_LEN];
  `INIT_UNPACKED_STR(baud_str_100k, STATUS_BAUD_VAL_100K, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_1m, STATUS_BAUD_VAL_1M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_2m, STATUS_BAUD_VAL_2M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)
  `INIT_UNPACKED_STR(baud_str_10m, STATUS_BAUD_VAL_10M, STATUS_BAUD_LEN, STATUS_BAUD_LEN + 1)

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
    if (link_bram.en)
      link_bram.dout <= link_connected ? link_str_a[link_bram.addr] : link_str_b[link_bram.addr];
    if (baud_bram.en) begin
      case (baud_rate)
        4'd0:    baud_bram.dout <= baud_str_100k[baud_bram.addr];
        4'd1:    baud_bram.dout <= baud_str_1m[baud_bram.addr];
        4'd2:    baud_bram.dout <= baud_str_2m[baud_bram.addr];
        4'd4:    baud_bram.dout <= baud_str_10m[baud_bram.addr];
        default: baud_bram.dout <= baud_str_1m[baud_bram.addr];
      endcase
    end
    if (pwr_bram.en) pwr_bram.dout <= pwr_str[pwr_bram.addr];
    if (about_btn_bram.en) about_btn_bram.dout <= btn_about_str[about_btn_bram.addr];
    if (popup_title_bram.en) popup_title_bram.dout <= popup_title_str[popup_title_bram.addr];
    if (popup_desc_bram.en) popup_desc_bram.dout <= popup_desc_str[popup_desc_bram.addr];
    if (popup_btn_bram.en) popup_btn_bram.dout <= popup_btn_str[popup_btn_bram.addr];
  end

endmodule
