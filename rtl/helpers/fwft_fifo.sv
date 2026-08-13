/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * FWFT FIFO Buffer for storing data.
 */

module fwft_fifo #(
    parameter WORD_WIDTH = 8,
    parameter DEPTH = 4
) (
    input logic clk,
    input logic rst_n,
    input logic flush,
    input logic push,
    input logic pop,
    input logic [WORD_WIDTH-1:0] din,
    output logic [WORD_WIDTH-1:0] dout,
    output logic empty,
    output logic full,
    output logic [$clog2(DEPTH+1)-1:0] count
);

  /*
  * Local variables and signals
  */

  logic [WORD_WIDTH-1:0] mem[DEPTH-1:0];
  logic [$clog2(DEPTH)-1:0] wptr, rptr;

  /*
  * Internal logic
  */

  // FWFT Combinational Read
  assign dout = mem[rptr];

  // Synchronous Memory Write (No Async Reset on Memory Array to allow LUTRAM/BRAM inference)
  always_ff @(posedge clk) begin
    if (push && !full) mem[wptr] <= din;
  end

  // Handling pointers and flags
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      // Reset state
      wptr  <= '0;
      rptr  <= '0;
      count <= '0;
      empty <= 1'b1;
      full  <= 1'b0;
    end else begin
      case ({
        push && !full, pop && !empty
      })
        2'b10: begin  // Push only
          wptr  <= wptr + 1;
          count <= count + 1;
          empty <= 1'b0;
          if (count == DEPTH - 1) full <= 1'b1;
        end
        2'b01: begin  // Pop only
          rptr  <= rptr + 1;
          count <= count - 1;
          full  <= 1'b0;
          if (count == 1) empty <= 1'b1;
        end
        2'b11: begin  // Simultaneous Push and Pop
          wptr <= wptr + 1;
          rptr <= rptr + 1;
        end
        default: ;
      endcase
    end
  end

endmodule
