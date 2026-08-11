`timescale 1ns / 1ps

module evaluation_controller_tb;

  logic clk;
  logic rst_n;

  logic [511:0] keys_pressed;
  logic cmd_up, cmd_down, cmd_left, cmd_right, cmd_enter, cmd_esc;
  logic show_popup, is_btn_yes_selected;
  logic [3:0] ui_selected_item;
  logic       show_progress;

  // Clocks
  always #5 clk = ~clk;

  keyboard_controller u_kbd (
      .clk(clk),
      .rst_n(rst_n),
      .keys_pressed(keys_pressed),
      .mode_text(1'b0),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc)
  );

  evaluation_controller u_eval (
      .clk(clk),
      .rst_n(rst_n),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .show_popup(show_popup),
      .ui_selected_item(ui_selected_item),
      .is_popup_btn_selected(is_btn_yes_selected),
      .progress_val(),
      .show_progress(show_progress)
  );

  task press_key(int key_code);
    keys_pressed[key_code] = 1'b1;
    #20;
    keys_pressed[key_code] = 1'b0;
    #20;
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    keys_pressed = '0;
    #20 rst_n = 1;

    // 1. Check basic navigation (Down then Up to Input)
    press_key('h172);  // Down
    #20;
    if (ui_selected_item != 4'd4) $error("Failed to navigate Down");

    press_key('h175);  // Up
    #20;
    if (ui_selected_item != 4'd1) $error("Failed to navigate Up back to Input");

    // 2. Navigate to About Button (Right Arrow)
    press_key('h174);  // Right
    #20;
    if (ui_selected_item != 4'd2) $error("Failed to navigate to About Button");

    // 3. Open popup
    press_key('h05A);  // Enter
    #20;
    if (!show_popup) $error("Popup should be visible!");

    // 4. Close popup
    press_key('h05A);  // Enter
    #20;
    if (show_popup) $error("Popup should be hidden!");

    $finish;
  end
endmodule
