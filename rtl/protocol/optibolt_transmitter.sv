/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Transmitter
 */


module optibolt_transmitter (
    input logic clk400,
    input logic rst_n,
    input logic [2:0] header,
    input logic [7:0] data,
    input logic transmit_start,
    input logic bit_out,
    output logic tx_binary,
    output logic tx_busy
);

import protocol_pkg::*;

typedef enum logic [2:0] {
    IDLE      = 3'b000,
    WAIT_SYNC = 3'b001,
    PREAMBLE  = 3'b010,
    HEADER    = 3'b011,
    PAYLOAD   = 3'b100,
    PARITY    = 3'b101,
    STOP      = 3'b110
} state_t;

state_t state_reg, state_next;
logic [7:0] shift_reg, shift_next, data_reg, data_next;
logic [2:0] header_reg, header_next;
logic [3:0] bit_counter, bit_counter_next;
logic tx_bin_reg, tx_bin_next;
logic parity_reg, parity_next;
logic tx_busy_reg, tx_busy_next;

assign tx_binary = tx_bin_reg;
assign tx_busy = tx_busy_reg;

always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        shift_reg <= '0;
        bit_counter <= '0;
        tx_bin_reg <= 1'b1;
        parity_reg <= '0;
        tx_busy_reg <= '0;
        header_reg <= '0;
        data_reg <= '0;
    end else begin
        state_reg <= state_next;
        shift_reg <= shift_next;
        bit_counter <= bit_counter_next;
        tx_bin_reg <= tx_bin_next;
        parity_reg <= parity_next;
        tx_busy_reg <= tx_busy_next;
        header_reg <= header_next;
        data_reg <= data_next;
    end
end

always_comb begin //zrobiłem to moudlarnie żeby było czytelniejesze i prostsze do debuggingu ale przez to troche kodu sie powtarza
    state_next = state_reg;
    shift_next = shift_reg;
    bit_counter_next = bit_counter;
    tx_bin_next = tx_bin_reg;
    parity_next = parity_reg;
    header_next = header_reg;
    data_next = data_reg;

    case (state_reg)
        IDLE: begin
            tx_bin_next = 1'b1;
            if (transmit_start) begin
                state_next = WAIT_SYNC;
                shift_next = 8'b0101_0100;
                bit_counter_next = '0;
                parity_next = ^{header, data};
                header_next = header;
                data_next = data;
            end
        end

        WAIT_SYNC: begin
            tx_bin_next = 1'b1; 
            if (bit_out) begin
                state_next = PREAMBLE;
            end
        end

        PREAMBLE: begin
            tx_bin_next = shift_reg[7];
            if (bit_out) begin
                shift_next = {shift_reg[6:0], 1'b0};
                bit_counter_next = bit_counter + 1;
                
                if (bit_counter == 4'd7) begin
                    state_next = HEADER;
                    shift_next = {header_reg, 5'd0}; 
                    bit_counter_next = '0;
                end
            end
        end

        HEADER: begin
            tx_bin_next = shift_reg[7];
            if (bit_out) begin
                shift_next = {shift_reg[6:0], 1'b0};
                bit_counter_next = bit_counter + 1;
                
                if (bit_counter == 4'd2) begin
                    state_next = PAYLOAD;
                    shift_next = data_reg;
                    bit_counter_next = '0;
                end
            end
        end

        PAYLOAD: begin
            tx_bin_next = shift_reg[7];
            if (bit_out) begin
                shift_next = {shift_reg[6:0], 1'b0};
                bit_counter_next = bit_counter + 1;
                
                if (bit_counter == 4'd7) begin
                    state_next = PARITY;
                    bit_counter_next = '0;
                end
            end
        end

        PARITY: begin
            tx_bin_next = parity_reg;
            if (bit_out) begin
                state_next = STOP;
            end
        end

        STOP: begin
            tx_bin_next = 1'b1;
            if (bit_out) begin
                state_next = IDLE;
            end
        end

        default: begin
            state_next = IDLE;
        end
    endcase

    tx_busy_next = (state_next != IDLE);
end

endmodule