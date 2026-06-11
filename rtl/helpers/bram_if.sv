/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Interface for Block RAM connections.
 */

interface bram_if #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 8,
    parameter bit READ_ONLY  = 0
);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic                  we;
    logic                  en;

    generate
        if (READ_ONLY) begin : gen_ro
            assign we  = 1'b0;
            assign din = '0;
        end
    endgenerate

    modport read (
        output addr,
        output en,
        input  dout
    );

    modport write (
        output addr,
        output din,
        output we,
        output en
    );

    modport rw (
        output addr,
        output din,
        input  dout,
        output we,
        output en
    );

    modport memory (
        input  addr,
        input  din,
        output dout,
        input  we,
        input  en
    );
endinterface