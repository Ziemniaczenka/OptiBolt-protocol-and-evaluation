/**
 * Minimal module for testing PS/2 on hardware.
 * Displays the last two received raw bytes on LEDs,
 * and decoded ASCII/commands on the 7-segment display.
 */
module top_ps2_test (
    input  logic        clk,     // 100MHz clock (default from Basys3)
    input  logic        btnC,    // Reset
    inout  wire         PS2Clk,
    inout  wire         PS2Data,
    output logic [15:0] led,
    output logic [ 3:0] an,
    output logic [ 6:0] seg,
    output logic        dp
);

  logic [7:0] rx_data;
  logic       read_data;

  logic [511:0] keys_pressed;
  logic         key_make_strobe;
  logic [  8:0] key_code;

  keyboard_decoder u_kbd_dec (
      .clk(clk),
      .rst_n(~btnC),
      .ps2_clk(PS2Clk),
      .ps2_data(PS2Data),
      .keys_pressed(keys_pressed),
      .key_make_strobe(key_make_strobe),
      .key_code(key_code),
      .dbg_rx_data(rx_data),
      .dbg_rx_valid(read_data)
  );

  logic cmd_up, cmd_down, cmd_left, cmd_right, cmd_enter, cmd_esc, cmd_backspace, char_valid;
  logic [7:0] char_ascii;
  logic shift_held;
  assign shift_held = keys_pressed[8'h12] | keys_pressed[8'h59];

  keyboard_controller u_kbd_ctrl (
      .clk(clk),
      .rst_n(~btnC),
      .key_make_strobe(key_make_strobe),
      .key_code(key_code),
      .shift_held(shift_held),
      .mode_text(1'b1), // Force text mode to see ASCII
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

  // --- 1. LEDs: Raw PS/2 Bytes History ---
  logic [15:0] history = 0;

  always_ff @(posedge clk) begin
    if (btnC) begin
      history <= 16'h0000;
    end else if (read_data) begin
      history <= {history[7:0], rx_data};
    end
  end
  assign led = history;

  // --- 2. 7-Segment: Decoded Key Info ---
  logic [15:0] display_data;
  logic [ 7:0] sseg_out;

  always_ff @(posedge clk) begin
    if (btnC) begin
      display_data <= 16'h0000;
    end else begin
      if (key_make_strobe) begin
        // Left half: Raw keycode ID
        display_data[15:8] <= key_code[7:0];
      end

      if (char_valid) begin
        // Right half: Decoded ASCII
        display_data[7:0] <= char_ascii;
      end else if (cmd_up) begin
        display_data[7:0] <= 8'hAA; // Custom ID for Up
      end else if (cmd_down) begin
        display_data[7:0] <= 8'hBB; // Custom ID for Down
      end else if (cmd_left) begin
        display_data[7:0] <= 8'hCC; // Custom ID for Left
      end else if (cmd_right) begin
        display_data[7:0] <= 8'hDD; // Custom ID for Right
      end else if (cmd_enter) begin
        display_data[7:0] <= 8'hEE; // Custom ID for Enter
      end else if (cmd_esc) begin
        display_data[7:0] <= 8'hFF; // Custom ID for Esc
      end else if (cmd_backspace) begin
        display_data[7:0] <= 8'h88; // Custom ID for Backspace
      end
    end
  end

  disp_hex_mux u_disp (
      .clk  (clk),
      .reset(btnC),
      .hex3 (display_data[15:12]),
      .hex2 (display_data[11:8]),
      .hex1 (display_data[7:4]),
      .hex0 (display_data[3:0]),
      .dp_in(4'b1111), // All decimal points off
      .an   (an),
      .sseg (sseg_out)
  );

  assign seg[0] = sseg_out[6];
  assign seg[1] = sseg_out[5];
  assign seg[2] = sseg_out[4];
  assign seg[3] = sseg_out[3];
  assign seg[4] = sseg_out[2];
  assign seg[5] = sseg_out[1];
  assign seg[6] = sseg_out[0];
  assign dp     = sseg_out[7];

endmodule
