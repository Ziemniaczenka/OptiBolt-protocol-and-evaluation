# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Modified by: Tomasz Więcławski & Sebastian Zoń
#
# Description:
# Project detiles required for generate_bitstream.tcl
# Make sure that project_name, top_module and target are correct.
# Provide paths to all the files required for synthesis and implementation.
# Depending on the file type, it should be added in the corresponding section.
# If the project does not use files of some type, leave the corresponding section commented out.

#-----------------------------------------------------#
#                   Project details                   #
#-----------------------------------------------------#
# Project name                                  -- EDIT
set project_name optibolt_project

# Top module name                               -- EDIT
set top_module top_basys3

# FPGA device
set target xc7a35tcpg236-1

#-----------------------------------------------------#
#                    Design sources                   #
#-----------------------------------------------------#
# Specify .xdc files location                   -- EDIT
set xdc_files {
    constraints/clk_wiz_0.xdc
    constraints/clk_wiz_0_late.xdc
    constraints/clk_wiz_1.xdc
    constraints/clk_wiz_1_late.xdc
    constraints/top_basys3.xdc
}

# Specify SystemVerilog design files location   -- EDIT
set sv_files {
    ../rtl/evaluation/display/vga/vga_pkg.sv
    ../rtl/evaluation/display/draw/font/font_pkg.sv
    ../rtl/evaluation/display/draw/string_pkg.sv
    ../rtl/evaluation/display/draw/bitmap_pkg.sv
    ../rtl/evaluation/ui_pkg.sv
    ../rtl/protocol/protocol_pkg.sv
    ../rtl/protocol/sampling_tick_generator.sv
    ../rtl/protocol/manchester_coder.sv
    ../rtl/protocol/manchester_decoder.sv
    ../rtl/protocol/optibolt_receiver.sv
    ../rtl/protocol/optibolt_transmitter.sv
    ../rtl/protocol/optibolt_controller.sv
    ../rtl/protocol/list_ch04_11_mod_m_counter.v
    ../rtl/protocol/list_ch04_20_fifo.v
    ../rtl/helpers/bram_if.sv
    ../rtl/evaluation/display/vga/vga_if.sv
    ../rtl/evaluation/display/vga/vga_timing.sv
    ../rtl/evaluation/display/draw/font/font.sv
    ../rtl/helpers/fwft_fifo.sv
    ../rtl/helpers/async_fifo.sv
    ../rtl/helpers/edge_detector.sv
    ../rtl/helpers/cdc_sync.sv
    ../rtl/helpers/bram_tdp.sv
    ../rtl/helpers/pixel_prng.sv
    ../rtl/helpers/counter.sv
    ../rtl/evaluation/display/draw/draw_bg.sv
    ../rtl/evaluation/display/draw/draw_string.sv
    ../rtl/evaluation/display/draw/draw_mux.sv
    ../rtl/helpers/delay.sv
    ../rtl/evaluation/display/draw/string_rom.sv
    ../rtl/evaluation/display/draw/draw_bitmap.sv
    ../rtl/evaluation/display/draw/draw_rect.sv
    ../rtl/evaluation/display/draw/draw_button.sv
    ../rtl/evaluation/display/draw/draw_progress_bar.sv
    ../rtl/evaluation/display/draw/draw_popup.sv
    ../rtl/evaluation/display/draw/top_draw.sv
    ../rtl/evaluation/display/top_display.sv
    ../rtl/protocol/optibolt_link_manager.sv
    ../rtl/evaluation/controller/eval_diagnostics.sv
    ../rtl/evaluation/controller/eval_cli_input.sv
    ../rtl/evaluation/controller/eval_console_buffer.sv
    ../rtl/evaluation/controller/eval_cmd_exec.sv
    ../rtl/evaluation/link_handshake.sv
    ../rtl/evaluation/evaluation_controller.sv
    ../rtl/evaluation/ui_navigation.sv
    ../rtl/evaluation/keyboard/keyboard_controller.sv
    ../rtl/evaluation/keyboard/keyboard_decoder.sv
    ../rtl/evaluation/keyboard/top_keyboard.sv
    ../rtl/evaluation/top_evaluation.sv
    rtl/top_basys3.sv
    ../rtl/top.sv
}

# Specify Verilog design files location         -- EDIT
set verilog_files {
    rtl/clk_wiz_0.v
    rtl/clk_wiz_0_clk_wiz.v
    rtl/clk_wiz_1.v
    rtl/clk_wiz_1_clk_wiz.v
    ../rtl/evaluation/7seg/disp_hex_mux.v
}

# Specify VHDL design files location            -- EDIT
set vhdl_files {
    ../rtl/evaluation/keyboard/Ps2Interface.vhd
}

# Specify files for a memory initialization     -- EDIT
set mem_files {
    ../rtl/evaluation/display/data/OptiBolt400x102.mem
    ../rtl/evaluation/display/data/bitmap1_152x64.mem
    ../rtl/evaluation/display/data/font_11x7.mem
}
