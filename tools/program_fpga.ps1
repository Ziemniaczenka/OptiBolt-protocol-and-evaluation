# PowerShell script
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# Load a bitstream to a Xilinx FPGA using Vivado in tcl mode
# Run from the project root directory.

# Ensure execution from the root directory
if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

$bitstream_file = (Get-ChildItem -Path results -Filter "*.bit" | Select-Object -First 1).FullName
$bitstream_file_posix = $bitstream_file -replace '\\', '/'
vivado.bat -mode tcl -source fpga/scripts/program_fpga.tcl -tclargs $bitstream_file_posix