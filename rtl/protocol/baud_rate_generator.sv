/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Generates baud rate.
 */

module baud_rate_generator #(
    parameter BAUDE_RATE = 115200,
    parameter OVERSAMPLING = 8
) (
input logic clk,
input logic rst_n,
output logic tick
);

localparam M_val = 100000000/(OVERSAMPLING*BAUDE_RATE);

mod_m_counter #(.N(8), .M(M_val)) u_mod_m_counter (
    .clk,
    .reset(!rst_n),
    .q(),
    .max_tick(tick)
);

endmodule