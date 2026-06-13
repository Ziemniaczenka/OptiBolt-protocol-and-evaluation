/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Converts 512-bit key state array to navigation commands and ASCII characters.
 * Includes edge detection so holding a key doesn't spam commands endlessly.
 * TODO: update decription
 * TODO: add all required ascii (uppercase?)
 */

module keyboard_controller (
    input logic       clk,
    input logic       rst_n,
    input logic       key_make_strobe,
    input logic [8:0] key_code,

    input logic mode_text,  // 0 = Navigation, 1 = Text input

    // Navigation Outputs
    output logic cmd_up,
    output logic cmd_down,
    output logic cmd_left,
    output logic cmd_right,
    output logic cmd_enter,
    output logic cmd_esc,

    // Text Outputs
    output logic       char_valid,
    output logic [7:0] char_ascii,
    output logic       cmd_backspace
);

  // Decoder LUT
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_up        <= 1'b0;
      cmd_down      <= 1'b0;
      cmd_left      <= 1'b0;
      cmd_right     <= 1'b0;
      cmd_enter     <= 1'b0;
      cmd_esc       <= 1'b0;
      char_valid    <= 1'b0;
      char_ascii    <= 8'h00;
      cmd_backspace <= 1'b0;
    end else begin
      // Clear pulses
      cmd_up        <= 1'b0;
      cmd_down      <= 1'b0;
      cmd_left      <= 1'b0;
      cmd_right     <= 1'b0;
      cmd_enter     <= 1'b0;
      cmd_esc       <= 1'b0;
      char_valid    <= 1'b0;
      cmd_backspace <= 1'b0;

      if (key_make_strobe) begin
        // Navigation Keys (Common for both modes, or specific)
        if (key_code == 9'h175) cmd_up <= 1'b1;  // Extended 75
        if (key_code == 9'h172) cmd_down <= 1'b1;
        if (key_code == 9'h16B) cmd_left <= 1'b1;
        if (key_code == 9'h174) cmd_right <= 1'b1;
        if (key_code == 9'h05A) cmd_enter <= 1'b1;  // Enter
        if (key_code == 9'h076) cmd_esc <= 1'b1;  // Esc
        if (key_code == 9'h066) cmd_backspace <= 1'b1;  // Backspace

        // Text Mode ASCII Translation
        if (mode_text) begin
          case (key_code)
            // Letters
            9'h01C: begin
              char_ascii <= "a";
              char_valid <= 1'b1;
            end
            9'h032: begin
              char_ascii <= "b";
              char_valid <= 1'b1;
            end
            9'h021: begin
              char_ascii <= "c";
              char_valid <= 1'b1;
            end
            9'h023: begin
              char_ascii <= "d";
              char_valid <= 1'b1;
            end
            9'h024: begin
              char_ascii <= "e";
              char_valid <= 1'b1;
            end
            9'h02B: begin
              char_ascii <= "f";
              char_valid <= 1'b1;
            end
            9'h034: begin
              char_ascii <= "g";
              char_valid <= 1'b1;
            end
            9'h033: begin
              char_ascii <= "h";
              char_valid <= 1'b1;
            end
            9'h043: begin
              char_ascii <= "i";
              char_valid <= 1'b1;
            end
            9'h03B: begin
              char_ascii <= "j";
              char_valid <= 1'b1;
            end
            9'h042: begin
              char_ascii <= "k";
              char_valid <= 1'b1;
            end
            9'h04B: begin
              char_ascii <= "l";
              char_valid <= 1'b1;
            end
            9'h03A: begin
              char_ascii <= "m";
              char_valid <= 1'b1;
            end
            9'h031: begin
              char_ascii <= "n";
              char_valid <= 1'b1;
            end
            9'h044: begin
              char_ascii <= "o";
              char_valid <= 1'b1;
            end
            9'h04D: begin
              char_ascii <= "p";
              char_valid <= 1'b1;
            end
            9'h015: begin
              char_ascii <= "q";
              char_valid <= 1'b1;
            end
            9'h02D: begin
              char_ascii <= "r";
              char_valid <= 1'b1;
            end
            9'h01B: begin
              char_ascii <= "s";
              char_valid <= 1'b1;
            end
            9'h02C: begin
              char_ascii <= "t";
              char_valid <= 1'b1;
            end
            9'h03C: begin
              char_ascii <= "u";
              char_valid <= 1'b1;
            end
            9'h02A: begin
              char_ascii <= "v";
              char_valid <= 1'b1;
            end
            9'h01D: begin
              char_ascii <= "w";
              char_valid <= 1'b1;
            end
            9'h022: begin
              char_ascii <= "x";
              char_valid <= 1'b1;
            end
            9'h035: begin
              char_ascii <= "y";
              char_valid <= 1'b1;
            end
            9'h01A: begin
              char_ascii <= "z";
              char_valid <= 1'b1;
            end
            // Numbers
            9'h045: begin
              char_ascii <= "0";
              char_valid <= 1'b1;
            end
            9'h016: begin
              char_ascii <= "1";
              char_valid <= 1'b1;
            end
            9'h01E: begin
              char_ascii <= "2";
              char_valid <= 1'b1;
            end
            9'h026: begin
              char_ascii <= "3";
              char_valid <= 1'b1;
            end
            9'h025: begin
              char_ascii <= "4";
              char_valid <= 1'b1;
            end
            9'h02E: begin
              char_ascii <= "5";
              char_valid <= 1'b1;
            end
            9'h036: begin
              char_ascii <= "6";
              char_valid <= 1'b1;
            end
            9'h03D: begin
              char_ascii <= "7";
              char_valid <= 1'b1;
            end
            9'h03E: begin
              char_ascii <= "8";
              char_valid <= 1'b1;
            end
            9'h046: begin
              char_ascii <= "9";
              char_valid <= 1'b1;
            end
            // Symbols
            9'h029: begin
              char_ascii <= " ";
              char_valid <= 1'b1;
            end  // Space
            9'h04A: begin
              char_ascii <= "/";
              char_valid <= 1'b1;
            end
            9'h041: begin
              char_ascii <= ",";
              char_valid <= 1'b1;
            end
            9'h049: begin
              char_ascii <= ".";
              char_valid <= 1'b1;
            end
            9'h04E: begin
              char_ascii <= "-";
              char_valid <= 1'b1;
            end
            9'h04C: begin
              char_ascii <= ";";
              char_valid <= 1'b1;
            end
            9'h052: begin
              char_ascii <= "'";
              char_valid <= 1'b1;
            end
            9'h054: begin
              char_ascii <= "[";
              char_valid <= 1'b1;
            end
            9'h05B: begin
              char_ascii <= "]";
              char_valid <= 1'b1;
            end
            9'h00E: begin
              char_ascii <= "`";
              char_valid <= 1'b1;
            end
            9'h055: begin
              char_ascii <= "=";
              char_valid <= 1'b1;
            end
            default: ;
          endcase
        end
      end
    end
  end

endmodule
