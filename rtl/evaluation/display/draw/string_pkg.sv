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


    // String 1 - static "OPTIBOLT - protocol and evaluation"
    localparam logic [11:0] COLOR_STRING1 = 12'hF_F_8;
    localparam STRING1_VAL = "OPTIBOLT - protocol and evaluation";
    localparam int STRING1_LEN = $bits(STRING1_VAL) / 8;

    // String 2 - switchable "Status: CONNECTED" : "Status: DISCONNECTED"
    localparam logic [11:0] COLOR_STRING2 = 12'h8_F_F;
    localparam STRING2_VAL_A = "Status: CONNECTED";
    localparam STRING2_VAL_B = "Status: DISCONNECTED";
    localparam int STRING2_LEN_A = $bits(STRING2_VAL_A) / 8;
    localparam int STRING2_LEN_B = $bits(STRING2_VAL_B) / 8;
    localparam int STRING2_MAX_LEN = (STRING2_LEN_A > STRING2_LEN_B) ? STRING2_LEN_A : STRING2_LEN_B;

    // String 3 - dynamic CONSOLE
    localparam logic [11:0] COLOR_CONSOLE = 12'hF_8_8;
    localparam CONSOLE_INIT_VAL = "Wpisz tekst: _";
    localparam int CONSOLE_INIT_LEN = $bits(CONSOLE_INIT_VAL) / 8;
    localparam int CONSOLE_MAX_LEN    = 2048;

endpackage
