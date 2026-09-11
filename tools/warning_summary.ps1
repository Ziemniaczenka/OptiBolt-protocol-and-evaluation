# PowerShell script
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk (adapted for Windows)
#
# Description:
# This script extracts warnings and errors from the synthesis
# and implementation logs to a single log file.
# Run from the project root directory.

# Ensure execution from the root directory
if (-not $env:ROOT_DIR) {
    $env:ROOT_DIR = (Resolve-Path "$PSScriptRoot\..").Path
}
Set-Location $env:ROOT_DIR

$PROJECT_PATH = "fpga\build"
$LOG_FILE = "results\warning_summary.log"

$SYNTH_IGNORE = '\[Constraints\s18-5210\]|\[Netlist\s29-345\]'
$IMPL_IGNORE = 'replace_with_codes_to_be_ignored_only_when_justified'

"Warnings, critical warnings and errors from synthesis and implementation`n" | Out-File $LOG_FILE -Encoding UTF8
"Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File $LOG_FILE -Append -Encoding UTF8

"----SYNTHESIS----" | Out-File $LOG_FILE -Append -Encoding UTF8
$SYNTH_LOG = Get-ChildItem -Path $PROJECT_PATH -Filter "runme.log" -Recurse | Where-Object { $_.DirectoryName -match "synth_1" } | Select-Object -First 1

if ($SYNTH_LOG) {
    $warnings = Get-Content $SYNTH_LOG.FullName | Where-Object { $_ -notmatch $SYNTH_IGNORE -and $_ -match 'CRITICAL|WARNING|ERROR' }
    if ($warnings) {
        $warnings | Out-File $LOG_FILE -Append -Encoding UTF8
    } else {
        "CLEAR :)`n" | Out-File $LOG_FILE -Append -Encoding UTF8
    }
} else {
    "No synthesis log file found!`n" | Out-File $LOG_FILE -Append -Encoding UTF8
}

"`n----IMPLEMENTATION----" | Out-File $LOG_FILE -Append -Encoding UTF8
$IMPL_LOG = Get-ChildItem -Path $PROJECT_PATH -Filter "runme.log" -Recurse | Where-Object { $_.DirectoryName -match "impl_1" } | Select-Object -First 1
$DRC_RPT  = Get-ChildItem -Path $PROJECT_PATH -Filter "*drc_routed.rpt" -Recurse | Where-Object { $_.DirectoryName -match "impl_1" } | Select-Object -First 1

if ($IMPL_LOG) {
    $impl_warnings = @()
    $warnings = Get-Content $IMPL_LOG.FullName | Where-Object { $_ -notmatch $IMPL_IGNORE -and $_ -match 'CRITICAL|WARNING|ERROR' }
    if ($warnings) { $impl_warnings += $warnings }

    # Extract individual DRC warnings from drc_routed.rpt
    if ($DRC_RPT) {
        $drc_content = Get-Content $DRC_RPT.FullName -Raw
        $drc_matches = [regex]::Matches($drc_content, '([A-Z0-9_-]+)#\d+\s+Warning\s*\r?\n([^\r\n]+)\s*\r?\n([^\r\n]+)')
        foreach ($m in $drc_matches) {
            $rule   = $m.Groups[1].Value
            $desc   = $m.Groups[2].Value.Trim()
            $detail = $m.Groups[3].Value.Trim()
            $drc_line = "WARNING: [DRC $rule] $desc`: $detail"
            if ($drc_line -notmatch $IMPL_IGNORE) {
                $impl_warnings += $drc_line
            }
        }
    }

    if ($impl_warnings.Count -gt 0) {
        $impl_warnings | Out-File $LOG_FILE -Append -Encoding UTF8
    } else {
        "CLEAR :)`n" | Out-File $LOG_FILE -Append -Encoding UTF8
    }
} else {
    "No implementation log file found!`n" | Out-File $LOG_FILE -Append -Encoding UTF8
}

$project_name = [System.IO.Path]::GetFileName((Get-Location).Path)
$escaped_project_name = [regex]::Escape($project_name)
$content = Get-Content $LOG_FILE
$pattern = "(?<=\[)(?:[A-Za-z]:)?[\\/][^\]]*?[\\/]$escaped_project_name[\\/]"
($content -replace $pattern, "") | Out-File $LOG_FILE -Encoding UTF8