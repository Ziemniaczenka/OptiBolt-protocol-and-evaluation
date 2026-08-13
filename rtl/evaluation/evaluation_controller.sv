/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Master FSM managing tests, console text processing, CLI commands, and UI Popups.
 * This module acts as the controller for the evaluation platform, writing data
 * directly to the shared display BRAM memory for top_display to render.
 */

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

    // --- RAM Outputs ---
    output logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr,
    output logic                                           console_we,
    output logic [                                    7:0] console_din,

    output logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr,
    output logic                                         input_we,
    output logic [                                  7:0] input_din,

    output logic [11:0] bmp_addr,
    output logic        bmp_we,
    output logic [11:0] bmp_din,

    input  logic [3:0] ui_selected_item,
    output logic       mode_text,
    output logic       show_popup,
    output logic       show_progress,
    output logic [7:0] progress_val,

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

  import string_pkg::*;
  import ui_pkg::*;
  import protocol_pkg::*;

  typedef enum logic [2:0] {
    S_INIT,
    S_IDLE,
    S_PROCESS_CMD,
    S_PRINT_MSG,
    S_CLEAR_CONSOLE,
    S_UPDATE_INPUT_RAM
  } state_t;
  state_t state;

  typedef enum logic [3:0] {
    SRC_NONE,
    SRC_INPUT_ECHO,
    SRC_HELP,
    SRC_STATUS,
    SRC_BAUD_100K,
    SRC_BAUD_1M,
    SRC_BAUD_2M,
    SRC_BAUD_10M,
    SRC_TEST
  } msg_src_t;

  msg_src_t msg_src;
  logic [10:0] msg_idx;
  logic [10:0] msg_len;

  // Input Buffer (128 bytes)
  logic [7:0] input_buf [0:INPUT_MAX_LEN-1];
  logic [10:0] input_len;
  logic [10:0] input_cursor;

  // Console BRAM Write Pointer (Direct BRAM Output)
  logic [9:0] console_write_ptr;
  logic [9:0] clear_idx;
  logic [6:0] input_update_idx;
  logic [5:0] init_idx;

  // Commands and other strings
  localparam logic [7:0] BANNER_BYTES [0:56] = '{
    "O", "p", "t", "i", "B", "o", "l", "t", " ", "O", "S", " ", "v", "1", ".", "0", "\n",
    "S", "y", "s", "t", "e", "m", " ", "R", "e", "a", "d", "y", ".", "\n",
    "T", "y", "p", "e", " ", "'", "h", "e", "l", "p", "'", " ", "f", "o", "r", " ", "c", "o", "m", "m", "a", "n", "d", "s", ".", "\n"
  };

  localparam logic [7:0] HELP_BYTES [0:74] = '{
    "C", "o", "m", "m", "a", "n", "d", "s", ":", "\n",
    " ", "b", "a", "u", "d", " ", "<", "1", "0", "0", "k", "|", "1", "m", "|", "2", "m", "|", "1", "0", "m", ">", "\n",
    " ", "t", "e", "s", "t", " ", "<", "1", "|", "2", "|", "b", "e", "r", "|", "p", "i", "n", "g", ">", "\n",
    " ", "c", "l", "e", "a", "r", "\n",
    " ", "s", "t", "a", "t", "u", "s", "\n",
    " ", "h", "e", "l", "p", "\n"
  };

  localparam logic [7:0] STATUS_BYTES [0:29] = '{
    "S", "t", "a", "t", "u", "s", ":", " ", "B", "a", "u", "d", "=", "1", "M", " ",
    "L", "i", "n", "k", "=", "O", "K", " ", "B", "E", "R", "=", "0", "\n"
  };

  localparam logic [7:0] ERR_PARITY_BYTES [0:12] = '{
    "[", "E", "R", "R", ":", "P", "a", "r", "i", "t", "y", "]", "\n"
  };

  localparam logic [7:0] ERR_MANCH_BYTES [0:16] = '{
    "[", "E", "R", "R", ":", "M", "a", "n", "c", "h", "e", "s", "t", "e", "r", "]", "\n"
  };

  localparam logic [7:0] ERR_PREAMBLE_BYTES [0:14] = '{
    "[", "E", "R", "R", ":", "P", "r", "e", "a", "m", "b", "l", "e", "]", "\n"
  };

  localparam logic [7:0] BAUD_100K_BYTES [0:14] = '{
    "B", "a", "u", "d", " ", "s", "e", "t", ":", " ", "1", "0", "0", "k", "\n"
  };

  localparam logic [7:0] BAUD_1M_BYTES [0:12] = '{
    "B", "a", "u", "d", " ", "s", "e", "t", ":", " ", "1", "M", "\n"
  };

  localparam logic [7:0] BAUD_2M_BYTES [0:12] = '{
    "B", "a", "u", "d", " ", "s", "e", "t", ":", " ", "2", "M", "\n"
  };

  localparam logic [7:0] BAUD_10M_BYTES [0:13] = '{
    "B", "a", "u", "d", " ", "s", "e", "t", ":", " ", "1", "0", "M", "\n"
  };

  localparam logic [7:0] TEST_START_BYTES [0:13] = '{
    "T", "e", "s", "t", " ", "s", "t", "a", "r", "t", "e", "d", ".", "\n"
  };

  logic [7:0] current_msg_char;
  always_comb begin
    case (msg_src)
      SRC_INPUT_ECHO:  current_msg_char = input_buf[msg_idx];
      SRC_HELP:        current_msg_char = HELP_BYTES[msg_idx];
      SRC_STATUS:      current_msg_char = STATUS_BYTES[msg_idx];
      SRC_BAUD_100K:   current_msg_char = BAUD_100K_BYTES[msg_idx];
      SRC_BAUD_1M:     current_msg_char = BAUD_1M_BYTES[msg_idx];
      SRC_BAUD_2M:     current_msg_char = BAUD_2M_BYTES[msg_idx];
      SRC_BAUD_10M:    current_msg_char = BAUD_10M_BYTES[msg_idx];
      SRC_TEST:        current_msg_char = TEST_START_BYTES[msg_idx];
      default:         current_msg_char = 8'h00;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_INIT;
      mode_text <= 1'b0;
      input_len <= 11'd2;
      show_popup <= 1'b0;
      show_progress <= 1'b0;
      progress_val <= '0;
      input_cursor <= 11'd2;

      msg_src <= SRC_NONE;
      msg_idx <= '0;
      msg_len <= '0;
      console_write_ptr <= '0;
      init_idx <= '0;
      clear_idx <= '0;
      input_update_idx <= '0;

      eval_proto_baud_rate <= 4'd1;        // 1 Mbps default
      eval_proto_oversampling <= 4'd8;     // 8x oversampling default
      eval_proto_loopback_en <= 1'b1;      // Enable loopback by default for testing
      eval_proto_tx_valid <= 1'b0;
      eval_proto_tx_type <= MSG_TEXT;
      eval_proto_tx_data <= 8'h00;

      for (int i = 0; i < INPUT_MAX_LEN; i++) input_buf[i] <= 8'h00;

      console_we <= 1'b0;
      input_we <= 1'b0;
      bmp_we <= 1'b0;
      input_addr <= '0;
      input_din <= '0;
      console_addr <= '0;
      console_din <= '0;
      bmp_addr <= '0;
      bmp_din <= '0;
    end else begin
      input_we   <= 1'b0;
      console_we <= 1'b0;
      bmp_we     <= 1'b0;
      eval_proto_tx_valid <= 1'b0; // Default pulse high for 1 cycle

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
          if (proto_eval_rx_valid) begin
            console_addr <= console_write_ptr;
            console_din  <= proto_eval_rx_data;
            console_we   <= 1'b1;
            console_write_ptr <= (console_write_ptr == CONSOLE_MAX_LEN - 1) ? 10'd0 : console_write_ptr + 10'd1;
          end
          else if (mode_text) begin
            if (cmd_esc) begin
              mode_text <= 1'b0;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (cmd_enter) begin
              state <= S_PROCESS_CMD;
            end else if (cmd_left && input_cursor > 2) begin
              input_cursor <= input_cursor - 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (cmd_right && input_cursor < input_len) begin
              input_cursor <= input_cursor + 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (char_valid && input_len < (INPUT_MAX_LEN - 2)) begin
              if (input_cursor == input_len) begin
                input_buf[input_cursor] <= char_ascii;
              end else begin
                for (int i = INPUT_MAX_LEN - 1; i > 0; i--) begin
                  if (i > input_cursor) input_buf[i] <= input_buf[i-1];
                end
                input_buf[input_cursor] <= char_ascii;
              end
              input_cursor <= input_cursor + 1;
              input_len <= input_len + 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end else if (cmd_backspace && input_cursor > 2) begin
              if (input_cursor == input_len) begin
                input_buf[input_cursor - 1] <= 8'h00;
              end else begin
                for (int i = 2; i < INPUT_MAX_LEN - 1; i++) begin
                  if (i >= input_cursor - 1) input_buf[i] <= input_buf[i+1];
                end
              end
              input_cursor <= input_cursor - 1;
              input_len <= input_len - 1;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end else begin
            if (cmd_enter) begin
              if (ui_selected_item == ITEM_INPUT) begin
                mode_text <= 1'b1;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end else if (ui_selected_item == ITEM_ABOUT_BTN) begin
                show_popup <= 1'b1;
              end else if (ui_selected_item == ITEM_POPUP_BTN) begin
                show_popup <= 1'b0;
              end
            end
          end
        end

        S_PROCESS_CMD: begin
          input_buf[0] <= 8'h3E; // '>'
          input_buf[1] <= 8'h20; // ' '
          input_buf[input_len] <= 8'h0A; // '\n'

          msg_src <= SRC_INPUT_ECHO;
          msg_idx <= '0;
          msg_len <= input_len + 11'd1;
          state <= S_PRINT_MSG;
        end

        S_PRINT_MSG: begin
          console_addr <= console_write_ptr;
          console_din  <= current_msg_char;
          console_we   <= 1'b1;
          console_write_ptr <= (console_write_ptr == CONSOLE_MAX_LEN - 1) ? 10'd0 : console_write_ptr + 10'd1;

          if (msg_idx + 11'd1 < msg_len) begin
            msg_idx <= msg_idx + 11'd1;
          end else begin
            if (msg_src == SRC_INPUT_ECHO) begin
              msg_idx <= '0;
              if (input_len >= 6 && input_buf[2]=="h" && input_buf[3]=="e" && input_buf[4]=="l" && input_buf[5]=="p") begin
                msg_src <= SRC_HELP;
                msg_len <= 11'd75;
              end else if (input_len >= 8 && input_buf[2]=="s" && input_buf[3]=="t" && input_buf[4]=="a" && input_buf[5]=="t" && input_buf[6]=="u" && input_buf[7]=="s") begin
                msg_src <= SRC_STATUS;
                msg_len <= 11'd30;
              end else if (input_len >= 7 && input_buf[2]=="c" && input_buf[3]=="l" && input_buf[4]=="e" && input_buf[5]=="a" && input_buf[6]=="r") begin
                clear_idx <= 10'd0;
                state <= S_CLEAR_CONSOLE;
              end else if (input_len >= 9 && input_buf[2]=="b" && input_buf[3]=="a" && input_buf[4]=="u" && input_buf[5]=="d" && input_buf[6]==" ") begin
                if (input_buf[7]=="1" && input_buf[8]=="0" && input_buf[9]=="0") begin
                  eval_proto_baud_rate <= 4'd0;
                  msg_src <= SRC_BAUD_100K;
                  msg_len <= 11'd15;
                end else if (input_buf[7]=="1" && input_buf[8]=="m") begin
                  eval_proto_baud_rate <= 4'd1;
                  msg_src <= SRC_BAUD_1M;
                  msg_len <= 11'd13;
                end else if (input_buf[7]=="2" && input_buf[8]=="m") begin
                  eval_proto_baud_rate <= 4'd2;
                  msg_src <= SRC_BAUD_2M;
                  msg_len <= 11'd13;
                end else if (input_buf[7]=="1" && input_buf[8]=="0" && input_buf[9]=="m") begin
                  eval_proto_baud_rate <= 4'd4;
                  msg_src <= SRC_BAUD_10M;
                  msg_len <= 11'd14;
                end else begin
                  input_len <= 11'd2;
                  input_cursor <= 11'd2;
                  input_update_idx <= 7'd0;
                  state <= S_UPDATE_INPUT_RAM;
                end
              end else if (input_len >= 6 && input_buf[2]=="t" && input_buf[3]=="e" && input_buf[4]=="s" && input_buf[5]=="t") begin
                msg_src <= SRC_TEST;
                msg_len <= 11'd14;
              end else begin
                if (input_len > 2) begin
                  eval_proto_tx_valid <= 1'b1;
                  eval_proto_tx_type  <= MSG_TEXT;
                  eval_proto_tx_data  <= input_buf[2];
                end
                input_len <= 11'd2;
                input_cursor <= 11'd2;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end
            end else begin
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end
        end

        S_CLEAR_CONSOLE: begin
          console_addr <= clear_idx;
          console_din  <= 8'h00;
          console_we   <= 1'b1;
          if (clear_idx == CONSOLE_MAX_LEN - 1) begin
            console_write_ptr <= 10'd0;
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
          if (input_update_idx < input_cursor) begin
            input_din <= input_buf[input_update_idx];
          end else if (input_update_idx == input_cursor) begin
            if (mode_text) input_din <= 8'h5F; // '_'
            else if (input_update_idx < input_len) input_din <= input_buf[input_update_idx];
            else input_din <= 8'h00;
          end else if (input_update_idx <= input_len) begin
            if (mode_text) input_din <= input_buf[input_update_idx - 1];
            else input_din <= input_buf[input_update_idx];
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
