/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Buffer for storing rows of pixels from memory
 */

module prefetch_buffer #(
        parameter WORD_WIDTH
    ) (
        input logic clk,
        input logic rst_n,
        input logic load,
        input logic shift,
        input logic [(WORD_WIDTH-1):0] in,
        output logic [(WORD_WIDTH-1):0] out
    );


    logic [((WORD_WIDTH*2)-1):0] buffer, buffer_nxt;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer <= '0;
        end else begin
            buffer <= buffer_nxt;
        end
    end

    always_comb begin
    unique case ({load,shift})
        00: buffer_nxt = buffer;
        01: buffer_nxt = {buffer[(WORD_WIDTH-1):0], '0};
        10: buffer_nxt = {buffer[((WORD_WIDTH*2)-1):WORD_WIDTH], in};
        11: buffer_nxt = {buffer[(WORD_WIDTH-1):0], in};
    endcase

    end

    assign out = buffer[((WORD_WIDTH*2)-1):WORD_WIDTH];

endmodule
