/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Decodes manchester to binary
 */

module manchester_decode (
    input logic clk400,
    input logic rst_n,
    input logic tick,
    input logic rx_manchester, //to z kabla
    input logic [3:0] oversampling,
    output logic rx_binary,
    output logic bit_valid
);

import protocol_pkg::*;
logic [3:0] C1_START, C1_END, CENTER, C2_START, C2_END;
logic rx_reg, rx_sync, rx_past, edge_detected;

always_comb begin
    case(oversampling)
        4'b0000: begin
            C1_START = O_8X_C1_START;
            C1_END   = O_8X_C1_END;
            CENTER   = O_8X_CENTER;
            C2_START = O_8X_C2_START;
            C2_END   = O_8X_C2_END;
        end
        4'b0001: begin 
            C1_START = O_16X_C1_START;
            C1_END   = O_16X_C1_END;
            CENTER   = O_16X_CENTER;
            C2_START = O_16X_C2_START;
            C2_END   = O_16X_C2_END;
        end
        default: begin
            C1_START = O_8X_C1_START;
            C1_END   = O_8X_C1_END;
            CENTER   = O_8X_CENTER;
            C2_START = O_8X_C2_START;
            C2_END   = O_8X_C2_END;
        end
    endcase
end    

always_ff @(posedge clk400 or negedge rst_n) begin
    if(!rst_n) begin
        rx_reg <= '0;
        rx_sync <= '0;
        rx_past <= '0;
        edge_detected <= '0; 
    end
    else begin
        rx_reg <= rx_manchester;
        rx_sync <= rx_reg;
        if(tick) begin
            rx_past <= rx_sync;
            edge_detected <= rx_sync ^ rx_past;
        end
    end
end


endmodule