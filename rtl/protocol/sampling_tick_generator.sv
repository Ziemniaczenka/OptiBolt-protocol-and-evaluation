/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Generates sampling tick.
 */

module sampling_tick_generator (
    input logic clk400,
    input logic rst_n,
    input logic [3:0] oversampling,
    input logic [3:0] bit_rate,
    output logic tick
);

import protocol_pkg::*;
logic [15:0] current_M;

always_comb begin
    case ({oversampling, bit_rate})
        8'b0000_0000: current_M = M_8X_100K;
        8'b0000_0001: current_M = M_8X_1M;
        8'b0001_0001: current_M = M_16X_1M;
        8'b0001_0010: current_M = M_16X_5M;
        default: current_M = M_8X_100K;
    endcase
end

mod_m_counter #(.N(16)) u_mod_m_counter (
    .clk400,
    .reset(!rst_n),
    .q(),
    .max_tick(tick),
    .M(current_M)
);

endmodule