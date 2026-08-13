`timescale 1ns / 1ps

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module evaluation_controller_tb;

  logic clk;
  logic rst_n;

  // Keyboard / Command inputs
  logic cmd_up, cmd_down, cmd_left, cmd_right, cmd_enter, cmd_esc;
  logic char_valid, cmd_backspace;
  logic [7:0] char_ascii;

  // RAM Outputs
  logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr;
  logic console_we;
  logic [7:0] console_din;

  logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr;
  logic input_we;
  logic [7:0] input_din;

  logic [11:0] bmp_addr;
  logic bmp_we;
  logic [11:0] bmp_din;

  logic [3:0] ui_selected_item;
  logic mode_text, show_popup, show_progress;
  logic [7:0] progress_val;

  // Protocol Interface Signals
  logic [3:0] eval_proto_baud_rate;
  logic [3:0] eval_proto_oversampling;
  logic eval_proto_loopback_en;
  logic eval_proto_tx_valid;
  logic [2:0] eval_proto_tx_type;
  logic [7:0] eval_proto_tx_data;

  logic proto_eval_tx_full, proto_eval_tx_empty;
  logic proto_eval_rx_valid;
  logic [2:0] proto_eval_rx_type;
  logic [7:0] proto_eval_rx_data;
  logic proto_eval_parity_error, proto_eval_manchester_code_error, proto_eval_preamble_error;
  logic proto_eval_link_status;
  logic [31:0] proto_eval_ber_count;
  logic [15:0] proto_eval_err_count;

  // Clock generation (100MHz)
  always #5 clk = ~clk;

  evaluation_controller u_eval (
      .clk(clk),
      .rst_n(rst_n),
      .cmd_up(cmd_up),
      .cmd_down(cmd_down),
      .cmd_left(cmd_left),
      .cmd_right(cmd_right),
      .cmd_enter(cmd_enter),
      .cmd_esc(cmd_esc),
      .char_valid(char_valid),
      .char_ascii(char_ascii),
      .cmd_backspace(cmd_backspace),
      .console_addr(console_addr),
      .console_we(console_we),
      .console_din(console_din),
      .input_addr(input_addr),
      .input_we(input_we),
      .input_din(input_din),
      .bmp_addr(bmp_addr),
      .bmp_we(bmp_we),
      .bmp_din(bmp_din),
      .ui_selected_item(ui_selected_item),
      .mode_text(mode_text),
      .show_popup(show_popup),
      .show_progress(show_progress),
      .progress_val(progress_val),

      .eval_proto_baud_rate(eval_proto_baud_rate),
      .eval_proto_oversampling(eval_proto_oversampling),
      .eval_proto_loopback_en(eval_proto_loopback_en),
      .eval_proto_tx_valid(eval_proto_tx_valid),
      .eval_proto_tx_type(eval_proto_tx_type),
      .eval_proto_tx_data(eval_proto_tx_data),
      .proto_eval_tx_full(proto_eval_tx_full),
      .proto_eval_tx_empty(proto_eval_tx_empty),
      .proto_eval_rx_valid(proto_eval_rx_valid),
      .proto_eval_rx_type(proto_eval_rx_type),
      .proto_eval_rx_data(proto_eval_rx_data),
      .proto_eval_parity_error(proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error(proto_eval_preamble_error),
      .proto_eval_link_status(proto_eval_link_status),
      .proto_eval_ber_count(proto_eval_ber_count),
      .proto_eval_err_count(proto_eval_err_count)
  );

  task type_char(input [7:0] ch);
    char_ascii = ch;
    char_valid = 1'b1;
    #10;
    char_valid = 1'b0;
    #10;
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    cmd_up = 0; cmd_down = 0; cmd_left = 0; cmd_right = 0;
    cmd_enter = 0; cmd_esc = 0;
    char_valid = 0; char_ascii = 0; cmd_backspace = 0;
    ui_selected_item = ITEM_INPUT;
    proto_eval_tx_full = 0; proto_eval_tx_empty = 1;
    proto_eval_rx_valid = 0; proto_eval_rx_type = MSG_TEXT; proto_eval_rx_data = 0;
    proto_eval_parity_error = 0; proto_eval_manchester_code_error = 0; proto_eval_preamble_error = 0;
    proto_eval_link_status = 1; proto_eval_ber_count = 0; proto_eval_err_count = 0;

    #20 rst_n = 1;
    #20;

    // 1. Select input box & enter text mode
    cmd_enter = 1;
    #10;
    cmd_enter = 0;
    #20;

    // 2. Type 'h' 'e' 'l' 'p'
    type_char("h");
    type_char("e");
    type_char("l");
    type_char("p");

    // 3. Press Enter to process command
    cmd_enter = 1;
    #10;
    cmd_enter = 0;

    // Wait for BRAM update sweep
    #11000;

    $display("Test evaluation_controller completed successfully!");
    $finish;
  end

endmodule

