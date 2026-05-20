/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Receiver
 */


module optibolt_receiver (
    input logic clk400,
    input logic rst_n,
    input logic rx_binary,
    input logic bit_valid,
    input logic decode_error,
    output logic [7:0] data,
    output logic data_ready,
    output logic [2:0] msg_type,
    output logic parity,
    output logic manchester_code_error,
    output logic preamble_error
);

import protocol_pkg::*;
typedef enum logic [2:0] {
    IDLE = 3'b000,
    PREAMBLE = 3'b001,
    HEADER = 3'b010,
    PAYLOAD = 3'b011,
    PARITY = 3'b100
} state_t;

state_t state_reg, state_next;
logic [7:0] shift_reg, shift_next;
logic [3:0] bit_counter, bit_counter_next;
logic [2:0] msg_type_reg, msg_type_next;
logic preamble_fail;

always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        shift_reg <= '0;
        bit_counter <= '0;
        msg_type_reg <= '0;
        data <= '0;
        msg_type <= '0;
        parity <= '0;
        data_ready <= '0;
        manchester_code_error <= '0;
        preamble_error <= '0;
    end else begin
        data_ready <= '0;
        manchester_code_error <= '0;
        preamble_error <= '0;
        if (decode_error) begin
            state_reg <= IDLE;
            shift_reg <= '0;
            bit_counter <= '0;
            manchester_code_error <= 1'b1;
        end 
        else if (preamble_fail) begin
            state_reg <= IDLE;
            shift_reg <= '0;
            bit_counter <= '0;
            preamble_error <= 1'b1;
        end
        else if (bit_valid) begin
            state_reg <= state_next;
            shift_reg <= shift_next;
            bit_counter <= bit_counter_next;
            msg_type_reg <= msg_type_next;

            if(state_reg == PARITY) begin
                data <= shift_reg;
                msg_type <= msg_type_reg;
                parity <= rx_binary;
                data_ready <= 1'b1;
            end
        end
    end
end


always_comb begin
    state_next = state_reg;
    shift_next = shift_reg;
    msg_type_next = msg_type_reg;
    bit_counter_next = bit_counter;
    preamble_fail = 1'b0;

    case(state_reg)

        IDLE: begin
            shift_next = {shift_reg[6:0], rx_binary};
            if({shift_reg[2:0], rx_binary} == 4'b0101) begin
                state_next = PREAMBLE;
                bit_counter_next = '0;
                shift_next = 8'b11111111;
            end
        end

        PREAMBLE: begin
            shift_next = {shift_reg[6:0], rx_binary};
            bit_counter_next = bit_counter +1;
            if({shift_reg[0], rx_binary} == 2'b00) begin
                state_next = HEADER;
                bit_counter_next = '0;
                shift_next = 0;
            end
            else if(bit_counter > 5)  begin
                state_next = IDLE;
                bit_counter_next = '0;
                shift_next = 0;
                preamble_fail = 1'b1;
            end
        end

        HEADER: begin
            shift_next = {shift_reg[6:0], rx_binary};
            bit_counter_next = bit_counter + 1;

            if(bit_counter == 4'd2) begin
                msg_type_next = {shift_reg[1:0], rx_binary}; 
                state_next = PAYLOAD;
                bit_counter_next = '0;
                shift_next = '0;
            end
        end

        PAYLOAD: begin
            shift_next = {shift_reg[6:0], rx_binary};
            bit_counter_next = bit_counter + 1'b1;

            if(bit_counter == 4'd7) begin
                state_next = PARITY; 
                bit_counter_next = '0;     
            end
        end

        PARITY: begin
            shift_next = '0;
            state_next = IDLE;
        end

        default: begin
            state_next = IDLE;
        end
    endcase
end

endmodule
