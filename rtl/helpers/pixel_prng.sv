/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Pseudo-Random Number Generator (PRNG) module based on a 16-bit Galois LFSR.
 * Used for dynamic pixel color generation during bitmap transmission tests.
 */

module pixel_prng (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        next_pixel,
    output logic [11:0] pixel_rgb,
    output logic [ 7:0] pixel_byte
);

  logic [15:0] lfsr;

  // 16-bit Galois LFSR with taps at bits 16, 14, 13, 11 (polynomial x^16 + x^14 + x^13 + x^11 + 1)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr <= 16'hACE1; // Non-zero initial seed
    end else if (next_pixel) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
  end

  // 12-bit RGB output derived from LFSR bits
  assign pixel_rgb  = {lfsr[11:8], lfsr[7:4], lfsr[3:0]};
  assign pixel_byte = lfsr[7:0];

endmodule
