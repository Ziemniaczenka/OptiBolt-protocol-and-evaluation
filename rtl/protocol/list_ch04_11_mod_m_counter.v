/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Pong P. Chu, FPGA Prototyping by Verilog Examples
 * Provided by: AGH University of Science and Technology
 * Modified by: Tomasz Więcławski & Sebastian Zoń
 *
 */

// Listing 4.11
module mod_m_counter
   #(
    parameter N=4 // number of bits in counter
   )
   (
    input wire clk, reset,
    input wire [N-1:0] M,
    output wire max_tick,
    output wire [N-1:0] q
   );

   //signal declaration
   reg [N-1:0] r_reg;
   wire [N-1:0] r_next;

   // body
   // register
   always @(posedge clk, posedge reset)
      if (reset)
         r_reg <= 0;
      else
         r_reg <= r_next;

   // next-state logic
   assign r_next = (r_reg==(M-1)) ? 0 : r_reg + 1;
   // output logic
   assign q = r_reg;
   assign max_tick = (r_reg==(M-1)) ? 1'b1 : 1'b0;

endmodule