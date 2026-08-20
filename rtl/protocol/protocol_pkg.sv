/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Look up table.
 */

package protocol_pkg;

    localparam CLK200 = 200_000_000;
    
    //M VALUE COUNTING//

    //localparam int M_OVERSAMPLING_BITRATE
    //oversampling 8x
    localparam logic [15:0] M_8X_100K       = CLK200 / (8 * 100_000);
    localparam logic [15:0] M_8X_1M         = CLK200 / (8 * 1_000_000);
    localparam logic [15:0] M_8X_2dot5M     = CLK200 / (8 * 2_500_000);
    localparam logic [15:0] M_8X_3dot125M   = CLK200 / (8 * 3_125_000);
    localparam logic [15:0] M_8X_5M         = CLK200 / (8 * 5_000_000);
    localparam logic [15:0] M_8X_8dot33M    = CLK200 / (8 * 8_333_333);
    localparam logic [15:0] M_8X_12dot5M    = CLK200 / (8 * 12_500_000);
    localparam logic [15:0] M_8X_25M        = CLK200 / (8 * 25_000_000);

    //oversampling 16x
    localparam logic [15:0] M_16X_1dot25M   = CLK200 / (16 * 1_250_000);
    localparam logic [15:0] M_16X_3dot125M  = CLK200 / (16 * 3_125_000);
    localparam logic [15:0] M_16X_6dot25M   = CLK200 / (16 * 6_250_000);

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
    
    //COMMUNICATION//

    //headers
    localparam logic [2:0] MSG_CAPABILITIES = 3'b000;
    localparam logic [2:0] MSG_REQUEST      = 3'b001;
    localparam logic [2:0] MSG_ACCEPT       = 3'b010;
    localparam logic [2:0] MSG_DENIED       = 3'b011;
    localparam logic [2:0] MSG_TEXT         = 3'b100;
    localparam logic [2:0] MSG_TEST1        = 3'b101;
    localparam logic [2:0] MSG_TEST2        = 3'b110;
    localparam logic [2:0] MSG_TEST3        = 3'b111;

    //power 
    localparam logic [7:0] PWR_5V_1A  = 8'b0000_0001;
    localparam logic [7:0] PWR_9V_2A  = 8'b0000_0010;
    localparam logic [7:0] PWR_20V_5A = 8'b0000_0100;

endpackage