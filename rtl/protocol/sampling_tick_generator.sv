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
logic [15:0] counter;

always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        current_M <= M_8X_100K;
    end
    else begin
        case ({oversampling, bit_rate})
            8'b0000_0000: current_M <= M_8X_100K;
            8'b0000_0001: current_M <= M_8X_1M;
            8'b0000_0010: current_M <= M_8X_2dot5M;
            8'b0000_0011: current_M <= M_8X_3dot125M;
            8'b0000_0100: current_M <= M_8X_5M;
            8'b0000_0101: current_M <= M_8X_8dot33M;
            8'b0000_0110: current_M <= M_8X_12dot5M;
            8'b0000_0110: current_M <= M_8X_25M;
            8'b0001_0001: current_M <= M_16X_1dot25M;
            8'b0001_0011: current_M <= M_16X_3dot125M;
            8'b0001_0101: current_M <= M_16X_6dot25M; 
            default: current_M <= M_8X_100K;
        endcase
    end
end

always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        counter <= '0;
        tick <= '0;
    end
    else begin
        if(counter == '0) begin
            counter <= current_M;
            tick <= 1'b1;
        end
        else begin
            counter <= counter - 1;
            tick <= '0;
        end
    end
end

// mod_m_counter #(.N(16)) u_mod_m_counter (
//     .clk400,
//     .reset(!rst_n),
//     .q(),
//     .max_tick(tick),
//     .M(current_M)
// );

endmodule