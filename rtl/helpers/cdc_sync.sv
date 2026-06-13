/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Simple Double-Flop Synchronizer for CDC.
 */

module cdc_sync #(
    parameter WIDTH = 1
) (
    input  logic             clk_dst,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] d_out
);

  /**
     * Local variables and signals
     */

  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_0, sync_1;
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) {sync_1, sync_0} <= '0;
    else {sync_1, sync_0} <= {sync_0, d_in};
  end

  assign d_out = sync_1;

endmodule
