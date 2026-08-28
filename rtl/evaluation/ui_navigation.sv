/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Interface grid navigation submodule.
 */

import ui_pkg::*;

module ui_navigation (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       show_popup,
    input  logic       cmd_up,
    input  logic       cmd_down,
    input  logic       cmd_left,
    input  logic       cmd_right,
    output logic [3:0] ui_selected_item
);

  // 7 Toolbar buttons (0 to 6)
  localparam int NUM_TOOLBAR_BTNS = 7;
  localparam ui_item_t TOOLBAR[0:NUM_TOOLBAR_BTNS-1] = '{
      ITEM_HELP_BTN,
      ITEM_PING_BTN,
      ITEM_SWEEP_BTN,
      ITEM_SNDBMP_BTN,
      ITEM_CLRBMP_BTN,
      ITEM_CLRCON_BTN,
      ITEM_ABOUT_BTN
  };

  logic [2:0] toolbar_idx, toolbar_idx_nxt;
  logic on_toolbar, on_toolbar_nxt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      toolbar_idx      <= 3'd0;
      on_toolbar       <= 1'b0;  // Default selection: Input Field
      ui_selected_item <= ITEM_INPUT;
    end else begin
      toolbar_idx <= toolbar_idx_nxt;
      on_toolbar  <= on_toolbar_nxt;

      if (show_popup) begin
        ui_selected_item <= ITEM_POPUP_BTN;
      end else if (on_toolbar_nxt) begin
        ui_selected_item <= TOOLBAR[toolbar_idx_nxt];
      end else begin
        ui_selected_item <= ITEM_INPUT;
      end
    end
  end

  always_comb begin
    toolbar_idx_nxt = toolbar_idx;
    on_toolbar_nxt  = on_toolbar;

    if (!show_popup) begin
      if (on_toolbar) begin
        if (cmd_down) begin
          on_toolbar_nxt = 1'b0;  // Move down to input field
        end else if (cmd_right) begin
          toolbar_idx_nxt = (toolbar_idx == NUM_TOOLBAR_BTNS - 1) ? 3'd0 : toolbar_idx + 3'd1;
        end else if (cmd_left) begin
          toolbar_idx_nxt = (toolbar_idx == 3'd0) ? 3'(NUM_TOOLBAR_BTNS - 1) : toolbar_idx - 3'd1;
        end
      end else begin
        // On Input Field
        if (cmd_up) begin
          on_toolbar_nxt = 1'b1;  // Return to toolbar
        end
      end
    end
  end

endmodule
