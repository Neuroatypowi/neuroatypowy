<#
.SYNOPSIS
    Installs and verifies Python libraries required for LibreOffice PyUNO document
    falsification on Windows using Windows PowerShell 5.1.

.DESCRIPTION
    File name: installation_script_pyuno_powershell.ps1
    Target environment: Windows PowerShell 5.1 + LibreOffice 26.8 embedded Python (64-bit).

    Safeguards built into this script:
      1. Compatible with both saved .ps1 execution and direct paste into an interactive
         PowerShell 5.1 console (no #Requires directive; single-line "} else {" and "} finally {").
      2. Clears PYTHONHOME and PYTHONPATH in the current session to prevent collisions
         with any system-wide Python installation.
      3. Passes "--only-binary" and ":all:" as two separate arguments to avoid the
         Windows PowerShell 5.1 native-command colon-splatting bug ("no such option: -o").
      4. Temporarily switches $ErrorActionPreference to "Continue" around native python.exe
         invocations so benign pip stderr notices do not terminate execution prematurely,
         while still strictly enforcing non-zero exit codes via $LASTEXITCODE.
      5. Installs num2words==0.5.14 with --no-deps and binary wheels only to bypass the
         docopt .tar.gz source build (WinError 5 under LibreOffice Python).
      6. Installs pl_core_news_md directly from its .whl URL to bypass "spacy download"
         (WinError 5 on sys.executable).
      7. Imports third-party packages (including spaCy/tqdm) BEFORE importing uno so
         LibreOffice's uno._uno_import hook cannot turn optional ModuleNotFoundError
         imports (such as tqdm -> envwrap) into unhandled ImportError crashes.
      8. Uses pure 7-bit ASCII characters throughout to avoid PowerShell 5.1 BOM issues.

.EXAMPLE
    Save as installation_script_pyuno_powershell.ps1 and run:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installation_script_pyuno_powershell.ps1"
#>

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "Windows PowerShell 5.1 or newer is required."
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure TLS 1.2 is enabled for bootstrap.pypa.io and github.com in Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = (
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
)

# Clear environment variables that can conflict with LibreOffice's embedded Python runtime
Remove-Item -Path Env:PYTHONHOME -ErrorAction SilentlyContinue
Remove-Item -Path Env:PYTHONPATH -ErrorAction SilentlyContinue

# Locate the LibreOffice embedded Python launcher
$CandidatePaths = @(
    "C:\Program Files\LibreOffice\program\python.exe",
    "C:\Program Files (x86)\LibreOffice\program\python.exe"
)

$LoPy = $null
foreach ($PathOption in $CandidatePaths) {
    if (Test-Path -LiteralPath $PathOption -PathType Leaf) {
        $LoPy = $PathOption
        break
    }
}

if (-not $LoPy) {
    throw "LibreOffice embedded python.exe was not found in standard Program Files directories."
}

function Invoke-LoPy {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $global:LASTEXITCODE = 0
    try {
        & $LoPy @Arguments
        $ExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousEap
    }

    if ($ExitCode -ne 0) {
        $JoinedArgs = $Arguments -join " "
        throw ("LibreOffice Python command failed (ExitCode={0}): `"{1}`" {2}" -f $ExitCode, $LoPy, $JoinedArgs)
    }
}

Write-Host ("[0/4] Using LibreOffice Python launcher: {0}" -f $LoPy) -ForegroundColor Cyan
Invoke-LoPy -Arguments @("--version")

# Step 1: Verify pip availability and bootstrap via get-pip.py if missing
Write-Host "[1/4] Checking and bootstrapping pip in user site-packages..." -ForegroundColor Cyan

$PreviousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$global:LASTEXITCODE = 0
try {
    & $LoPy -m pip --version 2>&1 | Out-Null
    $PipCheckCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $PreviousEap
}

if ($PipCheckCode -ne 0) {
    $GetPipPath = Join-Path -Path $env:TEMP -ChildPath "lo_get_pip.py"
    $PreviousProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $GetPipPath -UseBasicParsing
        Invoke-LoPy -Arguments @(
            $GetPipPath,
            "--user",
            "--no-warn-script-location"
        )
    } finally {
        $ProgressPreference = $PreviousProgress
        Remove-Item -LiteralPath $GetPipPath -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "      pip is already available." -ForegroundColor DarkGray
}

# Step 2: Install core prebuilt binary wheels (compatible with Python 3.12 and 3.13 win_amd64)
Write-Host "[2/4] Installing core packages from prebuilt binary wheels (.whl)..." -ForegroundColor Cyan

$CorePackages = @(
    "pymupdf",
    "fonttools",
    "spacy~=3.8.7",
    "holidays",
    "python-dateutil",
    "python-stdnum",
    "pyphen",
    "beautifulsoup4",
    "pillow"
)

$CoreInstallArgs = @(
    "-m", "pip", "install",
    "--user",
    "--upgrade",
    "--only-binary", ":all:",
    "--no-warn-script-location",
    "--disable-pip-version-check"
) + $CorePackages

Invoke-LoPy -Arguments $CoreInstallArgs

# Step 3: Install packages requiring special dependency handling on LibreOffice Windows Python
Write-Host "[3/4] Installing num2words (--no-deps) and Polish spaCy model wheel..." -ForegroundColor Cyan

$Num2WordsArgs = @(
    "-m", "pip", "install",
    "--user",
    "--upgrade",
    "--no-deps",
    "--only-binary", ":all:",
    "--no-warn-script-location",
    "--disable-pip-version-check",
    "num2words==0.5.14"
)
Invoke-LoPy -Arguments $Num2WordsArgs

$SpacyModelUrl = "https://github.com/explosion/spacy-models/releases/download/pl_core_news_md-3.8.0/pl_core_news_md-3.8.0-py3-none-any.whl"
$SpacyModelArgs = @(
    "-m", "pip", "install",
    "--user",
    "--upgrade",
    "--only-binary", ":all:",
    "--no-warn-script-location",
    "--disable-pip-version-check",
    $SpacyModelUrl
)
Invoke-LoPy -Arguments $SpacyModelArgs

# Step 4: Run end-to-end verification script inside LibreOffice's embedded Python
Write-Host "[4/4] Running end-to-end PyUNO and library verification..." -ForegroundColor Cyan

$TestScript = Join-Path -Path $env:TEMP -ChildPath "verify_pyuno_env.py"

$VerifyCode = @'
import builtins
import importlib.metadata
import site
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# IMPORTANT: Import third-party libraries BEFORE importing uno.
# LibreOffice's uno._uno_import converts ModuleNotFoundError into plain ImportError,
# which breaks optional fallback imports inside tqdm (from envwrap import envwrap).
# If running inside a LibreOffice Writer macro where uno is already loaded,
# temporarily restore uno._builtin_import around third-party imports.
import pymupdf
import fontTools
import spacy
import holidays
import dateutil
from stdnum.pl import pesel, nip, regon
from num2words import num2words
import pyphen
import bs4
import PIL

import uno

# Functional checks for Polish NLP, holidays, hyphenation, numbers, and identifiers
nlp = spacy.load("pl_core_news_md")
doc = nlp("Wykonano ocen\u0119 dokumentu.")
pl_hol = holidays.Poland(years=2026)
dic = pyphen.Pyphen(lang="pl_PL")

pesel_ok = pesel.is_valid("44051401359")
if not pesel_ok:
    raise RuntimeError("PESEL verification test failed unexpectedly.")

currency_pl = num2words(1234.56, to="currency", lang="pl", currency="PLN")
ordinal_pl = num2words(21, to="ordinal", lang="pl")
hyphen_pl = dic.inserted("odpowiedzialno\u015b\u0107")

print("--- PYUNO ENVIRONMENT VERIFICATION REPORT ---")
print("PYTHON_VERSION :", sys.version.split()[0])
print("PREFIX_PATH    :", sys.prefix)
print("USER_SITE      :", site.getusersitepackages())
print("UNO_FILE       :", getattr(uno, "__file__", "built-in"))
print("UNO_HOOK_SAFE  :", builtins.__import__ is uno._uno_import)
print("PYMUPDF_VER    :", importlib.metadata.version("PyMuPDF"))
print("FONTTOOLS_VER  :", importlib.metadata.version("fonttools"))
print("SPACY_VER      :", importlib.metadata.version("spacy"))
print("SPACY_MODEL    :", nlp.meta.get("name"), nlp.meta.get("version"))
print("SPACY_MORPH    :", doc[0].text, "->", str(doc[0].morph))
print("HOLIDAYS_2026  :", len(pl_hol), "Polish public holidays")
print("DATEUTIL_VER   :", importlib.metadata.version("python-dateutil"))
print("NUM2WORDS_VER  :", importlib.metadata.version("num2words"))
print("PLN_TEST       :", currency_pl)
print("ORDINAL_TEST   :", ordinal_pl)
print("SYLLABLES_TEST :", hyphen_pl)
print("PESEL_TEST     :", pesel_ok, "| NIP/REGON modules loaded:", bool(nip and regon))
print("BS4_VER        :", bs4.__version__)
print("PILLOW_VER     :", PIL.__version__)
print("ENVIRONMENT_READY")
'@

Set-Content -LiteralPath $TestScript -Value $VerifyCode -Encoding ASCII

try {
    Invoke-LoPy -Arguments @($TestScript)
    Write-Host ""
    Write-Host ">>> DEPLOYMENT AND VERIFICATION SUCCEEDED: ENVIRONMENT READY <<<" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $TestScript -Force -ErrorAction SilentlyContinue
}