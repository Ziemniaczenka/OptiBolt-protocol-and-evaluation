/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Draw function for single block of text
 */
    //TODO: Set size based on parameters
    //TODO: Add null, tab and new line handling
    //TODO: Reset line

import font_pkg::*;

module draw_string #(
    parameter font_t FONT,
    parameter int    MAX_STRING_LEN,
    parameter logic [11:0] COLOR     = 12'hFFF
) (
    input  logic        clk,
    input  logic        rst_n,

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

    logic shift_buffer;

    font #(
        .FONT(FONT)
    ) u_font (
        .clk(clk),
        .row_index(row),
        .char_code(char_code),
        .char_width(char_width),
        .pixels_row(char_row_pixels)
    );
    prefetch_buffer #(
        .WORD_WIDTH((FONT.BYTES_PER_ROW<<3))
    ) u_width_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .load(1),
        .shift(shift_buffer),
        .in(in_width_buffer),
        .out(out_width_buffer)
    );
    prefetch_buffer #(
        .WORD_WIDTH((FONT.BYTES_PER_ROW<<3))
    ) u_row_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .load(1),
        .shift(shift_buffer),
        .in(in_row_buffer),
        .out(out_row_buffer)
    );



    logic in_range_x, in_range_x_nxt;
    logic in_range_y, in_range_y_nxt;

    // Prefetch rows and widths
    enum logic [1:0] buffer_status {EMPTY, LOADED, FULL} buffer, buffer_nxt;
    logic char_in_string, char_in_string_nxt;
    logic pixel_in_row, pixel_in_row_nxt;

    logic [3:0] advance, advance_nxt;

    logic row_in_char, row_in_char_nxt;


    logic draw_pixel, draw_pixel_nxt;
    logic [11:0] pixel_color_nxt;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_y_before <= '0;
            pixel_color <= '0;
            draw_pixel <= '0;
            advance <= '0;
            in_range <= '0;
            char_in_string <= '0;
            pixel_in_row <= '0;
            column_in_char <= '0;
            row_in_char <= '0;

        end else begin
            vga_y_before <= vga_y;
            pixel_color <= pixel_color_nxt;
            advance <= advance_nxt;
            in_range <= in_range_nxt;
            draw_pixel <= draw_pixel_nxt;
            char_in_string <= char_in_string_nxt;
            pixel_in_row <= pixel_in_row_nxt;
            column_in_char <= column_in_char_nxt;
            row_in_char <= row_in_char_nxt;
        end
    end
    always_comb begin: in_range_x
        if((vga_x >= start_x - 1) && (vga_x <= end_x - 1)) begin
            in_range_x_nxt = 1;
        end else begin
            in_range_x_nxt = 0;
        end
    end

    always_comb begin: in_range_y
        if((vga_y >= start_y) && (vga_y <= end_y)) begin
            in_range_y_nxt = 1;
        end else begin
            in_range_y_nxt = 0;
        end
    end

    always_comb begin: prefetch
        if(in_range_x && in_range_y) begin
            if (out_width_buffer == pixel_in_row+1) begin
                shift_buffer = 1;
                pixel_in_row_nxt = '0;
                char_in_string_nxt = char_in_string + 1;
            end else begin
                shift_buffer = 0;
                pixel_in_row_nxt = pixel_in_row + 1;
                char_in_string_nxt = char_in_string;
            end
        end else begin
            
        end

    end

    always_comb begin: pixel_color
        pixel_color_nxt = draw_pixel_nxt ? COLOR : 12'h000;
    end

    always_comb begin: draw_pixel
        draw_pixel_nxt = char_row_pixels[(FONT.BYTES_PER_ROW<<3)-1-pixel_in_row];
    end



    always_comb begin: advance //inverse counter, if 0 -> proceed
        advance_nxt = advance;
        if(advance == 0) begin
            if(column_in_char == char_width-1) begin
                advance_nxt = letter_spacing;
            end else begin
                advance_nxt = 0;
            end
        end else begin
            advance_nxt = advance-1;
        end
    end

    always_comb begin: char_in_string
        char_in_string_nxt = char_in_string;
        if(in_range && !advance) begin
            if(column_in_char == char_width) begin
                char_in_string_nxt = char_in_string + 1;
            end
        end
    end

    always_comb begin: column_in_char
        column_in_char_nxt = column_in_char;
        if(in_range && !advance) begin
            if(column_in_char == char_width) begin
                column_in_char_nxt = 0;
            end else begin
                column_in_char_nxt = column_in_char + 1;
            end
        end
    end
    //TODO: fix logic
    always_comb begin: row_in_char
        row_in_char_nxt = row_in_char;
        if ((vga_y > vga_y_before) && (vga_y >= start_y) && (end_y >= vga_y)) begin
            if (row_in_char >= (FONT.LETTER_HEIGHT + row_spacing)) begin
                row_in_char_nxt = 0;
            end else begin
                row_in_char_nxt = row_in_char + 1;
            end
        end
    end

    assign char_code = string_data[char_in_string];
    assign row = row_in_char;

endmodule
