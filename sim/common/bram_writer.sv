/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Helper module to write strings into BRAM interface in testbenches.
 */

module bram_writer #(
    parameter int MAX_LEN = 16
) (
    input  logic       clk,
    bram_if.write      port
);

  task write_string(string s);
    for (int i = 0; i < MAX_LEN; i++) begin
      @(posedge clk);
      port.we   = 1'b1;
      port.en   = 1'b1;
      port.addr = i;
      if (i < s.len()) port.din = s[i];
      else port.din = 8'h00;
    end
    @(posedge clk);
    port.we = 1'b0;
    port.en = 1'b0;
  endtask

endmodule