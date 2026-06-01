/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Keyboard scan code decoder. Translates PS/2 scan codes into an array
 * representing the state of all keys.
 * Extended keys (e.g. arrows) are mapped starting at index 256.
 */

module keyboard_decoder (
        input  logic clk,
        input  logic rst_n,
        inout  wire  ps2_clk,
        inout  wire  ps2_data,
        output logic [511:0] keys_pressed
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    typedef enum logic [1:0] {
        IDLE,
        WAIT_RELEASE,
        WAIT_EXTENDED,
        WAIT_EXT_RELEASE
    } state_e;

    state_e state, state_nxt;
    logic [511:0] keys_pressed_nxt;

    logic [7:0] ps2_rx_data;
    logic ps2_read_data;
    logic ps2_busy;
    logic ps2_err;

    /**
     * Submodules
     */

    Ps2Interface ps2_inst (
        .ps2_clk    (ps2_clk),
        .ps2_data   (ps2_data),
        .clk        (clk),
        .rst        (~rst_n),    // VHDL module uses active HIGH reset
        .tx_data    (8'h00),
        .write_data (1'b0),
        .rx_data    (ps2_rx_data),
        .read_data  (ps2_read_data),
        .busy       (ps2_busy),
        .err        (ps2_err)
    );

    /**
     * Internal logic
     */

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            keys_pressed <= '0;
        end else begin
            state <= state_nxt;
            keys_pressed <= keys_pressed_nxt;
        end
    end

    always_comb begin
        state_nxt = state;
        keys_pressed_nxt = keys_pressed;

        if (ps2_read_data) begin
            case (state)
                IDLE: begin
                    if (ps2_rx_data == 8'hF0) begin
                        state_nxt = WAIT_RELEASE;
                    end else if (ps2_rx_data == 8'hE0) begin
                        state_nxt = WAIT_EXTENDED;
                    end else begin
                        // Normal make code
                        keys_pressed_nxt[ps2_rx_data] = 1'b1;
                    end
                end

                WAIT_RELEASE: begin
                    // Normal break code
                    keys_pressed_nxt[ps2_rx_data] = 1'b0;
                    state_nxt = IDLE;
                end

                WAIT_EXTENDED: begin
                    if (ps2_rx_data == 8'hF0) begin
                        state_nxt = WAIT_EXT_RELEASE;
                    end else begin
                        // Extended make code (concatenating 1'b1 shifts index by 256)
                        keys_pressed_nxt[{1'b1, ps2_rx_data}] = 1'b1;
                        state_nxt = IDLE;
                    end
                end

                WAIT_EXT_RELEASE: begin
                    // Extended break code
                    keys_pressed_nxt[{1'b1, ps2_rx_data}] = 1'b0;
                    state_nxt = IDLE;
                end
            endcase
        end
    end

endmodule
