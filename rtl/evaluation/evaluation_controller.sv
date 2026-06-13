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

    input logic [3:0] ui_selected_item
    //TODO: communication with optibolt
);

  import string_pkg::*;

  typedef enum logic [2:0] {
    S_INIT,
    S_IDLE,
    S_WRITE_CURSOR,
    S_WRITE_NULL
  } state_t;
  state_t state;

  logic [10:0] input_cursor;
  logic [10:0] init_idx;
  logic [7:0] init_str[0:2];

  always_comb begin
    init_str[0] = 8'h3E;  // '>'
    init_str[1] = 8'h20;  // ' '
    init_str[2] = 8'h5F;  // '_'
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_INIT;
      init_idx <= '0;
      input_cursor <= 11'd2;  // Za napisem "> " kursor '_' znajduje się na indeksie 2

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
          input_addr <= init_idx;
          if (init_idx < 3) begin
            input_din <= init_str[init_idx];
            init_idx  <= init_idx + 1;
          end else begin
            input_din <= 8'h00;  // Null terminator
            state <= S_IDLE;
          end
          input_we <= 1'b1;
        end

        S_IDLE: begin
          if (ui_selected_item == 4'd1) begin  // ID = 1 to ITEM_INPUT
            if (cmd_enter && input_cursor > 2) begin
              // Czyszczenie ekranu (docelowo "string engine" tu zczyta z pamieci i napisze do konsoli)
              input_cursor <= 11'd2;
              input_addr <= 11'd2;
              input_din <= 8'h5F;  // '_'
              input_we <= 1'b1;
              state <= S_WRITE_NULL;
            end else if (char_valid && input_cursor < (INPUT_MAX_LEN - 2)) begin
              input_addr <= input_cursor;
              input_din <= char_ascii;
              input_we <= 1'b1;
              input_cursor <= input_cursor + 1;
              state <= S_WRITE_CURSOR;
            end else if (cmd_backspace && input_cursor > 2) begin
              input_cursor <= input_cursor - 1;
              input_addr <= input_cursor - 1;
              input_din <= 8'h5F;  // '_'
              input_we <= 1'b1;
              state <= S_WRITE_NULL;
            end
          end
        end

        S_WRITE_CURSOR: begin
          input_addr <= input_cursor;
          input_din <= 8'h5F;  // '_'
          input_we <= 1'b1;
          state <= S_WRITE_NULL;
        end

        S_WRITE_NULL: begin
          input_addr <= input_cursor + 1;
          input_din <= 8'h00;  // '\0'
          input_we <= 1'b1;
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
