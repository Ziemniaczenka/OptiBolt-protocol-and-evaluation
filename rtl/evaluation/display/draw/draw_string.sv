/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw function for single block of text
 * Supports variable-width characters, custom letter/row spacing, text wrapping,
 * and dynamic fetching from ROM/BRAM using a pipelined architecture and a FWFT FIFO.
 * TODO: add registered output (at the cost of increasing delay by one cycle)
 * TODO: separate submodules (FWFT FIFO, etc.)
 * TODO: add fallback if char_width=0 (eg. char not implemented in font file)
 * TODO: add labels to blocks
 */

import font_pkg::*;

module draw_string #(
    parameter font_t        FONT,
    parameter string        FONT_PATH,
    parameter int           MAX_STRING_LEN,
    parameter logic  [11:0] COLOR          = 12'hFFF
) (
    input logic     clk,
    input logic     rst_n,
          vga_if.in vga_in,

    input logic [11:0] start_x,
    input logic [11:0] start_y,
    input logic [11:0] end_x,
    input logic [11:0] end_y,
    input logic wrap_text,

    // Memory / ROM Interface
    output logic [$clog2(MAX_STRING_LEN+1)-1:0] char_addr,
    input  logic [                         7:0] char_data,
    input  logic [                         7:0] letter_spacing,
    input  logic [                         7:0] row_spacing,

    output logic [11:0] pixel_color,
    output logic        draw_en
);

  /*
  * Local variables and signals
  */

  localparam PIXEL_ROW_W = (FONT.BYTES_PER_ROW << 3);  // Max width of a character in pixels
  localparam IDX_W = $clog2(MAX_STRING_LEN + 1);  // Bit width for character index

  typedef enum logic [2:0] {
    IDLE         = 3'd0,  // Standby, waiting for the correct screen region vcount
    WAIT_X       = 3'd1,  // Waiting for hcount == start_x
    DRAW_CHAR    = 3'd2,  // Drawing pixels of the current character
    DRAW_SPACE   = 3'd3,  // Drawing empty space between characters
    FAST_FORWARD = 3'd4,  // Skipping characters until newline/null (used when wrap_text=0)
    ROW_SETUP    = 3'd5   // Preparing pointers and fetcher for the next pixel row
  } draw_state_t;

  draw_state_t draw_state;

  /*
  * Pointers and Counters
  */

  logic [IDX_W-1:0] line_start_idx;  // Pointer to the first character of the current line
  logic [IDX_W-1:0] next_line_idx;  // Pointer to the first character of the next line
  logic [IDX_W-1:0] curr_drawn_idx;  // Pointer to the character currently being evaluated/drawn
  logic [7:0] y_in_line;  // Current pixel row within the text line (from 0 to letter_height + spacing)
  logic [7:0] col;  // Current pixel column within the currently drawn character
  logic [7:0] space_cnt;  // Counter for letter spacing pixels

  /*
  * Status Flags
  */

  logic is_null_reached;  // Flag set when reached null
  logic string_done;  // Flag set when string is fully drawn for the frame

  /*
  * Pipeline and FIFO Data Signals
  */

  logic [7:0] curr_char;
  logic [7:0] char_code_to_rom;
  logic [PIXEL_ROW_W-1:0] char_width;  // store whole row from rom
  logic [PIXEL_ROW_W-1:0] char_row_pixels;
  logic [PIXEL_ROW_W-1:0] active_char_width;  //?
  logic [IDX_W-1:0] fetch_start_idx;  //?

  logic [PIXEL_ROW_W-1:0] out_width_buffer;
  logic [PIXEL_ROW_W-1:0] out_row_buffer;

  /*
  * Combinatorial Draw Condition Signals
  */
  logic in_draw_region_x;
  logic in_draw_region_y;
  logic in_draw_region;
  logic is_last_pixel;  // last pixel in row
  logic char_wrap;
  logic stop_line;
  logic pixel_bit;
  logic draw_en_nxt;

  /*
  * Internal logic
  */

  /*
  *  1. Edge Detectors & Line Control
  */

  logic vsync_pulse;

  edge_detector u_vsync_ed (
      .clk(clk),
      .rst_n(rst_n),
      .in(vga_in.vsync),
      .rise(vsync_pulse),
      .fall()
  );

  logic line_done;
  assign line_done = (y_in_line >= FONT.LETTER_HEIGHT + row_spacing - 1);

  logic pre_block_y;
  assign pre_block_y = (12'(vga_in.vcount) == start_y - 12'd1);

  logic line_active_y;
  assign line_active_y = (12'(vga_in.vcount) >= start_y) && (12'(vga_in.vcount) <= end_y);

  // Trigger fetcher setup 1 line before rendering starts, or at VSYNC if start_y is 0
  logic do_first_line_setup;
  assign do_first_line_setup = (vsync_pulse && start_y == 0) || (vga_in.hcount == 0 && pre_block_y && start_y != 0);

  /*
  * 2. Fetcher Pipeline & FIFO
  */

  logic start_fetch;

  logic [2:0] valid_pipe;
  logic [7:0] char_data_q1, char_data_q2;
  logic fetching_active, stop_line_fetch, fifo_flush;
  logic [IDX_W-1:0] fetch_idx;

  logic fifo_push, fifo_pop, fifo_empty, fifo_full;
  logic [3:0] fifo_count;
  logic [(PIXEL_ROW_W*2)+7:0] fifo_dout;

  assign char_addr = fetch_idx;

  // Keep track of requests currently propagating through the pipeline to prevent FIFO overflow
  logic [3:0] in_flight;
  assign in_flight = {3'b0, valid_pipe[0]} + {3'b0, valid_pipe[1]} + {3'b0, valid_pipe[2]};
  logic req_fetch;
  assign req_fetch = fetching_active && !stop_line_fetch && !fifo_full && ((fifo_count + in_flight) < 8) && !fifo_flush;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipe <= '0;
      fetching_active <= 1'b0;
      fetch_idx <= '0;
      stop_line_fetch <= 1'b0;
      fifo_flush <= 1'b0;
      char_data_q1 <= '0;
      char_data_q2 <= '0;
    end else begin
      if (start_fetch) begin
        valid_pipe <= '0;
        fetching_active <= 1'b1;
        fetch_idx <= fetch_start_idx;
        stop_line_fetch <= 1'b0;
        fifo_flush <= 1'b1;
        char_data_q1 <= '0;
        char_data_q2 <= '0;
      end else begin
        fifo_flush <= 1'b0;

        // Pipeline Stage 1: Request character from Memory (BRAM/ROM)
        if (req_fetch) begin
          fetch_idx <= fetch_idx + 1;
          valid_pipe[0] <= 1'b1;
        end else begin
          valid_pipe[0] <= 1'b0;
        end

        // Pipeline Stage 2: Memory output is valid, capture char, request pixels from Font ROM
        valid_pipe[1] <= valid_pipe[0];
        if (valid_pipe[0]) char_data_q1 <= char_data;

        // Pipeline Stage 3: Font ROM output is valid, capture data for pushing to FIFO
        valid_pipe[2] <= valid_pipe[1];
        if (valid_pipe[1]) char_data_q2 <= char_data_q1;

        // Stop fetch if terminal char (data valid at end of stage 1)
        if (valid_pipe[0] && (char_data == 8'h0A || char_data == 8'h00)) begin
          stop_line_fetch <= 1'b1;
        end
      end
    end
  end

  assign fifo_push = valid_pipe[2];

  // Safe fallback for unprintable characters (e.g. \n, \t) or Null terminator
  // Prevents fetching garbage widths from ROM. They are treated as spaces (0x20). //TODO: add to font special character [x]
  assign char_code_to_rom = (char_data_q1 >= 8'h20 || char_data_q1 == 8'h00) ? char_data_q1 : 8'h20;

  font #(
      .FONT(FONT),
      .FONT_PATH(FONT_PATH)
  ) u_font (
      .clk(clk),
      .row_index(y_in_line[$clog2(FONT.ROWS_PER_LETTER)-1:0]),
      .char_code(char_code_to_rom),
      .char_width(char_width),
      .pixels_row(char_row_pixels)
  );

  fwft_fifo #(
      .WORD_WIDTH((PIXEL_ROW_W * 2) + 8),
      .DEPTH(8)
  ) u_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .flush(fifo_flush),
      .push(fifo_push),
      .pop(fifo_pop),
      .din({
        char_data_q2, char_width, char_row_pixels
      }),  // char_data_q2 is aligned with font output in Stage 3
      .dout(fifo_dout),
      .empty(fifo_empty),
      .full(fifo_full),
      .count(fifo_count)
  );

  assign curr_char = fifo_dout[(PIXEL_ROW_W*2)+7 : (PIXEL_ROW_W*2)];
  assign out_width_buffer = fifo_dout[(PIXEL_ROW_W*2)-1 : PIXEL_ROW_W];
  assign out_row_buffer = fifo_dout[PIXEL_ROW_W-1 : 0];

  // Handle tab character (width of 4 spaces) and prevent 0-width crashes
  assign active_char_width = (curr_char == 8'h09) ? (out_width_buffer << 2) : (out_width_buffer == 0) ? 8'd1 : out_width_buffer;

  assign in_draw_region_x = (12'(vga_in.hcount) >= start_x) && (12'(vga_in.hcount) <= end_x);
  assign in_draw_region_y = (12'(vga_in.vcount) >= start_y) && (12'(vga_in.vcount) <= end_y);
  assign in_draw_region = in_draw_region_x && in_draw_region_y;

  assign is_last_pixel = (col + 1 >= active_char_width);
  assign char_wrap = wrap_text && in_draw_region_x && (12'(vga_in.hcount) + 12'(active_char_width) > end_x + 1) && (col == 0) && (active_char_width > 0);
  assign stop_line = (curr_char == 8'h0A) || (curr_char == 8'h00) || char_wrap;

  /*
  * Combinational FWFT FIFO Pop Logic
  */

  always_comb begin
    fifo_pop = 1'b0;
    if (in_draw_region_y) begin
      if (draw_state == DRAW_CHAR && in_draw_region_x) begin
        if (!fifo_empty && !stop_line && is_last_pixel && col < active_char_width) begin
          fifo_pop = 1'b1;
        end
      end else if (draw_state == FAST_FORWARD) begin
        // Continue popping until a newline or null character is found
        if (!fifo_empty && curr_char != 8'h0A && curr_char != 8'h00) begin
          fifo_pop = 1'b1;
        end
      end
    end
  end

  /*
  * 3. Main Drawing FSM
  */
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y_in_line <= 'd0;
      line_start_idx <= 'd0;
      next_line_idx <= 'd0;
      is_null_reached <= 1'b0;
      string_done <= 1'b0;

      draw_state <= IDLE;
      col <= 'd0;
      space_cnt <= 'd0;
      curr_drawn_idx <= 'd0;
      fetch_start_idx <= '0;
      start_fetch <= 1'b0;
    end else begin
      start_fetch <= 1'b0;  // Default

      if (vsync_pulse) begin
        draw_state  <= IDLE;
        string_done <= 1'b0;
      end

      if (do_first_line_setup) begin
        y_in_line <= 'd0;
        line_start_idx <= 'd0;
        next_line_idx <= 'd0;
        is_null_reached <= 1'b0;
        string_done <= 1'b0;

        start_fetch <= 1'b1;
        fetch_start_idx <= 'd0;
        curr_drawn_idx <= 'd0;
        draw_state <= WAIT_X;
        col <= 'd0;
        space_cnt <= 'd0;
      end else if (line_active_y && !string_done) begin
        // Synchronize curr_drawn_idx with fifo_pop to perfectly track the FIFO head
        if (fifo_pop) curr_drawn_idx <= curr_drawn_idx + 1;

        unique case (draw_state)
          IDLE: begin
            // Managed by outer if-else logic
          end

          WAIT_X: begin
            if (vga_in.hcount == start_x) begin
              // Transition to drawing. Pixel output follows combinational draw_en_nxt logic
              draw_state <= DRAW_CHAR;
              col <= 'd0;
            end
          end

          DRAW_CHAR: begin
            if (!fifo_empty) begin
              if (stop_line) begin
                if (curr_char == 8'h00) is_null_reached <= 1'b1;

                if (curr_char == 8'h0A) next_line_idx <= curr_drawn_idx + 1;
                else if (char_wrap && curr_char != 8'h00) begin
                  if (curr_char == 8'h20) next_line_idx <= curr_drawn_idx + 1;
                  else next_line_idx <= curr_drawn_idx;
                end
                draw_state <= ROW_SETUP;
              end else if (12'(vga_in.hcount) > end_x) begin
                if (wrap_text) begin
                  if (curr_char == 8'h20) next_line_idx <= curr_drawn_idx + 1;
                  else next_line_idx <= curr_drawn_idx;
                  draw_state <= ROW_SETUP;
                end else begin
                  if (line_done) draw_state <= FAST_FORWARD;
                  else draw_state <= ROW_SETUP;
                end
              end else if (in_draw_region_x) begin
                if (is_last_pixel) begin
                  if (letter_spacing > 0) begin
                    draw_state <= DRAW_SPACE;
                    space_cnt  <= 8'd1;
                  end else begin
                    draw_state <= DRAW_CHAR;
                    col <= 'd0;
                  end
                end else begin
                  col <= col + 1;
                end
              end
            end else if (12'(vga_in.hcount) > end_x) begin
              if (wrap_text) begin
                next_line_idx <= curr_drawn_idx;
                draw_state <= ROW_SETUP;
              end else begin
                if (line_done) draw_state <= FAST_FORWARD;
                else draw_state <= ROW_SETUP;
              end
            end
          end

          DRAW_SPACE: begin
            if (12'(vga_in.hcount) > end_x) begin
              if (wrap_text) begin
                next_line_idx <= curr_drawn_idx;
                draw_state <= ROW_SETUP;
              end else begin
                if (line_done) draw_state <= FAST_FORWARD;
                else draw_state <= ROW_SETUP;
              end
            end else if (in_draw_region_x) begin
              if (space_cnt >= letter_spacing) begin
                draw_state <= DRAW_CHAR;
                col <= 'd0;
              end else begin
                space_cnt <= space_cnt + 1;
              end
            end
          end

          FAST_FORWARD: begin
            if (!fifo_empty) begin
              if (curr_char == 8'h0A || curr_char == 8'h00) begin
                if (curr_char == 8'h00) is_null_reached <= 1'b1;
                next_line_idx <= curr_drawn_idx + 1;
                draw_state <= ROW_SETUP;
              end
            end
          end

          ROW_SETUP: begin
            start_fetch <= 1'b1;
            if (line_done) begin
              y_in_line <= 'd0;
              line_start_idx <= next_line_idx;
              fetch_start_idx <= next_line_idx;
              curr_drawn_idx <= next_line_idx;
              if (is_null_reached) string_done <= 1'b1;
            end else begin
              y_in_line <= y_in_line + 1;
              fetch_start_idx <= line_start_idx;
              curr_drawn_idx <= line_start_idx;
            end
            draw_state <= WAIT_X;
            col <= 'd0;
            space_cnt <= 'd0;
          end
        endcase
      end
    end
  end

  // Out of bounds check (prevents reading/drawing garbage from memory if y_in_line exceeds letter height)
  logic out_of_bounds_y;
  assign out_of_bounds_y = (y_in_line >= FONT.LETTER_HEIGHT);

  assign pixel_bit = (!out_of_bounds_y && col < PIXEL_ROW_W) ? out_row_buffer[(PIXEL_ROW_W-1)-col] : 1'b0;
  assign draw_en_nxt = in_draw_region && !fifo_empty && (draw_state == DRAW_CHAR) && !stop_line && (col < active_char_width) && pixel_bit;

  // Combinational output (for now)
  assign pixel_color = draw_en_nxt ? COLOR : 12'h000;
  assign draw_en = draw_en_nxt;

endmodule
