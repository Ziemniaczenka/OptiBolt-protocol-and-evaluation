/* Copyright (C) 2025  AGH University of Krakow */

module counter #(
    parameter VALUE_MAX = 4'd7
)(
    input logic clk,
    input logic rst_n,
    input logic enabled,
    output logic [$clog2(VALUE_MAX + 1) - 1:0] value,
    output logic overflow
);


/* Local variables and signals */

logic [$clog2(VALUE_MAX + 1) - 1:0] value_nxt;
logic overflow_nxt;

/*localparam logic [3:0] value_max = 10;*/


/* Module internal logic */

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        value <= '0;
        overflow <= 1'b0;
    end else begin
        value <= value_nxt;
        overflow <= overflow_nxt;
    end
end

always_comb begin
    value_nxt = value;
    overflow_nxt = overflow;

    if (enabled) begin
        if (value == VALUE_MAX) begin
            value_nxt = 0;
            overflow_nxt = 1;
        end else begin
            value_nxt = value + 1;
            overflow_nxt = 0;
        end
    end
end

endmodule
