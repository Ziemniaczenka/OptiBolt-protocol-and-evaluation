/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * VGA top display module.
 */

module top_display (
    input logic       clk,
    input logic       rst_n,
    input logic       rx_carrier = 1'b0,
    input logic [1:0] link_status,
    input logic [3:0] baud_rate,
    input logic [3:0] oversampling,
    input logic [3:0] ui_selected_item,
    input logic       mode_text,
    input logic       show_popup,
    input logic       show_progress,
    input logic [7:0] progress_val,
    input logic [1:0] popup_mode,
    input logic       failover_en = 1'b1,

    input logic [ 7:0] prog_man,
    input logic [ 7:0] prog_pre,
    input logic [ 7:0] prog_par,
    input logic [ 7:0] prog_hlt,
    input logic [11:0] color_man,
    input logic [11:0] color_pre,
    input logic [11:0] color_par,
    input logic [11:0] color_hlt,

    // Power Negotiation
    input logic [2:0] pwr_status_code,
    input logic [1:0] active_voltage_id,
    input logic [3:0] active_amps,
    input logic       contract_active,

    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,

    bram_if.read console_bram,  // read-only BRAM interface for console
    bram_if.read input_bram,    // read-only BRAM interface for input field
    bram_if.read dyn_bmp_bram   // read-only BRAM interface for dynamic bitmap
);

  timeunit 1ns; timeprecision 1ps;

  /**
     * Local variables and signals
     */

  // VGA signals from timing
  vga_if if_tim ();

  // VGA signals from background
  vga_if if_bg ();

  // VGA signals from draw
  vga_if if_draw ();

  /**
     * Signals assignments
     */

  assign vs = if_draw.vsync;
  assign hs = if_draw.hsync;
  assign {r, g, b} = if_draw.rgb;

  /**
     * Submodules instances
     */

  vga_timing u_vga_timing (
      .clk,
      .rst_n,
      .vga_out(if_tim.out)
  );

  draw_bg u_draw_bg (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(if_tim.in),
      .vga_out(if_bg.out)
  );

  top_draw u_top_draw (
      .clk(clk),
      .rst_n(rst_n),
      .rx_carrier(rx_carrier),
      .link_status(link_status),
      .baud_rate(baud_rate),
      .oversampling(oversampling),
      .failover_en(failover_en),
      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .popup_mode(popup_mode),
      .prog_man(prog_man),
      .prog_pre(prog_pre),
      .prog_par(prog_par),
      .prog_hlt(prog_hlt),
      .color_man(color_man),
      .color_pre(color_pre),
      .color_par(color_par),
      .color_hlt(color_hlt),
      .pwr_status_code(pwr_status_code),
      .active_voltage_id(active_voltage_id),
      .active_amps(active_amps),
      .contract_active(contract_active),
      .console_bram(console_bram),
      .input_bram(input_bram),
      .dyn_bmp_bram(dyn_bmp_bram),
      .vga_in(if_bg.in),
      .vga_out(if_draw.out)
  );

endmodule
