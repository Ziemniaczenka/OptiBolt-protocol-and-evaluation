/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Generates sampling tick.
 */

module sampling_tick_generator (
    input logic clk200,
    input logic rst_n,
    input logic [3:0] oversampling,
    input logic [3:0] bit_rate,
    output logic tick
);

  import protocol_pkg::*;
  logic [15:0] current_M;
  logic [15:0] counter;

  always_ff @(posedge clk200 or negedge rst_n) begin
    if (!rst_n) begin
      current_M <= M_8X_100K;
    end else begin
      case ({
        oversampling[0], bit_rate
      })
        // 8x oversampling (oversampling == 4'b0000)
        {1'b0, 4'd0} : current_M <= M_8X_100K;
        {1'b0, 4'd1} : current_M <= M_8X_1M;
        {1'b0, 4'd2} : current_M <= M_8X_1dot25M;
        {1'b0, 4'd3} : current_M <= M_8X_2dot5M;
        {1'b0, 4'd4} : current_M <= M_8X_3dot125M;
        {1'b0, 4'd5} : current_M <= M_8X_5M;
        {1'b0, 4'd6} : current_M <= M_8X_6dot25M;
        {1'b0, 4'd7} : current_M <= M_8X_8dot33M;
        {1'b0, 4'd8} : current_M <= M_8X_12dot5M;
        {1'b0, 4'd9} : current_M <= M_8X_25M;

        // 16x oversampling (oversampling == 4'b0001)
        {1'b1, 4'd0} : current_M <= M_16X_100K;
        {1'b1, 4'd2} : current_M <= M_16X_1dot25M;
        {1'b1, 4'd3} : current_M <= M_16X_2dot5M;
        {1'b1, 4'd4} : current_M <= M_16X_3dot125M;
        {1'b1, 4'd6} : current_M <= M_16X_6dot25M;
        {1'b1, 4'd8} : current_M <= M_16X_12dot5M;

        default: current_M <= M_8X_1M;
      endcase
    end
  end

  always_ff @(posedge clk200 or negedge rst_n) begin
    if (!rst_n) begin
      counter <= '0;
      tick <= '0;
    end else begin
      if (counter == '0) begin
        counter <= current_M;
        tick <= 1'b1;
      end else begin
        counter <= counter - 1;
        tick <= '0;
      end
    end
  end

endmodule
