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

    localparam int MAX_STRING_LEN = 5000;

    localparam logic [11:0] START_X = 12'd10;
    localparam logic [11:0] START_Y = 12'd10;
    localparam logic [11:0] END_X   = 12'd500;
    localparam logic [11:0] END_Y   = 12'd400;
    localparam logic [11:0] COLOR   = 12'hF_F_8;

    localparam logic [7:0] LETTER_SPACING = 8'd1;
    localparam logic [7:0] ROW_SPACING    = 8'd1;

    string str_val = "Hello world!\n\
SZ & TW\n\
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque at vehicula mi. Vestibulum non sollicitudin urna. Fusce consectetur, ipsum nec viverra dictum, quam dolor scelerisque nunc, ac tincidunt ligula mi ac diam. Morbi convallis nisl sed porttitor mattis. Maecenas in nibh feugiat, vulputate massa eu, congue lacus. Maecenas ut interdum erat. Quisque congue erat dui, vel venenatis metus sollicitudin in. In dapibus commodo dolor, vel aliquam nunc malesuada iaculis. Ut mollis, eros nec rutrum blandit, ex mauris tincidunt turpis, a hendrerit dui nisi eget sapien. Vivamus laoreet massa et consequat eleifend. Aenean mattis justo sit amet placerat semper. In hac habitasse platea dictumst. Integer vulputate, metus sed pharetra lacinia, augue mauris lacinia quam, vitae faucibus massa lorem at orci. Morbi mollis eros non neque aliquam, ut condimentum lectus aliquam. Nullam sodales sit amet ante eget viverra. Sed eget erat imperdiet, scelerisque massa nec, auctor augue.\n\n\
Sed ac luctus diam. Fusce viverra lorem libero, ac dapibus neque consequat sit amet. Vestibulum scelerisque metus eu magna feugiat placerat. Integer quis justo pretium, porta dui a, efficitur nunc. Donec venenatis viverra ex venenatis facilisis. Aliquam auctor consectetur ligula sed porttitor. Proin molestie nisi sed lacus venenatis, in vestibulum mauris volutpat. Integer vel massa fringilla, pretium orci et, semper sem. Sed pretium et nulla ac posuere.\n\n\
Donec non congue mi. Fusce gravida neque at odio rhoncus accumsan. Aliquam gravida justo porttitor orci maximus, nec convallis lectus vehicula. Pellentesque rhoncus mollis luctus. Duis sapien sem, pellentesque ac lacus ut, vulputate accumsan urna. Quisque fermentum aliquet leo, nec sagittis arcu finibus volutpat. Vivamus a suscipit nisl, at porttitor eros. Nullam venenatis varius egestas.\n\n\
In odio libero, pellentesque vel nisl ac, porta fermentum nisl. Nulla in nisi vel felis pulvinar blandit. Phasellus auctor pharetra scelerisque. Suspendisse interdum dolor ut tortor lacinia bibendum. Cras rutrum nibh nisi, ut eleifend purus mattis non. Duis efficitur iaculis vehicula. Suspendisse gravida enim ac arcu malesuada, ac scelerisque felis consequat. Quisque ac nisi eget augue imperdiet pulvinar. Praesent nec euismod enim. Maecenas id lectus dolor. Sed ut ligula quam. Nam scelerisque pellentesque enim quis convallis.\n\n\
Praesent vitae arcu at massa venenatis venenatis. Curabitur at mollis turpis, eget mollis ipsum. Ut nec finibus sapien. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Vivamus sed lobortis elit. Etiam sed placerat magna. Vivamus id pretium mi. Donec egestas tellus sed facilisis efficitur. Sed laoreet diam quis metus vestibulum malesuada. Quisque dapibus ante sem, at semper augue volutpat sed. Aliquam suscipit faucibus felis vitae dignissim.\n\n\
";

    logic [7:0] string_data [0:MAX_STRING_LEN-1];

    initial begin
        for (int i = 0; i < MAX_STRING_LEN; i++) begin
            if (i < str_val.len())
                string_data[i] = str_val[i];
            else
                string_data[i] = 8'h00;
        end
    end

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
