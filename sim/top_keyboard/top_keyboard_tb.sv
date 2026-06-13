/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for the top_keyboard module including controller integration.
 */

module top_keyboard_tb;

  timeunit 1ns; timeprecision 1ps;

  /**
     * Local variables and signals
     */

  logic clk;
  logic rst_n;
  logic mode_text;

  wire  ps2_clk;
  wire  ps2_data;
  logic ps2_clk_drive;
  logic ps2_data_drive;

  logic cmd_up, cmd_down, cmd_left, cmd_right, cmd_enter, cmd_esc;
  logic char_valid, cmd_backspace;
  logic [7:0] char_ascii;

  // Drive strong 1 or 0
  assign ps2_clk  = ps2_clk_drive;
  assign ps2_data = ps2_data_drive;

  // Monitor 1-cycle pulses
  logic got_a, got_right;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      got_a <= 1'b0;
      got_right <= 1'b0;
    end else begin
      if (char_valid && char_ascii == "a") got_a <= 1'b1;
      if (cmd_right) got_right <= 1'b1;
    end
  end

  /**
     * Submodules
     */

  top_keyboard dut (
      .clk(clk),
      .rst_n(rst_n),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .mode_text(mode_text),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .cmd_backspace(cmd_backspace),
      .char_ascii(char_ascii)
  );

  /**
    * Clock generation
    */
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 100MHz clock
  end

  /**
    * Tasks
    */
  task send_ps2_byte(input logic [7:0] data);
    logic   parity;
    integer i;
    begin
      parity = ~^data;  // Odd parity
      ps2_data_drive = 1'b0;  // Start bit
      #20000;
      ps2_clk_drive = 1'b0;
      #20000;
      ps2_clk_drive = 1'b1;
      for (i = 0; i < 8; i++) begin
        ps2_data_drive = data[i];  // Data bits
        #20000;
        ps2_clk_drive = 1'b0;
        #20000;
        ps2_clk_drive = 1'b1;
      end
      ps2_data_drive = parity;  // Parity
      #20000;
      ps2_clk_drive = 1'b0;
      #20000;
      ps2_clk_drive  = 1'b1;
      ps2_data_drive = 1'b1;  // Stop bit
      #20000;
      ps2_clk_drive = 1'b0;
      #20000;
      ps2_clk_drive = 1'b1;
      #40000;  // Idle wait
    end
  endtask

  /**
    * Test sequence
    */
  initial begin
    ps2_clk_drive = 1'b1;
    ps2_data_drive = 1'b1;
    mode_text = 1'b1;  // Włącz tryb wpisywania tekstu dla testów
    rst_n = 1'b0;
    #100;
    rst_n = 1'b1;
    #1000;

    $display("TEST: Pressing 'A' (0x1C)");
    send_ps2_byte(8'h1C);  // Make A
    #1000;
    if (!got_a) $error("FAIL: Character 'a' not valid or incorrect");

    send_ps2_byte(8'hF0);
    send_ps2_byte(8'h1C);  // Break A
    #1000;

    $display("TEST: Pressing Right Arrow (E0, 74)");
    send_ps2_byte(8'hE0);
    send_ps2_byte(8'h74);  // Make Right Arrow
    #1000;
    if (!got_right) $error("FAIL: cmd_right not triggered");

    send_ps2_byte(8'hE0);
    send_ps2_byte(8'hF0);
    send_ps2_byte(8'h74);  // Break Right Arrow
    #1000;

    $display("INFO: All tests completed.");
    $finish;
  end
endmodule
