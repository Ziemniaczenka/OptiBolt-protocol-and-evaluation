<#
.SYNOPSIS
    Runs a fast in-memory Vivado synthesis check to verify hardware compilability and resource usage.
.DESCRIPTION
    Runs synthesis without the lengthy placement, routing, or bitstream generation steps.
    Produces resource utilization reports in results/ within 2–3 minutes.
.EXAMPLE
    .\tools\quick_synth.ps1
#>

if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

if (Test-Path ".\env.ps1") {
    . .\env.ps1
}

Write-Host "Running fast in-memory synthesis check..." -ForegroundColor Cyan
vivado.bat -mode batch -source fpga/scripts/quick_synth.tcl

if ($LASTEXITCODE -eq 0) {
    Write-Host "Fast synthesis succeeded! Reports generated in results/:" -ForegroundColor Green
    Write-Host "  - results/top_utilization.rpt"
    Write-Host "  - results/hierarchical_utilization.rpt"
} else {
    Write-Host "Synthesis failed. Check the logs above for errors." -ForegroundColor Red
}

