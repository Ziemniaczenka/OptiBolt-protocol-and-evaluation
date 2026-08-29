# PowerShell script
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# This script runs Vivado in tcl mode and sources an apropriate tcl file to run
# all the steps to generate bitstream. When finished, the bitsream is copied to
# the result directory. Additionally, all the warnings and errors logged during
# synthesis and implementation are also copied to results/warning_summary.log
# To work properly, a git repository in the project directory is required.
# Run from the project root directory.

# Ensure execution from the root directory
if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

# Remove untracked files
git clean -fXd fpga

# Run Vivado and generate bitstream
Set-Location fpga
vivado.bat -mode batch -notrace -source scripts/generate_bitstream.tcl
Set-Location $env:ROOT_DIR

# Ensure results directory exists
New-Item -ItemType Directory -Force -Path results | Out-Null

# Copy bitstream to results
Get-ChildItem -Path fpga/build -Filter "*.bit" -Recurse | Copy-Item -Destination results/

# Copy warnings and errors to a single log file in results
& .\tools\warning_summary.ps1