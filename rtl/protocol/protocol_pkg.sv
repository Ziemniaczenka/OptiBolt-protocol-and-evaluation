/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Look up table.
 */

package protocol_pkg;

    localparam CLK400 = 400_000_000;
    
    //M VALUE COUNTING//
    //localparam int M_OVERSAMPLING_BITRATE
    localparam int M_8X_100K = CLK400 / (8 * 100_000);
    localparam int M_8X_1M   = CLK400 / (8 * 1_000_000);
    localparam int M_16X_1M  = CLK400 / (16 * 1_000_000);
    localparam int M_16X_5M  = CLK400 / (16 * 5_000_000);


    //OVERSAMPLING TIMING WINDOWS//

    //8x oversampling
    localparam logic [3:0] O_8X_C1_START = 4'd1;
    localparam logic [3:0] O_8X_C1_END   = 4'd3;
    localparam logic [3:0] O_8X_CENTER   = 4'd4;
    localparam logic [3:0] O_8X_C2_START = 4'd5;
    localparam logic [3:0] O_8X_C2_END   = 4'd7;
    localparam logic [3:0] O_8X_MAX_COUNT = 4'd7;

    //16x oversampling
    localparam logic [3:0] O_16X_C1_START = 4'd2;
    localparam logic [3:0] O_16X_C1_END   = 4'd6;
    localparam logic [3:0] O_16X_CENTER   = 4'd8;
    localparam logic [3:0] O_16X_C2_START = 4'd10;
    localparam logic [3:0] O_16X_C2_END   = 4'd14;
    localparam logic [3:0] O_16X_MAX_COUNT = 4'd15;

endpackage