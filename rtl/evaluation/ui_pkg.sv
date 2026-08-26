/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Package for UI related enumerations.
 */
package ui_pkg;

  typedef enum logic [3:0] {
    ITEM_NONE       = 4'd0,
    ITEM_INPUT      = 4'd1,  // Main input field
    ITEM_HELP_BTN   = 4'd2,  // Toolbar: Help
    ITEM_PING_BTN   = 4'd3,  // Toolbar: Ping test
    ITEM_SWEEP_BTN  = 4'd4,  // Toolbar: Baudrate sweep test
    ITEM_SNDBMP_BTN = 4'd5,  // Toolbar: Send Bitmap
    ITEM_CLRBMP_BTN = 4'd6,  // Toolbar: Clear Bitmap
    ITEM_CLRCON_BTN = 4'd7,  // Toolbar: Clear Console
    ITEM_ABOUT_BTN  = 4'd8,  // Toolbar: About Dialog
    ITEM_POPUP_BTN  = 4'd9   // Button inside popup window
  } ui_item_t;

  typedef enum logic [1:0] {
    POPUP_NONE     = 2'd0,
    POPUP_ABOUT    = 2'd1,
    POPUP_PROGRESS = 2'd2
  } popup_mode_t;

endpackage
