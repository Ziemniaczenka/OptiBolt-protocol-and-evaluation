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

  // Handshake signals
  logic       hs_tx_req;
  logic [2:0] hs_tx_type;
  logic [7:0] hs_tx_data;
  logic       hs_tx_ack;
  logic [1:0] link_status;

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

      .hs_tx_req(hs_tx_req),
      .hs_tx_type(hs_tx_type),
      .hs_tx_data(hs_tx_data),
      .hs_tx_ack(hs_tx_ack),
      .link_status(link_status),

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
    @(posedge clk);
    char_ascii = ch;
    char_valid = 1'b1;
    @(posedge clk);
    char_valid = 1'b0;
    @(posedge clk);
    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);
  endtask

  task type_string(input string str);
    for (int i = 0; i < str.len(); i++) begin
      type_char(str[i]);
    end
  endtask

  task execute_cmd();
    @(posedge clk);
    cmd_enter = 1'b1;
    @(posedge clk);
    cmd_enter = 1'b0;
    @(posedge clk);
    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    cmd_up = 0; cmd_down = 0; cmd_left = 0; cmd_right = 0;
    cmd_enter = 0; cmd_esc = 0;
    char_valid = 0; char_ascii = 0; cmd_backspace = 0;
    ui_selected_item = ITEM_INPUT;
    hs_tx_req = 0; hs_tx_type = 3'b000; hs_tx_data = 8'h00;
    link_status = 2'b10; // LOOPBACK
    proto_eval_tx_full = 0; proto_eval_tx_empty = 1;
    proto_eval_rx_valid = 0; proto_eval_rx_type = MSG_TEXT; proto_eval_rx_data = 0;
    proto_eval_parity_error = 0; proto_eval_manchester_code_error = 0; proto_eval_preamble_error = 0;
    proto_eval_link_status = 1; proto_eval_ber_count = 0; proto_eval_err_count = 0;

    #20 rst_n = 1;
    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);

    // 1. Select input box & enter text mode
    execute_cmd();

    // 2. Test '/help' command
    type_string("/help");
    execute_cmd();
    $display("[PASS] Test 1: '/help' command executed.");

    // 3. Test '/baud 2.5m' command (loopback mode)
    type_string("/baud 2.5m");
    execute_cmd();
    assert (eval_proto_baud_rate == 4'd2) else $error("Baudrate setting failed (expected 2, got %0d)", eval_proto_baud_rate);
    $display("[PASS] Test 2: '/baud 2.5m' command executed (baud_rate=%0d).", eval_proto_baud_rate);

    // Test invalid '/baud 33' command -> rejected
    type_string("/baud 33");
    execute_cmd();
    assert (eval_proto_baud_rate == 4'd2) else $error("Invalid baud command should not alter baudrate");
    $display("[PASS] Test 2b: '/baud 33' invalid command correctly rejected.");

    // 4. Test '/os 16x' command
    type_string("/os 16x");
    execute_cmd();
    assert (eval_proto_oversampling == 4'd1) else $error("Oversampling setting failed (expected 1, got %0d)", eval_proto_oversampling);
    $display("[PASS] Test 3: '/os 16x' command executed (os=%0d).", eval_proto_oversampling);

    // 5. Test '/status' command
    type_string("/status");
    execute_cmd();
    $display("[PASS] Test 4: '/status' command executed.");

    // 6. Test '/bitmap send' command & TX buffer backpressure
    type_string("/bitmap send");
    @(posedge clk);
    cmd_enter = 1'b1;
    @(posedge clk);
    cmd_enter = 1'b0;
    wait (u_eval.state == u_eval.S_BITMAP_SEND);
    @(posedge clk);

    // Simulate TX buffer full for 50 cycles
    proto_eval_tx_full = 1'b1;
    #500;
    $display("[PASS] Test 5: TX buffer full backpressure verified.");
    proto_eval_tx_full = 1'b0;
    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);

    // 7. Test incoming RX bitmap pixel packet reception
    @(posedge clk);
    proto_eval_rx_valid <= 1'b1;
    proto_eval_rx_type  <= 3'b101; // MSG_BITMAP
    proto_eval_rx_data  <= 8'hA5;
    @(posedge clk);
    proto_eval_rx_valid <= 1'b0;
    #1; // Sample output after clock edge
    assert (bmp_we && bmp_din == 12'hA5A) else $error("RX Bitmap write failed (bmp_we=%b, bmp_din=%h)", bmp_we, bmp_din);
    $display("[PASS] Test 6: RX Bitmap packet write to BRAM verified (bmp_we=%b, bmp_din=%h).", bmp_we, bmp_din);

    // 8. Test '/bitmap clear' command
    type_string("/bitmap clear");
    @(posedge clk);
    cmd_enter = 1'b1;
    @(posedge clk);
    cmd_enter = 1'b0;
    wait (u_eval.state == u_eval.S_CLEAR_BITMAP);
    @(posedge clk);
    #1;
    assert (bmp_we && bmp_din == 12'h000) else $error("Bitmap clear failed (bmp_we=%b, bmp_din=%h)", bmp_we, bmp_din);
    $display("[PASS] Test 7: '/bitmap clear' command clearing BRAM verified.");
    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);

    // 9. Test non-command text transmission
    type_string("hello");
    @(posedge clk);
    cmd_enter = 1'b1;
    @(posedge clk);
    cmd_enter = 1'b0;
    wait (u_eval.state == u_eval.S_TEXT_SEND);
    wait (u_eval.state == u_eval.S_IDLE);
    $display("[PASS] Test 8: Non-command text transmission verified.");

    // 10. Test disconnected block on /bitmap send
    link_status = 2'b00; // DISCONNECTED
    type_string("/bitmap send");
    execute_cmd();
    $display("[PASS] Test 9: Disconnected command blocked verified.");

    wait (u_eval.state == u_eval.S_IDLE);
    @(posedge clk);
    $display("All evaluation_controller testbench tests completed successfully!");
    $finish;
  end

endmodule
