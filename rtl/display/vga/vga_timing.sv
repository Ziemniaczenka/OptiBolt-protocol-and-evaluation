/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 * Modified by: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Vga timing controller.
 */

module vga_timing (
        input  logic clk,
        input  logic rst_n,
        vga_if.out vga_out
    );

    timeunit 1ns;
    timeprecision 1ps;

    import vga_pkg::*;


    /**
     * Local variables and signals
     */

    logic [10:0] vcount_nxt, hcount_nxt;
    logic vsync_nxt, vblnk_nxt, hsync_nxt, hblnk_nxt;

    /**
     * Internal logic
     */

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_out.vcount <= '0;
            vga_out.hcount <= '0;
            vga_out.vsync <= '0;
            vga_out.hsync <= '0;
            vga_out.vblnk <= '0;
            vga_out.hblnk <= '0;
            vga_out.rgb <= '0;

        end else begin
            vga_out.vcount <= vcount_nxt;
            vga_out.hcount <= hcount_nxt;
            vga_out.vsync <= vsync_nxt;
            vga_out.hsync <= hsync_nxt;
            vga_out.vblnk <= vblnk_nxt;
            vga_out.hblnk <= hblnk_nxt;
            vga_out.rgb <= '0;
        end
    end

    always_comb begin
        vcount_nxt=vga_out.vcount;
        hcount_nxt=vga_out.hcount;
        vsync_nxt=vga_out.vsync;
        vblnk_nxt=vga_out.vblnk;
        /* hcount and vcount */
        if (vga_out.hcount<HOR_TOTAL_TIME-1) begin
            hcount_nxt = vga_out.hcount + 1;
        end else begin
            hcount_nxt = '0;
            vsync_nxt = ((vga_out.vcount>=VER_SYNC_START-1) & (vga_out.vcount < VER_SYNC_START+VER_SYNC_TIME-1));
            vblnk_nxt = ((vga_out.vcount>=VER_BLANK_START-1) & (vga_out.vcount < VER_BLANK_START+VER_BLANK_TIME-1));
            if (vga_out.vcount<VER_TOTAL_TIME-1) begin
                vcount_nxt = vga_out.vcount + 1;
            end else begin
                vcount_nxt = '0;
            end
        end

        /* hsync */
        hsync_nxt = (vga_out.hcount>=HOR_SYNC_START-1 & vga_out.hcount<HOR_SYNC_START+HOR_SYNC_TIME-1);

        /* hblnk */
        hblnk_nxt = (vga_out.hcount>=HOR_BLANK_START-1 & vga_out.hcount<HOR_BLANK_START+HOR_BLANK_TIME-1);

    end

endmodule
