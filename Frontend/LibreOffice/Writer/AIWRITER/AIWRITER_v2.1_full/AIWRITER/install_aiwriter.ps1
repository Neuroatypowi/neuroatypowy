<#
.SYNOPSIS
    AIWRITER - Skrypt instalacyjny dla Windows

.DESCRIPTION
    Automatycznie instaluje rozszerzenie AIWRITER w LibreOffice Writer.
    
.NOTES
    Wymagania:
    - Windows 10/11 x64
    - LibreOffice 24.x lub 25.x (x64)
    - PowerShell 5.1+
    - Prawa administratora
    
    Autor: Stowarzyszenie Zwykle "Neuroatypowi"
    Strona: https://neuroatypowi.org
    
.EXAMPLE
    .\install_aiwriter.ps1
    
.EXAMPLE
    .\install_aiwriter.ps1 -Force
#>

param(
    [string]$SourcePath = $PSScriptRoot,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Konfiguracja
$ProjectName = "AIWRITER"
$Version = "2.1"
$TargetBase = "$env:APPDATA\LibreOffice\4\user\Scripts\python"
$TargetPath = "$TargetBase\$ProjectName"

# Kolory
function Write-Step { param($msg) Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $msg" -ForegroundColor Yellow }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err { param($msg) Write-Host "  [BLAD] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  $msg" -ForegroundColor Gray }

# =============================================================================
# NAGLOWEK
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  $ProjectName v$Version - Instalator dla Windows" -ForegroundColor Cyan
Write-Host "  Stowarzyszenie Zwykle Neuroatypowi" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# KROK 1: Sprawdz prawa administratora
# =============================================================================
Write-Step "Sprawdzanie uprawnien..."

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[UWAGA] Uruchom skrypt jako Administrator!" -ForegroundColor Yellow
    Write-Host "        Kliknij PPM na plik > Uruchom jako administrator" -ForegroundColor White
    Write-Host ""
    # Kontynuuj mimo to - czesc operacji moze sie udac
}
Write-OK "Uprawnienia: $(if($isAdmin){'Administrator'}else{'Uzytkownik'})"

# =============================================================================
# KROK 2: Sprawdz LibreOffice
# =============================================================================
Write-Step "Sprawdzanie LibreOffice..."

$loPath = "$env:APPDATA\LibreOffice"
if (-not (Test-Path $loPath)) {
    Write-Err "LibreOffice nie jest zainstalowany!"
    Write-Host ""
    Write-Host "  Pobierz z: https://www.libreoffice.org/download/download/" -ForegroundColor Cyan
    Write-Host "  Wymagana wersja: 24.x lub 25.x (x64)" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-OK "LibreOffice znaleziony: $loPath"

# =============================================================================
# KROK 3: Utworz katalogi
# =============================================================================
Write-Step "Tworzenie katalogow..."

# Katalog python Scripts
if (-not (Test-Path $TargetBase)) {
    New-Item -ItemType Directory -Path $TargetBase -Force | Out-Null
    Write-Info "Utworzono: $TargetBase"
}

# Katalog AIWRITER
if (Test-Path $TargetPath) {
    if ($Force) {
        Remove-Item -Path $TargetPath -Recurse -Force
        Write-Info "Usunieto istniejacy katalog (Force)"
    } else {
        Write-Host ""
        $response = Read-Host "  Katalog $ProjectName juz istnieje. Nadpisac? (T/N)"
        if ($response -ne "T" -and $response -ne "t") {
            Write-Host "  Instalacja przerwana." -ForegroundColor Yellow
            exit 0
        }
        Remove-Item -Path $TargetPath -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetPath\backends" -Force | Out-Null
Write-OK "Katalog: $TargetPath"

# =============================================================================
# KROK 4: Kopiuj pliki
# =============================================================================
Write-Step "Kopiowanie plikow..."

$files = @(
    @{Src="__init__.py"; Dst=$TargetPath},
    @{Src="polonista_menu.py"; Dst=$TargetPath},
    @{Src=".env.example"; Dst=$TargetPath},
    @{Src=".gitignore"; Dst=$TargetPath},
    @{Src="backends\__init__.py"; Dst="$TargetPath\backends"},
    @{Src="backends\nvidia_nim_backend.py"; Dst="$TargetPath\backends"}
)

$copied = 0
foreach ($file in $files) {
    $srcFile = Join-Path $SourcePath $file.Src
    if (Test-Path $srcFile) {
        $dstFile = Join-Path $file.Dst (Split-Path $file.Src -Leaf)
        Copy-Item -Path $srcFile -Destination $dstFile -Force
        $copied++
        Write-Info "+ $($file.Src)"
    } else {
        Write-Info "- $($file.Src) (brak)"
    }
}
Write-OK "Skopiowano: $copied plikow"

# =============================================================================
# KROK 5: Utworz .env
# =============================================================================
Write-Step "Konfiguracja .env..."

$envPath = "$TargetPath\.env"
$envExamplePath = "$TargetPath\.env.example"

if (-not (Test-Path $envPath)) {
    if (Test-Path $envExamplePath) {
        Copy-Item -Path $envExamplePath -Destination $envPath
        Write-OK "Utworzono .env z szablonu"
    } else {
        $envContent = @"
# AIWRITER - Konfiguracja
NVIDIA_API_KEY=nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ
"@
        Set-Content -Path $envPath -Value $envContent -Encoding UTF8
        Write-OK "Utworzono nowy .env"
    }
    
    Write-Host ""
    Write-Host "  [WAZNE] Edytuj plik .env i wklej klucz API!" -ForegroundColor Yellow
} else {
    Write-OK "Plik .env juz istnieje"
}

# =============================================================================
# KROK 6: Weryfikacja
# =============================================================================
Write-Step "Weryfikacja instalacji..."

$requiredFiles = @(
    "$TargetPath\__init__.py",
    "$TargetPath\polonista_menu.py",
    "$TargetPath\backends\__init__.py",
    "$TargetPath\backends\nvidia_nim_backend.py"
)

$allOK = $true
foreach ($f in $requiredFiles) {
    if (Test-Path $f) {
        Write-Info "[OK] $(Split-Path $f -Leaf)"
    } else {
        Write-Err "BRAK: $f"
        $allOK = $false
    }
}

# =============================================================================
# PODSUMOWANIE
# =============================================================================
Write-Host ""
if ($allOK) {
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  INSTALACJA ZAKONCZONA POMYSLNIE!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
} else {
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "  INSTALACJA NIEKOMPLETNA - sprawdz bledy powyzej" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "NASTEPNE KROKI:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Pobierz klucz API NVIDIA:" -ForegroundColor White
Write-Host "   https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Edytuj plik .env:" -ForegroundColor White
Write-Host "   $envPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Wklej klucz:" -ForegroundColor White
Write-Host "   NVIDIA_API_KEY=nvapi-twoj-klucz" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Uruchom ponownie LibreOffice Writer" -ForegroundColor White
Write-Host ""
Write-Host "5. Uzycie:" -ForegroundColor White
Write-Host "   Narzedzia > Makra > Uruchom makro" -ForegroundColor Cyan
Write-Host "   > $ProjectName > polonista_menu" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Opcjonalnie otworz katalog
$open = Read-Host "Otworzyc katalog instalacji? (T/N)"
if ($open -eq "T" -or $open -eq "t") {
    Start-Process explorer.exe -ArgumentList $TargetPath
}

# Opcjonalnie otworz .env
$edit = Read-Host "Otworzyc plik .env do edycji? (T/N)"
if ($edit -eq "T" -or $edit -eq "t") {
    notepad.exe $envPath
}
