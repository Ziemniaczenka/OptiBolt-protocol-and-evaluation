//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   template_fsm
 Author:        Robert Szczygiel
 Version:       1.0
 Last modified: 2023-05-19
 Coding style: simple with FPGA sync reset
 Description:  Template for modified Moore FSM for UEC2 project
 */
//////////////////////////////////////////////////////////////////////////////
module template_fsm_simple
#(parameter
    MYPARAM = 7
)
(
    input  wire  clk,  // posedge active clock
    input  wire  rst,  // high-level active synchronous reset
    input  wire  myin, // exemplary input signal
    output logic myout // exemplary output signal
);

//------------------------------------------------------------------------------
// local parameters
//------------------------------------------------------------------------------
localparam STATE_BITS = 3; // number of bits used for state register

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
enum logic [STATE_BITS-1 :0] {
    ST_0 = 3'b000, // idle state
    ST_1 = 3'b001,
    ST_2 = 3'b011,
    ST_3 = 3'b010,
    ST_4 = 3'b110,
    ST_5 = 3'b111,
    ST_6 = 3'b101,
    ST_7 = 3'b100
} state;

//------------------------------------------------------------------------------
// state sequential with synchronous reset
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin : seq_blk
    if(rst)begin : seq_rst_blk
        state <= ST_0;
        myout <= 1'b0;
    end
    else begin : seq_run_blk
        case(state)
            ST_0: begin
                state <= myin ? ST_1 : ST_0;
                myout <= 1'b1;
            end
            ST_1: begin
                state <= ST_2;
                myout <= 1'b0;
            end
            default: begin
                state <= ST_0;
                myout <= 1'b0;
            end
        endcase
    end
end

endmodule
