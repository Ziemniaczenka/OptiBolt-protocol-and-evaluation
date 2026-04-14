//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   template_fsm
 Author:        Robert Szczygiel
 Version:       1.0
 Last modified: 2023-05-18
 Coding style: safe with FPGA sync reset
 Description:  Template for modified Moore FSM for UEC2 project
 */
//////////////////////////////////////////////////////////////////////////////
module template_fsm_safe
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
logic      myout_nxt;

enum logic [STATE_BITS-1 :0] {
    ST_0 = 3'b000, // idle state
    ST_1 = 3'b001,
    ST_2 = 3'b011,
    ST_3 = 3'b010,
    ST_4 = 3'b110,
    ST_5 = 3'b111,
    ST_6 = 3'b101,
    ST_7 = 3'b100
} state, state_nxt;

//------------------------------------------------------------------------------
// state sequential with synchronous reset
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin : state_seq_blk
    if(rst)begin : state_seq_rst_blk
        state <= ST_0;
    end
    else begin : state_seq_run_blk
        state <= state_nxt;
    end
end
//------------------------------------------------------------------------------
// next state logic
//------------------------------------------------------------------------------
always_comb begin : state_comb_blk
    case(state)
        ST_0: state_nxt    = myin ? ST_1 : ST_0;
        ST_1: state_nxt    = ST_2;
        default: state_nxt = ST_0;
    endcase
end
//------------------------------------------------------------------------------
// output register
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin : out_reg_blk
    if(rst) begin : out_reg_rst_blk
        myout <= 1'b0;
    end
    else begin : out_reg_run_blk
        myout <= myout_nxt;
    end
end
//------------------------------------------------------------------------------
// output logic
//------------------------------------------------------------------------------
always_comb begin : out_comb_blk
    case(state_nxt)
        ST_3: myout_nxt    = 1'b1;
        default: myout_nxt = 1'b0;
    endcase
end

endmodule
