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
  localparam bitmap_t BITMAP_DYN_64x64   = '{WIDTH: 64, HEIGHT: 64};
  localparam bitmap_t BITMAP_DYN_128x128 = '{WIDTH: 128, HEIGHT: 128};
  localparam bitmap_t BITMAP_OPTIBOLT_400x102 = '{WIDTH: 400, HEIGHT: 102};

`ifndef SYNTHESIS
  localparam string BITMAP_152x64_PATH = "../../rtl/evaluation/display/data/bitmap1_152x64.mem";
  localparam string BITMAP_TEST_128x64_PATH = "../../rtl/evaluation/display/data/BitmapTest128x64.mem";
  localparam string BITMAP_TEST_69x153_PATH = "../../rtl/evaluation/display/data/BitmapTest69x153.mem";
  localparam string BITMAP_OPTIBOLT_400x102_PATH = "../../rtl/evaluation/display/data/OptiBolt400x102.mem";
  localparam string BITMAP_OPTIBOLT_400x102_PALETTE_PATH = "../../rtl/evaluation/display/data/OptiBolt400x102_palette.mem";
`else
  localparam string BITMAP_152x64_PATH = "bitmap1_152x64.mem";
  localparam string BITMAP_TEST_128x64_PATH = "BitmapTest128x64.mem";
  localparam string BITMAP_TEST_69x153_PATH = "BitmapTest69x153.mem";
  localparam string BITMAP_OPTIBOLT_400x102_PATH = "OptiBolt400x102.mem";
  localparam string BITMAP_OPTIBOLT_400x102_PALETTE_PATH = "OptiBolt400x102_palette.mem";
`endif

  localparam logic [11:0] PALETTE_OPTIBOLT_400x102[0:3] = '{
      12'hFFF,  // 0: White Background
      12'h000,  // 1: Black Text / Outline
      12'hFF3,  // 2: Yellow Lightning Bolt
      12'hCDF   // 3: Light Blue Highlight
  };

endpackage
