/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Master FSM managing tests, console text processing, CLI commands, and UI Popups.
 * Directly writes to display BRAMs (console, input, dynamic bitmap), handles bitrate/oversampling selection,
 * arbitrates handshake packets, implements baud negotiation, and streams protocol test/chat packets.
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

  import string_pkg::*;
  import ui_pkg::*;
  import protocol_pkg::*;

  localparam logic [2:0] MSG_BITMAP = 3'b101; // Map bitmap packet to MSG_TEST1 (3'b101)

  typedef enum logic [3:0] {
    S_INIT,
    S_IDLE,
    S_PROCESS_CMD,
    S_PRINT_MSG,
    S_CLEAR_CONSOLE,
    S_UPDATE_INPUT_RAM,
    S_BITMAP_SEND,
    S_CLEAR_BITMAP,
    S_TEXT_SEND
  } state_t;
  state_t state;

  typedef enum logic [3:0] {
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
    SRC_REMOTE_BAUD
  } msg_src_t;

  msg_src_t msg_src;
  logic [10:0] msg_idx;
  logic [10:0] msg_len;

  // Input Buffer (128 bytes)
  logic [7:0] input_buf [0:INPUT_MAX_LEN-1];
  logic [10:0] input_len;
  logic [10:0] input_cursor;

  // BRAM Write Pointers
  logic [9:0] console_write_ptr;
  logic [9:0] clear_idx;
  logic [6:0] input_update_idx;
  logic [5:0] init_idx;
  logic [11:0] clear_bmp_idx;

  // Bitmap streaming & reception counters
  logic [12:0] tx_pixel_cnt;
  logic [11:0] rx_pixel_ptr;
  logic [10:0] text_send_idx;

  // Baud negotiation registers
  logic [7:0] pending_baud_req;
  logic       pending_baud_nego;
  logic       pending_nego_ack_tx;
  logic [7:0] nego_ack_payload;

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

  // String Constant Definitions
  localparam logic [7:0] BANNER_BYTES [0:57] = '{
    "O", "p", "t", "i", "B", "o", "l", "t", " ", "O", "S", " ", "v", "1", ".", "0", "\n",
    "S", "y", "s", "t", "e", "m", " ", "R", "e", "a", "d", "y", ".", "\n",
    "T", "y", "p", "e", " ", "'", "/", "h", "e", "l", "p", "'", " ", "f", "o", "r", " ", "c", "o", "m", "m", "a", "n", "d", "s", ".", "\n"
  };

  localparam logic [7:0] HELP_BYTES [0:187] = '{
    "C", "o", "m", "m", "a", "n", "d", "s", ":", "\n",
    " ", "/", "b", "a", "u", "d", " ", "<", " ", "1", "0", "0", "k", " ", "|", " ", "1", "m", " ", "|", " ", "1", ".", "2", "5", "m", " ", "|", " ", "2", ".", "5", "m", " ", "|", " ", "3", ".", "1", "2", "5", "m", " ", "|", " ", "5", "m", " ", "|", " ", "6", ".", "2", "5", "m", " ", "|", " ", "8", ".", "3", "3", "m", " ", "|", " ", "1", "2", ".", "5", "m", " ", "|", " ", "2", "5", "m", " ", ">", "\n",
    " ", "/", "o", "s", " ", "<", " ", "8", "x", " ", "|", " ", "1", "6", "x", " ", ">", "\n",
    " ", "/", "t", "e", "s", "t", " ", "<", " ", "1", " ", "|", " ", "2", " ", "|", " ", "b", "e", "r", " ", "|", " ", "p", "i", "n", "g", " ", ">", "\n",
    " ", "/", "b", "i", "t", "m", "a", "p", " ", "<", " ", "s", "e", "n", "d", " ", "|", " ", "c", "l", "e", "a", "r", " ", ">", "\n",
    " ", "/", "c", "l", "e", "a", "r", "\n",
    " ", "/", "s", "t", "a", "t", "u", "s", "\n",
    " ", "/", "h", "e", "l", "p", "\n"
  };

  localparam logic [7:0] STATUS_DISCONN_BYTES [0:28] = '{
    "S", "t", "a", "t", "u", "s", ":", " ", "D", "I", "S", "C", "O", "N", "N", "E", "C", "T", "E", "D", " ", " ", " ", " ", " ", " ", " ", " ", "\n"
  };

  localparam logic [7:0] STATUS_CONN_BYTES [0:28] = '{
    "S", "t", "a", "t", "u", "s", ":", " ", "C", "O", "N", "N", "E", "C", "T", "E", "D", " ", "(", "R", "e", "m", "o", "t", "e", ")", " ", " ", "\n"
  };

  localparam logic [7:0] STATUS_LOOP_BYTES [0:28] = '{
    "S", "t", "a", "t", "u", "s", ":", " ", "L", "O", "O", "P", "B", "A", "C", "K", " ", "(", "L", "o", "c", "a", "l", ")", " ", " ", " ", " ", "\n"
  };

  localparam logic [7:0] BAUD_SET_BYTES [0:17] = '{
    "B", "a", "u", "d", "r", "a", "t", "e", " ", "u", "p", "d", "a", "t", "e", "d", ".", "\n"
  };

  localparam logic [7:0] OS_SET_BYTES [0:20] = '{
    "O", "v", "e", "r", "s", "a", "m", "p", "l", "i", "n", "g", " ", "u", "p", "d", "a", "t", "e", "d", "\n"
  };

  localparam logic [7:0] TEST_START_BYTES [0:13] = '{
    "T", "e", "s", "t", " ", "s", "t", "a", "r", "t", "e", "d", ".", "\n"
  };

  localparam logic [7:0] BITMAP_SEND_BYTES [0:17] = '{
    "S", "e", "n", "d", "i", "n", "g", " ", "b", "i", "t", "m", "a", "p", ".", ".", ".", "\n"
  };

  localparam logic [7:0] BITMAP_CLEAR_BYTES [0:15] = '{
    "B", "i", "t", "m", "a", "p", " ", "c", "l", "e", "a", "r", "e", "d", ".", "\n"
  };

  localparam logic [7:0] UNKNOWN_CMD_BYTES [0:16] = '{
    "U", "n", "k", "n", "o", "w", "n", " ", "c", "o", "m", "m", "a", "n", "d", ".", "\n"
  };

  localparam logic [7:0] ERR_DISCONN_BYTES [0:25] = '{
    "E", "r", "r", "o", "r", ":", " ", "L", "i", "n", "k", " ", "d", "i", "s", "c", "o", "n", "n", "e", "c", "t", "e", "d", ".", "\n"
  };

  localparam logic [7:0] BAUD_NEGO_BYTES [0:23] = '{
    "N", "e", "g", "o", "t", "i", "a", "t", "i", "n", "g", " ", "b", "a", "u", "d", "r", "a", "t", "e", ".", ".", ".", "\n"
  };

  localparam logic [7:0] BAUD_SYNC_BYTES [0:22] = '{
    "B", "a", "u", "d", "r", "a", "t", "e", " ", "s", "y", "n", "c", "h", "r", "o", "n", "i", "z", "e", "d", ".", "\n"
  };

  localparam logic [7:0] REMOTE_BAUD_BYTES [0:24] = '{
    "R", "e", "m", "o", "t", "e", " ", "u", "p", "d", "a", "t", "e", "d", " ", "b", "a", "u", "d", "r", "a", "t", "e", ".", "\n"
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
      default:            current_msg_char = 8'h00;
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
      clear_bmp_idx <= '0;
      tx_pixel_cnt <= '0;
      rx_pixel_ptr <= '0;
      text_send_idx <= '0;
      prng_next_pixel <= 1'b0;
      hs_tx_ack <= 1'b0;

      pending_baud_req    <= '0;
      pending_baud_nego   <= 1'b0;
      pending_nego_ack_tx <= 1'b0;
      nego_ack_payload    <= '0;

      rx_line_start <= 1'b1;
      rx_fifo_head  <= '0;
      rx_fifo_tail  <= '0;
      rx_fifo_count <= '0;

      eval_proto_baud_rate    <= 4'd1;     // 1 Mbps default
      eval_proto_oversampling <= 4'd0;     // 8x oversampling default
      eval_proto_loopback_en  <= 1'b1;     // Enable loopback default
      eval_proto_tx_valid     <= 1'b0;
      eval_proto_tx_type      <= MSG_TEXT;
      eval_proto_tx_data      <= 8'h00;

      for (int i = 0; i < INPUT_MAX_LEN; i++) input_buf[i] <= 8'h00;

      console_we   <= 1'b0;
      input_we     <= 1'b0;
      bmp_we       <= 1'b0;
      input_addr   <= '0;
      input_din    <= '0;
      console_addr <= '0;
      console_din  <= '0;
      bmp_addr     <= '0;
      bmp_din      <= '0;
    end else begin
      input_we            <= 1'b0;
      console_we          <= 1'b0;
      bmp_we              <= 1'b0;
      eval_proto_tx_valid <= 1'b0;
      prng_next_pixel     <= 1'b0;
      hs_tx_ack           <= 1'b0;

      // ---------------------------------------------------------------------
      // Handle incoming RX packets from OptiBolt protocol
      // ---------------------------------------------------------------------
      if (proto_eval_rx_valid) begin
        if (proto_eval_rx_type == MSG_BITMAP) begin
          bmp_addr <= rx_pixel_ptr;
          bmp_din  <= {proto_eval_rx_data[7:4], proto_eval_rx_data[3:0], proto_eval_rx_data[7:4]};
          bmp_we   <= 1'b1;
          rx_pixel_ptr <= (rx_pixel_ptr == 12'd4095) ? 12'd0 : rx_pixel_ptr + 12'd1;
        end else if (proto_eval_rx_type == MSG_TEXT) begin
          // Format received text messages with "< " prefix for each line
          if (rx_line_start) begin
            rx_fifo_chars[0] <= 8'h3C; // '<'
            rx_fifo_chars[1] <= 8'h20; // ' '
            rx_fifo_chars[2] <= proto_eval_rx_data;
            rx_fifo_head     <= 2'd3;
            rx_fifo_tail     <= 2'd0;
            rx_fifo_count    <= 3'd3;
            rx_line_start    <= (proto_eval_rx_data == 8'h0A);
          end else begin
            rx_fifo_chars[rx_fifo_head] <= proto_eval_rx_data;
            rx_fifo_head  <= rx_fifo_head + 2'd1;
            rx_fifo_count <= rx_fifo_count + 3'd1;
            rx_line_start <= (proto_eval_rx_data == 8'h0A);
          end
        end else if (proto_eval_rx_type == MSG_REQUEST) begin
          // Remote board requested baudrate change: {oversampling, baudrate}
          eval_proto_baud_rate    <= proto_eval_rx_data[3:0];
          eval_proto_oversampling <= proto_eval_rx_data[7:4];
          pending_nego_ack_tx     <= 1'b1;
          nego_ack_payload        <= proto_eval_rx_data;
          if (state == S_IDLE) begin
            msg_src <= SRC_REMOTE_BAUD;
            msg_idx <= '0;
            msg_len <= 11'd25;
            state   <= S_PRINT_MSG;
          end
        end else if (proto_eval_rx_type == MSG_ACCEPT && pending_baud_nego) begin
          // Remote board accepted our requested baudrate change
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

      // Drain RX FIFO to console BRAM when controller is not actively printing
      if (state != S_PRINT_MSG && state != S_INIT && state != S_CLEAR_CONSOLE && rx_fifo_count > 0) begin
        console_addr      <= console_write_ptr;
        console_din       <= rx_fifo_chars[rx_fifo_tail];
        console_we        <= 1'b1;
        console_write_ptr <= (console_write_ptr == CONSOLE_MAX_LEN - 1) ? 10'd0 : console_write_ptr + 10'd1;
        rx_fifo_tail      <= rx_fifo_tail + 2'd1;
        rx_fifo_count     <= rx_fifo_count - 3'd1;
      end

      // ---------------------------------------------------------------------
      // Packet arbitration for Handshake / Baud Negotiation
      // ---------------------------------------------------------------------
      if (state == S_IDLE && !proto_eval_tx_full) begin
        if (pending_nego_ack_tx) begin
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

      // ---------------------------------------------------------------------
      // Main UI State Machine
      // ---------------------------------------------------------------------
      case (state)
        S_INIT: begin
          input_buf[0] <= 8'h3E; // '>'
          input_buf[1] <= 8'h20; // ' '

          console_addr <= init_idx;
          console_din  <= BANNER_BYTES[init_idx];
          console_we   <= 1'b1;

          if (init_idx == 6'd57) begin
            console_write_ptr <= 10'd58;
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

              // Check if input is a command starting with '/'
              if (input_len >= 3 && input_buf[2] == "/") begin
                if (input_len == 7 && input_buf[3]=="h" && input_buf[4]=="e" && input_buf[5]=="l" && input_buf[6]=="p") begin
                  msg_src <= SRC_HELP;
                  msg_len <= 11'd188;
                end else if (input_len == 9 && input_buf[3]=="s" && input_buf[4]=="t" && input_buf[5]=="a" && input_buf[6]=="t" && input_buf[7]=="u" && input_buf[8]=="s") begin
                  if (link_status == 2'b01) msg_src <= SRC_STATUS_CONN;
                  else if (link_status == 2'b10) msg_src <= SRC_STATUS_LOOP;
                  else msg_src <= SRC_STATUS_DISCONN;
                  msg_len <= 11'd29;
                end else if (input_len == 8 && input_buf[3]=="c" && input_buf[4]=="l" && input_buf[5]=="e" && input_buf[6]=="a" && input_buf[7]=="r") begin
                  clear_idx <= 10'd0;
                  state <= S_CLEAR_CONSOLE;
                end else if (input_len >= 6 && input_buf[3]=="o" && input_buf[4]=="s" && input_buf[5]==" ") begin
                  if (input_buf[6]=="1" && input_buf[7]=="6") begin
                    if (link_status == 2'b01) begin
                      pending_baud_req  <= {4'd1, eval_proto_baud_rate};
                      pending_baud_nego <= 1'b1;
                      msg_src <= SRC_BAUD_NEGO;
                      msg_len <= 11'd24;
                    end else begin
                      eval_proto_oversampling <= 4'd1;
                      msg_src <= SRC_OS_SET;
                      msg_len <= 11'd21;
                    end
                  end else if (input_buf[6]=="8") begin
                    if (link_status == 2'b01) begin
                      pending_baud_req  <= {4'd0, eval_proto_baud_rate};
                      pending_baud_nego <= 1'b1;
                      msg_src <= SRC_BAUD_NEGO;
                      msg_len <= 11'd24;
                    end else begin
                      eval_proto_oversampling <= 4'd0;
                      msg_src <= SRC_OS_SET;
                      msg_len <= 11'd21;
                    end
                  end else begin
                    msg_src <= SRC_UNKNOWN;
                    msg_len <= 11'd17;
                  end
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
                      msg_src <= SRC_BAUD_NEGO;
                      msg_len <= 11'd24;
                    end else begin
                      eval_proto_baud_rate    <= target_rate;
                      eval_proto_oversampling <= target_os;
                      msg_src <= SRC_BAUD_SET;
                      msg_len <= 11'd18;
                    end
                  end else begin
                    msg_src <= SRC_UNKNOWN;
                    msg_len <= 11'd17;
                  end
                end else if (input_len >= 10 && input_buf[3]=="b" && input_buf[4]=="i" && input_buf[5]=="t" && input_buf[6]=="m" && input_buf[7]=="a" && input_buf[8]=="p" && input_buf[9]==" ") begin
                  if (input_len >= 14 && input_buf[10]=="s" && input_buf[11]=="e" && input_buf[12]=="n" && input_buf[13]=="d") begin
                    if (link_status == 2'b00) begin
                      msg_src <= SRC_ERR_DISCONN;
                      msg_len <= 11'd26;
                    end else begin
                      msg_src <= SRC_BITMAP_SEND;
                      msg_len <= 11'd18;
                    end
                  end else if (input_len >= 15 && input_buf[10]=="c" && input_buf[11]=="l" && input_buf[12]=="e" && input_buf[13]=="a" && input_buf[14]=="r") begin
                    msg_src <= SRC_BITMAP_CLEAR;
                    msg_len <= 11'd16;
                  end else begin
                    msg_src <= SRC_UNKNOWN;
                    msg_len <= 11'd17;
                  end
                end else if (input_len >= 7 && input_buf[3]=="t" && input_buf[4]=="e" && input_buf[5]=="s" && input_buf[6]=="t") begin
                  if (link_status == 2'b00) begin
                    msg_src <= SRC_ERR_DISCONN;
                    msg_len <= 11'd26;
                  end else begin
                    msg_src <= SRC_TEST;
                    msg_len <= 11'd14;
                  end
                end else begin
                  msg_src <= SRC_UNKNOWN;
                  msg_len <= 11'd17;
                end
              end else if (input_len > 2) begin
                // Non-command text input -> Send over optical link as MSG_TEXT
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN;
                  msg_len <= 11'd26;
                end else begin
                  text_send_idx <= 11'd2;
                  state <= S_TEXT_SEND;
                end
              end else begin
                input_len <= 11'd2;
                input_cursor <= 11'd2;
                input_update_idx <= 7'd0;
                state <= S_UPDATE_INPUT_RAM;
              end
            end else if (msg_src == SRC_BITMAP_SEND) begin
              tx_pixel_cnt <= 12'd0;
              state <= S_BITMAP_SEND;
            end else if (msg_src == SRC_BITMAP_CLEAR) begin
              clear_bmp_idx <= 12'd0;
              state <= S_CLEAR_BITMAP;
            end else begin
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
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
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end
        end

        S_BITMAP_SEND: begin
          if (!eval_proto_tx_valid && !proto_eval_tx_full && tx_pixel_cnt < 13'd4096) begin
            eval_proto_tx_valid <= 1'b1;
            eval_proto_tx_type  <= MSG_BITMAP;
            eval_proto_tx_data  <= prng_pixel_byte;
            prng_next_pixel     <= 1'b1;
            tx_pixel_cnt        <= tx_pixel_cnt + 13'd1;
          end else begin
            eval_proto_tx_valid <= 1'b0;
            prng_next_pixel     <= 1'b0;
            if (tx_pixel_cnt == 13'd4096) begin
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              input_update_idx <= 7'd0;
              state <= S_UPDATE_INPUT_RAM;
            end
          end
        end

        S_CLEAR_BITMAP: begin
          bmp_addr <= clear_bmp_idx;
          bmp_din  <= 12'h000;
          bmp_we   <= 1'b1;
          if (clear_bmp_idx == 12'd4095) begin
            rx_pixel_ptr <= 12'd0;
            input_len <= 11'd2;
            input_cursor <= 11'd2;
            input_update_idx <= 7'd0;
            state <= S_UPDATE_INPUT_RAM;
          end else begin
            clear_bmp_idx <= clear_bmp_idx + 12'd1;
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
