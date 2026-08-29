# PowerShell script
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# This script runs simulations outside Vivado, making them faster.
# For usage details run the script with no arguments.
# For more information see: AMD Xilinx UG 900:
# https://docs.xilinx.com/r/en-US/ug900-vivado-logic-simulation/Simulating-in-Batch-or-Scripted-Mode-in-Vivado-Simulator
# To work properly, a git repository in the project directory is required.
# Run from the project root directory.

param (
    [switch]$a,
    [switch]$g,
    [switch]$l,
    [string]$t
)

if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot/..").Path
}

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

function Show-Usage {
    Write-Host "usage: .\run_simulation.ps1 [options]"
    Write-Host "  options:"
    Write-Host "    -l         list available tests"
    Write-Host "    -t <test>  run the specified <test>"
    Write-Host "    -g         show gui (use with -t)"
    Write-Host "    -a         run all available tests (does not work with gui)"
    exit 1
}

function Get-AvailableTests {
    Get-ChildItem -Path . -Filter "*.prj" -Recurse | 
        Where-Object { $_.DirectoryName -notmatch '[\\/](build|common)([\\/]|$)' } | 
        ForEach-Object {
            $relPath = (Resolve-Path -Relative $_.DirectoryName) -replace '^\.[\/\\]', ''
            $relPath -replace '\\', '/'
        }
}

function Execute-Test {
    param([string]$test_path)

    # --------------------------------------------------------------------------
    # Modification Note:
    # 1. Path Normalization:
    #    When users use PowerShell tab-completion (e.g., -t .\top_evaluation\),
    #    the path string contains leading '.\' and trailing '\'.
    #    We normalize this to avoid generating broken project paths like:
    #    sim/.\top_evaluation\//.\top_evaluation\.prj
    # --------------------------------------------------------------------------
    $test_path = $test_path.Trim().TrimEnd('/\')
    $test_path = $test_path -replace '^\.[\/\\]', ''
    $test_name = Split-Path $test_path -Leaf

    # Remove untracked files
    git clean -fXd .

    if (-not (Test-Path "$env:ROOT_DIR/results")) { New-Item -ItemType Directory -Path "$env:ROOT_DIR/results" | Out-Null }
    if (-not (Test-Path "build")) { New-Item -ItemType Directory -Path "build" | Out-Null }
    Set-Location build

    $prj_path = "$env:ROOT_DIR/sim/$test_path/$test_name.prj"
    $compile_glbl = ""
    if (Test-Path $prj_path) {
        if (Select-String -Path $prj_path -Pattern "glbl\.v" -Quiet) {
            $compile_glbl = "work.glbl"
        }
    }

    # Convert to posix paths to avoid Tcl parsing issues with backslashes
    $prj_posix = $prj_path -replace '\\', '/'
    $sim_cmd_posix = "$env:ROOT_DIR/tools/sim_cmd.tcl" -replace '\\', '/'

    $xelab_opts = @("work.${test_name}_tb")
    if ($compile_glbl) { $xelab_opts += $compile_glbl }
    $xelab_opts += @("-snapshot", "${test_name}_tb", "-prj", $prj_posix, "-timescale", "1ns/1ps", "-L", "unisims_ver")

    # --------------------------------------------------------------------------
    # Modification Note:
    # 2. Two-Stage Execution (xelab -> xsim -runall):
    #    Originally, the script invoked 'xelab -standalone -runall'.
    #    On Windows Vivado installations, '-standalone' often produces a fatal
    #    Boost filesystem file-locking error during temporary C file cleanup:
    #    "boost::filesystem::remove: The process cannot access the file..."
    #    which aborts the simulation prematurely.
    #    Splitting into xelab snapshot elaboration followed by native 'xsim -runall'
    #    completely eliminates this file lock collision, while also streaming
    #    all simulation $display outputs live to the terminal.
    # --------------------------------------------------------------------------
    if ($g) {
        & xelab.bat $xelab_opts -debug typical
        & xsim.bat "${test_name}_tb" -gui -t $sim_cmd_posix
    } else {
        & xelab.bat $xelab_opts
        if ($LASTEXITCODE -eq 0 -or (Test-Path "xsim.dir/${test_name}_tb/xsimk.exe")) {
            & xsim.bat "${test_name}_tb" -runall
        }
    }

    Set-Location ..
}

# ------------------------------------------------------------------------------
# Arguments parsing and checking
# ------------------------------------------------------------------------------

if (-not ($a -or $g -or $l -or $t)) {
    Show-Usage
}

Set-Location "$env:ROOT_DIR\sim"

if ($l) { Get-AvailableTests; exit 0 }

if ($a) {
    foreach ($test in (Get-AvailableTests)) {
        Write-Host -NoNewline "${test}:`t"
        $output = Execute-Test -test_path $test
        $err_ctr = ($output | Select-String -Pattern '(?i)error').Count
        if ($err_ctr -eq 0) { Write-Host -ForegroundColor Green " PASSED" } 
        else { Write-Host -ForegroundColor Red " FAILED" }
    }
    exit 0
}

if ($t) { Execute-Test -test_path $t }