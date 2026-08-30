/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * CLI Text Input and History Management module.
 *
 */

import string_pkg::*;
import ui_pkg::*;

module eval_cli_input #(
    parameter int CLI_BUF_LEN = 64
) (
    input logic clk,
    input logic rst_n,

    // Keyboard inputs
    input logic       cmd_up,
    input logic       cmd_down,
    input logic       cmd_left,
    input logic       cmd_right,
    input logic       cmd_enter,
    input logic       cmd_esc,
    input logic       char_valid,
    input logic [7:0] char_ascii,
    input logic       cmd_backspace,

    // UI navigation state
    input  logic [3:0] ui_selected_item,
    output logic       mode_text,
    output logic       btn_trigger,

    // Input BRAM interface (for VGA display rendering)
    output logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr,
    output logic                                         input_we,
    output logic [                                  7:0] input_din,

    // Command dispatch & echo interface to command executor
    output logic        cmd_valid,
    output logic [ 7:0] cmd_buf  [0:CLI_BUF_LEN-1],
    output logic [10:0] cmd_len,
    output logic        echo_req,
    input  logic        echo_ack
);

  typedef enum logic [2:0] {
    INP_IDLE,
    INP_UPDATE_RAM,
    INP_HIST_SCAN,
    INP_HIST_UPDATE,
    INP_WAIT_ECHO
  } inp_state_t;

  inp_state_t state;

  // Local CLI input line buffer (64 bytes)
  logic [7:0] input_buf_reg[0:CLI_BUF_LEN-1];
  logic [10:0] input_len_reg;
  logic [10:0] input_cursor_reg;
  logic [6:0] input_update_idx;

  // 4-entry static history buffer slots (zero inter-slot copying)
  logic [7:0] history_buf[0:3][0:CLI_BUF_LEN-1];
  logic [10:0] history_len[0:3];
  logic [1:0] hist_ptrs[0:3];  // hist_ptrs[0] = MRU slot, hist_ptrs[3] = LRU slot
  logic [2:0] history_count;
  logic [2:0] history_pos;

  // Sequential MRU history matching registers
  logic [1:0] hist_check_idx;
  logic [1:0] hist_match_idx;
  logic hist_matched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= INP_IDLE;
      mode_text        <= 1'b0;
      input_len_reg    <= 11'd2;
      input_cursor_reg <= 11'd2;
      input_update_idx <= 7'd0;
      input_addr       <= '0;
      input_we         <= 1'b0;
      input_din        <= 8'h00;
      cmd_valid        <= 1'b0;
      cmd_len          <= '0;
      btn_trigger      <= 1'b0;
      echo_req         <= 1'b0;
      history_count    <= '0;
      history_pos      <= '0;
      hist_check_idx   <= 2'd0;
      hist_match_idx   <= 2'd0;
      hist_matched     <= 1'b0;

      for (int i = 0; i < 4; i++) hist_ptrs[i] <= 2'(i);

      for (int i = 0; i < CLI_BUF_LEN; i++) begin
        input_buf_reg[i] <= 8'h00;
        cmd_buf[i]       <= 8'h00;
      end
      input_buf_reg[0] <= 8'h3E;  // '>'
      input_buf_reg[1] <= 8'h20;  // ' '

      for (int h = 0; h < 4; h++) begin
        history_len[h] <= '0;
        for (int c = 0; c < CLI_BUF_LEN; c++) history_buf[h][c] <= 8'h00;
      end
    end else begin
      cmd_valid   <= 1'b0;  // 1-cycle strobe
      btn_trigger <= 1'b0;  // 1-cycle strobe
      if (echo_ack) echo_req <= 1'b0;

      case (state)
        INP_IDLE: begin
          // 1. Navigation mode vs text mode toggle
          if (!mode_text) begin
            if (cmd_enter) begin
              if (ui_selected_item == ITEM_INPUT) begin
                mode_text        <= 1'b1;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end else begin
                btn_trigger <= 1'b1;  // Trigger toolbar button
              end
            end
          end else begin
            // In text mode
            if (cmd_esc) begin
              mode_text        <= 1'b0;
              input_update_idx <= 7'd0;
              state            <= INP_UPDATE_RAM;
            end else if (cmd_enter) begin
              if (input_len_reg > 11'd2) begin
                for (int i = 0; i < CLI_BUF_LEN; i++) begin
                  cmd_buf[i] <= input_buf_reg[i];
                end
                cmd_len        <= input_len_reg;
                cmd_valid      <= 1'b1;
                echo_req       <= 1'b1;

                // Begin sequential MRU history scan
                hist_check_idx <= 2'd0;
                hist_match_idx <= 2'd0;
                hist_matched   <= 1'b0;
                state          <= INP_HIST_SCAN;
              end else begin
                // Empty prompt, exit text mode
                mode_text        <= 1'b0;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end
            end else if (cmd_up) begin
              // History navigation UP (MRU to oldest)
              if (history_count > 0 && history_pos < history_count) begin
                logic [1:0] load_slot;
                load_slot = hist_ptrs[history_pos[1:0]];
                input_buf_reg[0] <= 8'h3E;
                input_buf_reg[1] <= 8'h20;
                for (int i = 2; i < CLI_BUF_LEN; i++) begin
                  input_buf_reg[i] <= (i < history_len[load_slot]) ? history_buf[load_slot][i] : 8'h00;
                end
                input_len_reg    <= history_len[load_slot];
                input_cursor_reg <= history_len[load_slot];
                history_pos      <= history_pos + 3'd1;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end
            end else if (cmd_down) begin
              // History navigation DOWN (towards latest / empty)
              if (history_pos > 3'd1) begin
                logic [1:0] load_slot;
                load_slot = hist_ptrs[history_pos[1:0]-2'd2];
                input_buf_reg[0] <= 8'h3E;
                input_buf_reg[1] <= 8'h20;
                for (int i = 2; i < CLI_BUF_LEN; i++) begin
                  input_buf_reg[i] <= (i < history_len[load_slot]) ? history_buf[load_slot][i] : 8'h00;
                end
                input_len_reg    <= history_len[load_slot];
                input_cursor_reg <= history_len[load_slot];
                history_pos      <= history_pos - 3'd1;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end else if (history_pos == 3'd1) begin
                input_buf_reg[0] <= 8'h3E;
                input_buf_reg[1] <= 8'h20;
                for (int i = 2; i < CLI_BUF_LEN; i++) input_buf_reg[i] <= 8'h00;
                input_len_reg    <= 11'd2;
                input_cursor_reg <= 11'd2;
                history_pos      <= 3'd0;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end
            end else if (char_valid && input_len_reg < CLI_BUF_LEN - 1 && char_ascii >= 8'h20 && char_ascii <= 8'h7E) begin
              // Character insertion: direct assign if at end of buffer
              if (input_cursor_reg == input_len_reg) begin
                input_buf_reg[input_cursor_reg[5:0]] <= char_ascii;
              end else begin
                for (int i = CLI_BUF_LEN - 1; i >= 2; i--) begin
                  if (i > input_cursor_reg) input_buf_reg[i] <= input_buf_reg[i-1];
                  else if (i == input_cursor_reg) input_buf_reg[i] <= char_ascii;
                end
              end
              input_len_reg    <= input_len_reg + 11'd1;
              input_cursor_reg <= input_cursor_reg + 11'd1;
              input_update_idx <= 7'd0;
              state            <= INP_UPDATE_RAM;
            end else if (cmd_backspace && input_cursor_reg > 11'd2) begin
              // Backspace deletion: direct clear if at end of buffer
              if (input_cursor_reg == input_len_reg) begin
                input_buf_reg[input_len_reg[5:0]-6'd1] <= 8'h00;
              end else begin
                for (int i = 2; i < CLI_BUF_LEN - 1; i++) begin
                  if (i >= input_cursor_reg - 1) input_buf_reg[i] <= input_buf_reg[i+1];
                end
              end
              input_len_reg    <= input_len_reg - 11'd1;
              input_cursor_reg <= input_cursor_reg - 11'd1;
              input_update_idx <= 7'd0;
              state            <= INP_UPDATE_RAM;
            end else if (cmd_left) begin
              if (input_cursor_reg > 11'd2) begin
                input_cursor_reg <= input_cursor_reg - 11'd1;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end
            end else if (cmd_right) begin
              if (input_cursor_reg < input_len_reg) begin
                input_cursor_reg <= input_cursor_reg + 11'd1;
                input_update_idx <= 7'd0;
                state            <= INP_UPDATE_RAM;
              end
            end
          end
        end

        /* Sequential 4-Entry MRU History Scan FSM */
        INP_HIST_SCAN: begin
          logic match;
          logic [1:0] check_slot;
          check_slot = hist_ptrs[hist_check_idx];
          match = 1'b1;

          if (hist_check_idx < history_count) begin
            if (input_len_reg != history_len[check_slot]) begin
              match = 1'b0;
            end else begin
              for (int c = 2; c < CLI_BUF_LEN; c++) begin
                if (c < input_len_reg && input_buf_reg[c] != history_buf[check_slot][c]) begin
                  match = 1'b0;
                end
              end
            end
            if (match) begin
              hist_matched   <= 1'b1;
              hist_match_idx <= hist_check_idx;
            end
          end

          if (hist_check_idx == 2'd3 || (hist_check_idx + 2'd1 >= history_count)) begin
            state <= INP_HIST_UPDATE;
          end else begin
            hist_check_idx <= hist_check_idx + 2'd1;
          end
        end

        // -------------------------------------------------------------------
        // Zero-Copy Pointer Reorder & Single-Slot History Update
        // -------------------------------------------------------------------
        INP_HIST_UPDATE: begin
          if (hist_matched) begin
            // Pointer reorder: promote matched pointer to MRU position (index 0)
            logic [1:0] m_slot;
            m_slot = hist_ptrs[hist_match_idx];
            case (hist_match_idx)
              2'd0: ;  // Already MRU
              2'd1: begin
                hist_ptrs[0] <= m_slot;
                hist_ptrs[1] <= hist_ptrs[0];
              end
              2'd2: begin
                hist_ptrs[0] <= m_slot;
                hist_ptrs[1] <= hist_ptrs[0];
                hist_ptrs[2] <= hist_ptrs[1];
              end
              2'd3: begin
                hist_ptrs[0] <= m_slot;
                hist_ptrs[1] <= hist_ptrs[0];
                hist_ptrs[2] <= hist_ptrs[1];
                hist_ptrs[3] <= hist_ptrs[2];
              end
            endcase
          end else begin
            // Overwrite the LRU slot (or next empty slot) and update pointers
            logic [1:0] new_slot;
            new_slot = (history_count < 3'd4) ? history_count[1:0] : hist_ptrs[3];

            for (int c = 0; c < CLI_BUF_LEN; c++) history_buf[new_slot][c] <= input_buf_reg[c];
            history_len[new_slot] <= input_len_reg;

            hist_ptrs[0] <= new_slot;
            hist_ptrs[1] <= hist_ptrs[0];
            hist_ptrs[2] <= hist_ptrs[1];
            hist_ptrs[3] <= hist_ptrs[2];

            if (history_count < 3'd4) history_count <= history_count + 3'd1;
          end

          history_pos <= 3'd0;

          // Clear input line back to '> '
          input_len_reg    <= 11'd2;
          input_cursor_reg <= 11'd2;
          for (int i = 2; i < CLI_BUF_LEN; i++) input_buf_reg[i] <= 8'h00;
          input_update_idx <= 7'd0;
          state            <= INP_WAIT_ECHO;
        end

        INP_WAIT_ECHO: begin
          if (!echo_req || echo_ack) begin
            echo_req <= 1'b0;
            state    <= INP_UPDATE_RAM;
          end
        end

        /* Hardware Input BRAM Update Pipeline */
        INP_UPDATE_RAM: begin
          input_addr <= input_update_idx;
          input_we   <= 1'b1;
          if (input_update_idx < input_cursor_reg && input_update_idx < CLI_BUF_LEN) begin
            input_din <= input_buf_reg[input_update_idx[5:0]];
          end else if (input_update_idx == input_cursor_reg) begin
            if (mode_text) input_din <= 8'h5F;  // '_'
            else if (input_update_idx < input_len_reg && input_update_idx < CLI_BUF_LEN)
              input_din <= input_buf_reg[input_update_idx[5:0]];
            else input_din <= 8'h00;
          end else if (input_update_idx <= input_len_reg && input_update_idx < CLI_BUF_LEN) begin
            if (mode_text) input_din <= input_buf_reg[input_update_idx[5:0]-6'd1];
            else input_din <= input_buf_reg[input_update_idx[5:0]];
          end else begin
            input_din <= 8'h00;
          end

          if (input_update_idx == string_pkg::INPUT_MAX_LEN - 1) begin
            state <= INP_IDLE;
          end else begin
            input_update_idx <= input_update_idx + 7'd1;
          end
        end

        default: state <= INP_IDLE;
      endcase
    end
  end

endmodule
