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
    import string_pkg::*;

    /**
    * Local variables and signals
    */

    // String 1 - static "OPTIBOLT - protocol and evaluation"
    logic [7:0] string1 [0:STRING1_LEN];
    `INIT_UNPACKED_STR(string1, STRING1_VAL, STRING1_LEN, STRING1_LEN + 1)

    // String 2 - switchable "Status: CONNECTED" : "Status: DISCONNECTED"
    logic [7:0] string2_a [0:STRING2_MAX_LEN];
    logic [7:0] string2_b [0:STRING2_MAX_LEN];
    logic [7:0] string2_sel [0:STRING2_MAX_LEN];
    `INIT_UNPACKED_STR(string2_a, STRING2_VAL_A, STRING2_LEN_A, STRING2_MAX_LEN + 1)
    `INIT_UNPACKED_STR(string2_b, STRING2_VAL_B, STRING2_LEN_B, STRING2_MAX_LEN + 1)

    // Demo (switch every few frames)
    logic       select_sig;
    logic [5:0] frame_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            select_sig <= 0;
            frame_cnt  <= 0;
        end else if (vga_in.vcount == 0 && vga_in.hcount == 0) begin
            if (frame_cnt == 2) begin
                frame_cnt  <= 0;
                select_sig <= ~select_sig;
            end else begin
                frame_cnt <= frame_cnt + 1;
            end
        end
    end

    always_comb begin
        string2_sel = select_sig ? string2_b : string2_a;
    end

    // String 3 - dynamic CONSOLE==========
    logic [7:0] console_str [0:CONSOLE_MAX_LEN-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CONSOLE_MAX_LEN; i++) begin
                if (i < CONSOLE_INIT_LEN)
                    console_str[i] <= CONSOLE_INIT_VAL[((CONSOLE_INIT_LEN - 1 - i) * 8) +: 8];
                else
                    console_str[i] <= 8'h00;
            end
        end else begin
            //TODO: console - keyboard connection
        end
    end

    // =========================================================================

    logic [2:0][11:0] text_rgb;
    logic [2:0]       text_draw_en;

    // Deleayed interface
    vga_if vga_in_d1 ();

    /**
    * Internal logic
    */

    // String 1 - static "OPTIBOLT - protocol and evaluation"
    draw_string #(
        .FONT(FONT_11x7),
        .FONT_PATH(FONT_11x7_PATH),
        .MAX_STRING_LEN(STRING1_LEN + 1),
        .COLOR(COLOR_STRING1)
    ) u_draw_string_static (
        .clk(clk),
        .rst_n(rst_n),
        .vsync(vga_in.vsync),
        .hsync(vga_in.hsync),
        .vga_x(12'(vga_in.hcount)),
        .vga_y(12'(vga_in.vcount)),
        .start_x(12'd50),
        .start_y(12'd10),
        .end_x(12'd400),
        .end_y(12'd100),
        .string_data(string1),
        .letter_spacing(8'd1),
        .row_spacing(8'd1),
        .pixel_color(text_rgb[0]),
        .draw_en(text_draw_en[0])
    );

    // String 2 - switchable "Status: CONNECTED" : "Status: DISCONNECTED"
    draw_string #(
        .FONT(FONT_11x7),
        .FONT_PATH(FONT_11x7_PATH),
        .MAX_STRING_LEN(STRING2_MAX_LEN + 1),
        .COLOR(COLOR_STRING2)
    ) u_draw_string_select (
        .clk(clk),
        .rst_n(rst_n),
        .vsync(vga_in.vsync),
        .hsync(vga_in.hsync),
        .vga_x(12'(vga_in.hcount)),
        .vga_y(12'(vga_in.vcount)),
        .start_x(12'd50),
        .start_y(12'd120),
        .end_x(12'd400),
        .end_y(12'd220),
        .string_data(string2_sel),
        .letter_spacing(8'd1),
        .row_spacing(8'd1),
        .pixel_color(text_rgb[1]),
        .draw_en(text_draw_en[1])
    );

    // String 3 - dynamic CONSOLE
    draw_string #(
        .FONT(FONT_11x7),
        .FONT_PATH(FONT_11x7_PATH),
        .MAX_STRING_LEN(CONSOLE_MAX_LEN),
        .COLOR(COLOR_CONSOLE)
    ) u_draw_string_dynamic (
        .clk(clk),
        .rst_n(rst_n),
        .vsync(vga_in.vsync),
        .hsync(vga_in.hsync),
        .vga_x(12'(vga_in.hcount)),
        .vga_y(12'(vga_in.vcount)),
        .start_x(12'd50),
        .start_y(12'd240),
        .end_x(12'd400),
        .end_y(12'd340),
        .string_data(console_str),
        .letter_spacing(8'd1),
        .row_spacing(8'd1),
        .pixel_color(text_rgb[2]),
        .draw_en(text_draw_en[2])
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_in_d1.rgb <= '0;
        end else begin
            vga_in_d1.rgb <= vga_in.rgb;
        end
    end

    delay #(
        .WIDTH(26),
        .CLK_DEL(1)
    ) u_delay_1 (
        .clk(clk),
        .rst_n(rst_n),
        .din({vga_in.vcount, vga_in.vsync, vga_in.vblnk, vga_in.hcount, vga_in.hsync, vga_in.hblnk}),
        .dout({vga_in_d1.vcount, vga_in_d1.vsync, vga_in_d1.vblnk, vga_in_d1.hcount, vga_in_d1.hsync, vga_in_d1.hblnk})
    );

    draw_mux #(
        .INPUT_COUNT(3)
    ) u_draw_mux (
        .clk(clk),
        .rst_n(rst_n),
        .in_rgb(text_rgb),
        .in_draw_en(text_draw_en),
        .vga_in(vga_in_d1),
        .out_rgb(vga_out.rgb)
    );

    delay #(
        .WIDTH(26),
        .CLK_DEL(1)
    ) u_delay_2 (
        .clk(clk),
        .rst_n(rst_n),
        .din({vga_in_d1.vcount, vga_in_d1.vsync, vga_in_d1.vblnk, vga_in_d1.hcount, vga_in_d1.hsync, vga_in_d1.hblnk}),
        .dout({vga_out.vcount, vga_out.vsync, vga_out.vblnk, vga_out.hcount, vga_out.hsync, vga_out.hblnk})
    );

endmodule
