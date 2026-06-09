/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Decodes manchester to binary
 */

module manchester_decoder (
    input logic clk400,
    input logic rst_n,
    input logic tick,
    input logic rx_manchester, //to z kabla
    input logic [3:0] oversampling,
    output logic rx_binary,
    output logic bit_valid,
    output logic decode_error
);

import protocol_pkg::*;
logic [3:0] C1_START, C1_END, CENTER, C2_START, C2_END;
logic [3:0] counter, MAX_COUNT;
logic rx_reg, rx_sync, rx_past, edge_detected;
logic [4:0] voting_c1, voting_c2;
logic result_c1, result_c2, vote_evaluation, searching, skip_vote;

always_comb begin
    case(oversampling)
        4'b0000: begin
            C1_START = O_8X_C1_START;
            C1_END   = O_8X_C1_END;
            CENTER   = O_8X_CENTER;
            C2_START = O_8X_C2_START;
            C2_END   = O_8X_C2_END;
            MAX_COUNT = O_8X_MAX_COUNT;
        end
        4'b0001: begin 
            C1_START = O_16X_C1_START;
            C1_END   = O_16X_C1_END;
            CENTER   = O_16X_CENTER;
            C2_START = O_16X_C2_START;
            C2_END   = O_16X_C2_END;
            MAX_COUNT = O_16X_MAX_COUNT;
        end
        default: begin
            C1_START = O_8X_C1_START;
            C1_END   = O_8X_C1_END;
            CENTER   = O_8X_CENTER;
            C2_START = O_8X_C2_START;
            C2_END   = O_8X_C2_END;
            MAX_COUNT = O_8X_MAX_COUNT;
        end
    endcase

    if(oversampling == 4'b0000) begin
        result_c1 = ((3'(voting_c1[0]) + 3'(voting_c1[1]) + 3'(voting_c1[2])) >= 3'd2);
        result_c2 = ((3'(voting_c2[0]) + 3'(voting_c2[1]) + 3'(voting_c2[2])) >= 3'd2);
    end
    else begin
        result_c1 = ((3'(voting_c1[0]) + 3'(voting_c1[1]) + 3'(voting_c1[2]) + 3'(voting_c1[3]) + 3'(voting_c1[4])) >= 3'd3);
        result_c2 = ((3'(voting_c2[0]) + 3'(voting_c2[1]) + 3'(voting_c2[2]) + 3'(voting_c2[3]) + 3'(voting_c2[4])) >= 3'd3);
    end
end    

always_ff @(posedge clk400 or negedge rst_n) begin
    if(!rst_n) begin
        rx_reg <= '0;
        rx_sync <= '0;
        rx_past <= '0;
        edge_detected <= '0;
        counter <= '0;
        rx_binary <= '0;
        bit_valid <= '0; 
        voting_c1 <= '0;
        voting_c2 <= '0;
        vote_evaluation <= '0;
        decode_error <= '0;
        searching <= 1'b1;
        skip_vote <= '0;
    end
    else begin
        rx_reg <= rx_manchester;
        rx_sync <= rx_reg;
        if(tick) begin
            rx_past <= rx_sync;
            edge_detected <= rx_sync ^ rx_past;
            bit_valid <= 1'b0;
            decode_error <= 1'b0;
            if(counter == MAX_COUNT) begin
                counter <= '0;
                vote_evaluation <= 1'b1;
            end else begin
                counter <= counter +1;
                vote_evaluation <= 1'b0;
            end
            if(edge_detected) begin
                if(searching) begin
                    counter <= CENTER + 1;
                    searching <= 1'b0;
                    skip_vote <= 1'b1;
                end
                else if(counter >= C1_END && counter <= C2_START) begin
                    counter <= CENTER + 1;
                end
            end
            if(counter >= C1_START && counter <= C1_END) begin
                voting_c1 <= {voting_c1[3:0], rx_sync};
            end
            if(counter >= C2_START && counter <= C2_END) begin
                voting_c2 <= {voting_c2[3:0], rx_sync};
            end
            if(vote_evaluation == 1'b1) begin
                if(skip_vote) begin
                    skip_vote <= '0;
                end
                else if(result_c1 == 1'b1 && result_c2 == 1'b0) begin
                    rx_binary <= 1'b1;
                    bit_valid <= 1'b1;
                end
                else if(result_c1 == 1'b0 && result_c2 == 1'b1) begin
                    rx_binary <= 1'b0;
                    bit_valid <= 1'b1;
                end
                else begin
                    bit_valid <= 1'b0;
                    decode_error <= 1'b1;
                    searching <= 1'b1;
                end
            end
        end
        else begin
            bit_valid <= 1'b0;
            decode_error <= 1'b0;
        end
    end
end


endmodule
