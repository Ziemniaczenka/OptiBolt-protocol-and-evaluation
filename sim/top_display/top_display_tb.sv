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
 * Testbench for top_display.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

module top_display_tb;

    timeunit 1ns;
    timeprecision 1ps;

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
    wire [3:0] r, g, b;


    /**
    * Clock generation
    */

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end


    /**
    * Submodules instances
    */

    top_display dut (
        .clk(clk),
        .rst_n(rst_n),
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b)
    );

    tiff_writer #(
        .XDIM(16'd1650),
        .YDIM(16'd750),
        .FILE_DIR("../../results")
    ) u_tiff_writer (
        .clk(clk),
        .r({r,r}), // fabricate an 8-bit value
        .g({g,g}), // fabricate an 8-bit value
        .b({b,b}), // fabricate an 8-bit value
        .go(vs)
    );


    /**
    * Main test
    */

    initial begin
        rst_n = 1'b1;
        #(RST_START_TIME) rst_n = 1'b0;
        #(RST_ACTIVE_TIME) rst_n = 1'b1;

        $display("If simulation ends before the testbench");
        $display("completes, use the menu option to run all.");
        $display("Prepare to wait a long time...");

        wait (vs == 1'b0);
        @(negedge vs) $display("Info: Frame 0 done at %t",$time);
        @(negedge vs) $display("Info: Frame 1 done at %t",$time);
        @(negedge vs) $display("Info: Frame 2 done at %t",$time);
        @(negedge vs) $display("Info: Frame 3 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 4 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 5 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 6 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 7 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 8 done at %t",$time);
        // @(negedge vs) $display("Info: Frame 9 done at %t",$time);

        // End the simulation.
        $display("Simulation is over, check the waveforms.");

        $finish;
    end

endmodule
