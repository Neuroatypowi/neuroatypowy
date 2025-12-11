<# 
.SYNOPSIS
    POLONISTA + localwriter - Skrypt instalacyjny dla Windows
    
.DESCRIPTION
    Automatycznie instaluje rozszerzenie POLONISTA w LibreOffice Writer.
    Kopiuje pliki do prawidlowego katalogu i tworzy szablon .env.
    
.NOTES
    Autor: Stowarzyszenie Zwykle "Neuroatypowi"
    Strona: https://neuroatypowi.org
    Wersja: 2.1
    
.EXAMPLE
    .\install_polonista.ps1
    
.EXAMPLE
    .\install_polonista.ps1 -SourcePath "C:\Downloads\localwriter"
#>

param(
    [string]$SourcePath = $PSScriptRoot,
    [switch]$Force
)

# Konfiguracja
$ErrorActionPreference = "Stop"
$TargetBase = "$env:APPDATA\LibreOffice\4\user\Scripts\python"
$TargetPath = "$TargetBase\localwriter"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  POLONISTA + localwriter - Instalacja" -ForegroundColor Cyan
Write-Host "  Stowarzyszenie Zwykle Neuroatypowi" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Krok 1: Sprawdz czy LibreOffice jest zainstalowany
Write-Host "[1/5] Sprawdzanie LibreOffice..." -ForegroundColor Yellow

if (-not (Test-Path "$env:APPDATA\LibreOffice")) {
    Write-Host "[BLAD] LibreOffice nie jest zainstalowany!" -ForegroundColor Red
    Write-Host "       Pobierz z: https://www.libreoffice.org" -ForegroundColor White
    exit 1
}
Write-Host "      LibreOffice znaleziony" -ForegroundColor Green

# Krok 2: Utworz katalog docelowy
Write-Host "[2/5] Tworzenie katalogu docelowego..." -ForegroundColor Yellow

if (-not (Test-Path $TargetBase)) {
    New-Item -ItemType Directory -Path $TargetBase -Force | Out-Null
    Write-Host "      Utworzono: $TargetBase" -ForegroundColor Green
}

if (Test-Path $TargetPath) {
    if ($Force) {
        Write-Host "      Usuwam istniejacy katalog (Force)..." -ForegroundColor Yellow
        Remove-Item -Path $TargetPath -Recurse -Force
    } else {
        Write-Host "[UWAGA] Katalog juz istnieje: $TargetPath" -ForegroundColor Yellow
        $response = Read-Host "         Nadpisac? (T/N)"
        if ($response -ne "T" -and $response -ne "t") {
            Write-Host "         Instalacja przerwana." -ForegroundColor Yellow
            exit 0
        }
        Remove-Item -Path $TargetPath -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetPath\backends" -Force | Out-Null
Write-Host "      Katalog: $TargetPath" -ForegroundColor Green

# Krok 3: Kopiuj pliki
Write-Host "[3/5] Kopiowanie plikow..." -ForegroundColor Yellow

$filesToCopy = @(
    @{Name="__init__.py"; Dest=$TargetPath},
    @{Name="localwriter.py"; Dest=$TargetPath},
    @{Name="polonista_menu.py"; Dest=$TargetPath},
    @{Name=".env.example"; Dest=$TargetPath},
    @{Name=".gitignore"; Dest=$TargetPath},
    @{Name="README.md"; Dest=$TargetPath},
    @{Name="backends\__init__.py"; Dest="$TargetPath\backends"},
    @{Name="backends\nvidia_nim_backend.py"; Dest="$TargetPath\backends"}
)

$copied = 0
foreach ($file in $filesToCopy) {
    $sourcefile = Join-Path $SourcePath $file.Name
    if (Test-Path $sourcefile) {
        $destFile = Join-Path $file.Dest (Split-Path $file.Name -Leaf)
        Copy-Item -Path $sourcefile -Destination $destFile -Force
        $copied++
        Write-Host "      + $($file.Name)" -ForegroundColor Gray
    } else {
        Write-Host "      - $($file.Name) (brak)" -ForegroundColor DarkGray
    }
}
Write-Host "      Skopiowano: $copied plikow" -ForegroundColor Green

# Krok 4: Utworz plik .env
Write-Host "[4/5] Konfiguracja .env..." -ForegroundColor Yellow

$envPath = "$TargetPath\.env"
$envExamplePath = "$TargetPath\.env.example"

if (-not (Test-Path $envPath)) {
    if (Test-Path $envExamplePath) {
        Copy-Item -Path $envExamplePath -Destination $envPath
        Write-Host "      Utworzono .env z szablonu" -ForegroundColor Green
    } else {
        # Utworz podstawowy .env
        $envContent = @"
# POLONISTA - Konfiguracja API
# Wklej swoj klucz API ponizej:
NVIDIA_API_KEY=nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ
"@
        Set-Content -Path $envPath -Value $envContent -Encoding UTF8
        Write-Host "      Utworzono nowy .env" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "      [WAZNE] Edytuj plik .env i wklej klucz API!" -ForegroundColor Yellow
    Write-Host "      Sciezka: $envPath" -ForegroundColor White
} else {
    Write-Host "      Plik .env juz istnieje" -ForegroundColor Green
}

# Krok 5: Instrukcje koncowe
Write-Host "[5/5] Instalacja zakonczona!" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  INSTALACJA ZAKONCZONA POMYSLNIE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "NASTEPNE KROKI:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Pobierz klucz API NVIDIA:" -ForegroundColor White
Write-Host "   https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Edytuj plik .env:" -ForegroundColor White
Write-Host "   $envPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Wklej klucz w linii:" -ForegroundColor White
Write-Host "   NVIDIA_API_KEY=nvapi-twoj-klucz-tutaj" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Uruchom ponownie LibreOffice Writer" -ForegroundColor White
Write-Host ""
Write-Host "5. Uzycie: Narzedzia > Makra > Uruchom makro" -ForegroundColor White
Write-Host "   > Moje makra > localwriter > polonista_menu" -ForegroundColor Cyan
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

# Opcjonalnie otworz katalog
$openFolder = Read-Host "Otworzyc katalog instalacji? (T/N)"
if ($openFolder -eq "T" -or $openFolder -eq "t") {
    Start-Process explorer.exe -ArgumentList $TargetPath
}
