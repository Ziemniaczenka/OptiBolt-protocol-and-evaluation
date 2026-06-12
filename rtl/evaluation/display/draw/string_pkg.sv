/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Package with string constants.
 */

package string_pkg;

    // Makro do inicjalizacji stałych tablic znaków
    // [x +: y] == [x+y-1 : x] (start plus: width)
    `define INIT_UNPACKED_STR(ARR, VAL, LEN, MAX_LEN) \
    initial begin \
        for (int i = 0; i < (MAX_LEN); i++) begin \
            if (i < (LEN)) ARR[i] = VAL[(((LEN) - 1 - i) * 8) +: 8]; \
            else ARR[i] = 8'h00; \
        end \
    end


    // TITLE
    localparam logic [11:0] COLOR_TITLE = 12'hF_F_8;
    localparam TITLE_VAL = "OPTIBOLT - Protocol and Evaluation Platform";
    localparam int TITLE_LEN = $bits(TITLE_VAL) / 8;

    // STATUS: LINK
    localparam logic [11:0] COLOR_STATUS_LINK = 12'h8_F_F;
    localparam STATUS_LINK_VAL_A = "Link Status : CONNECTED";
    localparam STATUS_LINK_VAL_B = "Link Status : DISCONNECTED";
    localparam int STATUS_LINK_LEN_A = $bits(STATUS_LINK_VAL_A) / 8;
    localparam int STATUS_LINK_LEN_B = $bits(STATUS_LINK_VAL_B) / 8;
    localparam int STATUS_LINK_MAX_LEN = (STATUS_LINK_LEN_A > STATUS_LINK_LEN_B) ? STATUS_LINK_LEN_A : STATUS_LINK_LEN_B;

    // STATUS: BAUDRATE
    localparam logic [11:0] COLOR_STATUS_BAUD = 12'h8_F_8;
    localparam STATUS_BAUD_VAL = "Baudrate    : 115200 bps";
    localparam int STATUS_BAUD_LEN = $bits(STATUS_BAUD_VAL) / 8;

    // STATUS: POWER
    localparam logic [11:0] COLOR_STATUS_PWR = 12'hF_8_8;
    localparam STATUS_PWR_VAL = "Power Neg.  : 5.0V / 1.0A";
    localparam int STATUS_PWR_LEN = $bits(STATUS_PWR_VAL) / 8;

    // CONSOLE
    localparam logic [11:0] COLOR_CONSOLE = 12'hC_C_C;
    localparam CONSOLE_INIT_VAL = "OptiBolt OS v1.0\nSystem Ready.\nWaiting for connection...";
    localparam int CONSOLE_INIT_LEN = $bits(CONSOLE_INIT_VAL) / 8;
    localparam int CONSOLE_MAX_LEN    = 1024;

    // INPUT
    localparam logic [11:0] COLOR_INPUT = 12'hF_8_F;
    localparam INPUT_INIT_VAL = "> _";
    localparam int INPUT_INIT_LEN = $bits(INPUT_INIT_VAL) / 8;
    localparam int INPUT_MAX_LEN    = 128;

    // ABOUT BTN & POPUP
    localparam BTN_ABOUT_VAL = "About";
    localparam int BTN_ABOUT_LEN = $bits(BTN_ABOUT_VAL) / 8;

    localparam ABOUT_TITLE_VAL = "About OptiBolt";
    localparam int ABOUT_TITLE_LEN = $bits(ABOUT_TITLE_VAL) / 8;
    localparam ABOUT_DESC_VAL = "Authors: T. Wieclawski, S. Zon";
    localparam int ABOUT_DESC_LEN = $bits(ABOUT_DESC_VAL) / 8;
    localparam BTN_OK_VAL = "OK";
    localparam int BTN_OK_LEN = $bits(BTN_OK_VAL) / 8;

endpackage
