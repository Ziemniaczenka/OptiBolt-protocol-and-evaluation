/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for top_evaluation.
 * Tests integrated UI Navigation, Keyboard PS/2 and Action handling logic.
 * Produces consecutive visual frames.
 */

module top_evaluation_tb;

  timeunit 1ns; timeprecision 1ps;

  // Clocks
  logic clk74p25, clk100, rst_n;
  wire vs, hs;
  wire [3:0] r, g, b;

  wire ps2_clk, ps2_data;
  logic ps2_clk_drive, ps2_data_drive;
  assign ps2_clk = ps2_clk_drive;
  assign ps2_data = ps2_data_drive;

  wire [3:0] an;
  wire [6:0] seg;
  wire dp;

  // Clock gen
  initial begin clk74p25 = 1'b0; forever #6.734 clk74p25 = ~clk74p25; end // ~74.25 MHz
  initial begin clk100 = 1'b0;   forever #5.000 clk100 = ~clk100;     end // 100 MHz

  top_evaluation dut (
      .clk74p25(clk74p25),
      .clk100(clk100),
      .rst_n(rst_n),
      .vs(vs), .hs(hs), .r(r), .g(g), .b(b),
      .ps2_clk(ps2_clk), .ps2_data(ps2_data),
      .an(an), .seg(seg), .dp(dp)
  );

  tiff_writer #(
      .XDIM(16'd1650),
      .YDIM(16'd750),
      .FILE_DIR("../../results")
  ) u_tiff_writer (
      .clk(clk74p25),
      .r({r, r}), .g({g, g}), .b({b, b}),
      .go(vs)
  );

  task send_ps2_byte(input logic [7:0] data);
    logic parity;
    integer i;
    begin
      parity = ~^data; // Odd parity
      ps2_data_drive = 1'b0; // Start bit
      #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;
      for (i = 0; i < 8; i++) begin
        ps2_data_drive = data[i]; // Data bits
        #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;
      end
      ps2_data_drive = parity; // Parity
      #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;
      ps2_data_drive = 1'b1; // Stop bit
      #20000; ps2_clk_drive = 1'b0; #20000; ps2_clk_drive = 1'b1;
      #40000; // Idle wait
    end
  endtask

  task wait_frames(input int frames);
    for (int i=0; i<frames; i++) begin
      wait(vs == 1'b0);
      @(negedge vs);
    end
  endtask

  initial begin
    ps2_clk_drive = 1'b1; ps2_data_drive = 1'b1;
    rst_n = 1'b0;
    #100 rst_n = 1'b1;

    wait_frames(1); // Frame 0: Boot - Default state points to Input field
    $display("Frame 0: Booted. Focus on Input Field.");

    // Press Right to go to About button
    send_ps2_byte(8'hE0); send_ps2_byte(8'h74); // Right make
    send_ps2_byte(8'hE0); send_ps2_byte(8'hF0); send_ps2_byte(8'h74); // Right break
    wait_frames(1);
    $display("Frame 1: About Button Selected.");

    // Press Enter to trigger popup
    send_ps2_byte(8'h5A); send_ps2_byte(8'hF0); send_ps2_byte(8'h5A);
    wait_frames(1);
    $display("Frame 2: Popup Window Opened.");

    // Press Down to select popup OK button
    send_ps2_byte(8'hE0); send_ps2_byte(8'h72); 
    send_ps2_byte(8'hE0); send_ps2_byte(8'hF0); send_ps2_byte(8'h72);
    wait_frames(1);
    $display("Frame 3: Popup OK Button Highlighted.");

    // Press Enter to close popup
    send_ps2_byte(8'h5A); send_ps2_byte(8'hF0); send_ps2_byte(8'h5A);
    wait_frames(1);
    $display("Frame 4: Popup Window Closed.");

    // Press Left to go back to Input field
    send_ps2_byte(8'hE0); send_ps2_byte(8'h6B); 
    send_ps2_byte(8'hE0); send_ps2_byte(8'hF0); send_ps2_byte(8'h6B);
    wait_frames(1);

    // Press Enter to enter text mode
    send_ps2_byte(8'h5A); send_ps2_byte(8'hF0); send_ps2_byte(8'h5A);
    wait_frames(1);
    $display("Frame 5: Text Mode Entered (Green Outline).");

    // Type 'H' (Shift + H -> 12/59 + 33)
    send_ps2_byte(8'h12); send_ps2_byte(8'h33);
    send_ps2_byte(8'hF0); send_ps2_byte(8'h33); send_ps2_byte(8'hF0); send_ps2_byte(8'h12);
    
    // Type 'i' (43)
    send_ps2_byte(8'h43); send_ps2_byte(8'hF0); send_ps2_byte(8'h43);
    wait_frames(1);
    $display("Frame 6: Typed 'Hi' in the Input box.");

    // Press Enter (Should stay in text mode but clear the text)
    send_ps2_byte(8'h5A); send_ps2_byte(8'hF0); send_ps2_byte(8'h5A);
    wait_frames(1);
    $display("Frame 7: Enter pressed. Text cleared, still in Text Mode.");

    // Press Esc to exit text mode
    send_ps2_byte(8'h76); send_ps2_byte(8'hF0); send_ps2_byte(8'h76);
    wait_frames(1);
    $display("Frame 8: Esc pressed. Exited Text Mode.");

    $finish;
  end
endmodule