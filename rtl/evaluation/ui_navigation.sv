/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description: Interface grid navigation submodule.
 */

import ui_pkg::*;

module ui_navigation (
    input logic clk,
    input logic rst_n,
    input logic cmd_up,
    input logic cmd_down,
    input logic cmd_left,
    input logic cmd_right,
    output logic [3:0] ui_selected_item
);

  /**
    * Local variables and signals
    */

  localparam GRID_X = 2;
  localparam GRID_Y = 2;

  // UI 2x2 Grid. Maps physical screen position of elements:
  // [Y=0][X=0] Empty / None  <---> [Y=0][X=1] About Button
  // [Y=1][X=0] Main Input      <---> [Y=1][X=1] Popup OK Button
  localparam ui_item_t UI_GRID[0:GRID_Y-1][0:GRID_X-1] = '{
      '{ITEM_NONE, ITEM_ABOUT_BTN},
      '{ITEM_INPUT, ITEM_POPUP_BTN}
  };

  logic [1:0] cursor_x, cursor_x_nxt;
  logic [1:0] cursor_y, cursor_y_nxt;

  /**
    * Internal logic
    */

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {cursor_x, cursor_y} <= {2'd0, 2'd1};  // Default selection: Input [1][0]
      ui_selected_item <= ITEM_INPUT;
    end else begin
      {cursor_x, cursor_y} <= {cursor_x_nxt, cursor_y_nxt};
      ui_selected_item <= UI_GRID[cursor_y_nxt][cursor_x_nxt];
    end
  end

  always_comb begin
    cursor_x_nxt = cursor_x;
    cursor_y_nxt = cursor_y;

    if (cmd_up) begin
      for (int i = GRID_Y - 1; i >= 0; i--) begin
        if (i < cursor_y && UI_GRID[i][cursor_x] != UI_GRID[cursor_y][cursor_x]) begin
          cursor_y_nxt = 2'(i);
          break;
        end
      end
    end else if (cmd_down) begin
      for (int i = 0; i < GRID_Y; i++) begin
        if (i > cursor_y && UI_GRID[i][cursor_x] != UI_GRID[cursor_y][cursor_x]) begin
          cursor_y_nxt = 2'(i);
          break;
        end
      end
    end else if (cmd_left) begin
      for (int i = GRID_X - 1; i >= 0; i--) begin
        if (i < cursor_x && UI_GRID[cursor_y][i] != UI_GRID[cursor_y][cursor_x]) begin
          cursor_x_nxt = 2'(i);
          break;
        end
      end
    end else if (cmd_right) begin
      for (int i = 0; i < GRID_X; i++) begin
        if (i > cursor_x && UI_GRID[cursor_y][i] != UI_GRID[cursor_y][cursor_x]) begin
          cursor_x_nxt = 2'(i);
          break;
        end
      end
    end
  end

endmodule
