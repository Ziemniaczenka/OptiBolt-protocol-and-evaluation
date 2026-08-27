<#
.SYNOPSIS
    Generates detailed FPGA resource utilization reports from the latest Vivado build.
.DESCRIPTION
    Runs Vivado in batch mode to inspect the synthesis or implementation checkpoint,
    producing top-level and hierarchical utilization reports in results/.
.EXAMPLE
    .\tools\report_utilization.ps1
#>

if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

if (Test-Path ".\env.ps1") {
    . .\env.ps1
}

Write-Host "Running Vivado utilization report generator..." -ForegroundColor Cyan
vivado.bat -mode batch -source fpga/scripts/report_utilization.tcl

if ($LASTEXITCODE -eq 0) {
    Write-Host "Reports successfully generated in results/:" -ForegroundColor Green
    Write-Host "  - results/top_utilization.rpt"
    Write-Host "  - results/hierarchical_utilization.rpt"
} else {
    Write-Host "Failed to generate utilization reports." -ForegroundColor Red
}

