/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2025  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 * Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * VGA top module.
 *
 */

module top_display (
    input logic clk,
    input logic rst_n,
    input logic [3:0] ui_selected_item,
    input logic mode_text,
    input logic show_popup,
    input logic show_progress,
    input logic [7:0] progress_val,
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
      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),
      .console_bram(console_bram),
      .input_bram(input_bram),
      .dyn_bmp_bram(dyn_bmp_bram),
      .vga_in(if_bg.in),
      .vga_out(if_draw.out)
  );

endmodule
