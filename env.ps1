# PowerShell environment setup script
# Usage: . .\env.ps1
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# Initialize environment for working with the project.

$env:ROOT_DIR = (Get-Location).Path
$env:PATH = "$env:ROOT_DIR\tools;$env:PATH"

$vivadoCmd = Get-Command vivado -ErrorAction SilentlyContinue
if ($vivadoCmd) {
    $env:VIVADO_DIR = $vivadoCmd.Path -replace '\\bin\\vivado.*$', ''
}

# Create local git repository - required for scripts
if (-not (Test-Path ".git")) {
    git init
    git add .
}

New-Item -ItemType Directory -Force -Path "results" | Out-Null

# Copy glbl.v from Vivado installation dir - required for IP simulation
if (-not (Test-Path "sim\common\glbl.v")) {
    New-Item -ItemType Directory -Force -Path "sim\common" | Out-Null
    if ($env:VIVADO_DIR) {
        Copy-Item -Path "$env:VIVADO_DIR\data\verilog\src\glbl.v" -Destination "sim\common\glbl.v"
    }
}