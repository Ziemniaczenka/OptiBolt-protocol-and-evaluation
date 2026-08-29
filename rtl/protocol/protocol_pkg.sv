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
  localparam logic [15:0] M_8X_100K = CLK200 / (8 * 100_000) - 1;
  localparam logic [15:0] M_8X_1M = CLK200 / (8 * 1_000_000) - 1;
  localparam logic [15:0] M_8X_1dot25M = CLK200 / (8 * 1_250_000) - 1;
  localparam logic [15:0] M_8X_2dot5M = CLK200 / (8 * 2_500_000) - 1;
  localparam logic [15:0] M_8X_3dot125M = CLK200 / (8 * 3_125_000) - 1;
  localparam logic [15:0] M_8X_5M = CLK200 / (8 * 5_000_000) - 1;
  localparam logic [15:0] M_8X_6dot25M = CLK200 / (8 * 6_250_000) - 1;
  localparam logic [15:0] M_8X_8dot33M = CLK200 / (8 * 8_333_333) - 1;
  localparam logic [15:0] M_8X_12dot5M = CLK200 / (8 * 12_500_000) - 1;
  localparam logic [15:0] M_8X_25M = CLK200 / (8 * 25_000_000) - 1;

  //oversampling 16x
  localparam logic [15:0] M_16X_100K = CLK200 / (16 * 100_000) - 1;
  localparam logic [15:0] M_16X_1dot25M = CLK200 / (16 * 1_250_000) - 1;
  localparam logic [15:0] M_16X_2dot5M = CLK200 / (16 * 2_500_000) - 1;
  localparam logic [15:0] M_16X_3dot125M = CLK200 / (16 * 3_125_000) - 1;
  localparam logic [15:0] M_16X_6dot25M = CLK200 / (16 * 6_250_000) - 1;
  localparam logic [15:0] M_16X_12dot5M = CLK200 / (16 * 12_500_000) - 1;

  //OVERSAMPLING TIMING WINDOWS//

  //8x oversampling
  localparam logic [3:0] O_8X_C1_START = 4'd1;
  localparam logic [3:0] O_8X_C1_END = 4'd3;
  localparam logic [3:0] O_8X_CENTER = 4'd4;
  localparam logic [3:0] O_8X_C2_START = 4'd5;
  localparam logic [3:0] O_8X_C2_END = 4'd7;
  localparam logic [3:0] O_8X_MAX_COUNT = 4'd7;

  //16x oversampling
  localparam logic [3:0] O_16X_C1_START = 4'd2;
  localparam logic [3:0] O_16X_C1_END = 4'd6;
  localparam logic [3:0] O_16X_CENTER = 4'd8;
  localparam logic [3:0] O_16X_C2_START = 4'd10;
  localparam logic [3:0] O_16X_C2_END = 4'd14;
  localparam logic [3:0] O_16X_MAX_COUNT = 4'd15;

  //COMMUNICATION//

  // Message Type Headers
  localparam logic [2:0] MSG_CAPABILITIES = 3'b000; // Link Handshake / Challenge Token exchange
  localparam logic [2:0] MSG_REQUEST      = 3'b001; // Speed Negotiation Requests, Ping, Sweep Control
  localparam logic [2:0] MSG_ACCEPT       = 3'b010; // Speed Negotiation ACKs, Handshake ACKs
  localparam logic [2:0] MSG_DENIED       = 3'b011; // Reserved / Command Rejections
  localparam logic [2:0] MSG_TEXT         = 3'b100; // Console ASCII Text Messaging
  localparam logic [2:0] MSG_TEST1        = 3'b101; // Dynamic 128x128 PRNG Bitmap Streaming (MSG_BITMAP)
  localparam logic [2:0] MSG_BITMAP       = 3'b101; // Alias for MSG_TEST1
  localparam logic [2:0] MSG_TEST2        = 3'b110; // Multi-profile Power Negotiation (MSG_POWER)
  localparam logic [2:0] MSG_POWER        = 3'b110; // Alias for MSG_TEST2
  localparam logic [2:0] MSG_TEST3        = 3'b111; // Baudrate Sweep Link Verification Packets

  // Control Constants for MSG_REQUEST
  localparam logic [7:0] CMD_PING_REQ    = 8'hA5;
  localparam logic [7:0] CMD_PING_RESP   = 8'h5A;
  localparam logic [7:0] CMD_SWEEP_START = 8'hE0;
  localparam logic [7:0] CMD_SWEEP_END   = 8'hE1;
  localparam logic [7:0] CMD_SPEED_ACK   = 8'hB1;

endpackage
