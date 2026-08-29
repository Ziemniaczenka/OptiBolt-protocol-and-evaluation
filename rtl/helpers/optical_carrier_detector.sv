/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Optical carrier activity detector.
 * Monitors Manchester edge transitions on the optical receiver pin.
 * Asserts carrier_detected as long as transitions occur within the hold window (default 10 ms).
 */

`timescale 1ns / 1ps

module optical_carrier_detector #(
    parameter int HOLD_CYCLES = 1_000_000  /* 10 ms at 100 MHz */
) (
    input  logic clk,
    input  logic rst_n,
    input  logic rx_pin,
    output logic carrier_detected
);

  logic rx_sync0, rx_sync1, rx_d1;
  logic [19:0] timer;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync0         <= 1'b0;
      rx_sync1         <= 1'b0;
      rx_d1            <= 1'b0;
      timer            <= '0;
      carrier_detected <= 1'b0;
    end else begin
      rx_sync0 <= rx_pin;
      rx_sync1 <= rx_sync0;
      rx_d1    <= rx_sync1;

      if (rx_sync1 ^ rx_d1) begin
        timer            <= 20'(HOLD_CYCLES);
        carrier_detected <= 1'b1;
      end else if (timer > 20'd0) begin
        timer <= timer - 20'd1;
      end else begin
        carrier_detected <= 1'b0;
      end
    end
  end

endmodule
