
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   template_simple
 Author:        Robert Szczygiel
 Version:       1.0
 Last modified: 2017-04-03
 Coding style: safe, with FPGA sync reset
 Description:  Template for simple module with registered outputs
 */
//////////////////////////////////////////////////////////////////////////////
module template_simple
#(parameter
    MYPARAM = 7 // can be removed is not used
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


//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
logic myout_nxt;

//------------------------------------------------------------------------------
// output register with sync reset
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
// logic
//------------------------------------------------------------------------------
always_comb begin : out_comb_blk
    myout_nxt = myout ^ ~myin;
end

endmodule
