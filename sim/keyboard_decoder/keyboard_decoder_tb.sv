/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for the SystemVerilog keyboard_decoder module.
 */

module keyboard_decoder_tb;

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    logic clk;
    logic rst_n;

    // Use wire and drive strong '1' instead of 'Z' to avoid simulation issues
    // with VHDL strictly comparing to '1' instead of 'H'
    wire  ps2_clk;
    wire  ps2_data;

    logic [511:0] keys_pressed;

    logic ps2_clk_drive;
    logic ps2_data_drive;

    // Drive strong 1 or 0
    assign ps2_clk  = ps2_clk_drive;
    assign ps2_data = ps2_data_drive;

    /**
     * Submodules
     */

    keyboard_decoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .keys_pressed(keys_pressed)
    );

    /**
    * Clock generation
    */

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    /**
    * Tasks
    */

    task send_ps2_byte(input logic [7:0] data);
        logic parity;
        integer i;
        begin
            parity = ~^data; // Odd parity

            // Start bit
            ps2_data_drive = 1'b0;
            #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;

            // Data bits
            for (i = 0; i < 8; i++) begin
                ps2_data_drive = data[i];
                #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;
            end

            // Parity bit
            ps2_data_drive = parity;
            #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;

            // Stop bit
            ps2_data_drive = 1'b1;
            #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;

            #40000; // Idle wait
        end
    endtask

    /**
    * Test sequence
    */

    initial begin
        ps2_clk_drive  = 1'b1;
        ps2_data_drive = 1'b1;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        #1000;

        // Normal press and make keys test
        $display("TEST: Pressing 'A' (0x1C)");
        send_ps2_byte(8'h1C);
        #1000;
        if (keys_pressed[8'h1C] !== 1'b1) $error("FAIL: 'A' key not detected as pressed");

        // Extended key (Right Arrow - E0 74)
        $display("TEST: Pressing Right Arrow (E0, 74)");
        send_ps2_byte(8'hE0);
        send_ps2_byte(8'h74);
        #1000;
        if (keys_pressed[{1'b1, 8'h74}] !== 1'b1) $error("FAIL: Right Arrow not detected");

        // Releasing extended key (E0 F0 74)
        $display("TEST: Releasing Right Arrow (E0, F0, 74)");
        send_ps2_byte(8'hE0);
        send_ps2_byte(8'hF0);
        send_ps2_byte(8'h74);
        #1000;
        if (keys_pressed[{1'b1, 8'h74}] !== 1'b0) $error("FAIL: Right Arrow not released");

        // Releasing normal key
        $display("TEST: Releasing 'A' (F0, 1C)");
        send_ps2_byte(8'hF0);
        send_ps2_byte(8'h1C);
        #1000;
        if (keys_pressed[8'h1C] !== 1'b0) $error("FAIL: 'A' key not detected as released");

        $display("INFO: All tests completed.");
        $finish;
    end
endmodule
