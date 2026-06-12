/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 * Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for draw_rect.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

module draw_rect_tb;

  timeunit 1ns; timeprecision 1ps;

  // f = 74.25 MHz -> T = 13.468 ns
  real CLK_PERIOD = 13.468;
  localparam RST_START_TIME = 30;
  localparam RST_ACTIVE_TIME = 30;

  logic clk, rst_n;
  wire vs, hs;
  wire [11:0] rgb_out;
  logic draw_en_out;

  logic [10:0] xstart, ystart, xend, yend, thickness;
  logic filled;
  logic [11:0] color;

  vga_if tim_if ();

  assign vs = tim_if.vsync;
  assign hs = tim_if.hsync;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );

  draw_rect dut (
      .clk(clk),
      .rst_n(rst_n),
      .xstart(xstart),
      .ystart(ystart),
      .xend(xend),
      .yend(yend),
      .filled(filled),
      .thickness(thickness),
      .color(color),
      .vga_in(tim_if.in),
      .rgb_out(rgb_out),
      .draw_en_out(draw_en_out)
  );

  // Ciemnoszare tło dla widoczności "przezroczystości"
  wire [3:0] r = draw_en_out ? rgb_out[11:8] : 4'h2;
  wire [3:0] g = draw_en_out ? rgb_out[7:4] : 4'h2;
  wire [3:0] b = draw_en_out ? rgb_out[3:0] : 4'h2;

  tiff_writer #(
      .XDIM(16'd1650),
      .YDIM(16'd750),
      .FILE_DIR("../../results")
  ) u_tiff_writer (
      .clk(clk),
      .r  ({r, r}),
      .g  ({g, g}),
      .b  ({b, b}),
      .go (vs)
  );

  initial begin
    rst_n = 1'b1;
    // dummy initial values
    xstart = 11'd100;
    ystart = 11'd100;
    xend = 11'd300;
    yend = 11'd200;
    filled = 1;
    thickness = 0;
    color = 12'hF_0_0;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;
    wait (vs == 1'b0);
    @(negedge vs);

    // Klatka 0: domyślny czerwony prostokąt
    xstart = 11'd100;
    ystart = 11'd100;
    xend = 11'd300;
    yend = 11'd200;
    filled = 1;
    thickness = 11'd0;
    color = 12'hF_0_0;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Klatka 1: Zarys prostokąta (ramka)
    xstart = 11'd200;
    ystart = 11'd200;
    xend = 11'd500;
    yend = 11'd400;
    filled = 0;
    thickness = 11'd5;
    color = 12'h0_F_0;
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    // Klatka 2: Wypełniony prostokąt
    xstart = 11'd400;
    ystart = 11'd100;
    xend = 11'd800;
    yend = 11'd300;
    filled = 1;
    thickness = 11'd0;
    color = 12'h0_0_F;
    @(posedge vs) $display("Info: Frame 2 done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
