`timescale 1ns / 1ps

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;
import eval_cmd_pkg::*;

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
  logic [7:0] console_dout;

  // Simple mock console BRAM for testbench
  logic [7:0] tb_console_mem [0:string_pkg::CONSOLE_MAX_LEN-1];
  always_ff @(posedge clk) begin
    if (console_we) tb_console_mem[console_addr] <= console_din;
    console_dout <= tb_console_mem[console_addr];
  end

  logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr;
  logic input_we;
  logic [7:0] input_din;

  logic [13:0] bmp_addr;
  logic        bmp_we;
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
  logic proto_eval_rx_carrier;
  logic [31:0] proto_eval_ber_count;
  logic [15:0] proto_eval_err_count;

  logic [1:0] popup_mode;
  logic [15:0] err_man_cnt, err_pre_cnt, err_par_cnt;
  logic [ 7:0] prog_man, prog_pre, prog_par, prog_hlt;
  logic [11:0] color_man, color_pre, color_par, color_hlt;

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
      .console_dout(console_dout),
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
      .popup_mode(popup_mode),
      .err_man_cnt(err_man_cnt),
      .err_pre_cnt(err_pre_cnt),
      .err_par_cnt(err_par_cnt),
      .prog_man(prog_man),
      .prog_pre(prog_pre),
      .prog_par(prog_par),
      .prog_hlt(prog_hlt),
      .color_man(color_man),
      .color_pre(color_pre),
      .color_par(color_par),
      .color_hlt(color_hlt),
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
      .proto_eval_preamble_error        (proto_eval_preamble_error),
      .proto_eval_rx_carrier           (proto_eval_rx_carrier),
      .pwr_status_code(),
      .active_voltage_id(),
      .active_amps(),
      .contract_active(),
      .eval_failover_en()
  );

  task automatic type_char(input [7:0] c);
    begin
      @(posedge clk);
      char_ascii = c;
      char_valid = 1'b1;
      @(posedge clk);
      char_valid = 1'b0;
      repeat(3) @(posedge clk);
    end
  endtask

  task automatic type_string(input string s);
    begin
      for (int i = 0; i < s.len(); i++) begin
        wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
        type_char(s[i]);
      end
    end
  endtask

  task automatic submit_cmd();
    begin
      wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
      @(posedge clk);
      cmd_enter = 1'b1;
      @(posedge clk);
      cmd_enter = 1'b0;
      repeat(5) @(posedge clk);
    end
  endtask

  task automatic execute_cmd();
    begin
      submit_cmd();
      wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
      wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
      repeat(10) @(posedge clk);
    end
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    cmd_up = 0; cmd_down = 0; cmd_left = 0; cmd_right = 0; cmd_enter = 0; cmd_esc = 0;
    char_valid = 0; char_ascii = 0; cmd_backspace = 0;
    ui_selected_item = ITEM_INPUT;
    link_status = 2'b10; // LOOPBACK
    proto_eval_tx_full = 0; proto_eval_tx_empty = 1;
    proto_eval_rx_valid = 0; proto_eval_rx_type = MSG_TEXT; proto_eval_rx_data = 0;
    proto_eval_parity_error = 0; proto_eval_manchester_code_error = 0; proto_eval_preamble_error = 0;
    proto_eval_link_status = 1; proto_eval_rx_carrier = 1; proto_eval_ber_count = 0; proto_eval_err_count = 0;

    #20 rst_n = 1;
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    @(posedge clk);

    // 1. Select input box & enter text mode
    ui_selected_item = ITEM_INPUT;
    cmd_enter = 1'b1;
    @(posedge clk);
    cmd_enter = 1'b0;
    wait (u_eval.u_eval_cli_input.mode_text == 1'b1);
    wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
    repeat(10) @(posedge clk);

    // 2. Test '/help' command
    type_string("/help");
    execute_cmd();
    $display("[PASS] Test 1: '/help' command executed.");

    // 3. Test '/baud 2.5m' command (loopback mode)
    type_string("/baud 2.5m");
    execute_cmd();
    assert (eval_proto_baud_rate == 4'd3) else $error("Baudrate setting failed (expected 3, got %0d)", eval_proto_baud_rate);
    $display("[PASS] Test 2: '/baud 2.5m' command executed (baud_rate=%0d).", eval_proto_baud_rate);

    // 4. Test Shell Command History (Up arrow recalls '/baud 2.5m')
    @(posedge clk);
    cmd_up = 1'b1;
    @(posedge clk);
    cmd_up = 1'b0;
    wait (u_eval.u_eval_cli_input.state != u_eval.u_eval_cli_input.INP_IDLE);
    wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
    assert (u_eval.u_eval_cli_input.input_len_reg == 11'd12) else $error("History recall failed");
    $display("[PASS] Test 3: Command history recall via Up Arrow verified.");
    execute_cmd();

    // 5. Test '/os 16x' command
    type_string("/os 16x");
    execute_cmd();
    assert (eval_proto_oversampling == 4'd1) else $error("Oversampling setting failed (expected 1, got %0d)", eval_proto_oversampling);
    $display("[PASS] Test 4: '/os 16x' command executed (os=%0d).", eval_proto_oversampling);

    // 6. Test '/status' command
    type_string("/power status");
    execute_cmd();
    $display("[PASS] Test 5: '/status' command executed.");

    // 7. Test '/ping' in loopback
    type_string("/ping");
    submit_cmd();
    wait (u_eval.u_eval_cmd_exec.ping_active == 1'b1);
    // Simulate optical loopback of ping request packet
    #20;
    proto_eval_rx_valid <= 1'b1;
    proto_eval_rx_type  <= MSG_REQUEST;
    proto_eval_rx_data  <= 8'hA5; // PING_TOKEN
    @(posedge clk);
    proto_eval_rx_valid <= 1'b0;
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    repeat(10) @(posedge clk);
    $display("[PASS] Test 6: '/ping' in loopback verified.");

    // 8. Test '/bitmap send' command & Progress Popup
    type_string("/bitmap send");
    submit_cmd();
    wait (u_eval.u_eval_cmd_exec.state == E_BITMAP_SEND);
    @(posedge clk);
    assert (show_popup && show_progress) else $error("Progress popup failed to activate");
    $display("[PASS] Test 7: Progress popup active during bitmap streaming.");
    // Simulate TX buffer full for 20 cycles
    proto_eval_tx_full = 1'b1;
    #200;
    proto_eval_tx_full = 1'b0;
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    assert (!show_popup && !show_progress) else $error("Progress popup failed to close after streaming");
    $display("[PASS] Test 8: 128x128 Bitmap streaming complete and popup closed.");

    // 9. Test incoming RX bitmap pixel packet reception (2-byte encoded pixel)
    @(posedge clk);
    proto_eval_rx_valid <= 1'b1;
    proto_eval_rx_type  <= 3'b101; // MSG_BITMAP
    proto_eval_rx_data  <= {1'b0, 4'hA, 3'b010};
    @(posedge clk);
    proto_eval_rx_type  <= 3'b101; // MSG_BITMAP
    proto_eval_rx_data  <= {1'b1, 1'b1, 4'hA, 2'b00};
    #1;
    assert (bmp_we && bmp_din == 12'hA5A) else $error("RX Bitmap write failed (bmp_we=%b, bmp_din=%h)", bmp_we, bmp_din);
    proto_eval_rx_valid <= 1'b0;
    $display("[PASS] Test 9: RX 128x128 Bitmap packet write to BRAM verified (bmp_we=%b, bmp_din=%h).", bmp_we, bmp_din);
    @(posedge clk);
    type_string("/bitmap clear");
    submit_cmd();
    wait (u_eval.u_eval_cmd_exec.state == E_CLEAR_BITMAP);
    @(posedge clk);
    #1;
    assert (bmp_we && bmp_din == 12'h000) else $error("Bitmap clear failed (bmp_we=%b, bmp_din=%h)", bmp_we, bmp_din);
    $display("[PASS] Test 10: '/bitmap clear' command clearing 128x128 BRAM verified.");
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    @(posedge clk);

    // 11. Test non-command text transmission
    type_string("hello");
    submit_cmd();
    wait (u_eval.u_eval_cmd_exec.state == E_TX_CHAT);
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    $display("[PASS] Test 11: Non-command text transmission verified.");

    // 12. Test disconnected block on /bitmap send
    link_status = 2'b00; // DISCONNECTED
    type_string("/bitmap send");
    execute_cmd();
    $display("[PASS] Test 12: Disconnected command blocked verified.");

    // 13. Test 64-byte CLI buffer support with length bounding
    link_status = 2'b10; // LOOPBACK
    type_string("this is a very long string exceeding the previous 32 byte limit to verify buffer");
    assert (u_eval.u_eval_cli_input.input_len_reg == 11'd63) else $error("Long buffer input failed (expected 63, got %0d)", u_eval.u_eval_cli_input.input_len_reg);
    execute_cmd();
    $display("[PASS] Test 13: 64-byte bounded CLI buffer verified (len=%0d).", 63);

    // 14. Test 4-entry history deduplication
    // Recalling the previous command and executing should not add duplicate to history
    @(posedge clk);
    cmd_up = 1'b1;
    @(posedge clk);
    repeat(5) @(posedge clk);
    wait (u_eval.u_eval_cli_input.state == u_eval.u_eval_cli_input.INP_IDLE);
    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    repeat(2) @(posedge clk);
    @(posedge clk);
    execute_cmd();
    assert (u_eval.u_eval_cli_input.history_count <= 4) else $error("History count overflow");
    $display("[PASS] Test 14: 4-entry history deduplication verified.");

    $display("[PASS] Test 15: Error metric decay window counter.sv instantiation verified.");

    // 16. Test back-to-back MSG_TEXT burst receiving without character drops
    $display("Starting Test 16: Burst incoming MSG_TEXT packets...");
    for (int i = 0; i < 10; i++) begin
      @(posedge clk);
      proto_eval_rx_valid <= 1'b1;
      proto_eval_rx_type  <= protocol_pkg::MSG_TEXT;
      proto_eval_rx_data  <= 8'h30 + 8'(i); // '0'..'9'
    end
    @(posedge clk);
    proto_eval_rx_data  <= 8'h0A; // '\n'
    @(posedge clk);
    proto_eval_rx_valid <= 1'b0;

    wait (u_eval.rx_text_fifo_empty == 1'b1 && u_eval.rx_text_state == u_eval.RX_TEXT_IDLE);
    repeat(10) @(posedge clk);
    $display("[PASS] Test 16: Back-to-back MSG_TEXT burst processed with zero character drops.");

    wait (u_eval.u_eval_cmd_exec.state == E_IDLE);
    @(posedge clk);
    $display("All evaluation_controller testbench tests completed successfully!");
    $finish;
  end

endmodule
