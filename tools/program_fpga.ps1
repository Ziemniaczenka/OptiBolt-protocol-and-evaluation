# PowerShell script
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# Load a bitstream to a Xilinx FPGA using Vivado in tcl mode
# Run from the project root directory.

param(
    [string]$BitstreamPath
)

# Ensure execution from the root directory
if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

if ($BitstreamPath) {
    if (Test-Path $BitstreamPath) {
        $bitstream_file = (Resolve-Path $BitstreamPath).Path
    } elseif (Test-Path "results\$BitstreamPath") {
        $bitstream_file = (Resolve-Path "results\$BitstreamPath").Path
    } else {
        Write-Error "Specified bitstream file '$BitstreamPath' not found!"
        exit 1
    }
} else {
    $found = Get-ChildItem -Path results -Filter "*.bit" | Select-Object -First 1
    if (-not $found) {
        Write-Error "No .bit file found in results/! Please generate bitstream first."
        exit 1
    }
    $bitstream_file = $found.FullName
}

Write-Host "Using bitstream: $bitstream_file"
$bitstream_file_posix = $bitstream_file -replace '\\', '/'
vivado.bat -mode tcl -source fpga/scripts/program_fpga.tcl -tclargs $bitstream_file_posix