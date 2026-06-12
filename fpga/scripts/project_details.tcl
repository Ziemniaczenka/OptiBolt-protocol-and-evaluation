# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Edited by: Tomasz Więcławski & Sebastian Zoń
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
    ../rtl/protocol/protocol_pkg.sv
    ../rtl/protocol/sampling_tick_generator.sv
    ../rtl/protocol/manchester_decoder.sv
    ../rtl/protocol/manchester_coder.sv
    ../rtl/protocol/optibolt_receiver.sv
    ../rtl/protocol/optibolt_transmitter.sv
    ../rtl/protocol/optibolt_controller.sv
    ../rtl/top.sv
    rtl/top_basys3.sv
}

# Specify Verilog design files location         -- EDIT
set verilog_files {
    rtl/clk_wiz_0.v
    rtl/clk_wiz_0_clk_wiz.v
    rtl/clk_wiz_1.v
    rtl/clk_wiz_1_clk_wiz.v
    ../rtl/protocol/list_ch04_20_fifo.v
    ../rtl/protocol/list_ch04_11_mod_m_counter.v
}

# Specify VHDL design files location            -- EDIT
# set vhdl_files {
#    path/to/file.vhd
# }

# Specify files for a memory initialization     -- EDIT
set mem_files {
    ../rtl/evaluation/display/data/bitmap1_152x64.mem
    ../rtl/evaluation/display/data/font_11x7.mem
}
