/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Master Evaluation Controller managing CLI commands, shell command history,
 * hardware Block RAM console line auto-scrolling, Double-Dabble hardware Ping RTT measurement,
 * full 11-speed baudrate sweep test, 128x128 dynamic bitmap streaming,
 * decoupled popups, and real-time log-scale error metrics.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module evaluation_controller (
    input logic clk,
    input logic rst_n,

    // Keyboard Inputs
    input logic cmd_up,
    input logic cmd_down,
    input logic cmd_left,
    input logic cmd_right,
    input logic cmd_enter,
    input logic cmd_esc,

    // Text Inputs
    input logic       char_valid,
    input logic [7:0] char_ascii,
    input logic       cmd_backspace,

    // --- RAM Interfaces ---
    output logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr,
    output logic                                           console_we,
    output logic [                                    7:0] console_din,
    input  logic [                                    7:0] console_dout,

    output logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr,
    output logic                                         input_we,
    output logic [                                  7:0] input_din,

    output logic [13:0] bmp_addr,
    output logic        bmp_we,
    output logic [11:0] bmp_din,

    input  logic [3:0] ui_selected_item,
    output logic       mode_text,
    output logic       show_popup,
    output logic       show_progress,
    output logic [7:0] progress_val,
    output logic [1:0] popup_mode,

    // --- Diagnostics & Error Metrics Outputs ---
    output logic [15:0] err_man_cnt,
    output logic [15:0] err_pre_cnt,
    output logic [15:0] err_par_cnt,
    output logic [ 7:0] prog_man,
    output logic [ 7:0] prog_pre,
    output logic [ 7:0] prog_par,
    output logic [ 7:0] prog_hlt,
    output logic [11:0] color_man,
    output logic [11:0] color_pre,
    output logic [11:0] color_par,
    output logic [11:0] color_hlt,

    // --- Handshake Interface ---
    input  logic       hs_tx_req,
    input  logic [2:0] hs_tx_type,
    input  logic [7:0] hs_tx_data,
    output logic       hs_tx_ack,
    input  logic [1:0] link_status,

    // --- OptiBolt Protocol Control & Telemetry Interface ---
    output logic [3:0] eval_proto_baud_rate,
    output logic [3:0] eval_proto_oversampling,
    output logic       eval_proto_loopback_en,

    // TX Interface
    output logic       eval_proto_tx_valid,
    output logic [2:0] eval_proto_tx_type,
    output logic [7:0] eval_proto_tx_data,
    input  logic       proto_eval_tx_full,
    input  logic       proto_eval_tx_empty,

    // RX Interface
    input  logic       proto_eval_rx_valid,
    input  logic [2:0] proto_eval_rx_type,
    input  logic [7:0] proto_eval_rx_data,
    input  logic       proto_eval_parity_error,
    input  logic       proto_eval_manchester_code_error,
    input  logic       proto_eval_preamble_error,

    // Telemetry / Status
    input  logic        proto_eval_link_status,
    input  logic [31:0] proto_eval_ber_count,
    input  logic [15:0] proto_eval_err_count
);

  localparam logic [2:0] MSG_BITMAP = 3'b101; // Map bitmap packet to MSG_TEST1 (3'b101)
  localparam logic [7:0] PING_TOKEN  = 8'hEE; // Ping request / response token

  typedef enum logic [4:0] {
    S_INIT,
    S_IDLE,
    S_HIST_SCAN,
    S_HIST_UPDATE,
    S_PROCESS_CMD,
    S_PRINT_MSG,
    S_FIND_NL_READ,
    S_FIND_NL_WAIT,
    S_FIND_NL_CHECK,
    S_SCROLL_READ,
    S_SCROLL_WAIT,
    S_SCROLL_WRITE,
    S_SCROLL_CLEAR,
    S_CLEAR_CONSOLE,
    S_UPDATE_INPUT_RAM,
    S_BITMAP_SEND,
    S_CLEAR_BITMAP,
    S_TEXT_SEND,
    S_SWEEP_STEP,
    S_SWEEP_WAIT,
    S_SWEEP_REPORT,
    S_PING_BCD_INIT,
    S_PING_BCD_STEP,
    S_PING_FMT_STEP
  } state_t;

  state_t state, state_after_scroll;

  typedef enum logic [4:0] {
    SRC_NONE,
    SRC_INPUT_ECHO,
    SRC_HELP,
    SRC_STATUS_DISCONN,
    SRC_STATUS_CONN,
    SRC_STATUS_LOOP,
    SRC_BAUD_SET,
    SRC_OS_SET,
    SRC_TEST,
    SRC_BITMAP_SEND,
    SRC_BITMAP_CLEAR,
    SRC_UNKNOWN,
    SRC_ERR_DISCONN,
    SRC_BAUD_NEGO,
    SRC_BAUD_SYNC,
    SRC_REMOTE_BAUD,
    SRC_PING_START,
    SRC_PING_MSG,
    SRC_SWEEP_START,
    SRC_SWEEP_PASS,
    SRC_SWEEP_FAIL,
    SRC_SWEEP_DONE,
    SRC_RX_CHAR
  } msg_src_t;

  msg_src_t msg_src;
  logic [10:0] msg_idx;
  logic [10:0] msg_len;

  // Small 48-byte Ping Response Formatting Buffer
  logic [7:0] ping_msg_buf [0:47];
  logic [5:0] ping_msg_len;
  logic       ping_is_timeout;
  logic       ping_is_loopback;

  // Double-Dabble Binary-to-BCD Sequential Converter Registers
  logic [31:0] bcd_reg;
  logic [31:0] bin_reg;
  logic [ 5:0] bcd_cnt;
  logic [ 3:0] bcd_d [0:7];
  logic [ 5:0] fmt_ptr;
  logic [ 2:0] fmt_phase;
  logic [ 3:0] fmt_digit_idx;
  logic [ 4:0] fmt_text_idx;
  logic        fmt_lead_zero;

  // CLI Input Buffer (128 bytes - full line width)
  localparam CLI_BUF_LEN = 128;
  logic [7:0] input_buf [0:CLI_BUF_LEN-1];
  logic [10:0] input_len;
  logic [10:0] input_cursor;

  // Shell Command History Buffer (4 commands x 64 chars)
  localparam HIST_BUF_LEN = 64;
  logic [7:0] history_buf [0:3][0:HIST_BUF_LEN-1];
  logic [6:0] history_len [0:3];
  logic [2:0] history_count;
  logic [2:0] history_pos; // 0 = current live, 1 = entry 0, 2 = entry 1...

  // Sequential History Reordering / Deduplication Registers
  logic [1:0] hist_check_idx;
  logic [1:0] hist_match_idx;
  logic       hist_matched;

  // Console Line & Scrolling Registers
  localparam int MAX_CONSOLE_LINES = 40;
  logic [5:0] console_line_cnt;
  logic [6:0] console_col_cnt;
  logic [7:0] rx_char_hold;

  // Pointers & Indices
  logic [9:0] console_write_ptr;
  logic [9:0] clear_idx;
  logic [9:0] scroll_src, scroll_dst;
  logic [6:0] input_update_idx;
  logic [5:0] init_idx;
  logic [13:0] clear_bmp_idx;

  // 128x128 Dynamic Bitmap counters (16384 pixels)
  logic [14:0] tx_pixel_cnt;
  logic [13:0] rx_pixel_ptr;
  logic [10:0] text_send_idx;

  // Baud negotiation registers
  logic [7:0] pending_baud_req;
  logic       pending_baud_nego;
  logic       pending_nego_ack_tx;
  logic [7:0] nego_ack_payload;

  // Ping test registers
  logic        ping_active;
  logic [31:0] ping_timer;
  logic [31:0] ping_rtt_cycles;
  logic        pending_ping_reply;

  // Baudrate Sweep Test Engine (11 combos)
  logic [3:0] sweep_step;
  logic [31:0] sweep_timer;
  logic [10:0] sweep_pass_mask;
  logic        sweep_active;
  logic        sweep_step_passed;

  // Newline-based console auto-scroll registers
  logic [9:0] scan_idx;
  logic [9:0] nl_len;
  logic [9:0] clear_src;

  // Periodic 0.5s Error Metric Window Registers
  logic [26:0] err_window_timer;
  logic [15:0] err_man_acc, err_pre_acc, err_par_acc;

  localparam logic [3:0] SWEEP_BAUD[0:10] = '{4'd0, 4'd1, 4'd1, 4'd2, 4'd3, 4'd3, 4'd4, 4'd5, 4'd5, 4'd6, 4'd7};
  localparam logic [3:0] SWEEP_OS[0:10]   = '{4'd0, 4'd0, 4'd1, 4'd0, 4'd0, 4'd1, 4'd0, 4'd1, 4'd0, 4'd0, 4'd0};

  // RX text line formatting buffer
  logic       rx_line_start;
  logic [7:0] rx_fifo_chars [0:3];
  logic [1:0] rx_fifo_head, rx_fifo_tail;
  logic [2:0] rx_fifo_count;

  // PRNG Instantiation for pixel colors
  logic        prng_next_pixel;
  logic [11:0] prng_pixel_rgb;
  logic [ 7:0] prng_pixel_byte;

  pixel_prng u_pixel_prng (
      .clk(clk),
      .rst_n(rst_n),
      .next_pixel(prng_next_pixel),
      .pixel_rgb(prng_pixel_rgb),
      .pixel_byte(prng_pixel_byte)
  );

  // 0.5s periodic window decay timer instantiated using counter.sv
  logic err_window_tick;
  counter #(
      .VALUE_MAX(50_000_000 - 1)
  ) u_err_window_counter (
      .clk(clk),
      .rst_n(rst_n),
      .enabled(1'b1),
      .value(),
      .overflow(err_window_tick)
  );

  // Real-time Error Counters (with edge detectors and 0.5s periodic window decay)
  logic man_err_d1, pre_err_d1, par_err_d1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      man_err_d1  <= 1'b0;
      pre_err_d1  <= 1'b0;
      par_err_d1  <= 1'b0;
      err_man_acc <= 16'd0;
      err_pre_acc <= 16'd0;
      err_par_acc <= 16'd0;
      err_man_cnt <= 16'd0;
      err_pre_cnt <= 16'd0;
      err_par_cnt <= 16'd0;
    end else begin
      man_err_d1 <= proto_eval_manchester_code_error;
      pre_err_d1 <= proto_eval_preamble_error;
      par_err_d1 <= proto_eval_parity_error;

      if (proto_eval_manchester_code_error && !man_err_d1) begin
        if (err_man_acc != 16'hFFFF) err_man_acc <= err_man_acc + 16'd1;
      end
      if (proto_eval_preamble_error && !pre_err_d1) begin
        if (err_pre_acc != 16'hFFFF) err_pre_acc <= err_pre_acc + 16'd1;
      end
      if (proto_eval_parity_error && !par_err_d1) begin
        if (err_par_acc != 16'hFFFF) err_par_acc <= err_par_acc + 16'd1;
      end

      // Latch counts to display registers and reset accumulator every 0.5s
      if (err_window_tick) begin
        err_man_cnt <= err_man_acc;
        err_pre_cnt <= err_pre_acc;
        err_par_cnt <= err_par_acc;
        err_man_acc <= 16'd0;
        err_pre_acc <= 16'd0;
        err_par_acc <= 16'd0;
      end
    end
  end

  // Synthesizable Log-Scale Mapping Function for Real-Time Error Progress Bars
  function automatic logic [7:0] log_scale_progress(input [15:0] cnt);
    if (cnt == 16'd0)        return 8'd0;
    else if (cnt < 16'd5)    return 8'd25;
    else if (cnt < 16'd20)   return 8'd60;
    else if (cnt < 16'd100)  return 8'd120;
    else if (cnt < 16'd500)  return 8'd180;
    else if (cnt < 16'd2000) return 8'd220;
    else                     return 8'd255;
  endfunction

  // Synthesizable 4-Color Gradient Function based on Error Severity
  function automatic logic [11:0] error_color(input [7:0] prog);
    if (prog < 8'd40)        return 12'h3C5; // Green
    else if (prog < 8'd120)  return 12'hEE3; // Yellow
    else if (prog < 8'd200)  return 12'hFA2; // Orange
    else                     return 12'hF33; // Red
  endfunction

  // Dynamic Health Rating Calculator (100% minus aggregate error penalties)
  function automatic logic [7:0] calc_health(input [15:0] man, input [15:0] pre, input [15:0] par, input [1:0] link);
    logic [17:0] penalty;
    if (link == 2'b00) return 8'd0; // Disconnected = 0% health
    penalty = (man * 18'd5) + (pre * 18'd3) + (par * 18'd8);
    if (penalty >= 18'd255) return 8'd10; // Floor at 10 (critical)
    else return 8'(18'd255 - penalty);
  endfunction

  function automatic logic [11:0] health_color(input [7:0] hlt);
    if (hlt >= 8'd200)       return 12'h3C5; // Green
    else if (hlt >= 8'd140)  return 12'hEE3; // Yellow
    else if (hlt >= 8'd70)   return 12'hFA2; // Orange
    else                     return 12'hF33; // Red
  endfunction

  always_comb begin
    prog_man = log_scale_progress(err_man_cnt);
    prog_pre = log_scale_progress(err_pre_cnt);
    prog_par = log_scale_progress(err_par_cnt);
    prog_hlt = calc_health(err_man_cnt, err_pre_cnt, err_par_cnt, link_status);

    color_man = error_color(prog_man);
    color_pre = error_color(prog_pre);
    color_par = error_color(prog_par);
    color_hlt = health_color(prog_hlt);
  end

  // Constant CLI Responses
  localparam logic [7:0] BANNER_BYTES [0:56] = '{
    "O", "p", "t", "i", "B", "o", "l", "t", " ", "E", "v", "a", "l", "u", "a", "t", "i", "o", "n", " ",
    "S", "y", "s", "t", "e", "m", " ", "v", "1", ".", "0", "\n",
    "T", "y", "p", "e", " ", "/", "h", "e", "l", "p", " ", "f", "o", "r", " ", "c", "o", "m", "m", "a", "n", "d", "s", ".", "\n"
  };

  localparam logic [7:0] HELP_BYTES [0:463] = '{
    "-", "-", "-", " ", "O", "p", "t", "i", "B", "o", "l", "t", " ", "H", "e", "l",
    "p", " ", "-", "-", "-", "\n", "/", "h", "e", "l", "p", " ", " ", " ", " ", " ",
    " ", " ", " ", " ", ":", " ", "S", "h", "o", "w", " ", "c", "o", "m", "m", "a",
    "n", "d", "s", "\n", "/", "s", "t", "a", "t", "u", "s", " ", " ", " ", " ", " ",
    " ", " ", ":", " ", "L", "i", "n", "k", " ", "&", " ", "b", "a", "u", "d", " ",
    "s", "t", "a", "t", "u", "s", "\n", "/", "b", "a", "u", "d", " ", "<", "r", "a",
    "t", "e", ">", " ", " ", ":", " ", "1", "0", "0", "k", ",", " ", "1", "m", ",",
    " ", "1", ".", "2", "5", "m", ",", " ", "2", ".", "5", "m", ",", " ", "3", ".",
    "1", "2", "5", "m", ",", "\n", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
    " ", " ", " ", " ", " ", " ", "5", "m", ",", " ", "6", ".", "2", "5", "m", ",",
    " ", "8", ".", "3", "3", "m", ",", " ", "1", "2", ".", "5", "m", ",", " ", "2",
    "5", "m", "\n", "/", "o", "s", " ", "<", "8", "|", "1", "6", ">", " ", " ", " ",
    " ", ":", " ", "S", "e", "t", " ", "8", "x", " ", "o", "r", " ", "1", "6", "x",
    " ", "o", "v", "e", "r", "s", "a", "m", "p", "l", "i", "n", "g", "\n", "/", "l",
    "o", "o", "p", "b", "a", "c", "k", " ", " ", " ", " ", " ", ":", " ", "T", "o",
    "g", "g", "l", "e", " ", "o", "p", "t", "i", "c", "a", "l", " ", "l", "o", "o",
    "p", "b", "a", "c", "k", "\n", "/", "p", "i", "n", "g", " ", " ", " ", " ", " ",
    " ", " ", " ", " ", ":", " ", "M", "e", "a", "s", "u", "r", "e", " ", "o", "p",
    "t", "i", "c", "a", "l", " ", "R", "T", "T", " ", "l", "a", "t", "e", "n", "c",
    "y", "\n", "/", "t", "e", "s", "t", " ", "s", "w", "e", "e", "p", " ", " ", " ",
    ":", " ", "S", "w", "e", "e", "p", " ", "a", "l", "l", " ", "1", "1", " ", "b",
    "a", "u", "d", "/", "o", "s", " ", "c", "o", "n", "f", "i", "g", "s", "\n", "/",
    "b", "i", "t", "m", "a", "p", " ", "s", "e", "n", "d", " ", " ", ":", " ", "S",
    "t", "r", "e", "a", "m", " ", "1", "2", "8", "x", "1", "2", "8", " ", "B", "M",
    "P", " ", "i", "m", "a", "g", "e", "\n", "/", "b", "i", "t", "m", "a", "p", " ",
    "c", "l", "e", "a", "r", " ", ":", " ", "C", "l", "e", "a", "r", " ", "d", "y",
    "n", "a", "m", "i", "c", " ", "b", "i", "t", "m", "a", "p", "\n", "/", "c", "l",
    "e", "a", "r", " ", " ", " ", " ", " ", " ", " ", " ", ":", " ", "C", "l", "e",
    "a", "r", " ", "c", "o", "n", "s", "o", "l", "e", " ", "t", "e", "x", "t", "\n"
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
  localparam logic [7:0] OS_SET_BYTES [0:20] = '{
    "O", "v", "e", "r", "s", "a", "m", "p", "l", "i", "n", "g", " ", "u", "p", "d", "a", "t", "e", "d", "\n"
  };
  localparam logic [7:0] TEST_START_BYTES [0:20] = '{
    "S", "t", "a", "r", "t", "i", "n", "g", " ", "B", "E", "R", " ", "t", "e", "s", "t", ".", ".", ".", "\n"
  };
  localparam logic [7:0] BITMAP_SEND_BYTES [0:17] = '{
    "S", "e", "n", "d", "i", "n", "g", " ", "b", "i", "t", "m", "a", "p", ".", ".", ".", "\n"
  };
  localparam logic [7:0] BITMAP_CLEAR_BYTES [0:14] = '{
    "B", "i", "t", "m", "a", "p", " ", "c", "l", "e", "a", "r", "e", "d", "\n"
  };
  localparam logic [7:0] UNKNOWN_CMD_BYTES [0:15] = '{
    "U", "n", "k", "n", "o", "w", "n", " ", "c", "o", "m", "m", "a", "n", "d", "\n"
  };
  localparam logic [7:0] ERR_DISCONN_BYTES [0:24] = '{
    "E", "r", "r", "o", "r", ":", " ", "L", "i", "n", "k", " ", "d", "i", "s", "c", "o", "n", "n", "e", "c", "t", "e", "d", "\n"
  };
  localparam logic [7:0] BAUD_NEGO_BYTES [0:23] = '{
    "R", "e", "q", "u", "e", "s", "t", "i", "n", "g", " ", "b", "a", "u", "d", " ", "c", "h", "a", "n", "g", "e", ".", "\n"
  };
  localparam logic [7:0] BAUD_SYNC_BYTES [0:21] = '{
    "B", "a", "u", "d", " ", "s", "y", "n", "c", "h", "r", "o", "n", "i", "z", "e", "d", " ", "O", "K", "!", "\n"
  };
  localparam logic [7:0] REMOTE_BAUD_BYTES [0:22] = '{
    "R", "e", "m", "o", "t", "e", " ", "b", "a", "u", "d", " ", "c", "h", "a", "n", "g", "e", " ", "a", "c", "k", "\n"
  };
  localparam logic [7:0] PING_START_BYTES [0:15] = '{
    "P", "i", "n", "g", "i", "n", "g", " ", "l", "i", "n", "k", ".", ".", ".", "\n"
  };
  localparam logic [7:0] SWEEP_START_BYTES [0:27] = '{
    "-", "-", "-", " ", "B", "a", "u", "d", "r", "a", "t", "e", " ", "S", "w", "e", "e", "p", " ", "T", "e", "s", "t", " ", "-", "-", "-", "\n"
  };
  localparam logic [7:0] SWEEP_DONE_BYTES [0:21] = '{
    "S", "w", "e", "e", "p", " ", "t", "e", "s", "t", " ", "c", "o", "m", "p", "l", "e", "t", "e", "d", "!", "\n"
  };

  localparam logic [7:0] PING_LOOP_PREFIX [0:16] = '{"P","i","n","g"," ","(","L","o","o","p","b","a","c","k",")",":"," "};
  localparam logic [7:0] PING_REM_PREFIX  [0:14] = '{"P","i","n","g"," ","(","R","e","m","o","t","e",")",":"," "};
  localparam logic [7:0] PING_TIMEOUT_STR [0:13] = '{"P","i","n","g"," ","t","i","m","e","o","u","t",".","\n"};
  localparam logic [7:0] PING_CYC_STR     [0:8]  = '{" ","c","y","c","l","e","s"," ","("};
  localparam logic [7:0] PING_US_STR      [0:4]  = '{" ","u","s",")","\n"};

  // Baudrate Sweep Pre-formatted Constant Lines
  localparam logic [7:0] SWEEP_PASS_STR [0:10][0:20] = '{
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "1", "0", "0", "k", " ", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "1", ".", "0", "0", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "1", "6", "x", " ", "1", ".", "2", "5", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "2", ".", "5", "0", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "3", ".", "1", "2", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "1", "6", "x", " ", "3", ".", "1", "2", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "5", ".", "0", "0", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "1", "6", "x", " ", "6", ".", "2", "5", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "8", ".", "3", "3", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "1", "2", ".", "5", "M", ":", " ", "O", "K", "\n"},
    '{"[", "P", "A", "S", "S", "]", " ", "8", "x", " ", " ", "2", "5", ".", "0", "M", ":", " ", "O", "K", "\n"}
  };

  localparam logic [7:0] SWEEP_FAIL_STR [0:10][0:25] = '{
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "1", "0", "0", "k", " ", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "1", ".", "0", "0", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "1", "6", "x", " ", "1", ".", "2", "5", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "2", ".", "5", "0", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "3", ".", "1", "2", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "1", "6", "x", " ", "3", ".", "1", "2", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "5", ".", "0", "0", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "1", "6", "x", " ", "6", ".", "2", "5", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "8", ".", "3", "3", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "1", "2", ".", "5", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"},
    '{"[", "F", "A", "I", "L", "]", " ", "8", "x", " ", " ", "2", "5", ".", "0", "M", ":", " ", "T", "i", "m", "e", "o", "u", "t", "\n"}
  };

  logic [7:0] current_msg_char;
  always_comb begin
    case (msg_src)
      SRC_INPUT_ECHO:     current_msg_char = input_buf[msg_idx];
      SRC_HELP:           current_msg_char = HELP_BYTES[msg_idx];
      SRC_STATUS_DISCONN: current_msg_char = STATUS_DISCONN_BYTES[msg_idx];
      SRC_STATUS_CONN:    current_msg_char = STATUS_CONN_BYTES[msg_idx];
      SRC_STATUS_LOOP:    current_msg_char = STATUS_LOOP_BYTES[msg_idx];
      SRC_BAUD_SET:       current_msg_char = BAUD_SET_BYTES[msg_idx];
      SRC_OS_SET:         current_msg_char = OS_SET_BYTES[msg_idx];
      SRC_TEST:           current_msg_char = TEST_START_BYTES[msg_idx];
      SRC_BITMAP_SEND:    current_msg_char = BITMAP_SEND_BYTES[msg_idx];
      SRC_BITMAP_CLEAR:   current_msg_char = BITMAP_CLEAR_BYTES[msg_idx];
      SRC_UNKNOWN:        current_msg_char = UNKNOWN_CMD_BYTES[msg_idx];
      SRC_ERR_DISCONN:    current_msg_char = ERR_DISCONN_BYTES[msg_idx];
      SRC_BAUD_NEGO:      current_msg_char = BAUD_NEGO_BYTES[msg_idx];
      SRC_BAUD_SYNC:      current_msg_char = BAUD_SYNC_BYTES[msg_idx];
      SRC_REMOTE_BAUD:    current_msg_char = REMOTE_BAUD_BYTES[msg_idx];
      SRC_PING_START:     current_msg_char = PING_START_BYTES[msg_idx];
      SRC_PING_MSG:       current_msg_char = ping_msg_buf[msg_idx];
      SRC_SWEEP_START:    current_msg_char = SWEEP_START_BYTES[msg_idx];
      SRC_SWEEP_PASS:     current_msg_char = SWEEP_PASS_STR[sweep_step][msg_idx];
      SRC_SWEEP_FAIL:     current_msg_char = SWEEP_FAIL_STR[sweep_step][msg_idx];
      SRC_SWEEP_DONE:     current_msg_char = SWEEP_DONE_BYTES[msg_idx];
      SRC_RX_CHAR:        current_msg_char = rx_char_hold;
      default:            current_msg_char = 8'h00;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_INIT;
      state_after_scroll <= S_IDLE;
      mode_text <= 1'b0;
      input_len <= 11'd2;
      show_popup <= 1'b0;
      show_progress <= 1'b0;
      progress_val <= '0;
      popup_mode <= POPUP_NONE;
      input_cursor <= 11'd2;

      msg_src <= SRC_NONE;
      msg_idx <= '0;
      msg_len <= '0;
      ping_msg_len <= '0;
      ping_is_timeout <= 1'b0;
      ping_is_loopback <= 1'b0;
      bcd_reg <= '0;
      bin_reg <= '0;
      bcd_cnt <= '0;

      console_write_ptr <= '0;
      init_idx <= '0;
      clear_idx <= '0;
      scroll_src <= '0;
      scroll_dst <= '0;
      input_update_idx <= '0;
      clear_bmp_idx <= '0;
      tx_pixel_cnt <= '0;
      rx_pixel_ptr <= '0;
      text_send_idx <= '0;
      prng_next_pixel <= 1'b0;
      hs_tx_ack <= 1'b0;

      console_line_cnt <= 6'd0;
      console_col_cnt  <= 7'd0;
      rx_char_hold     <= 8'h00;
      hist_check_idx   <= 2'd0;
      hist_match_idx   <= 2'd0;
      hist_matched     <= 1'b0;
      fmt_ptr          <= 6'd0;
      fmt_phase        <= 3'd0;
      fmt_digit_idx    <= 4'd0;
      fmt_text_idx     <= 4'd0;
      fmt_lead_zero    <= 1'b1;
      for (int i = 0; i < 8; i++) bcd_d[i] <= 4'd0;
      history_count <= '0;
      history_pos   <= '0;
      for (int h = 0; h < 4; h++) begin
        history_len[h] <= '0;
        for (int c = 0; c < 64; c++) history_buf[h][c] <= 8'h00;
      end

      pending_baud_req    <= '0;
      pending_baud_nego   <= 1'b0;
      pending_nego_ack_tx <= 1'b0;
      nego_ack_payload    <= '0;

      ping_active        <= 1'b0;
      ping_timer         <= '0;
      ping_rtt_cycles    <= '0;
      pending_ping_reply <= 1'b0;

      sweep_step      <= '0;
      sweep_timer     <= '0;
      sweep_pass_mask <= '0;
      sweep_active    <= 1'b0;

      rx_line_start <= 1'b1;
      rx_fifo_head  <= '0;
      rx_fifo_tail  <= '0;
      rx_fifo_count <= '0;

      eval_proto_baud_rate    <= 4'd0;
      eval_proto_oversampling <= 4'd0;
      eval_proto_loopback_en  <= 1'b0;
      eval_proto_tx_valid     <= 1'b0;
      eval_proto_tx_type      <= '0;
      eval_proto_tx_data      <= '0;

      console_we   <= 1'b0;
      console_addr <= '0;
      console_din  <= '0;
      input_we     <= 1'b0;
      input_addr   <= '0;
      input_din    <= '0;
      bmp_we       <= 1'b0;
      bmp_addr     <= '0;
      bmp_din      <= '0;

      for (int i = 0; i < 48; i++) ping_msg_buf[i] <= 8'h00;
      for (int i = 0; i < CLI_BUF_LEN; i++) input_buf[i] <= 8'h00;
      for (int i = 0; i < 4; i++) rx_fifo_chars[i] <= 8'h00;

    end else begin
      // Default single-cycle pulse resets
      console_we          <= 1'b0;
      input_we            <= 1'b0;
      bmp_we              <= 1'b0;
      hs_tx_ack           <= 1'b0;
      prng_next_pixel     <= 1'b0;
      if (eval_proto_tx_valid && !proto_eval_tx_full) begin
        eval_proto_tx_valid <= 1'b0;
      end

      // Ping timer tick
      if (ping_active) begin
        ping_timer <= ping_timer + 32'd1;
        if (ping_timer >= 32'd100_000_000) begin // 1.0s timeout at 100MHz
          ping_active      <= 1'b0;
          ping_is_timeout  <= 1'b1;
          ping_is_loopback <= (link_status == 2'b10);
          state            <= S_PING_BCD_INIT;
        end
      end

// Fake loopback self-reply removed: real packet transit through optical TX/RX is measured

      // Process Incoming Protocol Packets
      if (proto_eval_rx_valid) begin
        if (proto_eval_rx_type == MSG_TEXT) begin
          if (rx_line_start) begin
            if (rx_fifo_count < 3'd3) begin
              rx_fifo_chars[rx_fifo_head] <= "<";
              rx_fifo_head <= rx_fifo_head + 2'd1;
              rx_fifo_chars[rx_fifo_head + 2'd1] <= " ";
              rx_fifo_head <= rx_fifo_head + 2'd2;
              rx_fifo_chars[rx_fifo_head + 2'd2] <= proto_eval_rx_data;
              rx_fifo_head <= rx_fifo_head + 2'd3;
              rx_fifo_count <= rx_fifo_count + 3'd3;
            end
            rx_line_start <= 1'b0;
          end else begin
            if (rx_fifo_count < 3'd4) begin
              rx_fifo_chars[rx_fifo_head] <= proto_eval_rx_data;
              rx_fifo_head  <= rx_fifo_head + 2'd1;
              rx_fifo_count <= rx_fifo_count + 3'd1;
            end
          end
          if (proto_eval_rx_data == 8'h0A || proto_eval_rx_data == 8'h0D) rx_line_start <= 1'b1;
        end else if (proto_eval_rx_type == MSG_BITMAP) begin
          bmp_addr <= rx_pixel_ptr;
          bmp_din  <= {proto_eval_rx_data[7:4], proto_eval_rx_data[3:0], proto_eval_rx_data[7:4]};
          bmp_we   <= 1'b1;
          if (rx_pixel_ptr == 14'd16383) rx_pixel_ptr <= 14'd0;
          else rx_pixel_ptr <= rx_pixel_ptr + 14'd1;
        end else if (proto_eval_rx_type == MSG_REQUEST) begin
          if (proto_eval_rx_data == PING_TOKEN) begin
            if (ping_active) begin
              ping_active      <= 1'b0;
              ping_rtt_cycles  <= ping_timer;
              ping_is_timeout  <= 1'b0;
              ping_is_loopback <= (link_status == 2'b10);
              state            <= S_PING_BCD_INIT;
            end else begin
              pending_ping_reply <= 1'b1;
            end
          end else begin
            eval_proto_baud_rate    <= proto_eval_rx_data[3:0];
            eval_proto_oversampling <= proto_eval_rx_data[7:4];
            pending_nego_ack_tx     <= 1'b1;
            nego_ack_payload        <= proto_eval_rx_data;
            if (state == S_IDLE) begin
              msg_src <= SRC_REMOTE_BAUD;
              msg_idx <= '0;
              msg_len <= 11'd23;
              state   <= S_PRINT_MSG;
            end
          end
        end else if (proto_eval_rx_type == MSG_ACCEPT) begin
          if (proto_eval_rx_data == PING_TOKEN && ping_active) begin
            ping_active      <= 1'b0;
            ping_rtt_cycles  <= ping_timer;
            ping_is_timeout  <= 1'b0;
            ping_is_loopback <= 1'b0;
            state            <= S_PING_BCD_INIT;
          end else if (pending_baud_nego) begin
            eval_proto_baud_rate    <= pending_baud_req[3:0];
            eval_proto_oversampling <= pending_baud_req[7:4];
            pending_baud_nego       <= 1'b0;
            if (state == S_IDLE) begin
              msg_src <= SRC_BAUD_SYNC;
              msg_idx <= '0;
              msg_len <= 11'd23;
              state   <= S_PRINT_MSG;
            end
          end
        end
      end

      // Drain RX FIFO to console BRAM safely when controller is in S_IDLE
      if (state == S_IDLE && rx_fifo_count > 0) begin
        rx_char_hold  <= rx_fifo_chars[rx_fifo_tail];
        rx_fifo_tail  <= rx_fifo_tail + 2'd1;
        rx_fifo_count <= rx_fifo_count - 3'd1;
        msg_src       <= SRC_RX_CHAR;
        msg_idx       <= '0;
        msg_len       <= 11'd1;
        state         <= S_PRINT_MSG;
      end

      // Packet arbitration for Handshake / Baud Negotiation / Ping
      if (state != S_BITMAP_SEND && state != S_TEXT_SEND && !proto_eval_tx_full) begin
        if (pending_ping_reply) begin
          eval_proto_tx_valid <= 1'b1;
          eval_proto_tx_type  <= MSG_ACCEPT;
          eval_proto_tx_data  <= PING_TOKEN;
          pending_ping_reply  <= 1'b0;
        end else if (pending_nego_ack_tx) begin
          eval_proto_tx_valid <= 1'b1;
          eval_proto_tx_type  <= MSG_ACCEPT;
          eval_proto_tx_data  <= nego_ack_payload;
          pending_nego_ack_tx <= 1'b0;
        end else if (pending_baud_nego) begin
          eval_proto_tx_valid <= 1'b1;
          eval_proto_tx_type  <= MSG_REQUEST;
          eval_proto_tx_data  <= pending_baud_req;
        end else if (hs_tx_req) begin
          eval_proto_tx_valid <= 1'b1;
          eval_proto_tx_type  <= hs_tx_type;
          eval_proto_tx_data  <= hs_tx_data;
          hs_tx_ack           <= 1'b1;
        end
      end

      // Main State Machine
      case (state)
        S_INIT: begin
          input_buf[0] <= 8'h3E; // '>'
          input_buf[1] <= 8'h20; // ' '

          console_addr <= init_idx;
          console_din  <= BANNER_BYTES[init_idx];
          console_we   <= 1'b1;

          if (init_idx == 6'd56) begin
            console_write_ptr <= 10'd57;
            input_update_idx  <= 7'd0;
            state <= S_UPDATE_INPUT_RAM;
          end else begin
            init_idx <= init_idx + 6'd1;
          end
        end

        S_IDLE: begin
          if (mode_text) begin
            if (cmd_esc) begin
              mode_text <= 1'b0;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (cmd_enter) begin
              input_buf[input_len[6:0]] <= 8'h0A;
              msg_src <= SRC_INPUT_ECHO;
              msg_idx <= '0;
              msg_len <= 11'(input_len + 1);
              state   <= S_PRINT_MSG;
            end else if (cmd_up) begin
              if (history_count > 0 && history_pos < history_count) begin
                logic [1:0] load_idx;
                load_idx = history_pos[1:0];
                input_len    <= 11'(history_len[load_idx] + 2);
                input_cursor <= 11'(history_len[load_idx] + 2);
                for (int i = 2; i < CLI_BUF_LEN; i++) begin
                  if ((i - 2) < history_len[load_idx] && (i - 2) < HIST_BUF_LEN) input_buf[i] <= history_buf[load_idx][i-2];
                  else input_buf[i] <= 8'h00;
                end
                history_pos <= history_pos + 3'd1;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end
            end else if (cmd_down) begin
              if (history_pos > 1) begin
                logic [1:0] load_idx;
                history_pos <= history_pos - 3'd1;
                load_idx = 2'(history_pos[1:0] - 2'd2);
                input_len    <= 11'(history_len[load_idx] + 2);
                input_cursor <= 11'(history_len[load_idx] + 2);
                for (int i = 2; i < CLI_BUF_LEN; i++) begin
                  if ((i - 2) < history_len[load_idx] && (i - 2) < HIST_BUF_LEN) input_buf[i] <= history_buf[load_idx][i-2];
                  else input_buf[i] <= 8'h00;
                end
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end else if (history_pos == 1) begin
                history_pos  <= 3'd0;
                input_len    <= 11'd2;
                input_cursor <= 11'd2;
                for (int i = 2; i < CLI_BUF_LEN; i++) input_buf[i] <= 8'h00;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end
            end else if (char_valid && input_len < (CLI_BUF_LEN - 2)) begin
              input_buf[input_len[6:0]] <= char_ascii;
              input_cursor <= input_len + 1;
              input_len    <= input_len + 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (cmd_backspace && input_len > 2) begin
              input_buf[input_len[6:0] - 1] <= 8'h00;
              input_cursor <= input_len - 1;
              input_len    <= input_len - 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end else begin
            // Navigation mode: Process Button Activations
            if (cmd_enter) begin
              case (ui_selected_item)
                ITEM_INPUT: begin
                  mode_text <= 1'b1;
                  input_update_idx <= 7'd0;
                  state <= S_UPDATE_INPUT_RAM;
                end
                ITEM_HELP_BTN: begin
                  msg_src <= SRC_HELP;
                  msg_idx <= '0;
                  msg_len <= 11'd464;
                  state   <= S_PRINT_MSG;
                end
                ITEM_PING_BTN: begin
                  if (link_status == 2'b00) begin
                    msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
                  end else begin
                    ping_active <= 1'b1;
                    ping_timer  <= '0;
                    eval_proto_tx_valid <= 1'b1;
                    eval_proto_tx_type  <= MSG_REQUEST;
                    eval_proto_tx_data  <= PING_TOKEN;
                    msg_src <= SRC_PING_START; msg_len <= 11'd16;
                  end
                  msg_idx <= '0;
                  state   <= S_PRINT_MSG;
                end
                ITEM_SWEEP_BTN: begin
                  if (link_status == 2'b00) begin
                    msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
                    msg_idx <= '0;
                    state   <= S_PRINT_MSG;
                  end else begin
                    sweep_step      <= 4'd0;
                    sweep_timer     <= '0;
                    sweep_pass_mask <= '0;
                    sweep_active    <= 1'b1;
                    show_popup      <= 1'b1;
                    show_progress   <= 1'b1;
                    popup_mode      <= POPUP_PROGRESS;
                    progress_val    <= 8'd0;
                    msg_src         <= SRC_SWEEP_START;
                    msg_idx         <= '0;
                    msg_len         <= 11'd28;
                    state           <= S_PRINT_MSG;
                  end
                end
                ITEM_SNDBMP_BTN: begin
                  if (link_status == 2'b00) begin
                    msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
                    msg_idx <= '0;
                    state   <= S_PRINT_MSG;
                  end else begin
                    show_popup    <= 1'b1;
                    show_progress <= 1'b1;
                    popup_mode    <= POPUP_PROGRESS;
                    progress_val  <= 8'd0;
                    tx_pixel_cnt  <= '0;
                    state         <= S_BITMAP_SEND;
                  end
                end
                ITEM_CLRBMP_BTN: begin
                  clear_bmp_idx <= 14'd0;
                  state         <= S_CLEAR_BITMAP;
                end
                ITEM_CLRCON_BTN: begin
                  clear_idx <= 10'd0;
                  state_after_scroll <= S_IDLE;
                  state     <= S_CLEAR_CONSOLE;
                end
                ITEM_ABOUT_BTN: begin
                  show_popup    <= 1'b1;
                  show_progress <= 1'b0;
                  popup_mode    <= POPUP_ABOUT;
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
        end

        // Sequential Command History Deduplication & MRU Reordering FSM
        S_HIST_SCAN: begin
          if (hist_check_idx < history_count && history_len[hist_check_idx] == 7'(input_len - 2)) begin
            bit match;
            match = 1'b1;
            for (int c = 0; c < HIST_BUF_LEN; c++) begin
              if (c < input_len - 2 && input_buf[c+2] != history_buf[hist_check_idx][c]) match = 1'b0;
            end
            if (match) begin
              hist_matched   <= 1'b1;
              hist_match_idx <= hist_check_idx;
              state          <= S_HIST_UPDATE;
            end else if (hist_check_idx == 2'd3 || hist_check_idx == 2'(history_count - 1)) begin
              hist_matched <= 1'b0;
              state        <= S_HIST_UPDATE;
            end else begin
              hist_check_idx <= hist_check_idx + 2'd1;
            end
          end else if (hist_check_idx == 2'd3 || hist_check_idx == 2'(history_count - 1)) begin
            hist_matched <= 1'b0;
            state        <= S_HIST_UPDATE;
          end else begin
            hist_check_idx <= hist_check_idx + 2'd1;
          end
        end

        S_HIST_UPDATE: begin
          if (hist_matched) begin
            // Match found: promote hist_match_idx to entry 0 (MRU), shift newer entries down
            case (hist_match_idx)
              2'd0: begin
                // Already at MRU, update contents
                for (int c = 0; c < HIST_BUF_LEN; c++) history_buf[0][c] <= (c < input_len - 2) ? input_buf[c+2] : 8'h00;
                history_len[0] <= 7'(input_len - 2);
              end
              2'd1: begin
                history_buf[1] <= history_buf[0]; history_len[1] <= history_len[0];
                for (int c = 0; c < HIST_BUF_LEN; c++) history_buf[0][c] <= (c < input_len - 2) ? input_buf[c+2] : 8'h00;
                history_len[0] <= 7'(input_len - 2);
              end
              2'd2: begin
                history_buf[2] <= history_buf[1]; history_len[2] <= history_len[1];
                history_buf[1] <= history_buf[0]; history_len[1] <= history_len[0];
                for (int c = 0; c < HIST_BUF_LEN; c++) history_buf[0][c] <= (c < input_len - 2) ? input_buf[c+2] : 8'h00;
                history_len[0] <= 7'(input_len - 2);
              end
              2'd3: begin
                history_buf[3] <= history_buf[2]; history_len[3] <= history_len[2];
                history_buf[2] <= history_buf[1]; history_len[2] <= history_len[1];
                history_buf[1] <= history_buf[0]; history_len[1] <= history_len[0];
                for (int c = 0; c < HIST_BUF_LEN; c++) history_buf[0][c] <= (c < input_len - 2) ? input_buf[c+2] : 8'h00;
                history_len[0] <= 7'(input_len - 2);
              end
            endcase
          end else begin
            // Brand new command: shift older commands down, insert at entry 0 (MRU)
            history_buf[3] <= history_buf[2]; history_len[3] <= history_len[2];
            history_buf[2] <= history_buf[1]; history_len[2] <= history_len[1];
            history_buf[1] <= history_buf[0]; history_len[1] <= history_len[0];
            for (int c = 0; c < HIST_BUF_LEN; c++) history_buf[0][c] <= (c < input_len - 2) ? input_buf[c+2] : 8'h00;
            history_len[0] <= 7'(input_len - 2);
            if (history_count < 3'd4) history_count <= history_count + 3'd1;
          end
          history_pos <= 3'd0;
          state <= S_PROCESS_CMD;
        end

        S_PROCESS_CMD: begin
          // Parse commands
          if (input_len > 2 && input_buf[2] == "/") begin
            if (input_len >= 7 && input_buf[3]=="h" && input_buf[4]=="e" && input_buf[5]=="l" && input_buf[6]=="p") begin
              msg_src <= SRC_HELP;
              msg_idx <= '0;
              msg_len <= 11'd464;
              state <= S_PRINT_MSG;
            end else if (input_len >= 9 && input_buf[3]=="s" && input_buf[4]=="t" && input_buf[5]=="a" && input_buf[6]=="t" && input_buf[7]=="u" && input_buf[8]=="s") begin
              if (link_status == 2'b00) msg_src <= SRC_STATUS_DISCONN;
              else if (link_status == 2'b01) msg_src <= SRC_STATUS_CONN;
              else msg_src <= SRC_STATUS_LOOP; msg_len <= 11'd19;
              state <= S_PRINT_MSG;
            end else if (input_len >= 11 && input_buf[3]=="l" && input_buf[4]=="o" && input_buf[5]=="o" && input_buf[6]=="p" && input_buf[7]=="b" && input_buf[8]=="a" && input_buf[9]=="c" && input_buf[10]=="k") begin
              eval_proto_loopback_en <= ~eval_proto_loopback_en;
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (input_len >= 8 && input_buf[3]=="c" && input_buf[4]=="l" && input_buf[5]=="e" && input_buf[6]=="a" && input_buf[7]=="r") begin
              clear_idx <= 10'd0;
              state_after_scroll <= S_IDLE;
              state     <= S_CLEAR_CONSOLE;
            end else if (input_len >= 7 && input_buf[3]=="p" && input_buf[4]=="i" && input_buf[5]=="n" && input_buf[6]=="g") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
              end else begin
                ping_active <= 1'b1;
                ping_timer  <= '0;
                eval_proto_tx_valid <= 1'b1;
                eval_proto_tx_type  <= MSG_REQUEST;
                eval_proto_tx_data  <= PING_TOKEN;
                msg_src <= SRC_PING_START; msg_len <= 11'd16;
              end
              state <= S_PRINT_MSG;
            end else if (input_len >= 5 && input_buf[3]=="o" && input_buf[4]=="s") begin
              if (input_len >= 7 && input_buf[6]=="1" && input_buf[7]=="6") begin
                if (link_status == 2'b01) begin
                  pending_baud_req  <= {4'd1, eval_proto_baud_rate};
                  pending_baud_nego <= 1'b1;
                  msg_src <= SRC_BAUD_NEGO; msg_len <= 11'd24;
                end else begin
                  eval_proto_oversampling <= 4'd1;
                  msg_src <= SRC_OS_SET; msg_len <= 11'd21;
                end
              end else if (input_buf[6]=="8") begin
                if (link_status == 2'b01) begin
                  pending_baud_req  <= {4'd0, eval_proto_baud_rate};
                  pending_baud_nego <= 1'b1;
                  msg_src <= SRC_BAUD_NEGO; msg_len <= 11'd24;
                end else begin
                  eval_proto_oversampling <= 4'd0;
                  msg_src <= SRC_OS_SET; msg_len <= 11'd21;
                end
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= S_PRINT_MSG;
            end else if (input_len >= 8 && input_buf[3]=="b" && input_buf[4]=="a" && input_buf[5]=="u" && input_buf[6]=="d" && input_buf[7]==" ") begin
              logic [3:0] target_rate;
              logic [3:0] target_os;
              logic       valid_rate;
              valid_rate = 1'b1;
              target_os   = eval_proto_oversampling;

              if (input_buf[8]=="1" && input_buf[9]=="0" && input_buf[10]=="0" && (input_buf[11]=="k" || input_buf[11]=="K" || input_len==11)) begin
                target_rate = 4'd0;
                target_os   = 4'd0;
              end else if (input_buf[8]=="1" && input_buf[9]=="." && input_buf[10]=="2" && input_buf[11]=="5") begin
                target_rate = 4'd1;
                target_os   = 4'd1;
              end else if (input_buf[8]=="1" && (input_buf[9]=="m" || input_buf[9]=="M" || input_len==9)) begin
                target_rate = 4'd1;
                target_os   = 4'd0;
              end else if (input_buf[8]=="2" && input_buf[9]=="." && input_buf[10]=="5") begin
                target_rate = 4'd2;
                target_os   = 4'd0;
              end else if (input_buf[8]=="2" && (input_buf[9]=="m" || input_buf[9]=="M" || input_len==9)) begin
                target_rate = 4'd2;
                target_os   = 4'd0;
              end else if (input_buf[8]=="3" && input_buf[9]=="." && input_buf[10]=="1" && input_buf[11]=="2") begin
                target_rate = 4'd3;
                target_os   = 4'd0;
              end else if (input_buf[8]=="5" && (input_buf[9]=="m" || input_buf[9]=="M" || input_len==9)) begin
                target_rate = 4'd4;
                target_os   = 4'd0;
              end else if (input_buf[8]=="6" && input_buf[9]=="." && input_buf[10]=="2") begin
                target_rate = 4'd5;
                target_os   = 4'd1;
              end else if (input_buf[8]=="8" && input_buf[9]=="." && input_buf[10]=="3") begin
                target_rate = 4'd5;
                target_os   = 4'd0;
              end else if (input_buf[8]=="1" && input_buf[9]=="2" && input_buf[10]=="." && input_buf[11]=="5") begin
                target_rate = 4'd6;
                target_os   = 4'd0;
              end else if (input_buf[8]=="2" && input_buf[9]=="5" && (input_buf[10]=="m" || input_buf[10]=="M" || input_len==10)) begin
                target_rate = 4'd7;
                target_os   = 4'd0;
              end else begin
                valid_rate = 1'b0;
              end

              if (valid_rate) begin
                if (link_status == 2'b01) begin
                  pending_baud_req  <= {target_os, target_rate};
                  pending_baud_nego <= 1'b1;
                  msg_src <= SRC_BAUD_NEGO; msg_len <= 11'd24;
                end else begin
                  eval_proto_baud_rate    <= target_rate;
                  eval_proto_oversampling <= target_os;
                  msg_src <= SRC_BAUD_SET; msg_len <= 11'd17;
                end
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= S_PRINT_MSG;
            end else if (input_len >= 10 && input_buf[3]=="b" && input_buf[4]=="i" && input_buf[5]=="t" && input_buf[6]=="m" && input_buf[7]=="a" && input_buf[8]=="p" && input_buf[9]==" ") begin
              if (input_len >= 14 && input_buf[10]=="s" && input_buf[11]=="e" && input_buf[12]=="n" && input_buf[13]=="d") begin
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
                  state   <= S_PRINT_MSG;
                end else begin
                  show_popup    <= 1'b1;
                  show_progress <= 1'b1;
                  popup_mode    <= POPUP_PROGRESS;
                  progress_val  <= 8'd0;
                  tx_pixel_cnt  <= '0;
                  state         <= S_BITMAP_SEND;
                end
              end else if (input_len >= 15 && input_buf[10]=="c" && input_buf[11]=="l" && input_buf[12]=="e" && input_buf[13]=="a" && input_buf[14]=="r") begin
                clear_bmp_idx <= 14'd0;
                state         <= S_CLEAR_BITMAP;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
                state   <= S_PRINT_MSG;
              end
            end else if (input_len >= 7 && input_buf[3]=="t" && input_buf[4]=="e" && input_buf[5]=="s" && input_buf[6]=="t") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25;
              end else if (input_len >= 12 && input_buf[8]=="p" && input_buf[9]=="i" && input_buf[10]=="n" && input_buf[11]=="g") begin
                ping_active <= 1'b1;
                ping_timer  <= '0;
                eval_proto_tx_valid <= 1'b1;
                eval_proto_tx_type  <= MSG_REQUEST;
                eval_proto_tx_data  <= PING_TOKEN;
                msg_src <= SRC_PING_START; msg_len <= 11'd16;
              end else if (input_len >= 13 && input_buf[8]=="s" && input_buf[9]=="w" && input_buf[10]=="e" && input_buf[11]=="e" && input_buf[12]=="p") begin
                sweep_step      <= 4'd0;
                sweep_timer     <= '0;
                sweep_pass_mask <= '0;
                sweep_active    <= 1'b1;
                show_popup      <= 1'b1;
                show_progress   <= 1'b1;
                popup_mode      <= POPUP_PROGRESS;
                progress_val    <= 8'd0;
                msg_src <= SRC_SWEEP_START; msg_len <= 11'd28;
              end else begin
                msg_src <= SRC_TEST; msg_len <= 11'd21;
              end
              state <= S_PRINT_MSG;
            end else begin
              msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              state <= S_PRINT_MSG;
            end
          end else begin
            // Non-slash text message: transmit over wire
            text_send_idx <= 11'd2;
            state <= S_TEXT_SEND;
          end
        end

        S_PRINT_MSG: begin
          if (console_line_cnt >= MAX_CONSOLE_LINES || console_write_ptr >= 10'd850) begin
            state_after_scroll <= S_PRINT_MSG;
            scan_idx           <= 10'd0;
            state              <= S_FIND_NL_READ;
          end else begin
            console_addr      <= console_write_ptr;
            console_din       <= current_msg_char;
            console_we        <= 1'b1;
            console_write_ptr <= (console_write_ptr == CONSOLE_MAX_LEN - 1) ? 10'd0 : console_write_ptr + 10'd1;

            if (current_msg_char == 8'h0A) begin
              console_line_cnt <= console_line_cnt + 6'd1;
              console_col_cnt  <= 7'd0;
            end else begin
              if (console_col_cnt >= 7'd95) begin
                console_line_cnt <= console_line_cnt + 6'd1;
                console_col_cnt  <= 7'd0;
              end else begin
                console_col_cnt  <= console_col_cnt + 7'd1;
              end
            end

            if (msg_idx + 1 == msg_len) begin
              if (msg_src == SRC_INPUT_ECHO) begin
                if (input_len > 2) begin
                  hist_check_idx <= 2'd0;
                  hist_match_idx <= 2'd0;
                  hist_matched   <= 1'b0;
                  state          <= S_HIST_SCAN;
                end else begin
                  state          <= S_PROCESS_CMD;
                end
              end else if (sweep_active) begin
                if (msg_src == SRC_SWEEP_START || msg_src == SRC_SWEEP_PASS || msg_src == SRC_SWEEP_FAIL) begin
                  if (sweep_step == 4'd10 && (msg_src == SRC_SWEEP_PASS || msg_src == SRC_SWEEP_FAIL)) begin
                    msg_src <= SRC_SWEEP_DONE;
                    msg_idx <= '0;
                    msg_len <= 11'd22;
                  end else begin
                    if (msg_src == SRC_SWEEP_PASS || msg_src == SRC_SWEEP_FAIL) sweep_step <= sweep_step + 4'd1;
                    state <= S_SWEEP_STEP;
                  end
                end else if (msg_src == SRC_SWEEP_DONE) begin
                  sweep_active  <= 1'b0;
                  show_popup    <= 1'b0;
                  show_progress <= 1'b0;
                  popup_mode    <= POPUP_NONE;
                  input_len     <= 11'd2;
                  input_cursor  <= 11'd2;
                  for (int i = 2; i < CLI_BUF_LEN; i++) input_buf[i] <= 8'h00;
                  input_update_idx <= 7'd0;
                  state <= S_UPDATE_INPUT_RAM;
                end
              end else begin
                input_len     <= 11'd2;
                input_cursor  <= 11'd2;
                for (int i = 2; i < CLI_BUF_LEN; i++) input_buf[i] <= 8'h00;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end
            end else begin
              msg_idx <= msg_idx + 11'd1;
            end
          end
        end

        // -------------------------------------------------------------------
        // Double-Dabble Binary to BCD Conversion for Ping Latency
        // -------------------------------------------------------------------
        S_PING_BCD_INIT: begin
          bcd_reg <= 32'd0;
          bin_reg <= ping_rtt_cycles;
          bcd_cnt <= 6'd0;
          state   <= S_PING_BCD_STEP;
        end

        S_PING_BCD_STEP: begin
          logic [3:0] n7, n6, n5, n4, n3, n2, n1, n0;
          n7 = (bcd_reg[31:28] >= 4'd5) ? (bcd_reg[31:28] + 4'd3) : bcd_reg[31:28];
          n6 = (bcd_reg[27:24] >= 4'd5) ? (bcd_reg[27:24] + 4'd3) : bcd_reg[27:24];
          n5 = (bcd_reg[23:20] >= 4'd5) ? (bcd_reg[23:20] + 4'd3) : bcd_reg[23:20];
          n4 = (bcd_reg[19:16] >= 4'd5) ? (bcd_reg[19:16] + 4'd3) : bcd_reg[19:16];
          n3 = (bcd_reg[15:12] >= 4'd5) ? (bcd_reg[15:12] + 4'd3) : bcd_reg[15:12];
          n2 = (bcd_reg[11:8]  >= 4'd5) ? (bcd_reg[11:8]  + 4'd3) : bcd_reg[11:8];
          n1 = (bcd_reg[7:4]   >= 4'd5) ? (bcd_reg[7:4]   + 4'd3) : bcd_reg[7:4];
          n0 = (bcd_reg[3:0]   >= 4'd5) ? (bcd_reg[3:0]   + 4'd3) : bcd_reg[3:0];

          bcd_reg <= {n7[2:0], n6, n5, n4, n3, n2, n1, n0, bin_reg[31]};
          bin_reg <= {bin_reg[30:0], 1'b0};

          if (bcd_cnt == 6'd31) begin
            // Latch digits for timing-clean sequential formatting (1 byte/cycle)
            bcd_d[7] <= n7;
            bcd_d[6] <= n6;
            bcd_d[5] <= n5;
            bcd_d[4] <= n4;
            bcd_d[3] <= n3;
            bcd_d[2] <= n2;
            bcd_d[1] <= n1;
            bcd_d[0] <= {n0[2:0], bin_reg[31]};
            fmt_ptr       <= 6'd0;
            fmt_phase     <= 3'd0;
            fmt_digit_idx <= 4'd7;
            fmt_text_idx  <= 4'd0;
            fmt_lead_zero <= 1'b1;
            state         <= S_PING_FMT_STEP;
          end else begin
            bcd_cnt <= bcd_cnt + 6'd1;
          end
        end

        // -------------------------------------------------------------------
        // Sequential Timing-Clean Ping String Formatter (1 byte / cycle)
        // -------------------------------------------------------------------
        S_PING_FMT_STEP: begin
          if (ping_is_timeout) begin
            if (fmt_ptr < 6'd14) begin
              ping_msg_buf[fmt_ptr] <= PING_TIMEOUT_STR[fmt_ptr[3:0]];
              fmt_ptr <= fmt_ptr + 6'd1;
            end else begin
              ping_msg_len <= 6'd14;
              msg_src      <= SRC_PING_MSG;
              msg_idx      <= '0;
              msg_len      <= 11'd14;
              state        <= S_PRINT_MSG;
            end
          end else begin
            case (fmt_phase)
              // Phase 0: Prefix String
              3'd0: begin
                if (ping_is_loopback) begin
                  ping_msg_buf[fmt_ptr] <= PING_LOOP_PREFIX[fmt_text_idx];
                  fmt_ptr       <= fmt_ptr + 6'd1;
                  fmt_text_idx  <= fmt_text_idx + 5'd1;
                  if (fmt_text_idx == 5'd16) begin
                    fmt_phase     <= 3'd1;
                    fmt_digit_idx <= 4'd7;
                    fmt_lead_zero <= 1'b1;
                  end
                end else begin
                  ping_msg_buf[fmt_ptr] <= PING_REM_PREFIX[fmt_text_idx];
                  fmt_ptr       <= fmt_ptr + 6'd1;
                  fmt_text_idx  <= fmt_text_idx + 5'd1;
                  if (fmt_text_idx == 5'd14) begin
                    fmt_phase     <= 3'd1;
                    fmt_digit_idx <= 4'd7;
                    fmt_lead_zero <= 1'b1;
                  end
                end
              end

              // Phase 1: Cycles Integer Digits (7 down to 0)
              3'd1: begin
                if (fmt_digit_idx == 4'd0 || bcd_d[fmt_digit_idx[2:0]] != 4'd0 || !fmt_lead_zero) begin
                  fmt_lead_zero         <= 1'b0;
                  ping_msg_buf[fmt_ptr] <= 8'h30 + bcd_d[fmt_digit_idx[2:0]];
                  fmt_ptr               <= fmt_ptr + 6'd1;
                end
                if (fmt_digit_idx == 4'd0) begin
                  fmt_phase    <= 3'd2;
                  fmt_text_idx <= 4'd0;
                end else begin
                  fmt_digit_idx <= fmt_digit_idx - 4'd1;
                end
              end

              // Phase 2: " cycles (" (9 characters)
              3'd2: begin
                ping_msg_buf[fmt_ptr] <= PING_CYC_STR[fmt_text_idx];
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 4'd1;
                if (fmt_text_idx == 4'd8) begin
                  fmt_phase     <= 3'd3;
                  fmt_digit_idx <= 4'd7;
                  fmt_lead_zero <= 1'b1;
                end
              end

              // Phase 3: Microseconds Integer Digits (7 down to 2)
              3'd3: begin
                if (fmt_digit_idx == 4'd2 || bcd_d[fmt_digit_idx[2:0]] != 4'd0 || !fmt_lead_zero) begin
                  fmt_lead_zero         <= 1'b0;
                  ping_msg_buf[fmt_ptr] <= 8'h30 + bcd_d[fmt_digit_idx[2:0]];
                  fmt_ptr               <= fmt_ptr + 6'd1;
                end
                if (fmt_digit_idx == 4'd2) begin
                  fmt_phase    <= 3'd4;
                  fmt_text_idx <= 4'd0;
                end else begin
                  fmt_digit_idx <= fmt_digit_idx - 4'd1;
                end
              end

              // Phase 4: Decimal point and 2 fractional digits
              3'd4: begin
                case (fmt_text_idx)
                  4'd0: begin
                    ping_msg_buf[fmt_ptr] <= 8'h2E; // '.'
                    fmt_ptr      <= fmt_ptr + 6'd1;
                    fmt_text_idx <= 4'd1;
                  end
                  4'd1: begin
                    ping_msg_buf[fmt_ptr] <= 8'h30 + bcd_d[1];
                    fmt_ptr      <= fmt_ptr + 6'd1;
                    fmt_text_idx <= 4'd2;
                  end
                  4'd2: begin
                    ping_msg_buf[fmt_ptr] <= 8'h30 + bcd_d[0];
                    fmt_ptr      <= fmt_ptr + 6'd1;
                    fmt_phase    <= 3'd5;
                    fmt_text_idx <= 4'd0;
                  end
                  default: fmt_phase <= 3'd5;
                endcase
              end

              // Phase 5: " us)\n" (5 characters)
              3'd5: begin
                ping_msg_buf[fmt_ptr] <= PING_US_STR[fmt_text_idx];
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 4'd1;
                if (fmt_text_idx == 4'd4) begin
                  ping_msg_len <= 6'(fmt_ptr + 1);
                  msg_src      <= SRC_PING_MSG;
                  msg_idx      <= '0;
                  msg_len      <= 11'(fmt_ptr + 1);
                  state        <= S_PRINT_MSG;
                end
              end
              default: state <= S_IDLE;
            endcase
          end
        end

        // -------------------------------------------------------------------
        // Baudrate Sweep FSM (Tests all 11 configurations)
        // -------------------------------------------------------------------
        S_SWEEP_STEP: begin
          eval_proto_baud_rate    <= SWEEP_BAUD[sweep_step];
          eval_proto_oversampling <= SWEEP_OS[sweep_step];
          sweep_timer             <= '0;
          sweep_step_passed       <= 1'b0;
          progress_val            <= 8'((255 * (sweep_step + 1)) / 11);
          state                   <= S_SWEEP_WAIT;
        end

        S_SWEEP_WAIT: begin
          // Send ping request after 2 ms (200,000 cycles) to allow clock settling
          if (sweep_timer == 32'd200_000) begin
            eval_proto_tx_valid <= 1'b1;
            eval_proto_tx_type  <= MSG_REQUEST;
            eval_proto_tx_data  <= PING_TOKEN;
          end

          // Check if ping token returned through receiver
          if (proto_eval_rx_valid && proto_eval_rx_type == MSG_REQUEST && proto_eval_rx_data == PING_TOKEN) begin
            sweep_step_passed <= 1'b1;
          end

          // 20 ms timeout (2,000,000 cycles at 100MHz) per step
          if (sweep_timer >= 32'd2_000_000) begin
            if (sweep_step_passed && link_status != 2'b00) begin
              sweep_pass_mask[sweep_step] <= 1'b1;
              msg_src <= SRC_SWEEP_PASS;
              msg_len <= 11'd21;
            end else begin
              sweep_pass_mask[sweep_step] <= 1'b0;
              msg_src <= SRC_SWEEP_FAIL;
              msg_len <= 11'd26;
            end
            msg_idx <= '0;
            state   <= S_PRINT_MSG;
          end else begin
            sweep_timer <= sweep_timer + 32'd1;
          end
        end

        // -------------------------------------------------------------------
        // Line-by-Line Synchronous Block RAM Console Auto-Scrolling
        // -------------------------------------------------------------------
        S_FIND_NL_READ: begin
          console_addr <= scan_idx;
          console_we   <= 1'b0;
          state        <= S_FIND_NL_WAIT;
        end

        S_FIND_NL_WAIT: begin
          state <= S_FIND_NL_CHECK;
        end

        S_FIND_NL_CHECK: begin
          if (console_dout == 8'h0A || scan_idx >= 10'd100 || scan_idx >= console_write_ptr) begin
            nl_len     <= scan_idx + 10'd1;
            scroll_src <= scan_idx + 10'd1;
            scroll_dst <= 10'd0;
            state      <= S_SCROLL_READ;
          end else begin
            scan_idx <= scan_idx + 10'd1;
            state    <= S_FIND_NL_READ;
          end
        end

        S_SCROLL_READ: begin
          console_addr <= scroll_src;
          console_we   <= 1'b0;
          state        <= S_SCROLL_WAIT;
        end

        S_SCROLL_WAIT: begin
          state <= S_SCROLL_WRITE;
        end

        S_SCROLL_WRITE: begin
          console_addr <= scroll_dst;
          console_din  <= (scroll_src < CONSOLE_MAX_LEN) ? console_dout : 8'h00;
          console_we   <= 1'b1;
          scroll_dst   <= scroll_dst + 10'd1;
          scroll_src   <= scroll_src + 10'd1;

          if (scroll_src >= console_write_ptr) begin
            clear_src <= scroll_dst + 10'd1;
            state     <= S_SCROLL_CLEAR;
          end else begin
            state <= S_SCROLL_READ;
          end
        end

        S_SCROLL_CLEAR: begin
          console_addr <= clear_src;
          console_din  <= 8'h00;
          console_we   <= 1'b1;
          if (clear_src >= console_write_ptr) begin
            console_write_ptr <= (console_write_ptr > nl_len) ? (console_write_ptr - nl_len) : 10'd0;
            console_line_cnt  <= (console_line_cnt > 0) ? (console_line_cnt - 6'd1) : 6'd0;
            state <= state_after_scroll;
          end else begin
            clear_src <= clear_src + 10'd1;
          end
        end

        S_TEXT_SEND: begin
          if (!eval_proto_tx_valid && !proto_eval_tx_full && text_send_idx <= input_len) begin
            eval_proto_tx_valid <= 1'b1;
            eval_proto_tx_type  <= MSG_TEXT;
            eval_proto_tx_data  <= (text_send_idx == input_len) ? 8'h0A : input_buf[text_send_idx];
            text_send_idx       <= text_send_idx + 11'd1;
          end else begin
            eval_proto_tx_valid <= 1'b0;
            if (text_send_idx > input_len) begin
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              for (int i = 2; i < CLI_BUF_LEN; i++) input_buf[i] <= 8'h00;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end
        end

        S_BITMAP_SEND: begin
          // Stream full 128x128 = 16384 pixels with backpressure
          if (!eval_proto_tx_valid && !proto_eval_tx_full && tx_pixel_cnt < 15'd16384) begin
            eval_proto_tx_valid <= 1'b1;
            eval_proto_tx_type  <= MSG_BITMAP;
            eval_proto_tx_data  <= prng_pixel_byte;
            prng_next_pixel     <= 1'b1;
            tx_pixel_cnt        <= tx_pixel_cnt + 15'd1;
            progress_val <= (tx_pixel_cnt >= 15'd16384) ? 8'd255 : 8'(tx_pixel_cnt[13:6]);
          end else begin
            eval_proto_tx_valid <= 1'b0;
            prng_next_pixel     <= 1'b0;
            if (tx_pixel_cnt == 15'd16384) begin
              show_popup    <= 1'b0;
              show_progress <= 1'b0;
              popup_mode    <= POPUP_NONE;
              progress_val  <= 8'd0;
              input_len     <= 11'd2;
              input_cursor  <= 11'd2;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end
        end

        S_CLEAR_BITMAP: begin
          // Clear all 16384 pixels
          bmp_addr <= clear_bmp_idx;
          bmp_din  <= 12'h000;
          bmp_we   <= 1'b1;
          if (clear_bmp_idx == 14'd16383) begin
            rx_pixel_ptr <= 14'd0;
            input_len <= 11'd2;
            input_cursor <= 11'd2;
            input_update_idx <= 7'd0;
            state <= S_UPDATE_INPUT_RAM;
          end else begin
            clear_bmp_idx <= clear_bmp_idx + 14'd1;
          end
        end

        S_CLEAR_CONSOLE: begin
          console_addr <= clear_idx;
          console_din  <= 8'h00;
          console_we   <= 1'b1;

          if (clear_idx == CONSOLE_MAX_LEN - 1) begin
            console_write_ptr <= 10'd0;
            console_line_cnt  <= 6'd0;
            console_col_cnt   <= 7'd0;
            input_len <= 11'd2;
            input_cursor <= 11'd2;
            input_update_idx <= 7'd0;
            state <= S_UPDATE_INPUT_RAM;
          end else begin
            clear_idx <= clear_idx + 10'd1;
          end
        end

        S_UPDATE_INPUT_RAM: begin
          input_addr <= input_update_idx;
          input_we   <= 1'b1;
          if (input_update_idx < input_cursor && input_update_idx < CLI_BUF_LEN) begin
            input_din <= input_buf[input_update_idx[6:0]];
          end else if (input_update_idx == input_cursor) begin
            if (mode_text) input_din <= 8'h5F; // '_'
            else if (input_update_idx < input_len && input_update_idx < CLI_BUF_LEN) input_din <= input_buf[input_update_idx[6:0]];
            else input_din <= 8'h00;
          end else if (input_update_idx <= input_len && input_update_idx < CLI_BUF_LEN) begin
            if (mode_text) input_din <= input_buf[input_update_idx[6:0] - 1];
            else input_din <= input_buf[input_update_idx[6:0]];
          end else begin
            input_din <= 8'h00;
          end

          if (input_update_idx == INPUT_MAX_LEN - 1) begin
            state <= S_IDLE;
          end else begin
            input_update_idx <= input_update_idx + 7'd1;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
