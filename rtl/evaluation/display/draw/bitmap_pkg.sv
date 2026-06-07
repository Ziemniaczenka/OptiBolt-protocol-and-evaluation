/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Package with bitmap constants.
 */

package bitmap_pkg;

    typedef struct {
        int WIDTH;
        int HEIGHT;
    } bitmap_t;

    localparam bitmap_t BITMAP_152x64 = '{
        WIDTH:  152,
        HEIGHT: 64
    };

    `ifndef SYNTHESIS
    localparam string BITMAP_152x64_PATH = "../../rtl/evaluation/display/data/bitmap1_152x64.mem";
    `else
    localparam string BITMAP_152x64_PATH = "bitmap1_152x64.mem";
    `endif

endpackage
