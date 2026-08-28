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
    input logic [1:0] popup_mode,   // 0=None, 1=About, 2=Progress
    input logic       rx_carrier,   // 1=Optical light present, 0=No light

    // Status strings
    interface status_lbl_bram,
    interface link_bram,
    interface light_bram,
    interface baud_bram,
    interface os_bram,
    input logic [2:0] pwr_status_code,
    input logic [1:0] active_voltage_id,
    input logic [3:0] active_amps,
    input logic contract_active,
    interface pwr_state_bram,
    interface pwr_val_bram,
    input logic failover_en,
    interface failover_bram,

    // Toolbar buttons
    interface help_btn_bram,
    interface ping_btn_bram,
    interface sweep_btn_bram,
    interface sndbmp_btn_bram,
    interface clrbmp_btn_bram,
    interface clrcon_btn_bram,
    interface about_btn_bram,

    // Popup strings
    interface popup_title_bram,
    interface popup_desc_bram,
    interface popup_btn_bram,

    // Diagnostics strings
    interface diag_title_bram,
    interface diag_man_bram,
    interface diag_pre_bram,
    interface diag_par_bram,
    interface diag_hlt_bram,

    // Dynamic Bitmap label
    interface bmp_lbl_bram,

    // Console label
    interface console_title_bram
);

  /**
    * Local variables and signals
    */

  // STATUS: Box Label
  logic [7:0] status_title_str[0:STATUS_TITLE_LEN];
  `INIT_UNPACKED_STR(status_title_str, STATUS_TITLE_VAL, STATUS_TITLE_LEN, STATUS_TITLE_LEN + 1)

  // STATUS: Link
  logic [7:0] link_str_disconn[0:STATUS_LINK_MAX_LEN];
  logic [7:0] link_str_conn[0:STATUS_LINK_MAX_LEN];
  logic [7:0] link_str_loop[0:STATUS_LINK_MAX_LEN];
  `INIT_UNPACKED_STR(link_str_disconn, STATUS_LINK_VAL_DISCONN, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)
  `INIT_UNPACKED_STR(link_str_conn, STATUS_LINK_VAL_CONN, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)
  `INIT_UNPACKED_STR(link_str_loop, STATUS_LINK_VAL_LOOP, STATUS_LINK_MAX_LEN, STATUS_LINK_MAX_LEN + 1)

  // STATUS: Optical Light
  logic [7:0] light_str_on[0:STATUS_LIGHT_LEN];
  logic [7:0] light_str_off[0:STATUS_LIGHT_LEN];
  `INIT_UNPACKED_STR(light_str_on, STATUS_LIGHT_VAL_ON, STATUS_LIGHT_LEN, STATUS_LIGHT_LEN + 1)
  `INIT_UNPACKED_STR(light_str_off, STATUS_LIGHT_VAL_OFF, STATUS_LIGHT_LEN, STATUS_LIGHT_LEN + 1)

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

  // STATUS: Oversampling
  logic [7:0] os_str_8x[0:STATUS_OS_LEN];
  logic [7:0] os_str_16x[0:STATUS_OS_LEN];
  `INIT_UNPACKED_STR(os_str_8x, STATUS_OS_VAL_8X, STATUS_OS_LEN, STATUS_OS_LEN + 1)
  `INIT_UNPACKED_STR(os_str_16x, STATUS_OS_VAL_16X, STATUS_OS_LEN, STATUS_OS_LEN + 1)

  // STATUS: Power State
  logic [7:0] pwr_state_not_ready[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_ready[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_sending[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_receiving[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_active[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_error[0:STATUS_PWR_STATE_LEN];
  logic [7:0] pwr_state_loopback[0:STATUS_PWR_STATE_LEN];

  `INIT_UNPACKED_STR(pwr_state_not_ready, STATUS_PWR_STATE_VAL_NOT_READY, STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_ready,     STATUS_PWR_STATE_VAL_READY,     STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_sending,   STATUS_PWR_STATE_VAL_SENDING,   STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_receiving, STATUS_PWR_STATE_VAL_RECEIVING, STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_active,    STATUS_PWR_STATE_VAL_ACTIVE,    STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_error,     STATUS_PWR_STATE_VAL_ERROR,     STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)
  `INIT_UNPACKED_STR(pwr_state_loopback,  STATUS_PWR_STATE_VAL_LOOPBACK,  STATUS_PWR_STATE_LEN, STATUS_PWR_STATE_LEN + 1)

  // STATUS: Power Value
  logic [7:0] pwr_val_paused[0:STATUS_PWR_VAL_LEN];
  `INIT_UNPACKED_STR(pwr_val_paused, STATUS_PWR_VAL_PAUSED, STATUS_PWR_VAL_LEN, STATUS_PWR_VAL_LEN + 1)

  // STATUS: Failover
  logic [7:0] failover_str_on[0:STATUS_FAILOVER_LEN];
  logic [7:0] failover_str_off[0:STATUS_FAILOVER_LEN];
  `INIT_UNPACKED_STR(failover_str_on, STATUS_FAILOVER_VAL_ON, STATUS_FAILOVER_LEN, STATUS_FAILOVER_LEN + 1)
  `INIT_UNPACKED_STR(failover_str_off, STATUS_FAILOVER_VAL_OFF, STATUS_FAILOVER_LEN, STATUS_FAILOVER_LEN + 1)

  // TOOLBAR BUTTONS
  logic [7:0] btn_help_str[0:BTN_HELP_LEN];
  logic [7:0] btn_ping_str[0:BTN_PING_LEN];
  logic [7:0] btn_sweep_str[0:BTN_SWEEP_LEN];
  logic [7:0] btn_sndbmp_str[0:BTN_SNDBMP_LEN];
  logic [7:0] btn_clrbmp_str[0:BTN_CLRBMP_LEN];
  logic [7:0] btn_clrcon_str[0:BTN_CLRCON_LEN];
  logic [7:0] btn_about_str[0:BTN_ABOUT_LEN];

  `INIT_UNPACKED_STR(btn_help_str,   BTN_HELP_VAL,   BTN_HELP_LEN,   BTN_HELP_LEN + 1)
  `INIT_UNPACKED_STR(btn_ping_str,   BTN_PING_VAL,   BTN_PING_LEN,   BTN_PING_LEN + 1)
  `INIT_UNPACKED_STR(btn_sweep_str,  BTN_SWEEP_VAL,  BTN_SWEEP_LEN,  BTN_SWEEP_LEN + 1)
  `INIT_UNPACKED_STR(btn_sndbmp_str, BTN_SNDBMP_VAL, BTN_SNDBMP_LEN, BTN_SNDBMP_LEN + 1)
  `INIT_UNPACKED_STR(btn_clrbmp_str, BTN_CLRBMP_VAL, BTN_CLRBMP_LEN, BTN_CLRBMP_LEN + 1)
  `INIT_UNPACKED_STR(btn_clrcon_str, BTN_CLRCON_VAL, BTN_CLRCON_LEN, BTN_CLRCON_LEN + 1)
  `INIT_UNPACKED_STR(btn_about_str,  BTN_ABOUT_VAL,  BTN_ABOUT_LEN,  BTN_ABOUT_LEN + 1)

  // POPUP STRINGS
  logic [7:0] popup_title_str[0:ABOUT_TITLE_LEN];
  logic [7:0] popup_desc_str[0:ABOUT_DESC_LEN];
  logic [7:0] prog_title_str[0:PROG_TITLE_LEN];
  logic [7:0] prog_desc_str[0:PROG_DESC_LEN];
  logic [7:0] popup_btn_str[0:BTN_OK_LEN];

  `INIT_UNPACKED_STR(popup_title_str, ABOUT_TITLE_VAL, ABOUT_TITLE_LEN, ABOUT_TITLE_LEN + 1)
  `INIT_UNPACKED_STR(popup_desc_str,  ABOUT_DESC_VAL,  ABOUT_DESC_LEN,  ABOUT_DESC_LEN + 1)
  `INIT_UNPACKED_STR(prog_title_str,  PROG_TITLE_VAL,  PROG_TITLE_LEN,  PROG_TITLE_LEN + 1)
  `INIT_UNPACKED_STR(prog_desc_str,   PROG_DESC_VAL,   PROG_DESC_LEN,   PROG_DESC_LEN + 1)
  `INIT_UNPACKED_STR(popup_btn_str,   BTN_OK_VAL,      BTN_OK_LEN,      BTN_OK_LEN + 1)

  // DIAGNOSTICS & ERROR LABELS
  logic [7:0] diag_title_str[0:DIAG_TITLE_LEN];
  logic [7:0] diag_man_str[0:DIAG_MAN_LEN];
  logic [7:0] diag_pre_str[0:DIAG_PRE_LEN];
  logic [7:0] diag_par_str[0:DIAG_PAR_LEN];
  logic [7:0] diag_hlt_str[0:DIAG_HLT_LEN];
  logic [7:0] bmp_lbl_str[0:BITMAP_DYN_LBL_LEN];

  `INIT_UNPACKED_STR(diag_title_str, DIAG_TITLE_VAL, DIAG_TITLE_LEN, DIAG_TITLE_LEN + 1)
  `INIT_UNPACKED_STR(diag_man_str,   DIAG_MAN_VAL,   DIAG_MAN_LEN,   DIAG_MAN_LEN + 1)
  `INIT_UNPACKED_STR(diag_pre_str,   DIAG_PRE_VAL,   DIAG_PRE_LEN,   DIAG_PRE_LEN + 1)
  `INIT_UNPACKED_STR(diag_par_str,   DIAG_PAR_VAL,   DIAG_PAR_LEN,   DIAG_PAR_LEN + 1)
  `INIT_UNPACKED_STR(diag_hlt_str,   DIAG_HLT_VAL,   DIAG_HLT_LEN,   DIAG_HLT_LEN + 1)
  `INIT_UNPACKED_STR(bmp_lbl_str,    BITMAP_DYN_LBL_VAL, BITMAP_DYN_LBL_LEN, BITMAP_DYN_LBL_LEN + 1)

  // Console label
  logic [7:0] console_title_str[0:CONSOLE_TITLE_LEN];
  `INIT_UNPACKED_STR(console_title_str, CONSOLE_TITLE_VAL, CONSOLE_TITLE_LEN, CONSOLE_TITLE_LEN + 1)

  /**
    * Internal logic
    */

  always_ff @(posedge clk) begin
    // Status Box Title
    if (status_lbl_bram.en) begin
      status_lbl_bram.dout <= status_title_str[status_lbl_bram.addr];
    end

    // Line 1: Link Status
    if (link_bram.en) begin
      case (link_status)
        2'b00:   link_bram.dout <= link_str_disconn[link_bram.addr];
        2'b01:   link_bram.dout <= link_str_conn[link_bram.addr];
        2'b10:   link_bram.dout <= link_str_loop[link_bram.addr];
        default: link_bram.dout <= link_str_disconn[link_bram.addr];
      endcase
    end

    // Line 2: Optical Light Detection
    if (light_bram.en) begin
      light_bram.dout <= rx_carrier ? light_str_on[light_bram.addr] : light_str_off[light_bram.addr];
    end

    // Line 3: Baudrate
    if (baud_bram.en) begin
      case (baud_rate)
        4'd0:    baud_bram.dout <= baud_str_100k[baud_bram.addr];
        4'd1:    baud_bram.dout <= baud_str_1m[baud_bram.addr];
        4'd2:    baud_bram.dout <= baud_str_1dot25m[baud_bram.addr];
        4'd3:    baud_bram.dout <= baud_str_2dot5m[baud_bram.addr];
        4'd4:    baud_bram.dout <= baud_str_3dot125m[baud_bram.addr];
        4'd5:    baud_bram.dout <= baud_str_5m[baud_bram.addr];
        4'd6:    baud_bram.dout <= baud_str_6dot25m[baud_bram.addr];
        4'd7:    baud_bram.dout <= baud_str_8dot33m[baud_bram.addr];
        4'd8:    baud_bram.dout <= baud_str_12dot5m[baud_bram.addr];
        4'd9:    baud_bram.dout <= baud_str_25m[baud_bram.addr];
        default: baud_bram.dout <= baud_str_1m[baud_bram.addr];
      endcase
    end

    // Line 4: Oversampling
    if (os_bram.en) begin
      os_bram.dout <= (oversampling == 4'd1) ? os_str_16x[os_bram.addr] : os_str_8x[os_bram.addr];
    end

    // Line 5: Power State
    if (pwr_state_bram.en) begin
      case (pwr_status_code)
        3'd1:    pwr_state_bram.dout <= pwr_state_ready[pwr_state_bram.addr];
        3'd2:    pwr_state_bram.dout <= pwr_state_sending[pwr_state_bram.addr];
        3'd3:    pwr_state_bram.dout <= pwr_state_receiving[pwr_state_bram.addr];
        3'd4:    pwr_state_bram.dout <= pwr_state_active[pwr_state_bram.addr];
        3'd5:    pwr_state_bram.dout <= pwr_state_error[pwr_state_bram.addr];
        3'd6:    pwr_state_bram.dout <= pwr_state_loopback[pwr_state_bram.addr];
        default: pwr_state_bram.dout <= pwr_state_not_ready[pwr_state_bram.addr];
      endcase
    end

    // Line 6: Power Value
    if (pwr_val_bram.en) begin
      if (!contract_active) begin
        pwr_val_bram.dout <= pwr_val_paused[pwr_val_bram.addr];
      end else begin
        case (pwr_val_bram.addr)
          5'd0:  pwr_val_bram.dout <= "P";
          5'd1:  pwr_val_bram.dout <= "o";
          5'd2:  pwr_val_bram.dout <= "w";
          5'd3:  pwr_val_bram.dout <= "e";
          5'd4:  pwr_val_bram.dout <= "r";
          5'd5:  pwr_val_bram.dout <= " ";
          5'd6:  pwr_val_bram.dout <= "V";
          5'd7:  pwr_val_bram.dout <= "a";
          5'd8:  pwr_val_bram.dout <= "l";
          5'd9:  pwr_val_bram.dout <= "u";
          5'd10: pwr_val_bram.dout <= "e";
          5'd11: pwr_val_bram.dout <= " ";
          5'd12: pwr_val_bram.dout <= ":";
          5'd13: pwr_val_bram.dout <= " ";
          5'd14: pwr_val_bram.dout <= (active_voltage_id == 2'd3) ? "2" : (active_voltage_id == 2'd2) ? "1" : " ";
          5'd15: pwr_val_bram.dout <= (active_voltage_id == 2'd3) ? "0" : (active_voltage_id == 2'd2) ? "2" : (active_voltage_id == 2'd1) ? "9" : "5";
          5'd16: pwr_val_bram.dout <= "V";
          5'd17: pwr_val_bram.dout <= " ";
          5'd18: pwr_val_bram.dout <= "@";
          5'd19: pwr_val_bram.dout <= " ";
          5'd20: pwr_val_bram.dout <= 8'd48 + {4'd0, active_amps};
          5'd21: pwr_val_bram.dout <= "A";
          default: pwr_val_bram.dout <= " ";
        endcase
      end
    end

    // Line 6: Failover
    if (failover_bram.en) begin
      failover_bram.dout <= failover_en ? failover_str_on[failover_bram.addr] : failover_str_off[failover_bram.addr];
    end

    // Toolbar Buttons
    if (help_btn_bram.en)   help_btn_bram.dout   <= btn_help_str[help_btn_bram.addr];
    if (ping_btn_bram.en)   ping_btn_bram.dout   <= btn_ping_str[ping_btn_bram.addr];
    if (sweep_btn_bram.en)  sweep_btn_bram.dout  <= btn_sweep_str[sweep_btn_bram.addr];
    if (sndbmp_btn_bram.en) sndbmp_btn_bram.dout <= btn_sndbmp_str[sndbmp_btn_bram.addr];
    if (clrbmp_btn_bram.en) clrbmp_btn_bram.dout <= btn_clrbmp_str[clrbmp_btn_bram.addr];
    if (clrcon_btn_bram.en) clrcon_btn_bram.dout <= btn_clrcon_str[clrcon_btn_bram.addr];
    if (about_btn_bram.en)  about_btn_bram.dout  <= btn_about_str[about_btn_bram.addr];

    // Popups
    if (popup_title_bram.en) begin
      if (popup_mode == 2'd2) popup_title_bram.dout <= prog_title_str[popup_title_bram.addr];
      else popup_title_bram.dout <= popup_title_str[popup_title_bram.addr];
    end
    if (popup_desc_bram.en) begin
      if (popup_mode == 2'd2) popup_desc_bram.dout <= prog_desc_str[popup_desc_bram.addr];
      else popup_desc_bram.dout <= popup_desc_str[popup_desc_bram.addr];
    end
    if (popup_btn_bram.en)  popup_btn_bram.dout  <= popup_btn_str[popup_btn_bram.addr];

    // Diagnostics Labels
    if (diag_title_bram.en) diag_title_bram.dout <= diag_title_str[diag_title_bram.addr];
    if (diag_man_bram.en)   diag_man_bram.dout   <= diag_man_str[diag_man_bram.addr];
    if (diag_pre_bram.en)   diag_pre_bram.dout   <= diag_pre_str[diag_pre_bram.addr];
    if (diag_par_bram.en)   diag_par_bram.dout   <= diag_par_str[diag_par_bram.addr];
    if (diag_hlt_bram.en)   diag_hlt_bram.dout   <= diag_hlt_str[diag_hlt_bram.addr];

    // Bitmap Label
    if (bmp_lbl_bram.en)          bmp_lbl_bram.dout          <= bmp_lbl_str[bmp_lbl_bram.addr];

    // Console Label
    if (console_title_bram.en)    console_title_bram.dout    <= console_title_str[console_title_bram.addr];
  end

endmodule
