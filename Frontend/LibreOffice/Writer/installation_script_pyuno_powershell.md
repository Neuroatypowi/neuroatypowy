# ==============================================================================
# Skrypt instalacyjno-konfiguracyjny pyUNO dla LibreOffice 26.8 (Python 3.13.18)
# Data i czas generowania: 2026-11-23 23:09:00 CET
# Wymagania: Windows PowerShell 5.1 (Uruchom jako Administrator)
# ==============================================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LoPy = "C:\Program Files\LibreOffice\program\python.exe"

function Invoke-LoPy {
    param([string[]]$Arguments)
    & $LoPy @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Błąd wykonania polecenia: $LoPy $($Arguments -join ' ') (ExitCode: $LASTEXITCODE)"
    }
}

# 0. Weryfikacja sciezki interpretera pyUNO
if (-not (Test-Path $LoPy)) {
    throw "Nie znaleziono interpretera pyUNO pod sciezka: $LoPy"
}

Write-Host "[1/4] Sprawdzanie i instalacja pip..." -ForegroundColor Cyan
& $LoPy -m pip --version *> $null
if ($LASTEXITCODE -ne 0) {
    $getPipPath = Join-Path $env:TEMP "get-pip.py"
    Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipPath
    Invoke-LoPy @($getPipPath, "--user", "--no-warn-script-location")
}

Write-Host "[2/4] Instalacja glownych pakietów z gotowych kol binarnych (.whl)..." -ForegroundColor Cyan
$Packages = @(
    "pymupdf",
    "fonttools",
    "spacy",
    "holidays",
    "python-dateutil",
    "python-stdnum",
    "pyphen",
    "beautifulsoup4",
    "pillow"
)
Invoke-LoPy (@("-m", "pip", "install", "--user", "--only-binary=:all:", "--no-warn-script-location") + $Packages)

Write-Host "[3/4] Instalacja pakietow ze specjalna obsługa dependencies..." -ForegroundColor Cyan
# num2words 0.5.14 instalowany bez docopt (--no-deps) celem unikniecia WinError 5 podczas kompilacji .tar.gz
Invoke-LoPy @("-m", "pip", "install", "--user", "--upgrade", "--no-deps", "--only-binary=:all:", "--no-warn-script-location", "num2words==0.5.14")

# Model SpaCy z pliku .whl z pominięciem "spacy download" (omija WinError 5 sys.executable)
$ModelUrl = "https://github.com/explosion/spacy-models/releases/download/pl_core_news_md-3.8.0/pl_core_news_md-3.8.0-py3-none-any.whl"
Invoke-LoPy @("-m", "pip", "install", "--user", "--no-warn-script-location", $ModelUrl)

Write-Host "[4/4] Wykonywanie zbiorczego testu weryfikacyjnego..." -ForegroundColor Cyan
$TestScript = Join-Path $env:TEMP "verify_pyuno_env.py"
@'
import sys
import importlib.metadata
import pymupdf, fontTools, spacy, holidays, dateutil
from stdnum.pl import pesel, nip, regon
from num2words import num2words
import pyphen, bs4, PIL
import uno

# Test SpaCy
nlp = spacy.load("pl_core_news_md")
# Test Swiat PL 2026
pl_hol = holidays.Poland(years=2026)
# Test Sylabizowania ETR
dic = pyphen.Pyphen(lang="pl_PL")

print("--- RAPORT STANUSRODOWISKA pyUNO ---")
print("PYTHON_VERSION:", sys.version.split()[0])
print("PREFIX_PATH:   ", sys.prefix)
print("UNO_FILE:      ", uno.__file__)
print("SPACY_MODEL:   ", nlp.meta["name"], nlp.meta["version"])
print("HOLIDAYS_2026: ", len(pl_hol), "dni wolnych")
print("NUM2WORDS_VER: ", importlib.metadata.version('num2words'))
print("PLN_TEST:      ", num2words(1234.56, to='currency', lang='pl', currency='PLN'))
print("ORDINAL_TEST:  ", num2words(21, to='ordinal', lang='pl'))
print("SYLLABLES_TEST:", dic.inserted("odpowiedzialnosc"))
print("PESEL_TEST:    ", pesel.is_valid("44051401358"))
print("SRODOWISKO_GOTOWE")
'@ | Set-Content -Path $TestScript -Encoding ASCII

try {
    Invoke-LoPy @($TestScript)
    Write-Host "`n>>> WDROZENIE I FALSYFIKACJA ZAKONCZONE SUKCESEM: RAPORT OK <<<" -ForegroundColor Green
} finally {
    Remove-Item -Path $TestScript -Force -ErrorAction SilentlyContinue
}