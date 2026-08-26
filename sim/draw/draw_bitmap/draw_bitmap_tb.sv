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
  wire [11:0] rgb_rom, rgb_ram, rgb_pal;
  logic en_rom, en_ram, en_pal;

  logic [11:0] xstart_rom, ystart_rom;
  logic [11:0] xstart_ram, ystart_ram;
  logic [11:0] xstart_pal, ystart_pal;

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

  bram_if #(.ADDR_WIDTH(1), .DATA_WIDTH(12), .READ_ONLY(1)) rom_if(); // Defaultowy rom w tb nie uzywa BRAM do adresacji
  bram_if #(.ADDR_WIDTH(1), .DATA_WIDTH(12), .READ_ONLY(1)) pal_if();

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
      .bmp_bram(rom_if),
      .rgb_out(rgb_rom),
      .draw_en_out(en_rom)
  );

  // --- RAM DUT ---
  bram_if #(.ADDR_WIDTH($clog2(BITMAP_TEST_69x153.WIDTH*BITMAP_TEST_69x153.HEIGHT)), .DATA_WIDTH(12)) ram_if_a();
  bram_if #(.ADDR_WIDTH($clog2(BITMAP_TEST_69x153.WIDTH*BITMAP_TEST_69x153.HEIGHT)), .DATA_WIDTH(12), .READ_ONLY(1)) ram_if_b();

  bram_tdp #(
      .DATA_WIDTH(12),
      .ADDR_WIDTH($clog2(BITMAP_TEST_69x153.WIDTH * BITMAP_TEST_69x153.HEIGHT))
  ) u_ram (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(ram_if_a),
      .port_b(ram_if_b)
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
      .bmp_bram(ram_if_b),
      .rgb_out(rgb_ram),
      .draw_en_out(en_ram)
  );

  // --- PALETTE ROM DUT ---
  draw_bitmap #(
      .BITMAP(BITMAP_OPTIBOLT_400x102),
      .BITMAP_PATH(BITMAP_OPTIBOLT_400x102_PALETTE_PATH),
      .TRANSPARENT_COLOR(12'hFFF),
      .USE_TRANSPARENCY(1'b1),
      .USE_RAM(1'b0),
      .USE_PALETTE(1'b1),
      .PALETTE_BITS(2),
      .PALETTE(PALETTE_OPTIBOLT_400x102)
  ) dut_pal (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart_pal),
      .ystart(ystart_pal),
      .vga_in(tim_if.in),
      .bmp_bram(pal_if),
      .rgb_out(rgb_pal),
      .draw_en_out(en_pal)
  );

  wire [11:0] rgb_out = en_pal ? rgb_pal : (en_rom ? rgb_rom : (en_ram ? rgb_ram : 12'h222));
  logic draw_en_out;
  assign draw_en_out = en_pal | en_rom | en_ram;

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
    xstart_pal = 12'd0;
    ystart_pal = 12'd0;
    ram_if_a.we = 0;
    ram_if_a.en = 0;
    ram_if_a.addr = 0;
    ram_if_a.din = 0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    // BRAM Initialization Process via Port A
    $readmemh(BITMAP_TEST_69x153_PATH, bmp_mem);
    for (int i = 0; i < BITMAP_TEST_69x153.WIDTH * BITMAP_TEST_69x153.HEIGHT; i++) begin
      @(posedge clk);
      ram_if_a.we = 1'b1;
      ram_if_a.en = 1'b1;
      ram_if_a.addr = i;
      ram_if_a.din = bmp_mem[i];
    end
    @(posedge clk);
    ram_if_a.we = 1'b0;
    ram_if_a.en = 1'b0;

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0
    xstart_rom = 12'd50;
    ystart_rom = 12'd50;
    xstart_ram = 12'd250;
    ystart_ram = 12'd50;
    xstart_pal = 12'd400;
    ystart_pal = 12'd50;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Frame 1
    xstart_rom = 12'd200;
    ystart_rom = 12'd150;
    xstart_ram = 12'd400;
    ystart_ram = 12'd150;
    xstart_pal = 12'd600;
    ystart_pal = 12'd150;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
