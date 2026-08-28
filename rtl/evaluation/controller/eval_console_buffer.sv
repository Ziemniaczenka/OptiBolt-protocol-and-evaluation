/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Dedicated Console BRAM Controller and Line-Based Auto-Scroller submodule.
 * Manages character writing, automatic line wrapping at 95 columns,
 * tracking visible line count (0..40 lines), and synchronous Block RAM line scrolling.
 * Eliminates arbitrary character limits: scrolling is strictly line-governed.
 */

import string_pkg::*;

module eval_console_buffer #(
    parameter int MAX_LINES = 40,
    parameter int LINE_WRAP_COLS = 95
) (
    input logic clk,
    input logic rst_n,

    // Block RAM interface to Console memory
    output logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr,
    output logic                                           console_we,
    output logic [                                    7:0] console_din,
    input  logic [                                    7:0] console_dout,

    // High-priority print streaming interface (CLI echo, commands, ping, sweep)
    input  logic       print_valid,
    input  logic [7:0] print_char,
    input  logic       print_last,
    output logic       print_ready,

    // OptiBolt direct incoming RX text character interface
    input  logic       rx_char_valid,
    input  logic [7:0] rx_char_data,
    output logic       rx_char_ready,

    // Clear console control
    input  logic clear_req,
    output logic clear_ack,

    // Status outputs
    output logic [5:0] line_count,
    output logic       console_busy
);

  typedef enum logic [3:0] {
    C_INIT,
    C_IDLE,
    C_WRITE_CHAR,
    C_FIND_NL_READ,
    C_FIND_NL_WAIT,
    C_FIND_NL_CHECK,
    C_SCROLL_READ,
    C_SCROLL_WAIT,
    C_SCROLL_WRITE,
    C_SCROLL_CLEAR,
    C_CLEAR_CONSOLE
  } console_state_t;

  console_state_t       state;
  console_state_t       state_after_scroll;

  logic           [9:0] write_ptr;
  logic           [5:0] line_cnt;
  logic           [6:0] col_cnt;

  // Active character being processed
  logic           [7:0] char_to_write;
  logic                 char_is_last;

  // Clear & scroll counters
  logic           [9:0] scan_idx;
  logic           [9:0] nl_len;
  logic           [9:0] scroll_src;
  logic           [9:0] scroll_dst;
  logic           [9:0] clear_src;
  logic           [9:0] clear_idx;

  assign line_count   = line_cnt;
  assign console_busy = (state != C_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state              <= C_INIT;
      state_after_scroll <= C_IDLE;
      console_addr       <= '0;
      console_we         <= 1'b0;
      console_din        <= 8'h00;
      print_ready        <= 1'b0;
      rx_char_ready      <= 1'b0;
      clear_ack          <= 1'b0;
      write_ptr          <= '0;
      line_cnt           <= '0;
      col_cnt            <= '0;
      char_to_write      <= 8'h00;
      char_is_last       <= 1'b0;
      scan_idx           <= '0;
      nl_len             <= '0;
      scroll_src         <= '0;
      scroll_dst         <= '0;
      clear_src          <= '0;
      clear_idx          <= '0;
    end else begin
      console_we    <= 1'b0;
      print_ready   <= 1'b0;
      rx_char_ready <= 1'b0;
      clear_ack     <= 1'b0;

      case (state)
        // -------------------------------------------------------------------
        // Hardware BRAM initialization on reset
        // -------------------------------------------------------------------
        C_INIT: begin
          console_addr <= clear_idx;
          console_din  <= 8'h00;
          console_we   <= 1'b1;
          if (clear_idx == string_pkg::CONSOLE_MAX_LEN - 1) begin
            write_ptr <= '0;
            line_cnt  <= '0;
            col_cnt   <= '0;
            state     <= C_IDLE;
          end else begin
            clear_idx <= clear_idx + 10'd1;
          end
        end

        // -------------------------------------------------------------------
        // Idle: arbitrate between Clear, Print Stream, and Incoming RX Text
        // -------------------------------------------------------------------
        C_IDLE: begin
          if (clear_req) begin
            clear_idx <= '0;
            state     <= C_CLEAR_CONSOLE;
          end else if (print_valid) begin
            char_to_write <= print_char;
            char_is_last  <= print_last;
            print_ready   <= 1'b1;  // Accept character

            // Check if scroll is needed BEFORE writing
            if (line_cnt >= MAX_LINES || write_ptr >= (string_pkg::CONSOLE_MAX_LEN - 64)) begin
              scan_idx           <= 10'd0;
              state_after_scroll <= C_WRITE_CHAR;
              state              <= C_FIND_NL_READ;
            end else begin
              state <= C_WRITE_CHAR;
            end
          end else if (rx_char_valid) begin
            char_to_write <= rx_char_data;
            char_is_last  <= 1'b1;
            rx_char_ready <= 1'b1;  // Accept RX character

            if (line_cnt >= MAX_LINES || write_ptr >= (string_pkg::CONSOLE_MAX_LEN - 64)) begin
              scan_idx           <= 10'd0;
              state_after_scroll <= C_WRITE_CHAR;
              state              <= C_FIND_NL_READ;
            end else begin
              state <= C_WRITE_CHAR;
            end
          end
        end

        // -------------------------------------------------------------------
        // Write Character to BRAM and track columns / lines
        // -------------------------------------------------------------------
        C_WRITE_CHAR: begin
          if (char_to_write != 8'h00) begin
            console_addr <= write_ptr;
            console_din  <= char_to_write;
            console_we   <= 1'b1;

            if (write_ptr < string_pkg::CONSOLE_MAX_LEN - 1) begin
              write_ptr <= write_ptr + 10'd1;
            end

            // Line & column calculation
            if (char_to_write == 8'h0A) begin  // Newline
              line_cnt <= line_cnt + 6'd1;
              col_cnt  <= 7'd0;
            end else begin
              if (col_cnt >= LINE_WRAP_COLS - 1) begin
                line_cnt <= line_cnt + 6'd1;
                col_cnt  <= 7'd0;
              end else begin
                col_cnt <= col_cnt + 7'd1;
              end
            end
          end

          state <= C_IDLE;
        end

        // -------------------------------------------------------------------
        // Line-by-Line Synchronous Block RAM Console Auto-Scrolling
        // -------------------------------------------------------------------
        C_FIND_NL_READ: begin
          console_addr <= scan_idx;
          console_we   <= 1'b0;
          state        <= C_FIND_NL_WAIT;
        end

        C_FIND_NL_WAIT: begin
          state <= C_FIND_NL_CHECK;
        end

        C_FIND_NL_CHECK: begin
          if (console_dout == 8'h0A || scan_idx >= LINE_WRAP_COLS || scan_idx >= write_ptr) begin
            nl_len     <= scan_idx + 10'd1;
            scroll_src <= scan_idx + 10'd1;
            scroll_dst <= 10'd0;
            state      <= C_SCROLL_READ;
          end else begin
            scan_idx <= scan_idx + 10'd1;
            state    <= C_FIND_NL_READ;
          end
        end

        C_SCROLL_READ: begin
          console_addr <= scroll_src;
          console_we   <= 1'b0;
          state        <= C_SCROLL_WAIT;
        end

        C_SCROLL_WAIT: begin
          state <= C_SCROLL_WRITE;
        end

        C_SCROLL_WRITE: begin
          console_addr <= scroll_dst;
          console_din  <= (scroll_src < string_pkg::CONSOLE_MAX_LEN) ? console_dout : 8'h00;
          console_we   <= 1'b1;
          scroll_dst   <= scroll_dst + 10'd1;
          scroll_src   <= scroll_src + 10'd1;

          if (scroll_src >= write_ptr) begin
            clear_src <= scroll_dst + 10'd1;
            state     <= C_SCROLL_CLEAR;
          end else begin
            state <= C_SCROLL_READ;
          end
        end

        C_SCROLL_CLEAR: begin
          console_addr <= clear_src;
          console_din  <= 8'h00;
          console_we   <= 1'b1;
          if (clear_src >= write_ptr) begin
            write_ptr <= (write_ptr > nl_len) ? (write_ptr - nl_len) : 10'd0;
            line_cnt  <= (line_cnt > 0) ? (line_cnt - 6'd1) : 6'd0;
            state     <= state_after_scroll;
          end else begin
            clear_src <= clear_src + 10'd1;
          end
        end

        // -------------------------------------------------------------------
        // Clear entire console memory
        // -------------------------------------------------------------------
        C_CLEAR_CONSOLE: begin
          console_addr <= clear_idx;
          console_din  <= 8'h00;
          console_we   <= 1'b1;
          if (clear_idx == string_pkg::CONSOLE_MAX_LEN - 1) begin
            write_ptr <= 10'd0;
            line_cnt  <= 6'd0;
            col_cnt   <= 7'd0;
            clear_ack <= 1'b1;
            state     <= C_IDLE;
          end else begin
            clear_idx <= clear_idx + 10'd1;
          end
        end

        default: state <= C_IDLE;
      endcase
    end
  end

endmodule
