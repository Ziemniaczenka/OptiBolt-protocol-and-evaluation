/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 * Modified by: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Modern high-contrast dark theme background generator for OptiBolt evaluation UI.
 */

(* use_dsp = "no" *)

module draw_bg (
    input logic clk,
    input logic rst_n,

    vga_if.out vga_out,
    vga_if.in  vga_in
);

  timeunit 1ns; timeprecision 1ps;

  import vga_pkg::*;

  logic [11:0] rgb_nxt;

  always_ff @(posedge clk or negedge rst_n) begin : bg_ff_blk
    if (!rst_n) begin
      vga_out.vcount <= '0;
      vga_out.vsync  <= '0;
      vga_out.vblnk  <= '0;
      vga_out.hcount <= '0;
      vga_out.hsync  <= '0;
      vga_out.hblnk  <= '0;
      vga_out.rgb    <= '0;
    end else begin
      vga_out.vcount <= vga_in.vcount;
      vga_out.vsync  <= vga_in.vsync;
      vga_out.vblnk  <= vga_in.vblnk;
      vga_out.hcount <= vga_in.hcount;
      vga_out.hsync  <= vga_in.hsync;
      vga_out.hblnk  <= vga_in.hblnk;
      vga_out.rgb    <= rgb_nxt;
    end
  end

  always_comb begin : bg_comb_blk
    if (vga_in.vblnk || vga_in.hblnk) begin
      rgb_nxt = 12'h0_0_0;  // Blanking
    end else begin
      rgb_nxt = 12'h1_1_2;  // Base workspace background
    end
  end

endmodule
