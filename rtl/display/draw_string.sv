/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw function for single block of text
 */
    //TODO: Create logic and regs
    //TODO: Set register size based on parameters
    //TODO: Add null, tab and new line handling

import font_pkg::*;

module draw_string #(
    parameter font_t FONT,
    parameter string FONT_PATH,
    parameter int    MAX_STRING_LEN,
    parameter logic [11:0] COLOR     = 12'hFFF
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        vsync,
    input  logic        hsync,
    input  logic [11:0] vga_x,
    input  logic [11:0] vga_y,

    input  logic [11:0] start_x,
    input  logic [11:0] start_y,
    input  logic [11:0] end_x,
    input  logic [11:0] end_y,

    input  logic [7:0]  string_data [0:MAX_STRING_LEN-1],
    input  logic [7:0] letter_spacing,
    input logic [7:0] row_spacing,

    output logic [11:0] pixel_color
);

    localparam PIXEL_ROW_W = (FONT.BYTES_PER_ROW<<3);

    // FSM States for Background Prefetcher
    typedef enum logic [2:0] {
        PF_IDLE   = 3'd0,
        PF_INIT_0 = 3'd1, // Set address to char 0
        PF_INIT_1 = 3'd2, // Wait ROM, set address to char 1
        PF_INIT_2 = 3'd3, // Load char 0 to buf[0], set address to char 2
        PF_READY  = 3'd4  // Ready to draw
    } pf_state_t;

    typedef enum logic [1:0] {
        DRAW_CHAR  = 2'd0, // Drawing pixels of a character
        DRAW_SPACE = 2'd1, // Drawing empty space between characters
        DRAW_DONE  = 2'd2  // Finished drawing line (waiting for next line)
    } draw_state_t;

    pf_state_t   pf_state;
    draw_state_t draw_state;

    localparam IDX_W = $clog2(MAX_STRING_LEN + 1);

    // Pointers and counters
    logic [IDX_W-1:0] fetch_idx;      // Index of the character currently requested from ROM
    logic [IDX_W-1:0] curr_drawn_idx; // Index of the character currently in buffer[1]
    logic [IDX_W-1:0] line_start_idx; // Index of the first character in the current visual text line
    logic [IDX_W-1:0] next_line_idx;  // Index of the first character for the next wrapped text line
    logic [7:0]  y_in_line;      // Current pixel row within the text line (0 to letter height + spacing)
    logic [7:0]  col;            // Current pixel column within the currently drawn character
    logic [7:0]  space_cnt;      // Counter for letter spacing pixels
    logic        is_null_reached;// Flag set when string terminator (0x00) is encountered

    // ROM and Buffer signals
    logic [IDX_W-1:0] active_fetch_idx;
    logic [7:0]  raw_fetch_char;
    logic [7:0]  curr_char;
    logic [7:0]  char_code_to_rom;
    logic [PIXEL_ROW_W-1:0] char_width;
    logic [PIXEL_ROW_W-1:0] char_row_pixels;
    logic [PIXEL_ROW_W-1:0] active_char_width;

    logic load_buffer;
    logic shift_buffer;
    logic shift_en;
    logic [PIXEL_ROW_W-1:0] out_width_buffer;
    logic [PIXEL_ROW_W-1:0] out_row_buffer;

    // Combinatorial Draw Signals
    logic in_draw_region;
    logic stop_line;
    logic pixel_bit;

    logic init_y_trigger;
    logic [11:0] next_vga_y;
    logic active_line;

    // Edge detectors for sync signals
    logic vsync_prev, hsync_prev;
    logic vsync_pulse, hsync_pulse;     //detected rising edge

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_prev <= 1'b0;
            hsync_prev <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            hsync_prev <= hsync;
        end
    end

    assign vsync_pulse = vsync && !vsync_prev;
    assign hsync_pulse = hsync && !hsync_prev;

    assign init_y_trigger = (start_y == 0) ? vsync_pulse : (hsync_pulse && (vga_y == start_y - 12'd1));
    assign next_vga_y     = hsync_pulse ? (vga_y + 12'd1) : vga_y;

    assign in_draw_region = (vga_x >= start_x) && (vga_x <= end_x) && (vga_y >= start_y) && (vga_y <= end_y);

    always_comb begin
        if (curr_drawn_idx < MAX_STRING_LEN)
            curr_char = string_data[curr_drawn_idx];
        else
            curr_char = 8'h00;
    end

    // Obsługa znaku tabulacji (szerokość 4 spacji) oraz szerokości zerowej
    assign active_char_width = (curr_char == 8'h09) ? (out_width_buffer << 2) :
                               (out_width_buffer == 0) ? 8'd1 : out_width_buffer;

    // Determine if we need to wrap or stop entirely
    assign stop_line = (curr_char == 8'h0A) ||
                       (curr_char == 8'h00) ||
                       ((vga_x + 12'(active_char_width) > end_x + 1) && (col == 0));

    assign shift_en = in_draw_region && (pf_state == PF_READY) &&
                      ((draw_state == DRAW_CHAR && (col + 1 >= active_char_width) && letter_spacing == 0 && !stop_line) ||
                       (draw_state == DRAW_SPACE && (space_cnt + 1 >= letter_spacing)));

    assign shift_buffer = (pf_state == PF_INIT_1) || (pf_state == PF_INIT_2) || shift_en;
    assign load_buffer  = shift_buffer;

    always_comb begin
        case (pf_state)
            PF_INIT_0: active_fetch_idx = line_start_idx;
            PF_INIT_1: active_fetch_idx = line_start_idx + 1;
            PF_INIT_2: active_fetch_idx = line_start_idx + 2;
            PF_READY:  active_fetch_idx = shift_en ? (fetch_idx + 1) : fetch_idx;
            default:   active_fetch_idx = fetch_idx;
        endcase
    end

    always_comb begin
        if (active_fetch_idx < MAX_STRING_LEN)
            raw_fetch_char = string_data[active_fetch_idx];
        else
            raw_fetch_char = 8'h00;
    end

    // Safe fallback for unprintable characters (\n, \t) to avoid fetching garbage widths from ROM
    assign char_code_to_rom = (raw_fetch_char >= 8'h20 || raw_fetch_char == 8'h00) ? raw_fetch_char : 8'h20;

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

    prefetch_buffer #(
        .WORD_WIDTH((FONT.BYTES_PER_ROW<<3))
    ) u_width_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .load(load_buffer),
        .shift(shift_buffer),
        .in(char_width),
        .out(out_width_buffer)
    );

    prefetch_buffer #(
        .WORD_WIDTH((FONT.BYTES_PER_ROW<<3))
    ) u_row_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .load(load_buffer),
        .shift(shift_buffer),
        .in(char_row_pixels),
        .out(out_row_buffer)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pf_state <= PF_IDLE;
            draw_state <= DRAW_DONE;
            fetch_idx <= '0;
            curr_drawn_idx <= '0;
            line_start_idx <= '0;
            next_line_idx <= '0;
            y_in_line <= '0;
            col <= '0;
            space_cnt <= '0;
            is_null_reached <= '0;
            active_line <= '0;
        end else begin
            if (hsync_pulse) active_line <= 1'b0;
            else if (vga_x == start_x) active_line <= 1'b1;

            if (vsync_pulse && start_y != 0) begin
                pf_state <= PF_IDLE; // Reset to idle to wait for start_y - 1
                draw_state <= DRAW_DONE;
            end
            else if (init_y_trigger) begin
                y_in_line <= '0;
                line_start_idx <= '0;
                next_line_idx <= '0;
                is_null_reached <= '0;
                pf_state <= PF_INIT_0;
            end
            else if (hsync_pulse && vga_y >= start_y && vga_y <= end_y && pf_state != PF_IDLE) begin
                if (y_in_line >= FONT.LETTER_HEIGHT + row_spacing - 1) begin
                    y_in_line <= '0;
                    if (!is_null_reached) begin
                        line_start_idx <= next_line_idx;
                        pf_state <= PF_INIT_0;
                    end else begin
                        pf_state <= PF_IDLE;
                    end
                end else begin
                    y_in_line <= y_in_line + 1;
                    pf_state <= PF_INIT_0;
                end
                draw_state <= DRAW_DONE;
            end
            else begin
                case (pf_state)
                    PF_INIT_0: begin
                        pf_state <= PF_INIT_1;
                    end
                    PF_INIT_1: begin
                        pf_state <= PF_INIT_2;
                    end
                    PF_INIT_2: begin
                        fetch_idx <= line_start_idx + 2;
                        curr_drawn_idx <= line_start_idx;
                        pf_state <= PF_READY;
                        draw_state <= DRAW_CHAR;
                        col <= 0;
                        space_cnt <= 0;
                    end
                    PF_READY: begin
                        if (shift_en) fetch_idx <= fetch_idx + 1;
                    end
                    default: ;
                endcase

                if (pf_state == PF_READY) begin
                if ((active_line || vga_x == start_x) && vga_y >= start_y && vga_y <= end_y) begin
                        if (draw_state == DRAW_CHAR) begin
                            if (stop_line && !shift_en) begin
                                draw_state <= DRAW_DONE;
                                if (curr_char == 8'h00) is_null_reached <= 1'b1;
                                // Always calculate next line index, making it immune to y_in_line desyncs
                                if (curr_char == 8'h0A)
                                    next_line_idx <= curr_drawn_idx + 1;
                                else if (curr_char != 8'h00) begin
                                    if (curr_char == 8'h20) // Skip leading space on wrapped lines
                                        next_line_idx <= curr_drawn_idx + 1;
                                    else
                                        next_line_idx <= curr_drawn_idx;
                                end
                            end else begin
                                if (col + 1 >= active_char_width) begin
                                    if (letter_spacing > 0) begin
                                        draw_state <= DRAW_SPACE;
                                        space_cnt <= 0;
                                    end else begin
                                        col <= 0;
                                        curr_drawn_idx <= curr_drawn_idx + 1;
                                    end
                                end else begin
                                    col <= col + 1;
                                end
                            end
                        end else if (draw_state == DRAW_SPACE) begin
                            if (space_cnt + 1 >= letter_spacing) begin
                                draw_state <= DRAW_CHAR;
                                col <= 0;
                                curr_drawn_idx <= curr_drawn_idx + 1;
                            end else begin
                                space_cnt <= space_cnt + 1;
                            end
                        end
                    end
                end
            end
        end
    end


    assign pixel_bit = (col < PIXEL_ROW_W) ? out_row_buffer[(PIXEL_ROW_W - 1) - col] : 1'b0;

    assign pixel_color = (in_draw_region && pf_state == PF_READY && draw_state == DRAW_CHAR && !stop_line && pixel_bit) ? COLOR : 12'h000;

endmodule
