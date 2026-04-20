/**
* Copyright (C) 2026  AGH University of Science and Technology
* MTM UEC2
* Author: Tomasz Więcławski & Sebastian Zoń
*
* Description:
* Module with multiple draw functions.
*/

module top_draw (
        input  logic clk,
        input  logic rst_n,

    vga_if.in vga_in,
    vga_if.out vga_out
    );

    import vga_pkg::*;
    import font_pkg::*;

    /**
    * Local variables and signals
    */

    localparam int MAX_STRING_LEN = 16;

    localparam logic [11:0] START_X = 12'd100;
    localparam logic [11:0] START_Y = 12'd100;
    localparam logic [11:0] END_X   = 12'd900;
    localparam logic [11:0] END_Y   = 12'd400;
    localparam logic [11:0] COLOR   = 12'hF_F_0; // Żółty tekst

    localparam logic [7:0] LETTER_SPACING = 8'd2;
    localparam logic [7:0] ROW_SPACING    = 8'd3;

    logic [7:0] string_data [0:MAX_STRING_LEN-1] = '{
        8'h48, 8'h65, 8'h6C, 8'h6C, 8'h6F, // "Hello"
        8'h20, 8'h57, 8'h6F, 8'h72, 8'h6C, 8'h64, 8'h21, // " World!"
        8'h0A, // "\n"
        8'h3A, 8'h29, // ":)"
        8'h00  // "\0"
    };

    logic [11:0] text_rgb;

    /**
    * Internal logic
    */

    draw_string #(
        .FONT(FONT_11x7),
        .FONT_PATH(FONT_11x7_PATH),
        .MAX_STRING_LEN(MAX_STRING_LEN),
        .COLOR(COLOR)
    ) u_draw_string (
        .clk(clk),
        .rst_n(rst_n),
        .vsync(vga_in.vsync),
        .hsync(vga_in.hsync),
        .vga_x(12'(vga_in.hcount)),
        .vga_y(12'(vga_in.vcount)),
        .start_x(START_X),
        .start_y(START_Y),
        .end_x(END_X),
        .end_y(END_Y),
        .string_data(string_data),
        .letter_spacing(LETTER_SPACING),
        .row_spacing(ROW_SPACING),
        .pixel_color(text_rgb)
    );

    delay #(
        .WIDTH(26),
        .CLK_DEL(1)
    ) u_delay (
        .clk(clk),
        .rst(~rst_n),
        .din({vga_in.vcount, vga_in.vsync, vga_in.vblnk, vga_in.hcount, vga_in.hsync, vga_in.hblnk}),
        .dout({vga_out.vcount, vga_out.vsync, vga_out.vblnk, vga_out.hcount, vga_out.hsync, vga_out.hblnk})
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_out.rgb <= '0;
        end else begin
            if (text_rgb != 12'h000) begin
                vga_out.rgb <= text_rgb;
            end else begin
                vga_out.rgb <= vga_in.rgb;
            end
        end
    end

endmodule
