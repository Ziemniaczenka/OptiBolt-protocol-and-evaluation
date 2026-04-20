/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 * Modified by: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Package with vga related constants.
 */

 package font_pkg;

    typedef struct {
        int ROWS_PER_LETTER;
        int BYTES_PER_ROW;
        int LETTER_HEIGHT;
    } font_t;

    localparam font_t FONT_11x7 = '{
        ROWS_PER_LETTER: 16,
        BYTES_PER_ROW:   1,
        LETTER_HEIGHT:   11
    };

    localparam string FONT_11x7_PATH = "../../rtl/display/data/font_11x7.mem";

 endpackage
