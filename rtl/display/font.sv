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
        parameter font_t FONT
        // parameter   int     ROWS_PER_LETTER,
        // parameter   int     BYTES_PER_ROW,
        // parameter   string  FONT_PATH
    ) (
        input   logic                                           clk,
        input   logic   [($clog2(FONT.ROWS_PER_LETTER)-1):0]    row_index,
        input   logic   [7:0]                                   char_code,
        output  logic   [((FONT.BYTES_PER_ROW*8)-1):0]          char_width,
        output  logic   [((FONT.BYTES_PER_ROW*8)-1):0]          pixels_row
    );

    localparam SHIFT_VAL = $clog2(FONT.ROWS_PER_LETTER);

    logic [((FONT.BYTES_PER_ROW*8)-1):0] font_mem [0:((FONT.ROWS_PER_LETTER*256)-1)];

    initial begin
        $readmemh(FONT.FONT_PATH, font_mem);
    end


    always_ff @(posedge clk) begin
        length <= font_mem[(letter<<SHIFT_VAL)];
        row <= font_mem[(letter<<SHIFT_VAL)+(row_index+1)];
    end


endmodule
