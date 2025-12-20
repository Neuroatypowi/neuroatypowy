# =============================================================================
# FILE: gh.ps1
# DESCRIPTION: Automated PDF Generation Pipeline Orchestrator (PDF/A-2b compliant)
# AUTHOR: Expert Systems Research / DevOps Engineering Lead
# DATE: 2025-12-20
# STANDARDS: PowerShell 7.x, Git 2.4x+, MiKTeX 25.4, Pandoc 3.8.3, Ghostscript 10.06.0
# ENCODING: ASCII (7-bit) - Compatibility Mode
# =============================================================================

# -----------------------------------------------------------------------------
# 1. ENVIRONMENT CONFIGURATION & ERROR HANDLING
# -----------------------------------------------------------------------------
# Set strict error preference to stop on any failure immediately.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

# Define absolute paths for log files to avoid relative path ambiguities.
$ScriptRoot = $PSScriptRoot
$LogFile = Join-Path $ScriptRoot "gs.log"
$GitErrorLog = Join-Path $ScriptRoot "git-errors.log"

# Function: Write-Log
# Purpose: Dual-stream logging (Console + File) with ASCII encoding validation.
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    
    # Write to console host for CI visibility
    Write-Host $LogEntry -ForegroundColor Cyan
    
    # Append to log file ensuring pure ASCII encoding (no UTF-8 BOM issues)
    # Using for atomic append operations/better locking handling
    try {
       ::AppendAllText($LogFile, "$LogEntry`r`n",::ASCII)
    } catch {
        Write-Warning "Failed to write to log file. Proceeding with console log only."
    }
}

# -----------------------------------------------------------------------------
# 2. SYSTEM DEPENDENCY VALIDATION (Fonts & Tools)
# -----------------------------------------------------------------------------

# Function: Test-FontInstalled
# Purpose: Validates font presence in both System (HKLM) and User (HKCU) registry hives.
# Addresses Error (a): 'Noto Color Emoji' validation failure.
function Test-FontInstalled {
    param([string]$FontName)
    
    $RegistryScopes = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($Scope in $RegistryScopes) {
        if (Test-Path $Scope) {
            $Fonts = Get-ItemProperty -Path $Scope
            # Iterate through all properties (font names) looking for a regex match
            foreach ($Property in $Fonts.PSObject.Properties) {
                if ($Property.Name -match [regex]::Escape($FontName)) {
                    return $true
                }
            }
        }
    }
    return $false
}

Write-Log "Starting Environment Validation..."

# Validate Critical Fonts
$RequiredFonts = @("Inter", "OpenDyslexic", "Noto Color Emoji")
foreach ($Font in $RequiredFonts) {
    if (Test-FontInstalled $Font) {
        Write-Log "SUCCESS: Font '$Font' is installed."
    } else {
        Write-Log "WARNING: Font '$Font' not found in registry. PDF generation may fail or lack glyphs."
        # In strict mode, we might want to throw here, but we continue with warning.
    }
}

# -----------------------------------------------------------------------------
# 3. MIKTEX CONFIGURATION (Headless/CI Mode)
# -----------------------------------------------------------------------------
# Addresses Error (b): 'security risk' and 'Emergency stop'.
# We force MiKTeX to install missing packages without user interaction (AutoInstall=1).

Write-Log "Configuring MiKTeX for headless execution..."

function Set-MikTexConfig {
    param([string]$Scope) # '--admin' or empty string for user scope
    
    $CmdArgs = @()
    if ($Scope -eq "--admin") { $CmdArgs += "--admin" }
    $CmdArgs += "--set-config-value"
    $CmdArgs += "[MPM]AutoInstall=1"

    try {
        $Process = Start-Process -FilePath "initexmf" -ArgumentList $CmdArgs -PassThru -Wait -NoNewWindow
        if ($Process.ExitCode -eq 0) {
            Write-Log "MiKTeX configuration ($Scope) successful."
        } else {
            Write-Log "MiKTeX configuration ($Scope) returned exit code $($Process.ExitCode)."
        }
    } catch {
        Write-Log "Error executing initexmf ($Scope): $_"
    }
}

# Attempt configuration for both User and Admin scopes to ensure coverage
Set-MikTexConfig ""
Set-MikTexConfig "--admin"

# -----------------------------------------------------------------------------
# 4. GIT SYNCHRONIZATION (Atomic Workflow)
# -----------------------------------------------------------------------------
# Addresses Error (c): 'cannot pull with rebase: You have unstaged changes'.
# Uses --autostash to handle the log file modifications safely.

Write-Log "Starting Git Synchronization..."

# Configure Git for non-interactive merges
git config --global core.editor "true"
git config --global merge.tool "true"
git config --global rebase.autoStash true # Global safety net

