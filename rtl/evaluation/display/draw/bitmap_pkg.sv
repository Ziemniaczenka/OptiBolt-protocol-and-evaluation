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

  localparam bitmap_t BITMAP_152x64 = '{WIDTH: 152, HEIGHT: 64};
  localparam bitmap_t BITMAP_TEST_128x64 = '{WIDTH: 128, HEIGHT: 64};
  localparam bitmap_t BITMAP_TEST_69x153 = '{WIDTH: 69, HEIGHT: 153};

`ifndef SYNTHESIS
  localparam string BITMAP_152x64_PATH = "../../rtl/evaluation/display/data/bitmap1_152x64.mem";
  localparam string BITMAP_TEST_128x64_PATH = "../../rtl/evaluation/display/data/BitmapTest128x64.mem";
  localparam string BITMAP_TEST_69x153_PATH = "../../rtl/evaluation/display/data/BitmapTest69x153.mem";
`else
  localparam string BITMAP_152x64_PATH = "bitmap1_152x64.mem";
  localparam string BITMAP_TEST_128x64_PATH = "BitmapTest128x64.mem";
  localparam string BITMAP_TEST_69x153_PATH = "BitmapTest69x153.mem";
`endif

endpackage
