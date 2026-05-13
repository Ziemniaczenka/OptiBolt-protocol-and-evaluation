/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Look up table.
 */

package protocol_pkg;

    localparam CLK = 400_000_000;
    
    //localparam int M_OVERSAMPLING_BITRATE

    localparam int M_8X_100K = CLK / (8 * 100_000);
    localparam int M_8X_1M   = CLK / (8 * 1_000_000);
    localparam int M_16X_1M  = CLK / (16 * 1_000_000);
    localparam int M_16X_5M  = CLK / (16 * 5_000_000);

endpackage