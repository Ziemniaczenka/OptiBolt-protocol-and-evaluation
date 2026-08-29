/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Command Parser & Execution Engine module.
 * Parses CLI slash commands, controls UI popups & progress, manages 128x128 PRNG dynamic bitmap streaming,
 * executes Ping message formatting, runs Baudrate sweep test, and streams formatted text to the console buffer.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module eval_cmd_exec #(
    parameter int CLI_BUF_LEN      = 128,
    parameter int SWEEP_STEP_TICKS = 5_000_000
) (
    input  logic        clk,
    input  logic        rst_n,

    // Command packet input from eval_cli_input
    input  logic        cmd_valid,
    input  logic [7:0]  cmd_buf [0:CLI_BUF_LEN-1],
    input  logic [10:0] cmd_len,

    // UI button triggers from toolbar / popup
    input  logic        btn_trigger,
    input  logic [3:0]  ui_selected_item,

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
    output logic        sweep_active,
    input  logic [ 1:0] link_status,
    input  logic        rx_carrier,

    // OptiBolt packet TX interface
    output logic        proto_tx_valid,
    output logic [ 2:0] proto_tx_type,
    output logic [ 7:0] proto_tx_data,
    input  logic        proto_tx_full,

    // Power Negotiation Configuration
    output logic [ 1:0] cfg_role,
    output logic [ 3:0] cfg_in_amps[4],
    output logic [ 3:0] cfg_out_amps[4],
    output logic        cfg_ready,
    output logic        cfg_clear,
    input  logic [ 2:0] pwr_status_code,
    input  logic        contract_active,
    input  logic [ 1:0] active_voltage_id,
    input  logic [ 3:0] active_amps,
    input  logic        active_is_source,
    input  logic        contract_event_pulse,

    // OptiBolt packet RX interface
    input  logic        proto_rx_valid,
    input  logic [ 2:0] proto_rx_type,
    input  logic [ 7:0] proto_rx_data,
    input  logic        proto_eval_parity_error,
    input  logic        proto_eval_manchester_code_error,
    input  logic        proto_eval_preamble_error
);

  localparam logic [2:0] MSG_REQUEST = 3'b001;
  localparam logic [2:0] MSG_TEXT    = 3'b100;
  localparam logic [2:0] MSG_BITMAP  = 3'b101; // Map bitmap to MSG_TEST1 (3'b101)
  localparam logic [7:0] PING_TOKEN  = 8'hA5;
  localparam logic [7:0] PING_REPLY  = 8'h5A;

  // ROM Messages
  localparam logic [7:0] HELP_BYTES [0:563] = '{
    "/", "h", "e", "l", "p", " ", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "S", "h", "o", "w", " ", "h", "e", "l", "p", "\n",
    "/", "s", "t", "a", "t", "u", "s", " ", " ", " ", " ", " ", " ", " ", ":", " ", "L", "i", "n", "k", " ", "h", "e", "a", "l", "t", "h", "\n",
    "/", "p", "i", "n", "g", " ", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "T", "e", "s", "t", " ", "R", "T", "T", "\n",
    "/", "s", "w", "e", "e", "p", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "T", "e", "s", "t", " ", "b", "a", "u", "d", " ", "c", "o", "n", "f", "i", "g", "s", "\n",
    "/", "b", "a", "u", "d", " ", "<", "s", "p", "d", ">", " ", " ", " ", ":", " ", "1", "0", "0", "k", ",", " ", "1", "m", ",", " ", "1", ".", "2", "5", "m", ",", " ", "2", ".", "5", "m", ",", "\n",
    " ", " ", "3", ".", "1", "2", "5", "m", ",", " ", "5", "m", ",", " ", "6", ".", "2", "5", "m", ",", " ", "8", ".", "3", "3", "m", ",", " ", "1", "2", ".", "5", "m", ",", " ", "2", "5", "m", "\n",
    "/", "o", "s", " ", "<", "8", "x", " ", "|", " ", "1", "6", "x", ">", ":", " ", "S", "e", "t", " ", "o", "v", "e", "r", "s", "a", "m", "p", "l", "i", "n", "g", "\n",
    "/", "b", "i", "t", "m", "a", "p", " ", "s", "e", "n", "d", " ", " ", ":", " ", "S", "t", "r", "e", "a", "m", " ", "B", "M", "P", "\n",
    "/", "b", "i", "t", "m", "a", "p", " ", "c", "l", "e", "a", "r", " ", ":", " ", "C", "l", "e", "a", "r", " ", "B", "M", "P", "\n",
    "/", "f", "a", "i", "l", "o", "v", "e", "r", " ", "o", "n", " ", "|", " ", "o", "f", "f", " ", ":", " ", "F", "a", "i", "l", "o", "v", "e", "r", " ", "m", "o", "d", "e", "\n",
    "/", "c", "l", "e", "a", "r", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "C", "l", "e", "a", "r", " ", "c", "o", "n", "s", "o", "l", "e", "\n",
    "/", "p", "o", "w", "e", "r", " ", "r", "o", "l", "e", " ", "<", "w", "a", "l", "l", " ", "|", " ", "b", "a", "t", "t", "e", "r", "y", " ", "|", " ", "s", "i", "n", "k", ">", "\n",
    "/", "p", "o", "w", "e", "r", " ", "i", "n", " ", "<", "v", ">", " ", "<", "a", ">", ":", " ", "S", "e", "t", " ", "i", "n", " ", "r", "e", "q", "\n",
    "/", "p", "o", "w", "e", "r", " ", "o", "u", "t", " ", "<", "v", ">", " ", "<", "a", ">", ":", " ", "S", "e", "t", " ", "o", "u", "t", " ", "c", "a", "p", "\n",
    "/", "p", "o", "w", "e", "r", " ", "r", "e", "a", "d", "y", " ", " ", ":", " ", "A", "r", "m", " ", "n", "e", "g", "o", "t", "i", "a", "t", "i", "o", "n", "\n",
    "/", "p", "o", "w", "e", "r", " ", "o", "f", "f", " ", " ", " ", " ", ":", " ", "D", "i", "s", "a", "b", "l", "e", " ", "p", "o", "w", "e", "r", "\n",
    "/", "p", "o", "w", "e", "r", " ", "c", "l", "e", "a", "r", " ", " ", ":", " ", "R", "e", "s", "e", "t", " ", "t", "a", "b", "l", "e", "s", "\n",
    "/", "p", "o", "w", "e", "r", " ", "s", "t", "a", "t", "u", "s", " ", ":", " ", "S", "h", "o", "w", " ", "p", "o", "w", "e", "r", " ", "t", "a", "b", "l", "e", "\n"
  };
  localparam int HELP_LEN = $size(HELP_BYTES);

  localparam logic [7:0] PWR_OFF_BYTES [0:21] = '{
    "P", "o", "w", "e", "r", " ", "d", "i", "s", "a", "b", "l", "e", "d", " ", "(", "O", "F", "F", ")", ".", "\n"
  };
  localparam logic [7:0] PWR_ROLE_SET_BYTES [0:18] = '{
    "P", "o", "w", "e", "r", " ", "r", "o", "l", "e", " ", "u", "p", "d", "a", "t", "e", "d", "\n"
  };
  localparam logic [7:0] PWR_IN_SET_BYTES [0:23] = '{
    "P", "o", "w", "e", "r", " ", "i", "n", "p", "u", "t", " ", "r", "e", "q", "u", "i", "r", "e", "m", "e", "n", "t", "\n"
  };
  localparam logic [7:0] PWR_OUT_SET_BYTES [0:23] = '{
    "P", "o", "w", "e", "r", " ", "o", "u", "t", "p", "u", "t", " ", "c", "a", "p", "a", "b", "i", "l", "i", "t", "y", "\n"
  };
  localparam logic [7:0] PWR_CLEARED_BYTES [0:20] = '{
    "P", "o", "w", "e", "r", " ", "t", "a", "b", "l", "e", "s", " ", "c", "l", "e", "a", "r", "e", "d", "\n"
  };
  localparam logic [7:0] PWR_READY_BYTES [0:24] = '{
    "P", "o", "w", "e", "r", " ", "n", "e", "g", "o", "t", "i", "a", "t", "i", "o", "n", " ", "a", "r", "m", "e", "d", ".", "\n"
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
  localparam logic [7:0] BAUD_SET_BYTES [0:15] = '{
    "S", "p", "e", "e", "d", " ", "u", "p", "d", "a", "t", "e", "d", ".", " ", "\n"
  };
  localparam logic [7:0] FAILOVER_ON_BYTES [0:18] = '{
    "F", "a", "i", "l", "o", "v", "e", "r", ":", " ", "E", "N", "A", "B", "L", "E", "D", " ", "\n"
  };
  localparam logic [7:0] FAILOVER_OFF_BYTES [0:18] = '{
    "F", "a", "i", "l", "o", "v", "e", "r", ":", " ", "D", "I", "S", "A", "B", "L", "E", "D", "\n"
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

  localparam logic [7:0] SWEEP_PASS_STR[0:15][0:20] = '{
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "1", ".", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "1", ".", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{"3", ".", "1", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{"3", ".", "1", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", " ", "5", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "6", ".", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "6", ".", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "8", ".", "3", "3", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "P", "A", "S", "S", " ", "\n"},
    '{" ", "2", "5", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "P", "A", "S", "S", " ", "\n"}
  };

  localparam logic [7:0] SWEEP_FAIL_STR[0:15][0:23] = '{
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", " ", "1", "0", "0", "k", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", " ", "1", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "1", ".", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "1", ".", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", " ", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{"3", ".", "1", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{"3", ".", "1", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", " ", "5", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "6", ".", "2", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "6", ".", "2", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "8", ".", "3", "3", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "1", "2", ".", "5", "M", "b", "p", "s", " ", "1", "6", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"},
    '{" ", "2", "5", ".", "0", "M", "b", "p", "s", " ", " ", "8", "x", ":", " ", "F", "A", "I", "L", " ", "e", "r", "r", "\n"}
  };

  localparam logic [3:0] SWEEP_BAUD[0:15] = '{
    4'd0, 4'd0, 4'd1, 4'd2, 4'd2, 4'd3, 4'd3, 4'd4, 4'd4, 4'd5, 4'd6, 4'd6, 4'd7, 4'd8, 4'd8, 4'd9
  };
  localparam logic [3:0] SWEEP_OS[0:15]   = '{
    4'd0, 4'd1, 4'd0, 4'd0, 4'd1, 4'd0, 4'd1, 4'd0, 4'd1, 4'd0, 4'd0, 4'd1, 4'd0, 4'd0, 4'd1, 4'd0
  };

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
    SRC_SWEEP_DONE,
    SRC_PWR_ROLE_SET,
    SRC_PWR_IN_SET,
    SRC_PWR_OUT_SET,
    SRC_PWR_CLEARED,
    SRC_PWR_READY,
    SRC_PWR_OFF,
    SRC_PWR_STATUS
  } msg_src_t;

  typedef enum logic [3:0] {
    E_IDLE,
    E_PARSE_CMD,
    E_STREAM_MSG,
    E_PING_CONVERT,
    E_PING_FMT_STEP,
    E_SWEEP_STEP,
    E_SWEEP_WAIT,
    E_SWEEP_RESTORE,
    E_BITMAP_SEND,
    E_CLEAR_BITMAP,
    E_TX_CHAT
  } exec_state_t;

  exec_state_t state;
  msg_src_t    msg_src;

  logic [10:0] msg_idx;
  logic [10:0] msg_len;
  logic [ 7:0] current_msg_char;
  logic        pending_cmd;

  // Normal Chat TX
  logic [10:0] tx_chat_idx;

  // Dynamic Bitmap Streaming
  logic [14:0] tx_pixel_cnt;
  logic        tx_pixel_phase;
  logic [ 5:0] tx_gap_cnt;
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
  logic [ 4:0] sweep_step;
  logic [ 4:0] sweep_print_step;
  logic [31:0] sweep_timer;
  logic [31:0] sweep_pkt_gap;
  logic [ 4:0] sweep_tx_count;
  logic [ 4:0] sweep_rx_count;
  logic        sweep_had_error;

  // Power status message buffer
  logic [ 7:0] pwr_msg_buf [0:127];

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
      SRC_SWEEP_PASS:     current_msg_char = SWEEP_PASS_STR[sweep_print_step][msg_idx];
      SRC_SWEEP_FAIL:     current_msg_char = SWEEP_FAIL_STR[sweep_print_step][msg_idx];
      SRC_SWEEP_DONE:     current_msg_char = SWEEP_DONE_BYTES[msg_idx];
      SRC_PWR_ROLE_SET:   current_msg_char = PWR_ROLE_SET_BYTES[msg_idx];
      SRC_PWR_IN_SET:     current_msg_char = PWR_IN_SET_BYTES[msg_idx];
      SRC_PWR_OUT_SET:    current_msg_char = PWR_OUT_SET_BYTES[msg_idx];
      SRC_PWR_CLEARED:    current_msg_char = PWR_CLEARED_BYTES[msg_idx];
      SRC_PWR_READY:      current_msg_char = PWR_READY_BYTES[msg_idx];
      SRC_PWR_OFF:        current_msg_char = PWR_OFF_BYTES[msg_idx];
      SRC_PWR_STATUS:     current_msg_char = pwr_msg_buf[msg_idx];
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
      tx_pixel_phase    <= 1'b0;
      tx_gap_cnt        <= '0;
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
      sweep_print_step  <= '0;
      sweep_timer       <= '0;
      sweep_pkt_gap     <= '0;
      sweep_active      <= 1'b0;
      sweep_tx_count    <= '0;
      sweep_rx_count    <= '0;
      sweep_had_error   <= 1'b0;
      cfg_role          <= 2'd0;
      cfg_ready         <= 1'b0;
      cfg_clear         <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        cfg_in_amps[i]  <= 4'd0;
        cfg_out_amps[i] <= 4'd0;
      end
      for (int i = 0; i < 8; i++) bcd_d[i] <= 4'd0;
      for (int i = 0; i < 64; i++) ping_msg_buf[i] <= 8'h00;
    end else begin
      set_speed_req     <= 1'b0;
      clear_console_req <= 1'b0;
      echo_ack          <= 1'b0;
      bmp_we            <= 1'b0;
      prng_next_pixel   <= 1'b0;
      proto_tx_valid    <= 1'b0;
      cfg_clear         <= 1'b0;

      // Global incoming Ping Request responder (for dual-device and loopback):
      if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_PING_REQ) begin
        proto_tx_valid <= 1'b1;
        proto_tx_type  <= MSG_REQUEST;
        proto_tx_data  <= CMD_PING_RESP;
      end

      // Remote Sweep notification listeners
      if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_SWEEP_START) begin
        sweep_active <= 1'b1;
      end else if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_SWEEP_END) begin
        sweep_active <= 1'b0;
      end

      // Remote Sweep Test Packet Echo (dual-device mode):
      if (link_status == 2'b01 && proto_rx_valid && proto_rx_type == MSG_TEST3 && state == E_IDLE) begin
        proto_tx_valid <= 1'b1;
        proto_tx_type  <= MSG_TEST3;
        proto_tx_data  <= proto_rx_data;
      end

      // Ping timer & timeout monitor
      if (ping_active) begin
        ping_timer <= ping_timer + 32'd1;
        if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_PING_RESP) begin
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
            msg_idx     <= (echo_buf[2] == "/") ? 11'd2 : 11'd0;
            msg_len     <= echo_len;
            echo_ack    <= 1'b1;
            pending_cmd <= cmd_valid;
            state       <= E_STREAM_MSG;
          end else if (cmd_valid || pending_cmd) begin
            pending_cmd <= 1'b0;
            state       <= E_PARSE_CMD;
          end else if (btn_trigger) begin
            case (ui_selected_item)
              ITEM_HELP_BTN: begin
                msg_src <= SRC_HELP; msg_len <= 11'(HELP_LEN); msg_idx <= '0; state <= E_STREAM_MSG;
              end
              ITEM_PING_BTN: begin
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; msg_idx <= '0; state <= E_STREAM_MSG;
                end else begin
                  ping_active <= 1'b1; ping_timer <= '0;
                  proto_tx_valid <= 1'b1; proto_tx_type <= MSG_REQUEST; proto_tx_data <= CMD_PING_REQ;
                  msg_src <= SRC_PING_START; msg_len <= 11'd16; msg_idx <= '0; state <= E_STREAM_MSG;
                end
              end
              ITEM_SWEEP_BTN: begin
                sweep_step        <= 5'd0;
                sweep_print_step  <= 5'd0;
                sweep_timer       <= '0;
                sweep_pkt_gap     <= '0;
                sweep_active      <= 1'b1;
                sweep_tx_count    <= 4'd0;
                sweep_rx_count    <= 4'd0;
                sweep_had_error   <= 1'b0;
                popup_mode        <= POPUP_PROGRESS;
                progress_val      <= 8'd0;
                if (link_status == 2'b01) begin
                  proto_tx_valid <= 1'b1;
                  proto_tx_type  <= MSG_REQUEST;
                  proto_tx_data  <= CMD_SWEEP_START;
                end
                msg_src <= SRC_SWEEP_START; msg_len <= 11'd27; msg_idx <= '0; state <= E_STREAM_MSG;
              end
              ITEM_SNDBMP_BTN: begin
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; msg_idx <= '0; state <= E_STREAM_MSG;
                end else begin
                  show_popup     <= 1'b1;
                  show_progress  <= 1'b1;
                  popup_mode     <= POPUP_PROGRESS;
                  progress_val   <= 8'd0;
                  tx_pixel_cnt   <= '0;
                  tx_pixel_phase <= 1'b0;
                  state          <= E_BITMAP_SEND;
                end
              end
              ITEM_CLRBMP_BTN: begin
                clear_bmp_idx <= 14'd0;
                state         <= E_CLEAR_BITMAP;
              end
              ITEM_CLRCON_BTN: begin
                clear_console_req <= 1'b1;
              end
              ITEM_ABOUT_BTN: begin
                show_popup    <= 1'b1;
                show_progress <= 1'b0;
              end
              ITEM_POPUP_BTN: begin
                show_popup    <= 1'b0;
                show_progress <= 1'b0;
                popup_mode    <= POPUP_NONE;
              end
              default: ;
            endcase
          end
        end

        // -------------------------------------------------------------------
        // Parse and Execute Command
        // -------------------------------------------------------------------
        E_PARSE_CMD: begin
          msg_idx <= '0; // CRITICAL: Always reset msg_idx to 0!

          if (cmd_buf[2] != "/") begin
            // Normal chat message: stream payload over OptiBolt protocol as MSG_TEXT
            if (link_status != 2'b00) begin
              tx_chat_idx <= 11'd2; // Start from first character after "> "
              state       <= E_TX_CHAT;
            end else begin
              msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
            end
          end else begin
            // Local slash commands
            logic [3:0] target_rate, target_os;
            logic valid_rate, valid_os;
            target_rate = 4'd1; target_os = 4'd0;
            valid_rate = 1'b0;  valid_os = 1'b0;

            if (cmd_len >= 5 && cmd_buf[3]=="h" && cmd_buf[4]=="e") begin
              msg_src <= SRC_HELP; msg_len <= 11'(HELP_LEN); state <= E_STREAM_MSG;
            end else if (cmd_len >= 7 && cmd_buf[3]=="c" && cmd_buf[4]=="l" && cmd_buf[5]=="e" && cmd_buf[6]=="a") begin
              clear_console_req <= 1'b1;
              state <= E_IDLE;
            end else if (cmd_len >= 8 && cmd_buf[3]=="s" && cmd_buf[4]=="t" && cmd_buf[5]=="a" && cmd_buf[6]=="t") begin
              if (link_status == 2'b10) begin msg_src <= SRC_STATUS_LOOP; msg_len <= 11'd19; end
              else if (link_status == 2'b01) begin msg_src <= SRC_STATUS_CONN; msg_len <= 11'd20; end
              else begin msg_src <= SRC_STATUS_DISCONN; msg_len <= 11'd23; end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 6 && cmd_buf[3]=="p" && cmd_buf[4]=="i" && cmd_buf[5]=="n") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else begin
                ping_active <= 1'b1; ping_timer <= '0;
                proto_tx_valid <= 1'b1; proto_tx_type <= MSG_REQUEST; proto_tx_data <= CMD_PING_REQ;
                msg_src <= SRC_PING_START; msg_len <= 11'd16; state <= E_STREAM_MSG;
              end
            end else if (cmd_len >= 6 && cmd_buf[3]=="b" && cmd_buf[4]=="a" && cmd_buf[5]=="u") begin
              valid_rate = 1'b1;

              if (cmd_buf[8]=="1" && cmd_buf[9]=="0" && cmd_buf[10]=="0")      target_rate = 4'd0; // 100k
              else if (cmd_buf[8]=="1" && cmd_buf[9]=="." && cmd_buf[10]=="2") target_rate = 4'd2; // 1.25m
              else if (cmd_buf[8]=="1" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) target_rate = 4'd1; // 1m
              else if (cmd_buf[8]=="2" && cmd_buf[9]=="." && cmd_buf[10]=="5") target_rate = 4'd3; // 2.5m
              else if (cmd_buf[8]=="3" && cmd_buf[9]=="." && cmd_buf[10]=="1") target_rate = 4'd4; // 3.125m
              else if (cmd_buf[8]=="5" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) target_rate = 4'd5; // 5m
              else if (cmd_buf[8]=="6" && cmd_buf[9]=="." && cmd_buf[10]=="2") target_rate = 4'd6; // 6.25m
              else if (cmd_buf[8]=="8" && cmd_buf[9]=="." && cmd_buf[10]=="3") target_rate = 4'd7; // 8.33m
              else if (cmd_buf[8]=="1" && cmd_buf[9]=="2")                     target_rate = 4'd8; // 12.5m
              else if (cmd_buf[8]=="2" && cmd_buf[9]=="5")                     target_rate = 4'd9; // 25m
              else valid_rate = 1'b0;

              // Keep current oversampling if supported, otherwise force 8x
              target_os = req_oversampling;
              if (target_os == 4'd1 && (target_rate == 4'd1 || target_rate == 4'd5 || target_rate == 4'd7 || target_rate == 4'd9)) begin
                target_os = 4'd0;
              end

              if (valid_rate) begin
                req_baud_rate    <= target_rate;
                req_oversampling <= target_os;
                set_speed_req    <= 1'b1;
                msg_src <= SRC_BAUD_SET; msg_len <= 11'd16;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 5 && cmd_buf[3]=="o" && cmd_buf[4]=="s") begin
              valid_os = 1'b0;
              if (cmd_len >= 7 && cmd_buf[5] == " ") begin
                if (cmd_buf[6] == "8" && (cmd_len == 7 || cmd_buf[7] == "x" || cmd_buf[7] == "X")) begin
                  valid_os  = 1'b1;
                  target_os = 4'd0; // 8x
                end else if (cmd_buf[6] == "1" && cmd_buf[7] == "6" && (cmd_len == 8 || cmd_buf[8] == "x" || cmd_buf[8] == "X")) begin
                  // 16x is supported on 100k (0), 1.25m (2), 2.5m (3), 3.125m (4), 6.25m (6), 12.5m (8)
                  if (req_baud_rate == 4'd0 || req_baud_rate == 4'd2 || req_baud_rate == 4'd3 ||
                      req_baud_rate == 4'd4 || req_baud_rate == 4'd6 || req_baud_rate == 4'd8) begin
                    valid_os  = 1'b1;
                    target_os = 4'd1; // 16x
                  end
                end
              end

              if (valid_os) begin
                req_baud_rate    <= req_baud_rate; // PRESERVE active baud rate!
                req_oversampling <= target_os;
                set_speed_req    <= 1'b1;
                msg_src <= SRC_BAUD_SET; msg_len <= 11'd16;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 10 && cmd_buf[3]=="f" && cmd_buf[4]=="a" && cmd_buf[5]=="i" && cmd_buf[6]=="l") begin
              if (cmd_len >= 14 && cmd_buf[12]=="o" && cmd_buf[13]=="f" && cmd_buf[14]=="f") begin
                failover_en <= 1'b0;
                msg_src <= SRC_FAILOVER_OFF; msg_len <= 11'd19;
              end else begin
                failover_en <= 1'b1;
                msg_src <= SRC_FAILOVER_ON; msg_len <= 11'd19;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 14 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="s" && cmd_buf[11]=="e") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else begin
                show_popup     <= 1'b1;
                show_progress  <= 1'b1;
                popup_mode     <= POPUP_PROGRESS;
                progress_val   <= 8'd0;
                tx_pixel_cnt   <= '0;
                tx_pixel_phase <= 1'b0;
                tx_gap_cnt     <= '0;
                state          <= E_BITMAP_SEND;
              end
            end else if (cmd_len >= 15 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="c" && cmd_buf[11]=="l") begin
              clear_bmp_idx <= 14'd0;
              state         <= E_CLEAR_BITMAP;
            end else if (cmd_len >= 6 && cmd_buf[3]=="s" && cmd_buf[4]=="w" && cmd_buf[5]=="e") begin
              sweep_step        <= 5'd0;
              sweep_print_step  <= 5'd0;
              sweep_timer       <= '0;
              sweep_pkt_gap     <= '0;
              sweep_active      <= 1'b1;
              sweep_tx_count    <= 4'd0;
              sweep_rx_count    <= 4'd0;
              sweep_had_error   <= 1'b0;
              show_progress     <= 1'b1;
              popup_mode        <= POPUP_PROGRESS;
              progress_val      <= 8'd0;
              if (link_status == 2'b01) begin
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_REQUEST;
                proto_tx_data  <= CMD_SWEEP_START;
              end
              msg_src <= SRC_SWEEP_START; msg_len <= 11'd27; state <= E_STREAM_MSG;
            end else if (cmd_len >= 8 && cmd_buf[3]=="p" && cmd_buf[4]=="o" && cmd_buf[5]=="w" && cmd_buf[6]=="e" && cmd_buf[7]=="r") begin
              if (cmd_len >= 14 && cmd_buf[9]=="r" && cmd_buf[10]=="o" && cmd_buf[11]=="l" && cmd_buf[12]=="e") begin
                if (cmd_buf[14] == "w" || cmd_buf[14] == "W")      cfg_role <= 2'd1; // WALL
                else if (cmd_buf[14] == "b" || cmd_buf[14] == "B") cfg_role <= 2'd2; // BATTERY
                else if (cmd_buf[14] == "s" || cmd_buf[14] == "S") cfg_role <= 2'd3; // SINK
                msg_src <= SRC_PWR_ROLE_SET; msg_len <= 11'd19; state <= E_STREAM_MSG;
              end else if (cmd_len >= 12 && cmd_buf[9]=="i" && cmd_buf[10]=="n") begin
                // /power in <5|9|12|20> <amps>
                if (cmd_buf[12] == "5")        cfg_in_amps[0] <= cmd_buf[14][3:0];
                else if (cmd_buf[12] == "9")   cfg_in_amps[1] <= cmd_buf[14][3:0];
                else if (cmd_buf[12] == "1")   cfg_in_amps[2] <= cmd_buf[15][3:0];
                else if (cmd_buf[12] == "2")   cfg_in_amps[3] <= cmd_buf[15][3:0];
                msg_src <= SRC_PWR_IN_SET; msg_len <= 11'd24; state <= E_STREAM_MSG;
              end else if (cmd_len >= 13 && cmd_buf[9]=="o" && cmd_buf[10]=="u" && cmd_buf[11]=="t") begin
                // /power out <5|9|12|20> <amps>
                if (cmd_buf[13] == "5")        cfg_out_amps[0] <= cmd_buf[15][3:0];
                else if (cmd_buf[13] == "9")   cfg_out_amps[1] <= cmd_buf[15][3:0];
                else if (cmd_buf[13] == "1")   cfg_out_amps[2] <= cmd_buf[16][3:0];
                else if (cmd_buf[13] == "2")   cfg_out_amps[3] <= cmd_buf[16][3:0];
                msg_src <= SRC_PWR_OUT_SET; msg_len <= 11'd24; state <= E_STREAM_MSG;
              end else if (cmd_len >= 14 && cmd_buf[9]=="c" && cmd_buf[10]=="l" && cmd_buf[11]=="e") begin
                cfg_role  <= 2'd0;
                cfg_ready <= 1'b0;
                cfg_clear <= 1'b1;
                for (int i = 0; i < 4; i++) begin
                  cfg_in_amps[i]  <= 4'd0;
                  cfg_out_amps[i] <= 4'd0;
                end
                msg_src <= SRC_PWR_CLEARED; msg_len <= 11'd21; state <= E_STREAM_MSG;
              end else if (cmd_len >= 14 && cmd_buf[9]=="r" && cmd_buf[10]=="e" && cmd_buf[11]=="a") begin
                cfg_ready <= 1'b1;
                msg_src   <= SRC_PWR_READY; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else if (cmd_len >= 12 && cmd_buf[9]=="o" && cmd_buf[10]=="f" && cmd_buf[11]=="f") begin
                cfg_ready      <= 1'b0;
                cfg_clear      <= 1'b1;
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_POWER;
                proto_tx_data  <= 8'hFE;
                msg_src <= SRC_PWR_OFF; msg_len <= 11'd22; state <= E_STREAM_MSG;
              end else if (cmd_len >= 15 && cmd_buf[9]=="s" && cmd_buf[10]=="t" && cmd_buf[11]=="a") begin
                // /power status : Show full power table (In, Out, Active status)
                pwr_msg_buf[0]  <= "I"; pwr_msg_buf[1]  <= "n"; pwr_msg_buf[2]  <= " "; pwr_msg_buf[3]  <= ":"; pwr_msg_buf[4]  <= " ";
                pwr_msg_buf[5]  <= "5"; pwr_msg_buf[6]  <= "V"; pwr_msg_buf[7]  <= "="; pwr_msg_buf[8]  <= {4'h3, cfg_in_amps[0]}; pwr_msg_buf[9]  <= "A"; pwr_msg_buf[10] <= " ";
                pwr_msg_buf[11] <= "9"; pwr_msg_buf[12] <= "V"; pwr_msg_buf[13] <= "="; pwr_msg_buf[14] <= {4'h3, cfg_in_amps[1]}; pwr_msg_buf[15] <= "A"; pwr_msg_buf[16] <= " ";
                pwr_msg_buf[17] <= "1"; pwr_msg_buf[18] <= "2"; pwr_msg_buf[19] <= "V"; pwr_msg_buf[20] <= "="; pwr_msg_buf[21] <= {4'h3, cfg_in_amps[2]}; pwr_msg_buf[22] <= "A"; pwr_msg_buf[23] <= " ";
                pwr_msg_buf[24] <= "2"; pwr_msg_buf[25] <= "0"; pwr_msg_buf[26] <= "V"; pwr_msg_buf[27] <= "="; pwr_msg_buf[28] <= {4'h3, cfg_in_amps[3]}; pwr_msg_buf[29] <= "A";
                pwr_msg_buf[30] <= "\n";

                pwr_msg_buf[31] <= "O"; pwr_msg_buf[32] <= "u"; pwr_msg_buf[33] <= "t"; pwr_msg_buf[34] <= ":"; pwr_msg_buf[35] <= " ";
                pwr_msg_buf[36] <= "5"; pwr_msg_buf[37] <= "V"; pwr_msg_buf[38] <= "="; pwr_msg_buf[39] <= {4'h3, cfg_out_amps[0]}; pwr_msg_buf[40] <= "A"; pwr_msg_buf[41] <= " ";
                pwr_msg_buf[42] <= "9"; pwr_msg_buf[43] <= "V"; pwr_msg_buf[44] <= "="; pwr_msg_buf[45] <= {4'h3, cfg_out_amps[1]}; pwr_msg_buf[46] <= "A"; pwr_msg_buf[47] <= " ";
                pwr_msg_buf[48] <= "1"; pwr_msg_buf[49] <= "2"; pwr_msg_buf[50] <= "V"; pwr_msg_buf[51] <= "="; pwr_msg_buf[52] <= {4'h3, cfg_out_amps[2]}; pwr_msg_buf[53] <= "A"; pwr_msg_buf[54] <= " ";
                pwr_msg_buf[55] <= "2"; pwr_msg_buf[56] <= "0"; pwr_msg_buf[57] <= "V"; pwr_msg_buf[58] <= "="; pwr_msg_buf[59] <= {4'h3, cfg_out_amps[3]}; pwr_msg_buf[60] <= "A";
                pwr_msg_buf[61] <= "\n";

                if (contract_active) begin
                  pwr_msg_buf[62] <= "A"; pwr_msg_buf[63] <= "c"; pwr_msg_buf[64] <= "t"; pwr_msg_buf[65] <= "i"; pwr_msg_buf[66] <= "v"; pwr_msg_buf[67] <= "e"; pwr_msg_buf[68] <= ":"; pwr_msg_buf[69] <= " ";
                  if (active_is_source) begin
                    pwr_msg_buf[70] <= "S"; pwr_msg_buf[71] <= "O"; pwr_msg_buf[72] <= "U"; pwr_msg_buf[73] <= "R"; pwr_msg_buf[74] <= "C"; pwr_msg_buf[75] <= "E"; pwr_msg_buf[76] <= " ";
                    if (active_voltage_id == 2'd3) begin pwr_msg_buf[77] <= "2"; pwr_msg_buf[78] <= "0"; end
                    else if (active_voltage_id == 2'd2) begin pwr_msg_buf[77] <= "1"; pwr_msg_buf[78] <= "2"; end
                    else if (active_voltage_id == 2'd1) begin pwr_msg_buf[77] <= " "; pwr_msg_buf[78] <= "9"; end
                    else begin pwr_msg_buf[77] <= " "; pwr_msg_buf[78] <= "5"; end
                    pwr_msg_buf[79] <= "V"; pwr_msg_buf[80] <= " "; pwr_msg_buf[81] <= "@"; pwr_msg_buf[82] <= " ";
                    pwr_msg_buf[83] <= {4'h3, active_amps}; pwr_msg_buf[84] <= "A"; pwr_msg_buf[85] <= "\n";
                    msg_len <= 11'd86;
                  end else begin
                    pwr_msg_buf[70] <= "S"; pwr_msg_buf[71] <= "I"; pwr_msg_buf[72] <= "N"; pwr_msg_buf[73] <= "K"; pwr_msg_buf[74] <= " ";
                    if (active_voltage_id == 2'd3) begin pwr_msg_buf[75] <= "2"; pwr_msg_buf[76] <= "0"; end
                    else if (active_voltage_id == 2'd2) begin pwr_msg_buf[75] <= "1"; pwr_msg_buf[76] <= "2"; end
                    else if (active_voltage_id == 2'd1) begin pwr_msg_buf[75] <= " "; pwr_msg_buf[76] <= "9"; end
                    else begin pwr_msg_buf[75] <= " "; pwr_msg_buf[76] <= "5"; end
                    pwr_msg_buf[77] <= "V"; pwr_msg_buf[78] <= " "; pwr_msg_buf[79] <= "@"; pwr_msg_buf[80] <= " ";
                    pwr_msg_buf[81] <= {4'h3, active_amps}; pwr_msg_buf[82] <= "A"; pwr_msg_buf[83] <= "\n";
                    msg_len <= 11'd84;
                  end
                end else begin
                  pwr_msg_buf[62] <= "A"; pwr_msg_buf[63] <= "c"; pwr_msg_buf[64] <= "t"; pwr_msg_buf[65] <= "i"; pwr_msg_buf[66] <= "v"; pwr_msg_buf[67] <= "e"; pwr_msg_buf[68] <= ":"; pwr_msg_buf[69] <= " ";
                  pwr_msg_buf[70] <= "N"; pwr_msg_buf[71] <= "O"; pwr_msg_buf[72] <= "N"; pwr_msg_buf[73] <= "E"; pwr_msg_buf[74] <= "\n";
                  msg_len <= 11'd75;
                end
                msg_src <= SRC_PWR_STATUS; state <= E_STREAM_MSG;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
              end
            end else begin
              msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
            end
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
                  fmt_phase    <= 3'd6; // Timeout
                  fmt_text_idx <= 5'd0;
                end else begin
                  fmt_phase     <= 3'd1; // Digits
                  fmt_digit_idx <= 4'd7;
                  fmt_lead_zero <= 1'b1;
                  fmt_text_idx  <= 5'd0;
                end
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd1: begin // Decimal digits for clock cycles
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd0) begin
                ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd0) begin
                fmt_phase    <= 3'd2; // " cycles ("
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd2: begin // " cycles ("
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= " ";
                5'd1: ping_msg_buf[fmt_ptr] <= "c";
                5'd2: ping_msg_buf[fmt_ptr] <= "y";
                5'd3: ping_msg_buf[fmt_ptr] <= "c";
                5'd4: ping_msg_buf[fmt_ptr] <= "l";
                5'd5: ping_msg_buf[fmt_ptr] <= "e";
                5'd6: ping_msg_buf[fmt_ptr] <= "s";
                5'd7: ping_msg_buf[fmt_ptr] <= " ";
                5'd8: ping_msg_buf[fmt_ptr] <= "(";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd8) begin
                fmt_phase     <= 3'd3; // Microseconds integer digits
                fmt_digit_idx <= 4'd7;
                fmt_lead_zero <= 1'b1;
                fmt_text_idx  <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd3: begin // Microseconds integer digits (bcd_d[7:2])
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd2) begin
                ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd2) begin
                fmt_phase    <= 3'd4; // Decimal point + fractions
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd4: begin // "." then bcd_d[1], bcd_d[0]
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= ".";
                5'd1: ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[1]};
                5'd2: ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[0]};
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd2) begin
                fmt_phase    <= 3'd5; // " us)\n"
                fmt_text_idx <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd5: begin // " us)\n"
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= " ";
                5'd1: ping_msg_buf[fmt_ptr] <= "u";
                5'd2: ping_msg_buf[fmt_ptr] <= "s";
                5'd3: ping_msg_buf[fmt_ptr] <= ")";
                5'd4: ping_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd4) begin
                msg_src <= SRC_PING_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end

            3'd6: begin // "timeout\n"
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
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end
            default: state <= E_IDLE;
          endcase
        end

        // -------------------------------------------------------------------
        // Baudrate Sweep FSM (16 combos)
        // -------------------------------------------------------------------
        E_SWEEP_STEP: begin
          if (sweep_step < 5'd16) begin
            req_baud_rate    <= SWEEP_BAUD[sweep_step];
            req_oversampling <= SWEEP_OS[sweep_step];
            set_speed_req    <= 1'b1;
            sweep_timer      <= '0;
            sweep_pkt_gap    <= '0;
            sweep_tx_count   <= 4'd0;
            sweep_rx_count   <= 4'd0;
            sweep_had_error  <= 1'b0;
            progress_val     <= 8'((255 * (sweep_step + 1)) / 16);
            state            <= E_SWEEP_WAIT;
          end else begin
            // Sweep complete: notify remote peer, restore default 1.0 Mbps 8x
            if (link_status == 2'b01) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_REQUEST;
              proto_tx_data  <= CMD_SWEEP_END;
            end
            req_baud_rate    <= 4'd1;
            req_oversampling <= 4'd0;
            set_speed_req    <= 1'b1;
            sweep_active     <= 1'b0;
            show_popup       <= 1'b0;
            show_progress    <= 1'b0;
            popup_mode       <= POPUP_NONE;
            msg_src          <= SRC_SWEEP_DONE;
            msg_len          <= 11'd21;
            msg_idx          <= '0;
            state            <= E_STREAM_MSG;
          end
        end

        E_SWEEP_WAIT: begin
          sweep_timer <= sweep_timer + 32'd1;

          /* Settle guard window (1/8th of step duration): ignore switching transients */
          if (sweep_timer < (SWEEP_STEP_TICKS >> 3)) begin
            sweep_had_error <= 1'b0;
            sweep_pkt_gap   <= '0;
          end else begin
            /* Latch protocol errors during active measurement window */
            if (proto_eval_parity_error || proto_eval_manchester_code_error || proto_eval_preamble_error) begin
              sweep_had_error <= 1'b1;
            end

            /* Pace packet transmissions across active test window */
            sweep_pkt_gap <= sweep_pkt_gap + 32'd1;
            if (sweep_pkt_gap >= (SWEEP_STEP_TICKS >> 5) && sweep_tx_count < 5'd16) begin
              if (!proto_tx_full) begin
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_TEST3;
                proto_tx_data  <= {sweep_step[3:0], sweep_tx_count[3:0]};
                sweep_tx_count <= sweep_tx_count + 5'd1;
                sweep_pkt_gap  <= '0;
              end
            end else if (proto_tx_valid && !proto_tx_full) begin
              proto_tx_valid <= 1'b0;
            end
          end

          /* Count received test packets tagged specifically for this sweep step */
          if (proto_rx_valid && proto_rx_type == MSG_TEST3 && proto_rx_data[7:4] == sweep_step[3:0]) begin
            sweep_rx_count <= sweep_rx_count + 5'd1;
          end

          /* Evaluate link performance at end of dwell window */
          if (sweep_timer >= SWEEP_STEP_TICKS) begin
            proto_tx_valid   <= 1'b0;
            sweep_print_step <= sweep_step;
            sweep_step       <= sweep_step + 5'd1;
            if (sweep_rx_count == 5'd16 && !sweep_had_error && rx_carrier && link_status != 2'b00) begin
              msg_src <= SRC_SWEEP_PASS;
              msg_len <= 11'd21;
            end else begin
              msg_src <= SRC_SWEEP_FAIL;
              msg_len <= 11'd24;
            end
            // Always return to default speed (1.0 Mbps) so next step can negotiate cleanly
            req_baud_rate    <= 4'd1;
            req_oversampling <= 4'd0;
            set_speed_req    <= 1'b1;
            sweep_timer      <= '0;
            state            <= E_SWEEP_RESTORE;
          end
        end

        E_SWEEP_RESTORE: begin
          sweep_timer <= sweep_timer + 32'd1;
          if (sweep_timer >= (SWEEP_STEP_TICKS >> 3)) begin
            msg_idx <= '0;
            state   <= E_STREAM_MSG;
          end
        end

        // -------------------------------------------------------------------
        // Dynamic Bitmap Streaming (2 bytes per pixel for 4096 colors)
        // -------------------------------------------------------------------
        E_BITMAP_SEND: begin
          if (proto_tx_valid && proto_tx_full) begin
            // Hold current byte valid until FIFO accepts it
            proto_tx_valid <= 1'b1;
          end else if (proto_tx_valid) begin
            // Byte was consumed by FIFO: enter 200ns recovery gap
            proto_tx_valid <= 1'b0;
            tx_gap_cnt     <= 6'd0;
          end else if (tx_gap_cnt < 6'd20) begin
            // 20 cycles @ 100MHz = 200ns recovery gap between bytes
            tx_gap_cnt <= tx_gap_cnt + 6'd1;
          end else begin
            // Recovery gap elapsed (or first byte starting)
            if (tx_pixel_cnt < 15'd16384) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_BITMAP;
              if (!tx_pixel_phase) begin
                // Byte 0: {1'b0, R[3:0], G[3:1]}
                proto_tx_data  <= {1'b0, prng_pixel_rgb[11:8], prng_pixel_rgb[7:5]};
                tx_pixel_phase <= 1'b1;
              end else begin
                // Byte 1: {1'b1, G[0], B[3:0], 2'b00}
                proto_tx_data   <= {1'b1, prng_pixel_rgb[4], prng_pixel_rgb[3:0], 2'b00};
                prng_next_pixel <= 1'b1;
                tx_pixel_cnt    <= tx_pixel_cnt + 15'd1;
                tx_pixel_phase  <= 1'b0;
                progress_val    <= 8'(tx_pixel_cnt[13:6]);
              end
            end else begin
              proto_tx_valid <= 1'b0;
              show_popup     <= 1'b0;
              show_progress  <= 1'b0;
              popup_mode     <= POPUP_NONE;
              state          <= E_IDLE;
            end
          end
        end

        E_CLEAR_BITMAP: begin
          bmp_addr <= clear_bmp_idx;
          bmp_din  <= 12'h000;
          bmp_we   <= 1'b1;
          if (clear_bmp_idx == 14'd16383) begin
            state <= E_IDLE;
          end else begin
            clear_bmp_idx <= clear_bmp_idx + 14'd1;
          end
        end

        // -------------------------------------------------------------------
        // Normal Chat Message TX
        // -------------------------------------------------------------------
        E_TX_CHAT: begin
          if (proto_tx_valid && proto_tx_full) begin
            proto_tx_valid <= 1'b1;
          end else begin
            if (tx_chat_idx < cmd_len) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_TEXT;
              proto_tx_data  <= cmd_buf[tx_chat_idx];
              tx_chat_idx    <= tx_chat_idx + 11'd1;
            end else if (tx_chat_idx == cmd_len) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_TEXT;
              proto_tx_data  <= 8'h0A; // Trailing newline
              tx_chat_idx    <= tx_chat_idx + 11'd1;
            end else begin
              proto_tx_valid <= 1'b0;
              state          <= E_IDLE;
            end
          end
        end

        default: state <= E_IDLE;
      endcase
    end
  end

endmodule
