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
 * Testbench for draw_string.
 * Thanks to the tiff_writer module, an expected image
 * produced by the project is exported to a tif file.
 */

import font_pkg::*;

module draw_string_tb;

  timeunit 1ns; timeprecision 1ps;

  // f = 74.25 MHz -> T = 13.468 ns
  real CLK_PERIOD = 13.468;
  localparam RST_START_TIME = 30;
  localparam RST_ACTIVE_TIME = 30;
  localparam MAX_LEN = 130;


  logic clk, rst_n;
  wire vs, hs;
  wire [11:0] rgb_rom, rgb_ram;
  logic en_rom, en_ram;

  logic wrap_text;
  logic [7:0] letter_spacing;

  vga_if tim_if ();

  assign vs = tim_if.vsync;
  assign hs = tim_if.hsync;

  /**
    * Clock generation
    */

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  /**
    * Submodules instances
    */

  vga_timing u_timing (
      .clk(clk),
      .rst_n(rst_n),
      .vga_out(tim_if.out)
  );

  // --- ROM DUT ---
  bram_if #(
      .ADDR_WIDTH($clog2(MAX_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) rom_if ();

  logic [7:0] rom_str[0:MAX_LEN];
  always_ff @(posedge clk) begin
    if (rom_if.en) rom_if.dout <= rom_str[rom_if.addr];
  end

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(MAX_LEN),
      .COLOR(12'h0_F_F)
  ) dut_rom (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(tim_if.in),
      .start_x(12'd000),
      .start_y(12'd000),
      .end_x(12'd400),
      .end_y(12'd200),
      .wrap_text(wrap_text),
      .char_bram(rom_if),
      .letter_spacing(letter_spacing),
      .row_spacing(8'd1),
      .pixel_color(rgb_rom),
      .draw_en(en_rom)
  );

  // --- RAM DUT ---
  bram_if #(
      .ADDR_WIDTH($clog2(MAX_LEN + 1)),
      .DATA_WIDTH(8)
  ) ram_if_a ();
  bram_if #(
      .ADDR_WIDTH($clog2(MAX_LEN + 1)),
      .DATA_WIDTH(8),
      .READ_ONLY (1)
  ) ram_if_b ();

  bram_tdp #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH($clog2(MAX_LEN + 1))
  ) u_ram (
      .clk_a (clk),
      .clk_b (clk),
      .port_a(ram_if_a),
      .port_b(ram_if_b)
  );

  bram_writer #(
      .MAX_LEN(MAX_LEN + 1)
  ) u_writer_ram (
      .clk (clk),
      .port(ram_if_a)
  );

  draw_string #(
      .FONT(FONT_11x7),
      .FONT_PATH(FONT_11x7_PATH),
      .MAX_STRING_LEN(MAX_LEN),
      .COLOR(12'hF_F_0)  // yellow text for BRAM
  ) dut_ram (
      .clk(clk),
      .rst_n(rst_n),
      .vga_in(tim_if.in),
      .start_x(12'd100),
      .start_y(12'd250),
      .end_x(12'd400),
      .end_y(12'd350),  // Shifted down
      .wrap_text(wrap_text),
      .char_bram(ram_if_b),
      .letter_spacing(letter_spacing),
      .row_spacing(8'd1),
      .pixel_color(rgb_ram),
      .draw_en(en_ram)
  );

  // Mux the outputs based on active regions
  wire [11:0] rgb_out = en_rom ? rgb_rom : (en_ram ? rgb_ram : 12'h222);  // Default dark gray bg
  logic draw_en_out;
  assign draw_en_out = en_rom | en_ram;

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

  /**
    * Helper tasks
    */

  task write_rom_str(string s);
    for (int i = 0; i <= MAX_LEN; i++) begin
      if (i < s.len()) rom_str[i] = s[i];
      else rom_str[i] = 8'h00;
    end
  endtask

  task write_rom_bytes(logic [7:0] s[]);
    for (int i = 0; i <= MAX_LEN; i++) begin
      if (i < s.size()) rom_str[i] = s[i];
      else rom_str[i] = 8'h00;
    end
  endtask

  logic [7:0] polish_str[] = '{
      8'h54,
      8'h65,
      8'h73,
      8'h74,
      8'h20,  // "Test "
      8'h5a,
      8'h61,
      8'hbf,
      8'hf3,
      8'hb3,
      8'he6,
      8'h20,  // "Zażółć "
      8'h67,
      8'hea,
      8'h9c,
      8'h6c,
      8'hb9,
      8'h20,  // "gęślą "
      8'h6a,
      8'h61,
      8'h9f,
      8'hf1,  // "jaźń"
      8'h2e  // "."
  };

  /**
    * Main test
    */

  initial begin
    rst_n = 1'b1;

    ram_if_a.we = 1'b0;
    ram_if_a.en = 1'b0;
    ram_if_a.addr = 0;
    ram_if_a.din = 8'h0;

    wrap_text = 1'b1;
    letter_spacing = 8'd1;

    #(RST_START_TIME) rst_n = 1'b0;
    #(RST_ACTIVE_TIME) rst_n = 1'b1;

    // Initial strings for frame 0
    write_rom_str("Hello\nWorld!");
    u_writer_ram.write_string("RAM Test");

    wait (vs == 1'b0);
    @(negedge vs);

    // Frame 0
    letter_spacing = 8'd1;
    @(posedge vs) $display("Info: Frame 0 done at %t", $time);

    // Frame 1
    letter_spacing = 8'd0;
    write_rom_str("0_spacing_test (`|.`|.)");
    u_writer_ram.write_string("NoSpace (`|.`|.)");
    @(posedge vs) $display("Info: Frame 1 done at %t", $time);

    // Frame 2
    letter_spacing = 8'd5;
    write_rom_str(
        "This is a very long line of text that should wrap around the screen boundary to test the line wrapping feature.");
    u_writer_ram.write_string("Another test for RAM with a newline character \n  <- here.");
    @(posedge vs) $display("Info: Frame 2 done at %t", $time);

    // Frame 3
    letter_spacing = 8'd1;
    // Using byte array for Polish characters to avoid string encoding issues.
    // write_rom_str("Test Zażółć gęślą jaźń.");  // Keep original for comparison if needed
    write_rom_bytes(polish_str);

    u_writer_ram.write_string("A B C\nD E F\nG H I");
    @(posedge vs) $display("Info: Frame 3 done at %t", $time);

    // Frame 4 - no wrap test
    wrap_text = 1'b0;
    letter_spacing = 8'd4;
    write_rom_str("This very long line should be clipped and not wrap at all.");
    u_writer_ram.write_string(
        "This line has a newline and first line is very long.\nThis part should be on the next line.");
    @(posedge vs) $display("Info: Frame 4 (no wrap) done at %t", $time);

    $display("Simulation is over, check the frames.");
    $finish;
  end

endmodule
