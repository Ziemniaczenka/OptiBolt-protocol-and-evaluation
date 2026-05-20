/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Codes binary to manchester
 */

 module manchester_coder (
    input logic clk400,
    input logic rst_n,
    input logic tick, 
    input logic [3:0] oversampling,
    input logic tx_binary,
    output logic tx_manchester,
    output logic bit_out
);

import protocol_pkg::*;

logic [3:0] counter;
logic [3:0] CENTER, MAX_COUNT;
logic current_bit;

always_comb begin
    if (oversampling == 4'b0000) begin
        CENTER = O_8X_CENTER;
        MAX_COUNT = O_8X_MAX_COUNT;
    end else begin                     
        CENTER = O_16X_CENTER;
        MAX_COUNT = O_16X_MAX_COUNT;
    end
end

always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        counter <= '0;
        tx_manchester <= 1'b1; 
        bit_out <= '0;
        current_bit <= '0;
    end else begin
        bit_out <= 1'b0;

        if (tick) begin
            if (counter >= MAX_COUNT) begin
                counter <= '0;
            end else begin
                counter <= counter + 1;
            end
            if (counter == 4'd0) begin
                current_bit <= tx_binary;
                tx_manchester <= tx_binary;
            end
            else if (counter == CENTER) begin
                tx_manchester <= ~current_bit;
            end
            else if (counter == MAX_COUNT) begin
                bit_out <= 1'b1;
            end
        end
    end
end

endmodule