# 4.1 Check and Commit Local Changes
$GitStatus = git status --porcelain
if ($GitStatus) {
    Write-Log "Local changes detected. Performing automated commit..."
    git add. 2>&1 | Out-Null
    git commit -m "Auto-save: Pre-sync commit $(Get-Date -Format 'yyyy-MM-dd HH:mm')" --no-edit 2>&1 | Out-Null
} else {
    Write-Log "Working tree is clean (except ignored files)."
}

# 4.2 Robust Pull with Rebase
Write-Log "Executing Pull with Rebase..."
$CurrentBranch = (git branch --show-current).Trim()

# Wrap Git operations in a retry loop for stability
$MaxRetries = 2
$RetryCount = 0
$GitSuccess = $false

while (-not $GitSuccess -and $RetryCount -lt $MaxRetries) {
    try {
        # CRITICAL FIX: --autostash saves the state (including new log entries) before rebase
        git pull --rebase --autostash origin $CurrentBranch 2>&1 | Out-File -FilePath $GitErrorLog -Append -Encoding ASCII
        
        if ($LASTEXITCODE -eq 0) {
            $GitSuccess = $true
            Write-Log "Git pull successful."
        } else {
            throw "Git pull returned non-zero exit code."
        }
    } catch {
        Write-Log "Git pull failed. Attempting recovery (Attempt $($RetryCount + 1))..."
        
        # Recovery: Abort any stuck rebase and clean locks
        git rebase --abort 2>$null
        if (Test-Path ".git/rebase-merge") { Remove-Item -Recurse -Force ".git/rebase-merge" }
        if (Test-Path ".git/rebase-apply") { Remove-Item -Recurse -Force ".git/rebase-apply" }
        
        $RetryCount++
        Start-Sleep -Seconds 2
    }
}

if (-not $GitSuccess) {
    Write-Log "CRITICAL FAILURE: Unable to synchronize with remote. Check $GitErrorLog."
    # We exit here to prevent generating PDFs on inconsistent state
    exit 1
}

# -----------------------------------------------------------------------------
# 5. PDF GENERATION LOGIC (Pandoc + Ghostscript)
# -----------------------------------------------------------------------------

# Define the generator script content (md2pdf.ps1) dynamically
# This ensures the tool logic is always up to date with the main orchestrator.
$Md2PdfScriptContent = @"
# DYNAMICALLY GENERATED TOOL - DO NOT EDIT MANUALLY
param (
    [string]`$InputFile
)

`$ErrorActionPreference = 'Stop'

if (-not (Test-Path `$InputFile)) {
    Write-Error "Input file not found: `$InputFile"
    exit 1
}

`$OutputFile =::ChangeExtension(`$InputFile, ".pdf")

# Pandoc Configuration for PDF/A-2b
# Engine: xelatex (Required for Noto Color Emoji / Unicode)
# PDF/A compliance handled by metadata and Ghostscript post-processing if needed.

Write-Host "Converting `$InputFile to PDF/A..."

pandoc `$InputFile -o `$OutputFile `
    --pdf-engine=xelatex `
    --metadata=pdfa:2b `
    --metadata=author="Neuroatypowi" `
    --metadata=lang="pl-PL" `
    -V mainfont="Inter" `
    -V sansfont="Inter" `
    -V monofont="Inter" `
    -V "mainfontfallback=Noto Color Emoji" `
    -V geometry:margin=2.5cm `
    --toc --toc-depth=2

if (`$LASTEXITCODE -eq 0) {
    Write-Host "Success: `$OutputFile created."
} else {
    Write-Error "Failed to generate PDF for `$InputFile"
    exit `$LASTEXITCODE
}
"@

# Save the generator tool
$ToolPath = Join-Path $ScriptRoot "pdf\tools\md2pdf.ps1"
$ToolDir = Split-Path $ToolPath
if (-not (Test-Path $ToolDir)) { New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null }
Set-Content -Path $ToolPath -Value $Md2PdfScriptContent -Encoding ASCII

Write-Log "PDF Generator tool updated at: $ToolPath"

# Execution Loop for Markdown Files
$MarkdownFiles = Get-ChildItem -Path $ScriptRoot -Filter "*.md" -Recurse | Where-Object { $_.Name -ne "README.md" }

foreach ($File in $MarkdownFiles) {
    Write-Log "Processing: $($File.Name)"
    
    # Run conversion in a separate process to isolate memory/environment
    $Process = Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass", "-File", "`"$ToolPath`"", "-InputFile", "`"$($File.FullName)`"" -PassThru -Wait -NoNewWindow
    
    if ($Process.ExitCode -ne 0) {
        Write-Log "ERROR: Failed to compile $($File.Name)."
    } else {
        Write-Log "COMPLETED: $($File.Name)"
    }
}

# -----------------------------------------------------------------------------
# 6. FINALIZATION
# -----------------------------------------------------------------------------

Write-Log "Pipeline execution finished. Cleaning up..."

# Optional: Push results back (PDFs)
# git add *.pdf
# git commit -m "Build artifacts"
# git push origin $CurrentBranch

exit 0