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
 * Top level synthesizable module including the project top and all the FPGA-referred modules.
 */

module top_basys3 (
        input  wire clk,
        input  wire btnC,
        output wire Vsync,
        output wire Hsync,
        output wire [3:0] vgaRed,
        output wire [3:0] vgaGreen,
        output wire [3:0] vgaBlue,
        output wire JA1
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    wire clk_400MHz;      // for OptiBolt protocol
    wire clk_100MHz;           // for PS/2
    wire clk_74p25MHz;           // for VGA

    wire locked_0;          // Locked signal from the first clock wizard
    wire locked_1;          // Locked signal from the second clock wizard
    wire all_clocks_locked; // All clocks are stable
    wire clk_ibuf;          // Buffered global clock
    wire pclk_mirror;


    /**
     * Signals assignments
     */

    assign JA1 = pclk_mirror;
    assign all_clocks_locked = locked_0 & locked_1;


    IBUF u_ibuf_clk (
        .I(clk),
        .O(clk_ibuf)
    );

    /**
     * FPGA submodules placement
     */


    clk_wiz_0 u_clk_wiz_0
    (
        .clk_400MHz(clk_400MHz), // output 400.000MHz
        .clk_100MHz(clk_100MHz),
        .locked(locked_0),         // output locked
        .clk_in1(clk_ibuf)         // input clk_in1
    );

    clk_wiz_1 u_clk_wiz_1
    (
        .clk_74p25MHz(clk_74p25MHz),    // output 74.250MHz
        .locked(locked_1),         // output locked
        .clk_in1(clk_ibuf)         // input clk_in1
    );

    // Mirror pclk on a pin for use by the testbench;
    // not functionally required for this design to work.

    ODDR pclk_oddr (
        .Q(pclk_mirror),
        .C(clk_74p25MHz),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );


    /**
     *  Project functional top module
     */

    top_display u_top_display (
        .clk(clk_74p25MHz),
        .rst_n(!btnC & all_clocks_locked),
        .vs(Vsync),
        .hs(Hsync),
        .r(vgaRed),
        .g(vgaGreen),
        .b(vgaBlue)
    );

endmodule
