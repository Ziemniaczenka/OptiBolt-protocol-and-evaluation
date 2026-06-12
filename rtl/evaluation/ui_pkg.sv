/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Package for UI related enumerations.
 */
package ui_pkg;

  typedef enum logic [3:0] {
    ITEM_NONE      = 4'd0,
    ITEM_INPUT     = 4'd1,  // Main input field
    ITEM_ABOUT_BTN = 4'd2,  // Top About button
    ITEM_POPUP_BTN = 4'd3   // OK button inside popup window
  } ui_item_t;

endpackage
