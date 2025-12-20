# =============================================================================
# FILE: gh.ps1
# DESCRIPTION: Automated PDF Generation Pipeline (PDF/A-2b) & Git Sync
# TARGET: PowerShell 5.1 / 7.x (Core)
# AUTHOR: DevOps Engineering Lead
# DATE: 2025-12-20
# ENCODING: UTF-8
# =============================================================================

# -----------------------------------------------------------------------------
# 1. INITIALIZATION AND CONFIGURATION
# -----------------------------------------------------------------------------

# Stop script immediately on any unhandled error
$ErrorActionPreference = "Stop"

# Enable strict mode for better safety
Set-StrictMode -Version 2.0

# Define absolute paths for log files
$ScriptRoot   = $PSScriptRoot
$LogFile      = Join-Path $ScriptRoot "gh.log"
$GitErrorLog  = Join-Path $ScriptRoot "git-errors.log"

# Function: Write-Log
# Purpose:  Dual-stream logging (console + file)
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp][$Level] $Message"
    Write-Host $logLine
    Add-Content -Path $LogFile -Value $logLine
}

Write-Log "=== Starting PDF Generation + Git Sync Pipeline ==="

# -----------------------------------------------------------------------------
# 2. PDF/A-2b GENERATION USING GHOSTSCRIPT
# -----------------------------------------------------------------------------

# Configuration
$InputFolder  = Join-Path $ScriptRoot "pdf_src"
$OutputFolder = Join-Path $ScriptRoot "pdf_out"

if (-not (Test-Path $OutputFolder)) {
    Write-Log "Creating output directory: $OutputFolder"
    New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
}

# Function: ConvertTo-PDFA
# Converts input PDF into compliant PDF/A-2b using Ghostscript
function ConvertTo-PDFA {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputPDF
    )

    $OutputPDF = Join-Path $OutputFolder ([IO.Path]::GetFileNameWithoutExtension($InputPDF) + "_PDF-A.pdf")

    Write-Log "Converting to PDF/A-2b: $InputPDF → $OutputPDF"

    $gsArgs = @(
        "-dPDFA=2",
        "-dBATCH",
        "-dNOPAUSE",
        "-dNOOUTERSAVE",
        "-sProcessColorModel=DeviceRGB",
        "-sDEVICE=pdfwrite",
        "-dPDFACompatibilityPolicy=1",
        "-sOutputFile=$OutputPDF",
        "$InputPDF"
    )

    try {
        & gs @gsArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Conversion succeeded: $OutputPDF" "SUCCESS"
        }
        else {
            throw "Ghostscript returned error code $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Ghostscript failed: $_" "ERROR"
    }
}

# Process all PDFs in input folder
$inputPDFs = Get-ChildItem -Path $InputFolder -Filter "*.pdf" -File
foreach ($pdf in $inputPDFs) {
    ConvertTo-PDFA -InputPDF $pdf.FullName
}

# -----------------------------------------------------------------------------
# 3. GIT SYNCHRONIZATION
# -----------------------------------------------------------------------------

Write-Log "Starting Git synchronization..."

try {
    & git add -A
    & git commit -m "Automated PDF/A generation update ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
    & git push
    Write-Log "Git synchronization completed successfully." "SUCCESS"
}
catch {
    Write-Log "Git synchronization failed: $_" "ERROR"
    Add-Content -Path $GitErrorLog -Value $_
}

Write-Log "=== Pipeline Complete ==="
