/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for dynamic bitmap streaming and rendering with draw_bitmap.
 * Connects pixel_prng to bram_tdp Port A and draw_bitmap to Port B (128x128 = 16384 pixels).
 * Uses tiff_writer to export dynamic bitmap frame rendering to TIF format.
 */

import bitmap_pkg::*;

module draw_dyn_bitmap_tb;

  timeunit 1ns; timeprecision 1ps;

  // f = 74.25 MHz -> T = 13.468 ns
  real CLK_PERIOD = 13.468;
  localparam RST_START_TIME = 30;
  localparam RST_ACTIVE_TIME = 30;

  logic clk, rst_n;
  wire vs, hs;
  wire [11:0] rgb_ram;
  logic en_ram;

  logic [11:0] xstart_ram, ystart_ram;

  vga_if tim_if ();

  assign vs = tim_if.vsync;
  assign hs = tim_if.hsync;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );

  // BRAM Interfaces (128x128 dynamic bitmap = 16384 entries -> ADDR_WIDTH = 14)
  bram_if #(.ADDR_WIDTH(14), .DATA_WIDTH(12)) ram_if_a();
  bram_if #(.ADDR_WIDTH(14), .DATA_WIDTH(12), .READ_ONLY(1)) ram_if_b();

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH(14)
  ) u_dyn_ram (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(ram_if_a),
      .port_b(ram_if_b)
  );

  draw_bitmap #(
      .BITMAP(BITMAP_DYN_128x128),
      .USE_RAM(1'b1),
      .USE_TRANSPARENCY(1'b0)
  ) dut_dyn_ram (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart_ram),
      .ystart(ystart_ram),
      .vga_in(tim_if.in),
      .bmp_bram(ram_if_b),
      .rgb_out(rgb_ram),
      .draw_en_out(en_ram)
  );

  // PRNG Pixel Generator
  logic        next_pixel;
  logic [11:0] prng_pixel_rgb;
  logic [ 7:0] prng_pixel_byte;

  pixel_prng u_prng (
      .clk(clk),
      .rst_n(rst_n),
      .next_pixel(next_pixel),
      .pixel_rgb(prng_pixel_rgb),
      .pixel_byte(prng_pixel_byte)
  );

  wire [3:0] r = en_ram ? rgb_ram[11:8] : 4'h1;
  wire [3:0] g = en_ram ? rgb_ram[7:4]  : 4'h1;
  wire [3:0] b = en_ram ? rgb_ram[3:0]  : 4'h2;

  tiff_writer #(
      .XDIM(16'd1650),
      .YDIM(16'd750),
      .FILE_DIR("../../results")
  ) u_tiff_writer (
      .clk(clk),
      .r  ({r, r}),
      .g  ({g, g}),
      .b  ({b, b}),
      .go (vs)
  );

  initial begin
    rst_n = 1'b1;
    xstart_ram = 12'd950;
    ystart_ram = 12'd80;
    ram_if_a.we = 0;
    ram_if_a.en = 0;
    ram_if_a.addr = 0;
    ram_if_a.din = 0;
    next_pixel = 0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    $display("Starting PRNG 128x128 dynamic bitmap fill test...");

    // Stream 16,384 PRNG generated pixels into BRAM via Port A
    for (int i = 0; i < 16384; i++) begin
      @(posedge clk);
      next_pixel = 1'b1;
      ram_if_a.we = 1'b1;
      ram_if_a.en = 1'b1;
      ram_if_a.addr = 14'(i);
      ram_if_a.din = prng_pixel_rgb;
    end
    @(posedge clk);
    next_pixel = 1'b0;
    ram_if_a.we = 1'b0;
    ram_if_a.en = 1'b0;

    wait (vs == 1'b0);
    @(negedge vs);
    $display("Frame 0 rendered with 128x128 dynamic PRNG bitmap at %t", $time);

    @(posedge vs);
    $display("Frame 1 rendered at %t", $time);

    $display("128x128 Dynamic bitmap test finished successfully.");
    $finish;
  end

endmodule
