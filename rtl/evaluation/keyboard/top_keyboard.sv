/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Top module for Keyboard logic including Cross Domain Crossing.
 */

module top_keyboard (
    input  logic       clk,
    input  logic       rst_n,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    input  logic       mode_text,
    output logic       cmd_up,
    cmd_down,
    cmd_left,
    cmd_right,
    cmd_enter,
    cmd_esc,
    output logic       char_valid,
    cmd_backspace,
    output logic [7:0] char_ascii
);

  logic [511:0] keys_pressed;
  logic         key_make_strobe;
  logic [  8:0] key_code;

  keyboard_decoder u_kbd_dec (
      .clk(clk),
      .rst_n(rst_n),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .keys_pressed(keys_pressed),
      .key_make_strobe(key_make_strobe),
      .key_code(key_code)
  );

  keyboard_controller u_kbd_ctrl (
      .clk(clk),
      .rst_n(rst_n),
      .key_make_strobe(key_make_strobe),
      .key_code(key_code),
      .mode_text(mode_text),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .char_ascii(char_ascii),
      .cmd_backspace(cmd_backspace)
  );
endmodule
