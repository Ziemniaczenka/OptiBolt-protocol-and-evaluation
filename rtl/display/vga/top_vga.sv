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
 * The project top module.
 */

module top_vga (
        input  logic clk,
        input  logic rst_n,
        output logic vs,
        output logic hs,
        output logic [3:0] r,
        output logic [3:0] g,
        output logic [3:0] b
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    // VGA signals from timing
    vga_if if_tim();

    // VGA signals from background
    vga_if if_bg();

    // VGA signals from rectangle
    vga_if if_rect();

    /**
     * Signals assignments
     */

    assign vs = if_rect.vsync;
    assign hs = if_rect.hsync;
    assign {r,g,b} = if_rect.rgb;


    /**
     * Submodules instances
     */

    vga_timing u_vga_timing (
        .clk,
        .rst_n,
        .vga_out(if_tim.out)
    );

    draw_bg u_draw_bg (
        .clk,
        .rst_n,
        .vga_in(if_tim.in),
        .vga_out(if_bg.out)
    );

    draw_rect u_draw_rect (
        .clk,
        .rst_n,
        .vga_in(if_bg.in),
        .vga_out(if_rect.out)
    );

endmodule
