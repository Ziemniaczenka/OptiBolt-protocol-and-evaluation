/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 * Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for draw_bitmap.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

import bitmap_pkg::*;

module draw_bitmap_tb;

  timeunit 1ns; timeprecision 1ps;

  /**
  *  Local parameters
  */

  // f = 74.25 MHz -> T = 13.468 ns
  real CLK_PERIOD = 13.468;
  localparam RST_START_TIME = 30;
  localparam RST_ACTIVE_TIME = 30;

  /**
  * Local variables and signals
  */

  logic clk, rst_n;
  wire vs, hs;
  wire [11:0] rgb_rom, rgb_ram;
  logic en_rom, en_ram;

  logic [11:0] xstart_rom, ystart_rom;
  logic [11:0] xstart_ram, ystart_ram;

  vga_if tim_if ();

  assign vs = tim_if.vsync;
  assign hs = tim_if.hsync;

  /**
  * Clock generation
  */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  /**
  * Submodules instances
  */

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );

  // --- ROM DUT ---
  draw_bitmap #(
      .BITMAP(BITMAP_TEST_128x64),
      .BITMAP_PATH(BITMAP_TEST_128x64_PATH),
      .USE_RAM(1'b0)
  ) dut_rom (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart_rom),
      .ystart(ystart_rom),
      .vga_in(tim_if.in),
      .mem_addr(),  // unused
      .mem_data(12'h0),  // unused
      .rgb_out(rgb_rom),
      .draw_en_out(en_rom)
  );

  // --- RAM DUT ---
  logic ram_we;
  logic [$clog2(BITMAP_TEST_69x153.WIDTH*BITMAP_TEST_69x153.HEIGHT)-1:0] ram_addr_w, ram_addr;
  logic [11:0] ram_din, ram_data;

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH($clog2(BITMAP_TEST_69x153.WIDTH * BITMAP_TEST_69x153.HEIGHT))
  ) u_ram (
      .clk_a (clk),
      .we_a  (ram_we),
      .addr_a(ram_addr_w),
      .din_a (ram_din),
      .dout_a(),
      .clk_b (clk),
      .we_b  (1'b0),
      .addr_b(ram_addr),
      .din_b (12'h0),
      .dout_b(ram_data)
  );

  draw_bitmap #(
      .BITMAP(BITMAP_TEST_69x153),
      .USE_RAM(1'b1),
      .USE_TRANSPARENCY(1'b1)
  ) dut_ram (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart_ram),
      .ystart(ystart_ram),
      .vga_in(tim_if.in),
      .mem_addr(ram_addr),
      .mem_data(ram_data),
      .rgb_out(rgb_ram),
      .draw_en_out(en_ram)
  );

  wire [11:0] rgb_out = en_rom ? rgb_rom : (en_ram ? rgb_ram : 12'h222);
  logic draw_en_out;
  assign draw_en_out = en_rom | en_ram;

  wire [3:0] r = draw_en_out ? rgb_out[11:8] : 4'h2;
  wire [3:0] g = draw_en_out ? rgb_out[7:4] : 4'h2;
  wire [3:0] b = draw_en_out ? rgb_out[3:0] : 4'h2;

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

  logic [11:0] bmp_mem[0:BITMAP_TEST_69x153.WIDTH*BITMAP_TEST_69x153.HEIGHT-1];

  /**
  * Main test
  */

  initial begin
    rst_n = 1'b1;
    // dummy initial values
    xstart_rom = 12'd0;
    ystart_rom = 12'd0;
    xstart_ram = 12'd0;
    ystart_ram = 12'd0;
    ram_we = 0;
    ram_addr_w = 0;
    ram_din = 0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    // BRAM Initialization Process via Port A
    $readmemh(BITMAP_TEST_69x153_PATH, bmp_mem);
    for (int i = 0; i < BITMAP_TEST_69x153.WIDTH * BITMAP_TEST_69x153.HEIGHT; i++) begin
      @(posedge clk);
      ram_we = 1'b1;
      ram_addr_w = i;
      ram_din = bmp_mem[i];
    end
    @(posedge clk);
    ram_we = 1'b0;

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0
    xstart_rom = 12'd50;
    ystart_rom = 12'd50;
    xstart_ram = 12'd250;
    ystart_ram = 12'd50;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Frame 1
    xstart_rom = 12'd200;
    ystart_rom = 12'd150;
    xstart_ram = 12'd400;
    ystart_ram = 12'd150;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
