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
    parameter bitmap_t     BITMAP,
    parameter string       BITMAP_PATH,
    parameter logic [11:0] TRANSPARENT_COLOR = 12'h0_0_0,
    parameter bit          USE_TRANSPARENCY  = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] xstart,
    input  logic [11:0] ystart,

    vga_if.in           vga_in,

    output logic [11:0] rgb_out,
    output logic        draw_en_out
);

    logic [11:0] rom [0:BITMAP.WIDTH*BITMAP.HEIGHT-1];

    initial begin
        if (BITMAP_PATH != "") begin
            $readmemh(BITMAP_PATH, rom);
        end
    end

    logic in_region;
    logic in_region_d1;
    logic [$clog2(BITMAP.WIDTH*BITMAP.HEIGHT)-1:0] addr;
    logic [11:0] rom_data;

    always_comb begin : bitmap_bounds_blk
        in_region = (12'(vga_in.hcount) >= xstart) && (12'(vga_in.hcount) < xstart + BITMAP.WIDTH) &&
                    (12'(vga_in.vcount) >= ystart) && (12'(vga_in.vcount) < ystart + BITMAP.HEIGHT);

        addr = (12'(vga_in.vcount) - ystart) * BITMAP.WIDTH + (12'(vga_in.hcount) - xstart);
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

    always_comb begin : bitmap_comb_blk
        if (in_region_d1 && !(USE_TRANSPARENCY && rom_data == TRANSPARENT_COLOR)) begin
            rgb_out     = rom_data;
            draw_en_out = 1'b1;
        end else begin
            rgb_out     = 12'h0_0_0;
            draw_en_out = 1'b0;
        end
    end

endmodule
