/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw bitmap from BRAM/ROM.
 */

import bitmap_pkg::*;

module draw_bitmap #(
    parameter bitmap_t        BITMAP,
    parameter string          BITMAP_PATH       = "",
    parameter logic    [11:0] TRANSPARENT_COLOR = 12'h0_0_0,
    parameter bit             USE_TRANSPARENCY  = 1'b0,
    parameter bit             USE_RAM           = 1'b0,       // 0 - static, 1 - dynamic
    parameter bit             USE_PALETTE       = 1'b0,
    parameter int             PALETTE_BITS      = 2,
    parameter logic    [11:0] PALETTE[0:(1<<PALETTE_BITS)-1] = '{default: 12'h000}
) (
    input logic        clk,
    input logic        rst_n,
    input logic [11:0] xstart,
    input logic [11:0] ystart,

    vga_if.in vga_in,

    bram_if.read bmp_bram,

    output logic [11:0] rgb_out,
    output logic        draw_en_out
);

  /**
    * Local variables and signals
    */

  localparam int ROM_ADDR_WIDTH = (BITMAP.WIDTH * BITMAP.HEIGHT > 1) ? $clog2(BITMAP.WIDTH * BITMAP.HEIGHT) : 1;
  localparam int ROM_DEPTH      = (1 << ROM_ADDR_WIDTH);

  logic in_region;
  logic in_region_d1;
  logic [ROM_ADDR_WIDTH-1:0] addr;
  logic [11:0] active_data;


  /**
    * Internal logic
    */

  always_comb begin : bitmap_bounds_blk
    in_region = (12'(vga_in.hcount) >= xstart) && (12'(vga_in.hcount) < xstart + BITMAP.WIDTH) &&
                (12'(vga_in.vcount) >= ystart) && (12'(vga_in.vcount) < ystart + BITMAP.HEIGHT);

    if (in_region) begin
      addr = ROM_ADDR_WIDTH'((12'(vga_in.vcount) - ystart) * BITMAP.WIDTH + (12'(vga_in.hcount) - xstart));
    end else begin
      addr = '0;
    end
  end

  generate
    if (USE_RAM) begin : gen_ram
      assign bmp_bram.addr = addr;
      assign bmp_bram.en   = 1'b1;
      assign active_data   = bmp_bram.dout;
    end else if (USE_PALETTE) begin : gen_palette_rom
      (* rom_style = "block" *) logic [PALETTE_BITS-1:0] rom[0:ROM_DEPTH-1];
      logic [PALETTE_BITS-1:0] rom_idx;

      initial begin
        for (int i = 0; i < ROM_DEPTH; i++) rom[i] = '0;
        if (BITMAP_PATH != "") $readmemh(BITMAP_PATH, rom);
      end

      always_ff @(posedge clk) begin
        rom_idx <= rom[addr];
      end

      assign active_data   = PALETTE[rom_idx];

      // Safe default state for unused interface
      assign bmp_bram.addr = '0;
      assign bmp_bram.en   = 1'b0;
    end else begin : gen_rom
      (* rom_style = "block" *) logic [11:0] rom[0:ROM_DEPTH-1];
      logic [11:0] rom_data;

      initial begin
        for (int i = 0; i < ROM_DEPTH; i++) rom[i] = 12'h0;
        if (BITMAP_PATH != "") $readmemh(BITMAP_PATH, rom);
      end

      always_ff @(posedge clk) begin
        rom_data <= rom[addr];
      end

      assign active_data   = rom_data;

      // Safe default state for unused interface
      assign bmp_bram.addr = '0;
      assign bmp_bram.en   = 1'b0;
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_region_d1 <= 1'b0;
    end else begin
      in_region_d1 <= in_region;
    end
  end

  always_comb begin : bitmap_comb_blk
    if (in_region_d1 && !(USE_TRANSPARENCY && active_data == TRANSPARENT_COLOR)) begin
      rgb_out     = active_data;
      draw_en_out = 1'b1;
    end else begin
      rgb_out     = 12'h0_0_0;
      draw_en_out = 1'b0;
    end
  end

endmodule
