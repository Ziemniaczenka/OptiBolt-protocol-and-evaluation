/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Converts key code to navigation commands and ASCII characters.
 */

module keyboard_controller (
    input logic       clk,
    input logic       rst_n,
    input logic       key_make_strobe,
    input logic [8:0] key_code,
    input logic       shift_held,

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
        if (key_code == 9'h175 || key_code == 9'h075) cmd_up <= 1'b1;  // Ext/Num 75
        if (key_code == 9'h172 || key_code == 9'h072) cmd_down <= 1'b1;  // Ext/Num 72
        if (key_code == 9'h16B || key_code == 9'h06B) cmd_left <= 1'b1;  // Ext/Num 6B
        if (key_code == 9'h174 || key_code == 9'h074) cmd_right <= 1'b1;  // Ext/Num 74
        if (key_code == 9'h05A || key_code == 9'h15A) cmd_enter <= 1'b1;  // Normal/Ext Enter
        if (key_code == 9'h076) cmd_esc <= 1'b1;  // Esc
        if (key_code == 9'h066) cmd_backspace <= 1'b1;  // Backspace

        // Text Mode ASCII Translation
        if (mode_text) begin
          case (key_code)
            // Letters
            9'h01C: begin
              char_ascii <= shift_held ? "A" : "a";
              char_valid <= 1'b1;
            end
            9'h032: begin
              char_ascii <= shift_held ? "B" : "b";
              char_valid <= 1'b1;
            end
            9'h021: begin
              char_ascii <= shift_held ? "C" : "c";
              char_valid <= 1'b1;
            end
            9'h023: begin
              char_ascii <= shift_held ? "D" : "d";
              char_valid <= 1'b1;
            end
            9'h024: begin
              char_ascii <= shift_held ? "E" : "e";
              char_valid <= 1'b1;
            end
            9'h02B: begin
              char_ascii <= shift_held ? "F" : "f";
              char_valid <= 1'b1;
            end
            9'h034: begin
              char_ascii <= shift_held ? "G" : "g";
              char_valid <= 1'b1;
            end
            9'h033: begin
              char_ascii <= shift_held ? "H" : "h";
              char_valid <= 1'b1;
            end
            9'h043: begin
              char_ascii <= shift_held ? "I" : "i";
              char_valid <= 1'b1;
            end
            9'h03B: begin
              char_ascii <= shift_held ? "J" : "j";
              char_valid <= 1'b1;
            end
            9'h042: begin
              char_ascii <= shift_held ? "K" : "k";
              char_valid <= 1'b1;
            end
            9'h04B: begin
              char_ascii <= shift_held ? "L" : "l";
              char_valid <= 1'b1;
            end
            9'h03A: begin
              char_ascii <= shift_held ? "M" : "m";
              char_valid <= 1'b1;
            end
            9'h031: begin
              char_ascii <= shift_held ? "N" : "n";
              char_valid <= 1'b1;
            end
            9'h044: begin
              char_ascii <= shift_held ? "O" : "o";
              char_valid <= 1'b1;
            end
            9'h04D: begin
              char_ascii <= shift_held ? "P" : "p";
              char_valid <= 1'b1;
            end
            9'h015: begin
              char_ascii <= shift_held ? "Q" : "q";
              char_valid <= 1'b1;
            end
            9'h02D: begin
              char_ascii <= shift_held ? "R" : "r";
              char_valid <= 1'b1;
            end
            9'h01B: begin
              char_ascii <= shift_held ? "S" : "s";
              char_valid <= 1'b1;
            end
            9'h02C: begin
              char_ascii <= shift_held ? "T" : "t";
              char_valid <= 1'b1;
            end
            9'h03C: begin
              char_ascii <= shift_held ? "U" : "u";
              char_valid <= 1'b1;
            end
            9'h02A: begin
              char_ascii <= shift_held ? "V" : "v";
              char_valid <= 1'b1;
            end
            9'h01D: begin
              char_ascii <= shift_held ? "W" : "w";
              char_valid <= 1'b1;
            end
            9'h022: begin
              char_ascii <= shift_held ? "X" : "x";
              char_valid <= 1'b1;
            end
            9'h035: begin
              char_ascii <= shift_held ? "Y" : "y";
              char_valid <= 1'b1;
            end
            9'h01A: begin
              char_ascii <= shift_held ? "Z" : "z";
              char_valid <= 1'b1;
            end
            // Numbers
            9'h045: begin
              char_ascii <= shift_held ? ")" : "0";
              char_valid <= 1'b1;
            end
            9'h016: begin
              char_ascii <= shift_held ? "!" : "1";
              char_valid <= 1'b1;
            end
            9'h01E: begin
              char_ascii <= shift_held ? "@" : "2";
              char_valid <= 1'b1;
            end
            9'h026: begin
              char_ascii <= shift_held ? "#" : "3";
              char_valid <= 1'b1;
            end
            9'h025: begin
              char_ascii <= shift_held ? "$" : "4";
              char_valid <= 1'b1;
            end
            9'h02E: begin
              char_ascii <= shift_held ? "%" : "5";
              char_valid <= 1'b1;
            end
            9'h036: begin
              char_ascii <= shift_held ? "^" : "6";
              char_valid <= 1'b1;
            end
            9'h03D: begin
              char_ascii <= shift_held ? "&" : "7";
              char_valid <= 1'b1;
            end
            9'h03E: begin
              char_ascii <= shift_held ? "*" : "8";
              char_valid <= 1'b1;
            end
            9'h046: begin
              char_ascii <= shift_held ? "(" : "9";
              char_valid <= 1'b1;
            end
            // Symbols
            9'h029: begin
              char_ascii <= " ";
              char_valid <= 1'b1;
            end  // Space
            9'h04A: begin
              char_ascii <= shift_held ? "?" : "/";
              char_valid <= 1'b1;
            end
            9'h041: begin
              char_ascii <= shift_held ? "<" : ",";
              char_valid <= 1'b1;
            end
            9'h049: begin
              char_ascii <= shift_held ? ">" : ".";
              char_valid <= 1'b1;
            end
            9'h04E: begin
              char_ascii <= shift_held ? "_" : "-";
              char_valid <= 1'b1;
            end
            9'h04C: begin
              char_ascii <= shift_held ? ":" : ";";
              char_valid <= 1'b1;
            end
            9'h052: begin
              char_ascii <= shift_held ? "\"" : "'";
              char_valid <= 1'b1;
            end
            9'h054: begin
              char_ascii <= shift_held ? "{" : "[";
              char_valid <= 1'b1;
            end
            9'h05B: begin
              char_ascii <= shift_held ? "}" : "]";
              char_valid <= 1'b1;
            end
            9'h00E: begin
              char_ascii <= shift_held ? "~" : "`";
              char_valid <= 1'b1;
            end
            9'h055: begin
              char_ascii <= shift_held ? "+" : "=";
              char_valid <= 1'b1;
            end
            default: ;
          endcase
        end
      end
    end
  end

endmodule
