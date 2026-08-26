/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Package with string constants and colors for the evaluation UI.
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
    localparam logic [11:0] COLOR_STATUS_LINK_DISCONN = 12'hF_8_8;
    localparam logic [11:0] COLOR_STATUS_LINK_CONN    = 12'h8_F_8;
    localparam logic [11:0] COLOR_STATUS_LINK_LOOP    = 12'h8_F_F;

    localparam STATUS_LINK_VAL_DISCONN = "Link Status : DISCONNECTED";
    localparam STATUS_LINK_VAL_CONN    = "Link Status : CONNECTED   ";
    localparam STATUS_LINK_VAL_LOOP    = "Link Status : LOOPBACK    ";
    localparam int STATUS_LINK_MAX_LEN = $bits(STATUS_LINK_VAL_DISCONN) / 8;

    // STATUS: BAUDRATE
    localparam logic [11:0] COLOR_STATUS_BAUD = 12'h8_F_8;
    localparam STATUS_BAUD_VAL_100K     = "Baudrate    : 100 kbps  ";
    localparam STATUS_BAUD_VAL_1M       = "Baudrate    : 1.0 Mbps  ";
    localparam STATUS_BAUD_VAL_1dot25M  = "Baudrate    : 1.25 Mbps ";
    localparam STATUS_BAUD_VAL_2dot5M   = "Baudrate    : 2.5 Mbps  ";
    localparam STATUS_BAUD_VAL_3dot125M = "Baudrate    : 3.125 Mbps";
    localparam STATUS_BAUD_VAL_5M       = "Baudrate    : 5.0 Mbps  ";
    localparam STATUS_BAUD_VAL_6dot25M  = "Baudrate    : 6.25 Mbps ";
    localparam STATUS_BAUD_VAL_8dot33M  = "Baudrate    : 8.33 Mbps ";
    localparam STATUS_BAUD_VAL_12dot5M  = "Baudrate    : 12.5 Mbps ";
    localparam STATUS_BAUD_VAL_25M      = "Baudrate    : 25.0 Mbps ";
    localparam int STATUS_BAUD_LEN      = $bits(STATUS_BAUD_VAL_100K) / 8;

    // STATUS: POWER
    localparam logic [11:0] COLOR_STATUS_PWR = 12'hF_8_8;
    localparam STATUS_PWR_VAL = "Power Neg.  : 5.0V / 1.0A";
    localparam int STATUS_PWR_LEN = $bits(STATUS_PWR_VAL) / 8;

    // CONSOLE
    localparam logic [11:0] COLOR_CONSOLE = 12'hC_C_C;
    localparam CONSOLE_INIT_VAL = "OptiBolt OS v1.0\nSystem Ready.\nWaiting for connection...";
    localparam int CONSOLE_INIT_LEN = $bits(CONSOLE_INIT_VAL) / 8;
    localparam int CONSOLE_MAX_LEN  = 1024;

    // INPUT
    localparam logic [11:0] COLOR_INPUT = 12'hF_8_F;
    localparam INPUT_INIT_VAL = "> _";
    localparam int INPUT_INIT_LEN = $bits(INPUT_INIT_VAL) / 8;
    localparam int INPUT_MAX_LEN  = 128;

    // TOOLBAR BUTTONS
    localparam BTN_HELP_VAL   = "Help";
    localparam int BTN_HELP_LEN   = $bits(BTN_HELP_VAL) / 8;

    localparam BTN_PING_VAL   = "Ping";
    localparam int BTN_PING_LEN   = $bits(BTN_PING_VAL) / 8;

    localparam BTN_SWEEP_VAL  = "Sweep";
    localparam int BTN_SWEEP_LEN  = $bits(BTN_SWEEP_VAL) / 8;

    localparam BTN_SNDBMP_VAL = "Send BMP";
    localparam int BTN_SNDBMP_LEN = $bits(BTN_SNDBMP_VAL) / 8;

    localparam BTN_CLRBMP_VAL = "Clr BMP";
    localparam int BTN_CLRBMP_LEN = $bits(BTN_CLRBMP_VAL) / 8;

    localparam BTN_CLRCON_VAL = "Clr Con";
    localparam int BTN_CLRCON_LEN = $bits(BTN_CLRCON_VAL) / 8;

    localparam BTN_ABOUT_VAL  = "About";
    localparam int BTN_ABOUT_LEN  = $bits(BTN_ABOUT_VAL) / 8;

    // ABOUT POPUP
    localparam ABOUT_TITLE_VAL = "About OptiBolt";
    localparam int ABOUT_TITLE_LEN = $bits(ABOUT_TITLE_VAL) / 8;
    localparam ABOUT_DESC_VAL = "OptiBolt Evaluation Platform\nBy T. Wieclawski & S. Zon";
    localparam int ABOUT_DESC_LEN = $bits(ABOUT_DESC_VAL) / 8;
    localparam BTN_OK_VAL = "OK";
    localparam int BTN_OK_LEN = $bits(BTN_OK_VAL) / 8;

    // PROGRESS POPUP
    localparam PROG_TITLE_VAL = "Task Progress";
    localparam int PROG_TITLE_LEN = $bits(PROG_TITLE_VAL) / 8;
    localparam PROG_DESC_VAL = "Active test / data stream in progress...";
    localparam int PROG_DESC_LEN = $bits(PROG_DESC_VAL) / 8;

    // DIAGNOSTICS & ERROR METRICS LABELS
    localparam DIAG_TITLE_VAL = "DIAGNOSTICS & ERROR METRICS";
    localparam int DIAG_TITLE_LEN = $bits(DIAG_TITLE_VAL) / 8;

    localparam DIAG_MAN_VAL = "Manchester Errors";
    localparam int DIAG_MAN_LEN = $bits(DIAG_MAN_VAL) / 8;

    localparam DIAG_PRE_VAL = "Preamble / Sync Err";
    localparam int DIAG_PRE_LEN = $bits(DIAG_PRE_VAL) / 8;

    localparam DIAG_PAR_VAL = "Parity Check Errors";
    localparam int DIAG_PAR_LEN = $bits(DIAG_PAR_VAL) / 8;

    localparam DIAG_HLT_VAL = "Link Integrity / Health";
    localparam int DIAG_HLT_LEN = $bits(DIAG_HLT_VAL) / 8;

    // DYNAMIC BITMAP LABEL
    localparam BITMAP_DYN_LBL_VAL = "DYNAMIC BITMAP (128x128)";
    localparam int BITMAP_DYN_LBL_LEN = $bits(BITMAP_DYN_LBL_VAL) / 8;

endpackage
