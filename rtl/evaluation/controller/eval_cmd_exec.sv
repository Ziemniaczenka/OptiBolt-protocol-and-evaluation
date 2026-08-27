/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Dedicated Command Parser & Execution Engine submodule.
 * Parses CLI slash commands, controls UI popups & progress, manages 128x128 PRNG
 * dynamic bitmap streaming, executes sequential Ping RTT Double-Dabble formatting,
 * runs the 11-step Baudrate sweep test, and streams formatted text to the console buffer.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module eval_cmd_exec #(
    parameter int CLI_BUF_LEN = 128
) (
    input  logic        clk,
    input  logic        rst_n,

    // Command packet input from eval_cli_input
    input  logic        cmd_valid,
    input  logic [7:0]  cmd_buf [0:CLI_BUF_LEN-1],
    input  logic [10:0] cmd_len,

    // CLI text echo stream from eval_cli_input
    input  logic        echo_req,
    input  logic [7:0]  echo_buf [0:CLI_BUF_LEN-1],
    input  logic [10:0] echo_len,
    output logic        echo_ack,

    // Console print stream output to eval_console_buffer
    output logic        print_valid,
    output logic [7:0]  print_char,
    output logic        print_last,
    input  logic        print_ready,

    // Clear console control to eval_console_buffer
    output logic        clear_console_req,
    input  logic        clear_console_ack,

    // Dynamic Bitmap RAM interface
    output logic [13:0] bmp_addr,
    output logic        bmp_we,
    output logic [11:0] bmp_din,

    // UI Popups & Progress
    output logic        show_popup,
    output logic        show_progress,
    output logic [ 7:0] progress_val,
    output logic [ 1:0] popup_mode,

    // Link manager control & telemetry
    output logic        set_speed_req,
    output logic [ 3:0] req_baud_rate,
    output logic [ 3:0] req_oversampling,
    output logic        failover_en,
    input  logic        failover_triggered,
    input  logic [ 1:0] link_status,
    input  logic        rx_carrier,

    // OptiBolt packet TX interface
    output logic        proto_tx_valid,
    output logic [ 2:0] proto_tx_type,
    output logic [ 7:0] proto_tx_data,
    input  logic        proto_tx_full,

    // OptiBolt packet RX interface
    input  logic        proto_rx_valid,
    input  logic [ 2:0] proto_rx_type,
    input  logic [ 7:0] proto_rx_data
);

  localparam logic [2:0] MSG_BITMAP = 3'b101; // Map bitmap to MSG_TEST1 (3'b101)
  localparam logic [7:0] PING_TOKEN = 8'hA5;
  localparam logic [7:0] PING_REPLY = 8'h5A;

  // ROM Messages
  localparam logic [7:0] HELP_BYTES [0:217] = '{
    "/", "h", "e", "l", "p", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "S",
    "h", "o", "w", " ", "h", "e", "l", "p", "\n", "/", "s", "t", "a", "t", "u", "s",
    " ", " ", " ", " ", " ", ":", " ", "L", "i", "n", "k", " ", "h", "e", "a", "l",
    "t", "h", "\n", "/", "p", "i", "n", "g", " ", " ", " ", " ", " ", " ", ":", " ",
    "T", "e", "s", "t", " ", "R", "T", "T", "\n", "/", "t", "e", "s", "t", " ", "s",
    "w", "e", "e", "p", " ", ":", " ", "T", "e", "s", "t", " ", "b", "a", "u", "d",
    " ", "c", "o", "n", "f", "i", "g", "s", "\n", "/", "b", "i", "t", "m", "a", "p",
    " ", "s", "e", "n", "d", " ", ":", " ", "S", "t", "r", "e", "a", "m", " ", "B",
    "M", "P", "\n", "/", "b", "i", "t", "m", "a", "p", " ", "c", "l", "e", "a", "r",
    " ", ":", " ", "C", "l", "e", "a", "r", " ", "B", "M", "P", "\n", "/", "f", "a",
    "i", "l", "o", "v", "e", "r", " ", "o", "n", "/", "o", "f", "f", " ", ":", " ",
    "F", "a", "i", "l", "o", "v", "e", "r", " ", "m", "o", "d", "e", "\n", "/", "c",
    "l", "e", "a", "r", " ", " ", " ", " ", " ", " ", ":", " ", "C", "l", "e", "a",
    "r", " ", "c", "o", "n", "s", "o", "l", "e", "\n"
  };

  localparam logic [7:0] STATUS_DISCONN_BYTES [0:22] = '{
    "L", "i", "n", "k", ":", " ", "D", "I", "S", "C", "O", "N", "N", "E", "C", "T", "E", "D", " ", "(", "0", ")", "\n"
  };
  localparam logic [7:0] STATUS_CONN_BYTES [0:19] = '{
    "L", "i", "n", "k", ":", " ", "C", "O", "N", "N", "E", "C", "T", "E", "D", " ", "(", "1", ")", "\n"
  };
  localparam logic [7:0] STATUS_LOOP_BYTES [0:18] = '{
    "L", "i", "n", "k", ":", " ", "L", "O", "O", "P", "B", "A", "C", "K", " ", "(", "2", ")", "\n"
  };
  localparam logic [7:0] BAUD_SET_BYTES [0:16] = '{
    "B", "a", "u", "d", "r", "a", "t", "e", " ", "u", "p", "d", "a", "t", "e", "d", "\n"
  };
  localparam logic [7:0] FAILOVER_ON_BYTES [0:20] = '{
    "F", "a", "i", "l", "o", "v", "e", "r", " ", "e", "n", "a", "b", "l", "e", "d", " ", "(", "1", ")", "\n"
  };
  localparam logic [7:0] FAILOVER_OFF_BYTES [0:21] = '{
    "F", "a", "i", "l", "o", "v", "e", "r", " ", "d", "i", "s", "a", "b", "l", "e", "d", " ", "(", "0", ")", "\n"
  };
  localparam logic [7:0] FAILOVER_ALERT_BYTES [0:46] = '{
    "A", "L", "E", "R", "T", ":", " ", "F", "a", "i", "l", "o", "v", "e", "r", " ", "t", "r", "i", "g",
    "g", "e", "r", "e", "d", "!", " ", "S", "p", "e", "e", "d", " ", "d", "r", "o", "p", "p", "e", "d",
    " ", "t", "o", " ", "1", "M", "\n"
  };
  localparam logic [7:0] UNKNOWN_CMD_BYTES [0:15] = '{
    "U", "n", "k", "n", "o", "w", "n", " ", "c", "o", "m", "m", "a", "n", "d", "\n"
  };
  localparam logic [7:0] ERR_DISCONN_BYTES [0:24] = '{
    "E", "r", "r", "o", "r", ":", " ", "L", "i", "n", "k", " ", "d", "i", "s", "c", "o", "n", "n", "e", "c", "t", "e", "d", "\n"
  };
  localparam logic [7:0] PING_START_BYTES [0:15] = '{
    "S", "e", "n", "d", "i", "n", "g", " ", "p", "i", "n", "g", ".", ".", ".", "\n"
  };
  localparam logic [7:0] SWEEP_START_BYTES [0:26] = '{
    "S", "t", "a", "r", "t", "i", "n", "g", " ", "b", "a", "u", "d", "r", "a", "t", "e", " ", "s", "w", "e", "e", "p", ".", ".", ".", "\n"
  };
  localparam logic [7:0] SWEEP_DONE_BYTES [0:20] = '{
    "B", "a", "u", "d", " ", "s", "w", "e", "e", "p", " ", "c", "o", "m", "p", "l", "e", "t", "e", ".", "\n"
  };

  localparam logic [7:0] SWEEP_PASS_STR[0:10][0:20] = '{
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "3", ".", "1", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "3", ".", "1", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "5", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "6", ".", "2", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "8", ".", "3", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "2", "5", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"}
  };

  localparam logic [7:0] SWEEP_FAIL_STR[0:10][0:25] = '{
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "3", ".", "1", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "3", ".", "1", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "5", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "6", ".", "2", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", " ", "8", ".", "3", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "},
    '{" ", "2", "5", ".", "0", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n", " ", " "}
  };

  localparam logic [3:0] SWEEP_BAUD[0:10] = '{4'd0, 4'd1, 4'd1, 4'd2, 4'd3, 4'd3, 4'd4, 4'd5, 4'd5, 4'd6, 4'd7};
  localparam logic [3:0] SWEEP_OS[0:10]   = '{4'd0, 4'd0, 4'd1, 4'd0, 4'd0, 4'd1, 4'd0, 4'd1, 4'd0, 4'd0, 4'd0};

  typedef enum logic [4:0] {
    SRC_NONE,
    SRC_ECHO,
    SRC_HELP,
    SRC_STATUS_DISCONN,
    SRC_STATUS_CONN,
    SRC_STATUS_LOOP,
    SRC_BAUD_SET,
    SRC_FAILOVER_ON,
    SRC_FAILOVER_OFF,
    SRC_FAILOVER_ALERT,
    SRC_UNKNOWN,
    SRC_ERR_DISCONN,
    SRC_PING_START,
    SRC_PING_MSG,
    SRC_SWEEP_START,
    SRC_SWEEP_PASS,
    SRC_SWEEP_FAIL,
    SRC_SWEEP_DONE
  } msg_src_t;

  typedef enum logic [3:0] {
    E_IDLE,
    E_PARSE_CMD,
    E_STREAM_MSG,
    E_PING_CONVERT,
    E_PING_FMT_STEP,
    E_SWEEP_STEP,
    E_SWEEP_WAIT,
    E_BITMAP_SEND,
    E_CLEAR_BITMAP
  } exec_state_t;

  exec_state_t state;
  msg_src_t    msg_src;

  logic [10:0] msg_idx;
  logic [10:0] msg_len;
  logic [ 7:0] current_msg_char;
  logic        pending_cmd;

  // Dynamic Bitmap Streaming
  logic [14:0] tx_pixel_cnt;
  logic [13:0] clear_bmp_idx;
  logic        prng_next_pixel;
  logic [11:0] prng_pixel_rgb;
  logic [ 7:0] prng_pixel_byte;

  pixel_prng u_pixel_prng (
      .clk        (clk),
      .rst_n      (rst_n),
      .next_pixel (prng_next_pixel),
      .pixel_rgb  (prng_pixel_rgb),
      .pixel_byte (prng_pixel_byte)
  );

  // Ping test registers
  logic        ping_active;
  logic [31:0] ping_timer;
  logic [31:0] ping_rtt_cycles;
  logic        ping_is_loopback;
  logic [ 7:0] ping_msg_buf [0:63];

  // BCD conversion registers
  logic [31:0] bcd_reg;
  logic [31:0] bin_reg;
  logic [ 5:0] bcd_cnt;
  logic [ 3:0] bcd_d [0:7];

  // Sequential Ping formatter registers
  logic [ 5:0] fmt_ptr;
  logic [ 2:0] fmt_phase;
  logic [ 3:0] fmt_digit_idx;
  logic [ 4:0] fmt_text_idx;
  logic        fmt_lead_zero;

  // Sweep registers
  logic [ 3:0] sweep_step;
  logic [31:0] sweep_timer;
  logic        sweep_step_passed;
  logic        sweep_active;

  // Message multiplexer
  always_comb begin
    case (msg_src)
      SRC_ECHO:           current_msg_char = (msg_idx == echo_len - 11'd1) ? 8'h0A : echo_buf[msg_idx];
      SRC_HELP:           current_msg_char = HELP_BYTES[msg_idx];
      SRC_STATUS_DISCONN: current_msg_char = STATUS_DISCONN_BYTES[msg_idx];
      SRC_STATUS_CONN:    current_msg_char = STATUS_CONN_BYTES[msg_idx];
      SRC_STATUS_LOOP:    current_msg_char = STATUS_LOOP_BYTES[msg_idx];
      SRC_BAUD_SET:       current_msg_char = BAUD_SET_BYTES[msg_idx];
      SRC_FAILOVER_ON:    current_msg_char = FAILOVER_ON_BYTES[msg_idx];
      SRC_FAILOVER_OFF:   current_msg_char = FAILOVER_OFF_BYTES[msg_idx];
      SRC_FAILOVER_ALERT: current_msg_char = FAILOVER_ALERT_BYTES[msg_idx];
      SRC_UNKNOWN:        current_msg_char = UNKNOWN_CMD_BYTES[msg_idx];
      SRC_ERR_DISCONN:    current_msg_char = ERR_DISCONN_BYTES[msg_idx];
      SRC_PING_START:     current_msg_char = PING_START_BYTES[msg_idx];
      SRC_PING_MSG:       current_msg_char = ping_msg_buf[msg_idx];
      SRC_SWEEP_START:    current_msg_char = SWEEP_START_BYTES[msg_idx];
      SRC_SWEEP_PASS:     current_msg_char = SWEEP_PASS_STR[sweep_step][msg_idx];
      SRC_SWEEP_FAIL:     current_msg_char = SWEEP_FAIL_STR[sweep_step][msg_idx];
      SRC_SWEEP_DONE:     current_msg_char = SWEEP_DONE_BYTES[msg_idx];
      default:            current_msg_char = 8'h00;
    endcase
  end

  // Command Execution State Machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= E_IDLE;
      msg_src           <= SRC_NONE;
      msg_idx           <= '0;
      msg_len           <= '0;
      pending_cmd       <= 1'b0;
      print_valid       <= 1'b0;
      print_char        <= 8'h00;
      print_last        <= 1'b0;
      echo_ack          <= 1'b0;
      clear_console_req <= 1'b0;
      show_popup        <= 1'b0;
      show_progress     <= 1'b0;
      progress_val      <= '0;
      popup_mode        <= POPUP_NONE;
      set_speed_req     <= 1'b0;
      req_baud_rate     <= 4'd1;
      req_oversampling  <= 4'd0;
      failover_en       <= 1'b1; // Failover enabled by default
      proto_tx_valid    <= 1'b0;
      proto_tx_type     <= 3'b000;
      proto_tx_data     <= 8'h00;
      bmp_addr          <= '0;
      bmp_we            <= 1'b0;
      bmp_din           <= '0;
      tx_pixel_cnt      <= '0;
      clear_bmp_idx     <= '0;
      prng_next_pixel   <= 1'b0;
      ping_active       <= 1'b0;
      ping_timer        <= '0;
      ping_rtt_cycles   <= '0;
      ping_is_loopback  <= 1'b0;
      bcd_reg           <= '0;
      bin_reg           <= '0;
      bcd_cnt           <= '0;
      fmt_ptr           <= '0;
      fmt_phase         <= '0;
      fmt_digit_idx     <= '0;
      fmt_text_idx      <= '0;
      fmt_lead_zero     <= 1'b1;
      sweep_step        <= '0;
      sweep_timer       <= '0;
      sweep_step_passed <= 1'b0;
      sweep_active      <= 1'b0;
      for (int i = 0; i < 8; i++) bcd_d[i] <= 4'd0;
      for (int i = 0; i < 64; i++) ping_msg_buf[i] <= 8'h00;
    end else begin
      set_speed_req     <= 1'b0;
      clear_console_req <= 1'b0;
      echo_ack          <= 1'b0;
      bmp_we            <= 1'b0;
      prng_next_pixel   <= 1'b0;
      proto_tx_valid    <= 1'b0;

      // Ping timer & timeout monitor
      if (ping_active) begin
        ping_timer <= ping_timer + 32'd1;
        if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == PING_TOKEN) begin
          proto_tx_valid <= 1'b1;
          proto_tx_type  <= MSG_REQUEST;
          proto_tx_data  <= PING_REPLY;
        end
        if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == PING_REPLY) begin
          ping_active      <= 1'b0;
          ping_rtt_cycles  <= ping_timer;
          ping_is_loopback <= (link_status == 2'b10);
          bin_reg          <= ping_timer;
          bcd_reg          <= '0;
          bcd_cnt          <= 6'd32;
          state            <= E_PING_CONVERT;
        end else if (ping_timer >= 32'd10_000_000) begin // 100ms timeout
          ping_active      <= 1'b0;
          ping_rtt_cycles  <= 32'd0;
          ping_is_loopback <= 1'b0;
          bin_reg          <= 32'd0;
          bcd_reg          <= '0;
          bcd_cnt          <= 6'd32;
          state            <= E_PING_CONVERT;
        end
      end

      // Automatic failover alert notification
      if (failover_triggered && state == E_IDLE && failover_en && !print_valid) begin
        msg_src <= SRC_FAILOVER_ALERT;
        msg_idx <= '0;
        msg_len <= 11'd47;
        state   <= E_STREAM_MSG;
      end

      case (state)
        // -------------------------------------------------------------------
        // Idle: check CLI echo requests and parsed commands
        // -------------------------------------------------------------------
        E_IDLE: begin
          if (echo_req) begin
            msg_src     <= SRC_ECHO;
            msg_idx     <= '0;
            msg_len     <= echo_len;
            echo_ack    <= 1'b1;
            pending_cmd <= cmd_valid;
            state       <= E_STREAM_MSG;
          end else if (cmd_valid || pending_cmd) begin
            pending_cmd <= 1'b0;
            state       <= E_PARSE_CMD;
          end
        end

        // -------------------------------------------------------------------
        // Parse and Execute Command
        // -------------------------------------------------------------------
        E_PARSE_CMD: begin
          msg_idx <= '0; // CRITICAL: Always reset msg_idx to 0!

          if (cmd_len >= 5 && cmd_buf[2]=="/" && cmd_buf[3]=="h" && cmd_buf[4]=="e") begin
            msg_src <= SRC_HELP; msg_len <= 11'd218; state <= E_STREAM_MSG;
          end else if (cmd_len >= 7 && cmd_buf[2]=="/" && cmd_buf[3]=="c" && cmd_buf[4]=="l" && cmd_buf[5]=="e" && cmd_buf[6]=="a") begin
            clear_console_req <= 1'b1;
            state <= E_IDLE;
          end else if (cmd_len >= 8 && cmd_buf[2]=="/" && cmd_buf[3]=="s" && cmd_buf[4]=="t" && cmd_buf[5]=="a" && cmd_buf[6]=="t") begin
            if (link_status == 2'b10) begin msg_src <= SRC_STATUS_LOOP; msg_len <= 11'd19; end
            else if (link_status == 2'b01) begin msg_src <= SRC_STATUS_CONN; msg_len <= 11'd20; end
            else begin msg_src <= SRC_STATUS_DISCONN; msg_len <= 11'd23; end
            state <= E_STREAM_MSG;
          end else if (cmd_len >= 6 && cmd_buf[2]=="/" && cmd_buf[3]=="p" && cmd_buf[4]=="i" && cmd_buf[5]=="n") begin
            if (link_status == 2'b00) begin
              msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
            end else begin
              ping_active <= 1'b1; ping_timer <= '0;
              proto_tx_valid <= 1'b1; proto_tx_type <= MSG_REQUEST; proto_tx_data <= PING_TOKEN;
              msg_src <= SRC_PING_START; msg_len <= 11'd16; state <= E_STREAM_MSG;
            end
          end else if (cmd_len >= 6 && cmd_buf[2]=="/" && cmd_buf[3]=="b" && cmd_buf[4]=="a" && cmd_buf[5]=="u") begin
            logic [3:0] target_rate, target_os;
            logic valid_rate;
            valid_rate = 1'b1; target_rate = 4'd1; target_os = 4'd0;

            if (cmd_buf[8]=="1" && cmd_buf[9]=="0" && cmd_buf[10]=="0") begin target_rate = 4'd0; target_os = 4'd0; end
            else if (cmd_buf[8]=="1" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) begin target_rate = 4'd1; target_os = 4'd0; end
            else if (cmd_buf[8]=="2" && cmd_buf[9]=="." && cmd_buf[10]=="5") begin target_rate = 4'd2; target_os = 4'd0; end
            else if (cmd_buf[8]=="3" && cmd_buf[9]=="." && cmd_buf[10]=="1") begin target_rate = 4'd3; target_os = 4'd0; end
            else if (cmd_buf[8]=="5" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) begin target_rate = 4'd4; target_os = 4'd0; end
            else if (cmd_buf[8]=="6" && cmd_buf[9]=="." && cmd_buf[10]=="2") begin target_rate = 4'd5; target_os = 4'd1; end
            else if (cmd_buf[8]=="8" && cmd_buf[9]=="." && cmd_buf[10]=="3") begin target_rate = 4'd5; target_os = 4'd0; end
            else if (cmd_buf[8]=="1" && cmd_buf[9]=="2") begin target_rate = 4'd6; target_os = 4'd0; end
            else if (cmd_buf[8]=="2" && cmd_buf[9]=="5") begin target_rate = 4'd7; target_os = 4'd0; end
            else valid_rate = 1'b0;

            if (valid_rate) begin
              req_baud_rate    <= target_rate;
              req_oversampling <= target_os;
              set_speed_req    <= 1'b1;
              msg_src <= SRC_BAUD_SET; msg_len <= 11'd17;
            end else begin
              msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
            end
            state <= E_STREAM_MSG;
          end else if (cmd_len >= 10 && cmd_buf[2]=="/" && cmd_buf[3]=="f" && cmd_buf[4]=="a" && cmd_buf[5]=="i" && cmd_buf[6]=="l") begin
            if (cmd_len >= 14 && cmd_buf[12]=="o" && cmd_buf[13]=="f" && cmd_buf[14]=="f") begin
              failover_en <= 1'b0;
              msg_src <= SRC_FAILOVER_OFF; msg_len <= 11'd22;
            end else begin
              failover_en <= 1'b1;
              msg_src <= SRC_FAILOVER_ON; msg_len <= 11'd21;
            end
            state <= E_STREAM_MSG;
          end else if (cmd_len >= 14 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="s" && cmd_buf[11]=="e") begin
            if (link_status == 2'b00) begin
              msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
            end else begin
              show_popup    <= 1'b1;
              show_progress <= 1'b1;
              popup_mode    <= POPUP_PROGRESS;
              progress_val  <= 8'd0;
              tx_pixel_cnt  <= '0;
              state         <= E_BITMAP_SEND;
            end
          end else if (cmd_len >= 15 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="c" && cmd_buf[11]=="l") begin
            clear_bmp_idx <= 14'd0;
            state         <= E_CLEAR_BITMAP;
          end else if (cmd_len >= 12 && cmd_buf[3]=="t" && cmd_buf[4]=="e" && cmd_buf[5]=="s" && cmd_buf[8]=="s" && cmd_buf[9]=="w") begin
            sweep_step        <= 4'd0;
            sweep_timer       <= '0;
            sweep_active      <= 1'b1;
            sweep_step_passed <= 1'b0;
            show_popup        <= 1'b1;
            show_progress     <= 1'b1;
            popup_mode        <= POPUP_PROGRESS;
            progress_val      <= 8'd0;
            msg_src <= SRC_SWEEP_START; msg_len <= 11'd27; state <= E_STREAM_MSG;
          end else begin
            msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
          end
        end

        // -------------------------------------------------------------------
        // Stream Message Bytes to eval_console_buffer
        // -------------------------------------------------------------------
        E_STREAM_MSG: begin
          if (!print_valid) begin
            print_char  <= current_msg_char;
            print_last  <= (msg_idx == msg_len - 11'd1);
            print_valid <= 1'b1;
          end else if (print_ready) begin
            print_valid <= 1'b0;
            if (msg_idx == msg_len - 11'd1) begin
              if (sweep_active) state <= E_SWEEP_STEP;
              else if (pending_cmd) begin
                pending_cmd <= 1'b0;
                state       <= E_PARSE_CMD;
              end else begin
                state <= E_IDLE;
              end
            end else begin
              msg_idx <= msg_idx + 11'd1;
            end
          end
        end

        // -------------------------------------------------------------------
        // Sequential Double-Dabble BCD Formatter for Ping
        // -------------------------------------------------------------------
        E_PING_CONVERT: begin
          if (bcd_cnt > 0) begin
            logic [31:0] bcd_next;
            bcd_next = bcd_reg;
            for (int i = 0; i < 8; i++) begin
              if (bcd_next[i*4 +: 4] >= 4'd5) bcd_next[i*4 +: 4] = bcd_next[i*4 +: 4] + 4'd3;
            end
            bcd_reg <= {bcd_next[30:0], bin_reg[31]};
            bin_reg <= {bin_reg[30:0], 1'b0};
            bcd_cnt <= bcd_cnt - 6'd1;
          end else begin
            for (int i = 0; i < 8; i++) bcd_d[i] <= bcd_reg[i*4 +: 4];
            fmt_ptr       <= 6'd0;
            fmt_phase     <= 3'd0;
            fmt_digit_idx <= 4'd7;
            fmt_text_idx  <= 5'd0;
            fmt_lead_zero <= 1'b1;
            state         <= E_PING_FMT_STEP;
          end
        end

        E_PING_FMT_STEP: begin
          case (fmt_phase)
            3'd0: begin // "Ping: "
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= "P";
                5'd1: ping_msg_buf[fmt_ptr] <= "i";
                5'd2: ping_msg_buf[fmt_ptr] <= "n";
                5'd3: ping_msg_buf[fmt_ptr] <= "g";
                5'd4: ping_msg_buf[fmt_ptr] <= ":";
                5'd5: ping_msg_buf[fmt_ptr] <= " ";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd5) begin
                if (ping_rtt_cycles == 32'd0) begin
                  fmt_phase <= 3'd4; // Timeout
                  fmt_text_idx <= 5'd0;
                end else begin
                  fmt_phase <= 3'd1; // Digits
                  fmt_text_idx <= 5'd0;
                end
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd1: begin // Decimal digits
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd0) begin
                ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd0) begin
                fmt_phase <= 3'd2; // " cycles"
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd2: begin // " cycles\n"
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= " ";
                5'd1: ping_msg_buf[fmt_ptr] <= "c";
                5'd2: ping_msg_buf[fmt_ptr] <= "y";
                5'd3: ping_msg_buf[fmt_ptr] <= "c";
                5'd4: ping_msg_buf[fmt_ptr] <= "l";
                5'd5: ping_msg_buf[fmt_ptr] <= "e";
                5'd6: ping_msg_buf[fmt_ptr] <= "s";
                5'd7: ping_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd7) begin
                msg_src <= SRC_PING_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end

            3'd4: begin // "timeout\n"
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= "t";
                5'd1: ping_msg_buf[fmt_ptr] <= "i";
                5'd2: ping_msg_buf[fmt_ptr] <= "m";
                5'd3: ping_msg_buf[fmt_ptr] <= "e";
                5'd4: ping_msg_buf[fmt_ptr] <= "o";
                5'd5: ping_msg_buf[fmt_ptr] <= "u";
                5'd6: ping_msg_buf[fmt_ptr] <= "t";
                5'd7: ping_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd7) begin
                msg_src <= SRC_PING_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end
            default: state <= E_IDLE;
          endcase
        end

        // -------------------------------------------------------------------
        // Baudrate Sweep FSM (11 combos)
        // -------------------------------------------------------------------
        E_SWEEP_STEP: begin
          req_baud_rate     <= SWEEP_BAUD[sweep_step];
          req_oversampling  <= SWEEP_OS[sweep_step];
          set_speed_req     <= 1'b1;
          sweep_timer       <= '0;
          sweep_step_passed <= 1'b0;
          progress_val      <= 8'((255 * (sweep_step + 1)) / 11);
          state             <= E_SWEEP_WAIT;
        end

        E_SWEEP_WAIT: begin
          if (sweep_timer == 32'd200_000) begin
            proto_tx_valid <= 1'b1;
            proto_tx_type  <= MSG_REQUEST;
            proto_tx_data  <= PING_TOKEN;
          end
          if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == PING_TOKEN) begin
            sweep_step_passed <= 1'b1;
          end
          if (sweep_timer >= 32'd2_000_000) begin
            msg_idx <= '0;
            if (sweep_step_passed && link_status != 2'b00) begin
              msg_src <= SRC_SWEEP_PASS; msg_len <= 11'd21;
            end else begin
              msg_src <= SRC_SWEEP_FAIL; msg_len <= 11'd26;
            end
            if (sweep_step == 4'd10) begin
              sweep_active  <= 1'b0;
              show_popup    <= 1'b0;
              show_progress <= 1'b0;
            end else begin
              sweep_step <= sweep_step + 4'd1;
            end
            state <= E_STREAM_MSG;
          end else begin
            sweep_timer <= sweep_timer + 32'd1;
          end
        end

        // -------------------------------------------------------------------
        // Dynamic Bitmap Streaming
        // -------------------------------------------------------------------
        E_BITMAP_SEND: begin
          if (!proto_tx_valid && !proto_tx_full && tx_pixel_cnt < 15'd16384) begin
            bmp_addr        <= tx_pixel_cnt[13:0];
            bmp_din         <= prng_pixel_rgb;
            bmp_we          <= 1'b1;
            proto_tx_valid  <= 1'b1;
            proto_tx_type   <= MSG_BITMAP;
            proto_tx_data   <= prng_pixel_byte;
            prng_next_pixel <= 1'b1;
            tx_pixel_cnt    <= tx_pixel_cnt + 15'd1;
            progress_val    <= (tx_pixel_cnt >= 15'd16384) ? 8'd255 : 8'(tx_pixel_cnt[13:6]);
          end else begin
            if (tx_pixel_cnt == 15'd16384) begin
              show_popup    <= 1'b0;
              show_progress <= 1'b0;
              popup_mode    <= POPUP_NONE;
              progress_val  <= 8'd0;
              state         <= E_IDLE;
            end
          end
        end

        E_CLEAR_BITMAP: begin
          bmp_addr <= clear_bmp_idx;
          bmp_din  <= 12'h000;
          bmp_we   <= 1'b1;
          if (clear_bmp_idx == 14'd16383) state <= E_IDLE;
          else clear_bmp_idx <= clear_bmp_idx + 14'd1;
        end

        default: state <= E_IDLE;
      endcase
    end
  end

endmodule
