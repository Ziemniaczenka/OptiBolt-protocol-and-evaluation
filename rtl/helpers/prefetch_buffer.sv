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


    logic [(WORD_WIDTH-1):0] buffer[1:0], buffer_nxt[1:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer[0] <= '0;
            buffer[1] <= '0;
        end else begin
            buffer <= buffer_nxt;
        end
    end

    always_comb begin
        case ({load,shift})
            2'b00: buffer_nxt = buffer;
            2'b01: begin
                    buffer_nxt[0] = '0;
                    buffer_nxt[1] = buffer[0];
            end
            2'b10: begin
                    buffer_nxt[0] = in;
                    buffer_nxt[1] = buffer[1];
            end
            2'b11: begin
                    buffer_nxt[0] = in;
                    buffer_nxt[1] = buffer[0];
            end
            default: buffer_nxt = buffer;
        endcase
    end

    assign out = buffer[1];

endmodule
