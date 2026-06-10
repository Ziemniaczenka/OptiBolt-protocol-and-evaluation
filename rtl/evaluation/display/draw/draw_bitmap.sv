/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw bitmap from BRAM/ROM.
 * TODO: remove rom if using ram
 */

import bitmap_pkg::*;

module draw_bitmap #(
    parameter bitmap_t        BITMAP,
    parameter string          BITMAP_PATH       = "",
    parameter logic    [11:0] TRANSPARENT_COLOR = 12'h0_0_0,
    parameter bit             USE_TRANSPARENCY  = 1'b0,
    parameter bit             USE_RAM           = 1'b0        // 0 - static, 1 - dynamic
) (
    input logic        clk,
    input logic        rst_n,
    input logic [11:0] xstart,
    input logic [11:0] ystart,

    vga_if.in vga_in,

    output logic [$clog2(BITMAP.WIDTH*BITMAP.HEIGHT)-1:0] mem_addr,
    input  logic [                                  11:0] mem_data,

    output logic [11:0] rgb_out,
    output logic        draw_en_out
);

  /**
    * Local variables and signals
    */

  logic [11:0] rom[0:BITMAP.WIDTH*BITMAP.HEIGHT-1];

  generate
    if (!USE_RAM) begin
      initial begin
        $readmemh(BITMAP_PATH, rom);
      end
    end
  endgenerate

  logic in_region;
  logic in_region_d1;
  logic [$clog2(BITMAP.WIDTH*BITMAP.HEIGHT)-1:0] addr;
  logic [11:0] rom_data;


  /**
    * Internal logic
    */

  always_comb begin : bitmap_bounds_blk
    in_region = (12'(vga_in.hcount) >= xstart) && (12'(vga_in.hcount) < xstart + BITMAP.WIDTH) &&
                    (12'(vga_in.vcount) >= ystart) && (12'(vga_in.vcount) < ystart + BITMAP.HEIGHT);

    addr = (12'(vga_in.vcount) - ystart) * BITMAP.WIDTH + (12'(vga_in.hcount) - xstart);
    mem_addr = addr;
  end


  always_ff @(posedge clk) begin
    if (in_region) begin
      rom_data <= rom[addr];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_region_d1 <= 1'b0;
    end else begin
      in_region_d1 <= in_region;
    end
  end

  logic [11:0] active_data;
  assign active_data = USE_RAM ? mem_data : rom_data;

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
