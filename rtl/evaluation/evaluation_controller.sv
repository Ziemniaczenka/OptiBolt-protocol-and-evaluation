/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Master FSM managing tests and UI Popups.
 * This module acts as the controller for the evaluation platform, writing data
 * to the shared display memory for the top_display to render.
 * Work in progress
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

    // --- Outputs ---
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
    output logic [7:0] progress_val
    //TODO: communication with optibolt
);

  import string_pkg::*;
  import ui_pkg::*;

  typedef enum logic [2:0] {
    S_INIT,
    S_IDLE,
    S_BRAM_UPDATE
  } state_t;
  state_t state;

  logic [7:0] input_buf [0:INPUT_MAX_LEN-1];
  logic [10:0] input_len;
  logic [10:0] input_cursor;
  logic [10:0] bram_update_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_INIT;
      mode_text <= 1'b0;
      input_len <= 11'd2;
      show_popup <= 1'b0;
      show_progress <= 1'b0;
      progress_val <= '0;
      input_cursor <= 11'd2;  // Za napisem "> " kursor '_' znajduje się na indeksie 2
      bram_update_idx <= '0;

      for (int i=0; i<INPUT_MAX_LEN; i++) input_buf[i] <= 8'h00;

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
      input_we   <= 1'b0;  // Default
      console_we <= 1'b0;  // Default
      bmp_we     <= 1'b0;  // Default

      case (state)
        S_INIT: begin
          input_buf[0] <= 8'h3E; // '>'
          input_buf[1] <= 8'h20; // ' '
          state <= S_BRAM_UPDATE;
          bram_update_idx <= '0;
        end

        S_IDLE: begin
          if (mode_text) begin
            if (cmd_esc) begin
              mode_text <= 1'b0;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end else if (cmd_enter) begin
              input_len <= 11'd2;
              input_cursor <= 11'd2;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end else if (cmd_left && input_cursor > 2) begin
              input_cursor <= input_cursor - 1;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end else if (cmd_right && input_cursor < input_len) begin
              input_cursor <= input_cursor + 1;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end else if (char_valid && input_len < (INPUT_MAX_LEN - 2)) begin
              for (int i = INPUT_MAX_LEN - 1; i > 0; i--) begin
                if (i > input_cursor) input_buf[i] <= input_buf[i-1];
              end
              input_buf[input_cursor] <= char_ascii;
              input_cursor <= input_cursor + 1;
              input_len <= input_len + 1;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end else if (cmd_backspace && input_cursor > 2) begin
              for (int i = 2; i < INPUT_MAX_LEN - 1; i++) begin
                if (i >= input_cursor - 1) input_buf[i] <= input_buf[i+1];
              end
              input_cursor <= input_cursor - 1;
              input_len <= input_len - 1;
              bram_update_idx <= '0;
              state <= S_BRAM_UPDATE;
            end
          end else begin
            if (cmd_enter) begin
              if (ui_selected_item == ITEM_INPUT) begin
                mode_text <= 1'b1;
                bram_update_idx <= '0;
                state <= S_BRAM_UPDATE;
              end else if (ui_selected_item == ITEM_ABOUT_BTN) begin
                show_popup <= 1'b1; // Pokaż popup
              end else if (ui_selected_item == ITEM_POPUP_BTN) begin
                show_popup <= 1'b0; // Zamknij popup
              end
            end
          end
        end

        S_BRAM_UPDATE: begin
          input_addr <= bram_update_idx;
          input_we <= 1'b1;

          if (bram_update_idx < input_cursor) begin
            input_din <= input_buf[bram_update_idx];
          end else if (bram_update_idx == input_cursor) begin
            if (mode_text) input_din <= 8'h5F; // '_'
            else if (bram_update_idx < input_len) input_din <= input_buf[bram_update_idx];
            else input_din <= 8'h00;
          end else if (bram_update_idx <= input_len) begin
            if (mode_text) input_din <= input_buf[bram_update_idx - 1];
            else input_din <= input_buf[bram_update_idx];
          end else begin
            input_din <= 8'h00;
          end

          if (bram_update_idx > input_len) begin
            state <= S_IDLE;
          end else begin
            bram_update_idx <= bram_update_idx + 1;
          end
        end
      endcase
    end
  end

endmodule
