/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Parametric memory for storing fonts
 */
import font_pkg::*;

module font #(
    parameter font_t FONT,
    parameter string FONT_PATH
) (
    input  logic                                      clk,
    input  logic [($clog2(FONT.ROWS_PER_LETTER)-1):0] row_index,
    input  logic [                               7:0] char_code,
    output logic [      ((FONT.BYTES_PER_ROW*8)-1):0] char_width,
    output logic [      ((FONT.BYTES_PER_ROW*8)-1):0] pixels_row
);

  /**
    * Local parameters
    */

  localparam SHIFT_VAL = $clog2(FONT.ROWS_PER_LETTER);

  /**
    * ROM initialisation
    */

  logic [((FONT.BYTES_PER_ROW*8)-1):0] font_mem[0:((FONT.ROWS_PER_LETTER*256)-1)];

  initial begin
    $readmemh(FONT_PATH, font_mem);
  end

  /**
    * Internal logic
    */

  always_ff @(posedge clk) begin
    char_width <= font_mem[((SHIFT_VAL+8)'(char_code)<<SHIFT_VAL)];
    pixels_row <= font_mem[((SHIFT_VAL+8)'(char_code)<<SHIFT_VAL)+(16'(row_index)+1)];
  end


endmodule
