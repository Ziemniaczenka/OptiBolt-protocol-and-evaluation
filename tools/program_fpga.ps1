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
Set-Location $env:ROOT_DIR

if ($args.Count -gt 0) {
    $bitstream_file = (Resolve-Path $args[0]).Path
} else {
    # Domyślnie bierzemy najnowiej wygenerowany plik .bit
    $bitstream_file = (Get-ChildItem -Path results -Filter "*.bit" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$bitstream_file_posix = $bitstream_file -replace '\\', '/'
vivado.bat -mode tcl -source fpga/scripts/program_fpga.tcl -tclargs $bitstream_file_posix