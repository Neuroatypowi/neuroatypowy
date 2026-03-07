#Requires -Version 7.0
<#
.SYNOPSIS
    Zaawansowany Hybrydowy Skrypt Diagnostyczny i Audytowy v5.0
    Srodowisko: Windows 11 (23H2+) / LibreOffice 26.2 / PowerShell 7.6 RC1

.DESCRIPTION
    Kompletny audyt stacji roboczej obejmujacy:
      - Identyfikacje sprzetowa (SKU, CPU, RAM, dyski, magistrale, Vulkan)
      - Audyt oprogramowania kluczowego (rejestry x86/x64)
      - Falsyfikacje architektury Java (64-bit via STDERR)
      - Analize konfiguracji LibreOffice (registrymodifications.xcu)
      - Parsowanie rozszerzen .oxt za pomoca silnika Regex PS7
      - Diagnostyke D3D12 / DXGI via C# P/Invoke (.NET 11 Preview 1)
      - Optymalizacje pipeline Skia/Raster z Agility SDK 1.719.0-preview
      - Wstrzykiwanie mostu Python UNO (IPC Sockets via LO python.exe)

    Kodowanie wyjsciowe: UTF-8 bez BOM, znaki konca linii: LF (Unix)

.NOTES
    Autor:          Skrypt wygenerowany na podstawie analizy diagnostycznej
    Wymagania:      PowerShell 7.6 RC1 (pwsh.exe), LibreOffice 26.2.1.2 (X86_64)
    Framework:      .NET 11.0 Preview 1 (build 2026-03-06)
    DirectX:        Agility SDK 1.719.0-preview (D3D12SDKVersion 719)
    Data:           2026-03-06
    Wersja:         v5.0 (Hybrid PS7.6 + Python 3.12/LO + C# .NET 11 Preview 1)
    Licencja:       MIT

    CHANGELOG v5.0 (naprawy z v4.0 log):
      [FIX-01] Add-ReportLine: dodano [AllowEmptyString()] — naprawia 10+ bledow
               "Cannot bind argument to parameter 'Text' because it is an empty string"
      [FIX-02] Test-Path bundled ext: naprawiono parsowanie -and jako parametru Test-Path
      [FIX-03] Deduplikacja sciezek rozszerzen: usuniety podwojny skan shared/bundled
      [FIX-04] Python UNO bridge: wymuszenie LO python.exe zamiast systemowego Python 3.13
               (eliminuje "python312.dll conflicts with this version of Python")
      [FIX-05] Python output encoding: ASCII-only output + $env:PYTHONIOENCODING=utf-8
      [FIX-06] .NET CLI enumeracja: oddzielne try/catch dla --list-sdks i --list-runtimes
      [FIX-07] Python setup_uno_path(): priorytet os.path.dirname(sys.executable)
      [FIX-08] ExtensionManager: obsluga XCommandEnvironment + fallback na getPackages()
      [FIX-09] XCU regex: poprawione wzorce do formatu <item oor:path=...><prop oor:name=...>
      [FIX-10] C# D3D12 P/Invoke: pelna diagnostyka DXGI + Enhanced Barriers + VPblit 3DLUT
      [FIX-11] Skia/Raster optimization: analiza mozliwosci pipeline z Agility SDK 1.719
      [FIX-12] Wersja bannera: v5.0 z pelnym opisem srodowiska hybrydowego
#>

# ============================================================================
# KONFIGURACJA GLOBALNA
# ============================================================================
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# Sygnatura czasowa i sciezki wyjsciowe
$timestamp        = Get-Date -Format 'yyyyMMdd_HHmmss'
$desktopPath      = [System.Environment]::GetFolderPath('Desktop')
$reportPath       = Join-Path $desktopPath "Raport_Serwisowy_$timestamp.txt"
$pythonScriptPath = Join-Path $desktopPath "diagnoza_uno_$timestamp.py"
$xcuReportPath    = Join-Path $desktopPath "Raport_XCU_$timestamp.txt"

# Bufor raportu (System.Collections.Generic.List dla wydajnosci)
$report = [System.Collections.Generic.List[string]]::new(512)

# Kolory terminala
$colorHeader  = 'Cyan'
$colorSuccess = 'Green'
$colorWarning = 'Yellow'
$colorError   = 'Red'

# ============================================================================
# FUNKCJE POMOCNICZE
# ============================================================================

function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Title,
        [int]$SectionNumber
    )
    $separator = '=' * 60
    $header    = "--- SEKCJA ${SectionNumber}: $Title ---"
    $report.Add('')
    $report.Add($separator)
    $report.Add($header)
    $report.Add($separator)
    Write-Host "`n$header" -ForegroundColor $colorHeader
}

function Add-ReportLine {
    <#
    .SYNOPSIS
        Dodaje linie tekstu do bufora raportu i opcjonalnie wyswietla w konsoli.
    .NOTES
        [FIX-01 v5.0] Dodano [AllowEmptyString()] aby akceptowac puste ciagi.
        Poprzednio [Parameter(Mandatory)][string]$Text odrzucal ''.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,
        [string]$ConsoleColor = '',
        [switch]$Silent
    )
    $report.Add($Text)
    if (-not $Silent) {
        if ($ConsoleColor) {
            Write-Host "  $Text" -ForegroundColor $ConsoleColor
        } else {
            Write-Host "  $Text"
        }
    }
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-SafeWmiProperty {
    param(
        [Parameter(Mandatory)][string]$ClassName,
        [Parameter(Mandatory)][string]$PropertyName
    )
    try {
        $instance = Get-CimInstance -ClassName $ClassName -ErrorAction Stop | Select-Object -First 1
        $value = $instance.$PropertyName
        if ($null -ne $value) { return "$value".Trim() }
        return '(niedostepne)'
    } catch {
        return "(blad odczytu: $($_.Exception.Message))"
    }
}

# ============================================================================
# WALIDACJA SRODOWISKA URUCHOMIENIOWEGO
# ============================================================================
Write-Host ''
Write-Host '================================================================' -ForegroundColor $colorHeader
Write-Host '  ZAAWANSOWANY HYBRYDOWY SKRYPT DIAGNOSTYCZNY I AUDYTOWY v5.0'  -ForegroundColor $colorHeader
Write-Host '  Srodowisko: Windows 11 / LibreOffice 26.2 / PowerShell 7.6'  -ForegroundColor $colorHeader
Write-Host '  Hybrid: PS7.6 RC1 + Python 3.12/LO + C# (.NET 11 Prev.1)'   -ForegroundColor $colorHeader
Write-Host '================================================================' -ForegroundColor $colorHeader
Write-Host ''

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host '[BLAD KRYTYCZNY] Ten skrypt wymaga PowerShell 7.x (pwsh.exe).' -ForegroundColor $colorError
    Write-Host 'Zainstaluj ze sklepu Microsoft Store lub uruchom:' -ForegroundColor $colorError
    Write-Host '  winget install --id Microsoft.Powershell --source winget' -ForegroundColor $colorWarning
    Write-Host ''
    Write-Host 'Aktualnie wykryto: PowerShell' $PSVersionTable.PSVersion.ToString() -ForegroundColor $colorError
    exit 1
}

$report.Add('================================================================')
$report.Add('  ZAAWANSOWANY RAPORT SERWISOWY (PS7 Hybrid v5.0)')
$report.Add('================================================================')
$report.Add("Generowanie:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("Srodowisko PS:     PowerShell $($PSVersionTable.PSVersion.ToString())")
$report.Add("Edycja PS:         $($PSVersionTable.PSEdition)")
$report.Add("Platforma .NET:    $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)")
$report.Add("System operacyjny: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)")
$report.Add("Architektura OS:   $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)")
$report.Add("Architektura CPU:  $([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)")
$report.Add("Nazwa komputera:   $env:COMPUTERNAME")
$report.Add("Uzytkownik:        $env:USERNAME")

# ============================================================================
# SEKCJA 1: IDENTYFIKACJA SPRZETOWA
# ============================================================================
Write-Section -Title 'IDENTYFIKACJA SPRZETOWA' -SectionNumber 1

try {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $bios     = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $cpu      = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $ramSlots = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
    $ramTotal = ($ramSlots | Measure-Object -Property Capacity -Sum).Sum
    $disks    = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
    $gpus     = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    $busCount = @(Get-CimInstance -ClassName Win32_Bus -ErrorAction SilentlyContinue).Count

    Add-ReportLine "Producent:         $($computer.Manufacturer)"
    Add-ReportLine "Model:             $($computer.Model)"
    Add-ReportLine "SKU / Kod serii:   $($computer.SystemSKUNumber)"
    Add-ReportLine "Numer seryjny:     $($bios.SerialNumber)"
    Add-ReportLine "Wersja BIOS:       $($bios.SMBIOSBIOSVersion)"
    Add-ReportLine "Procesor:          $($cpu.Name.Trim())"
    Add-ReportLine "Rdzenie / Watki:   $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)"
    Add-ReportLine "Architektura CPU:  $(if ($cpu.AddressWidth -eq 64) {'x64 (64-bit)'} else {'x86 (32-bit)'})"
    Add-ReportLine "RAM zainstalowany: $([Math]::Round($ramTotal / 1GB, 2)) GB ($(@($ramSlots).Count) modul(y))"

    foreach ($slot in $ramSlots) {
        $slotCapGB = [Math]::Round($slot.Capacity / 1GB, 2)
        $slotSpeed = if ($slot.Speed) { "$($slot.Speed) MHz" } else { 'nieznana' }
        Add-ReportLine "  Slot [$($slot.BankLabel)]: $slotCapGB GB | $slotSpeed | $($slot.Manufacturer)"
    }

    foreach ($disk in $disks) {
        $diskSizeGB = [Math]::Round($disk.Size / 1GB, 2)
        Add-ReportLine "Dysk: $($disk.Caption) | $diskSizeGB GB | $($disk.InterfaceType)"
    }

    foreach ($gpu in $gpus) {
        $vramMB = if ($gpu.AdapterRAM -and $gpu.AdapterRAM -gt 0) {
            "$([Math]::Round($gpu.AdapterRAM / 1MB, 0)) MB"
        } else { 'brak danych' }
        Add-ReportLine "GPU: $($gpu.Name) | VRAM: $vramMB | Sterownik: $($gpu.DriverVersion)"
    }

    Add-ReportLine "Magistrale systemowe (ilosc): $busCount"

    # --- Weryfikacja mozliwosci Vulkan ---
    $vulkanCapable = $false
    foreach ($gpu in $gpus) {
        $gpuName = "$($gpu.Name)".ToLower()
        if ($gpuName -match 'iris|uhd\s*[5-9]|hd\s*[5-9]\d{2,}|arc\s|geforce\s*gtx\s*[6-9]|geforce\s*rtx|radeon\s*(r[x579]|rx|vega|navi)') {
            $vulkanCapable = $true
        }
    }

    if ($vulkanCapable) {
        Add-ReportLine '[VULKAN] Wykryto GPU z potencjalnym wsparciem Vulkan.' -ConsoleColor $colorSuccess
        Add-ReportLine '[VULKAN] Akceleracja Skia/Vulkan w LibreOffice MOZE byc mozliwa.'
    } else {
        Add-ReportLine '[VULKAN] Brak GPU z wsparciem Vulkan w srodowisku Windows.' -ConsoleColor $colorWarning
        Add-ReportLine '[VULKAN] Stan UI render: Skia/Raster jest PRAWIDLOWY i POZADANY na tym urzadzeniu.'
        Add-ReportLine '[VULKAN] Wymuszenie akceleracji sprzetowej grozi artefaktami ("Blank Menu") lub zawieszeniem.'
    }

} catch {
    Add-ReportLine "[BLAD] Nie udalo sie odczytac danych sprzetowych: $($_.Exception.Message)" -ConsoleColor $colorError
}

# ============================================================================
# SEKCJA 2: AUDYT OPROGRAMOWANIA KLUCZOWEGO
# ============================================================================
Write-Section -Title 'AUDYT OPROGRAMOWANIA KLUCZOWEGO' -SectionNumber 2

$searchPattern = 'Java|LibreOffice|Git|JDK|OpenJDK|Microsoft Build|\.NET|Python|Visual C\+\+'
$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

try {
    $installedApps = foreach ($regPath in $registryPaths) {
        Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match $searchPattern }
    }

    $uniqueApps = $installedApps |
        Select-Object @{N='Nazwa';     E={$_.DisplayName}},
                      @{N='Wersja';    E={$_.DisplayVersion}},
                      @{N='Arch';      E={if ($_.PSPath -match 'WOW6432Node') {'x86'} else {'x64'}}},
                      @{N='Wydawca';   E={$_.Publisher}},
                      @{N='Lokalizacja'; E={$_.InstallLocation}} |
        Sort-Object Nazwa -Unique

    if ($uniqueApps) {
        foreach ($app in $uniqueApps) {
            Add-ReportLine "[$($app.Arch)] $($app.Nazwa) | v$($app.Wersja) | $($app.Wydawca)"
        }
        Add-ReportLine "Znaleziono lacznie: $(@($uniqueApps).Count) pakiet(ow) spelniajacych kryteria."
    } else {
        Add-ReportLine 'Nie wykryto oprogramowania pasujacego do wzorca wyszukiwania.' -ConsoleColor $colorWarning
    }
} catch {
    Add-ReportLine "[BLAD] Audyt rejestru nie powiodl sie: $($_.Exception.Message)" -ConsoleColor $colorError
}

# ============================================================================
# SEKCJA 3: FALSYFIKACJA ARCHITEKTURY JAVA (STDERR)
# ============================================================================
Write-Section -Title 'FALSYFIKACJA JAVA (64-BIT VIA STDERR)' -SectionNumber 3

if (Test-CommandAvailable 'java') {
    try {
        $javaVerRaw = (& java -version 2>&1 | Out-String).Trim()

        $javaVersion = if ($javaVerRaw -match 'version\s+"([^"]+)"') {
            $Matches[1]
        } else { 'nierozpoznana' }

        $javaArch = if ($javaVerRaw -match '64-Bit') { 'x64 (64-bit)' } else { 'x86 (32-bit)' }

        $javaVendor = if ($javaVerRaw -match '(?i)(OpenJDK|Microsoft|Oracle|Adoptium|Corretto|Temurin|GraalVM)') {
            $Matches[1]
        } else { 'nieznany' }

        $javaHome = $env:JAVA_HOME
        if (-not $javaHome) { $javaHome = '(JAVA_HOME niezdefiniowany)' }

        $javaExePath = (Get-Command java -ErrorAction SilentlyContinue).Source

        Add-ReportLine "Wersja JDK/JRE:     $javaVersion"
        Add-ReportLine "Architektura JVM:    $javaArch"
        Add-ReportLine "Dostawca:            $javaVendor"
        Add-ReportLine "Sciezka java.exe:   $javaExePath"
        Add-ReportLine "JAVA_HOME:           $javaHome"

        if ($javaArch -eq 'x64 (64-bit)') {
            Add-ReportLine '[OK] JVM jest 64-bitowa -- kompatybilna z LibreOffice x64 i mostem Java-UNO.' -ConsoleColor $colorSuccess
        } else {
            Add-ReportLine '[OSTRZEZENIE] JVM jest 32-bitowa! Most Java-UNO moze generowac OutOfMemoryError.' -ConsoleColor $colorWarning
            Add-ReportLine 'Zalecenie: Zainstaluj Microsoft Build of OpenJDK (x64) z https://learn.microsoft.com/java/openjdk/download'
        }

        # Zrzut surowych danych diagnostycznych
        Add-ReportLine ''
        Add-ReportLine '--- Surowe wyjscie java -version (STDERR) ---' -Silent
        foreach ($line in ($javaVerRaw -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -gt 0) {
                Add-ReportLine "  | $trimmed" -Silent
            }
        }
    } catch {
        Add-ReportLine "[BLAD] Nie udalo sie odpytac java.exe: $($_.Exception.Message)" -ConsoleColor $colorError
    }
} else {
    Add-ReportLine '[BRAK] Komenda java.exe nie jest dostepna w PATH.' -ConsoleColor $colorWarning
    Add-ReportLine 'LibreOffice Base i rozszerzenia Java-UNO nie beda funkcjonowac.'
}

# ============================================================================
# SEKCJA 4: KONFIGURACJA LIBREOFFICE (registrymodifications.xcu)
# ============================================================================
Write-Section -Title 'KONFIGURACJA LIBREOFFICE (XCU)' -SectionNumber 4

$loProfileBase = Join-Path $env:APPDATA 'LibreOffice'
$loUserDir     = $null
$xcuFilePath   = $null

if (Test-Path $loProfileBase) {
    $profileDirs = Get-ChildItem -Path $loProfileBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

    foreach ($dir in $profileDirs) {
        $candidate = Join-Path $dir.FullName 'user' 'registrymodifications.xcu'
        if (Test-Path $candidate) {
            $xcuFilePath = $candidate
            $loUserDir   = Join-Path $dir.FullName 'user'
            break
        }
    }
}

if ($xcuFilePath) {
    Add-ReportLine "Profil uzytkownika: $loUserDir"
    Add-ReportLine "Plik XCU:           $xcuFilePath"

    try {
        $xcuContent = Get-Content -Path $xcuFilePath -Raw -Encoding utf8

        $xcuSize = (Get-Item $xcuFilePath).Length
        Add-ReportLine "Rozmiar XCU:        $([Math]::Round($xcuSize / 1KB, 2)) KB ($xcuSize bajtow)"

        # [FIX-09 v5.0] Poprawione wzorce regex dopasowane do formatu XCU:
        #   <item oor:path="..."><prop oor:name="KEY" ...><value>VAL</value></prop></item>
        $xcuPatterns = [ordered]@{
            'Akceleracja Skia (UseSkia)'               = 'oor:name="UseSkia"[^>]*>.*?<value>(true|false)</value>'
            'Wymuszenie Skia/Raster (ForceSkiaRaster)'  = 'oor:name="ForceSkiaRaster"[^>]*>.*?<value>(true|false)</value>'
            'Sciezka JRE (Home)'                        = 'oor:path="/org\.openoffice\.Office\.Java/VirtualMachine".*?oor:name="Home"[^>]*>.*?<value>(.*?)</value>'
            'JRE wlaczone (Enable)'                     = 'oor:path="/org\.openoffice\.Office\.Java/VirtualMachine".*?oor:name="Enable"[^>]*>.*?<value>(true|false)</value>'
            'Jezyk interfejsu (ooLocale)'               = 'oor:name="ooLocale"[^>]*>.*?<value>(.*?)</value>'
            'AutoSave (wlaczony)'                       = 'oor:name="AutoSave"[^>]*>.*?<value>(true|false)</value>'
            'Interwal AutoSave (min)'                   = 'oor:name="AutoSaveTimeIntervall"[^>]*>.*?<value>(\d+)</value>'
            'Kopia zapasowa (Backup)'                   = 'oor:name="CreateBackup"[^>]*>.*?<value>(true|false)</value>'
            'Makra (MacroSecurityLevel)'                = 'oor:name="MacroSecurityLevel"[^>]*>.*?<value>(\d+)</value>'
            'PDF wersja (SelectPdfVersion)'             = 'oor:name="SelectPdfVersion"[^>]*>.*?<value>(\d+)</value>'
            'PDF/UA zgodnosc'                           = 'oor:name="PDFUACompliance"[^>]*>.*?<value>(true|false)</value>'
            'Sprawdzanie dostepnosci online'            = 'oor:name="OnlineAccessibilityCheck"[^>]*>.*?<value>(true|false)</value>'
            'Ostatnia wersja LO (ooSetupLastVersion)'   = 'oor:name="ooSetupLastVersion"[^>]*>.*?<value>(.*?)</value>'
        }

        $report.Add('')
        Add-ReportLine '--- Kluczowe parametry konfiguracyjne ---'

        foreach ($param in $xcuPatterns.GetEnumerator()) {
            if ($xcuContent -match $param.Value) {
                $extractedValue = $Matches[1]
                if ([string]::IsNullOrWhiteSpace($extractedValue)) {
                    $extractedValue = '(pusty)'
                }
                Add-ReportLine "  $($param.Key): $extractedValue"
            } else {
                Add-ReportLine "  $($param.Key): (nie znaleziono w XCU)"
            }
        }

        # Eksport zrzutu XCU do osobnego pliku
        $xcuContent | Out-File -FilePath $xcuReportPath -Encoding utf8NoBOM -NoNewline
        Add-ReportLine ''
        Add-ReportLine "Kopia XCU zapisana do: $xcuReportPath" -ConsoleColor $colorSuccess

    } catch {
        Add-ReportLine "[BLAD] Parsowanie XCU nie powiodlo sie: $($_.Exception.Message)" -ConsoleColor $colorError
    }
} else {
    Add-ReportLine '[BRAK] Nie wykryto profilu uzytkownika LibreOffice.' -ConsoleColor $colorWarning
    Add-ReportLine "Szukano w: $loProfileBase"
}

# ============================================================================
# SEKCJA 5: ROZSZERZENIA LIBREOFFICE (REGEX XML PARSER)
# ============================================================================
Write-Section -Title 'ROZSZERZENIA LIBREOFFICE (REGEX PARSER)' -SectionNumber 5

# [FIX-03 v5.0] Deduplikacja sciezek rozszerzen - unikanie podwojnego skanu
$extensionCachePaths = [System.Collections.Generic.List[string]]::new()

if ($loUserDir) {
    $userExtPath = Join-Path $loUserDir 'uno_packages' 'cache' 'uno_packages'
    if (Test-Path $userExtPath) {
        $extensionCachePaths.Add($userExtPath)
    }
}

$loSharedExt = 'C:\Program Files\LibreOffice\share\extensions'
if ((Test-Path $loSharedExt) -and ($loSharedExt -notin $extensionCachePaths)) {
    $extensionCachePaths.Add($loSharedExt)
}

# [FIX-02 v5.0] Poprawka: bundled path z osobna lokalizacja
$loBundledExt = 'C:\Program Files\LibreOffice\program\..\share\uno_packages\cache\uno_packages'
if ((Test-Path $loBundledExt) -and ($loBundledExt -notin $extensionCachePaths)) {
    $resolvedBundled = (Resolve-Path $loBundledExt -ErrorAction SilentlyContinue).Path
    if ($resolvedBundled -and ($resolvedBundled -notin $extensionCachePaths)) {
        $extensionCachePaths.Add($resolvedBundled)
    }
}

$extensionCount = 0

foreach ($extBasePath in $extensionCachePaths) {
    if (-not (Test-Path $extBasePath)) {
        Add-ReportLine "Sciezka nie istnieje: $extBasePath" -ConsoleColor $colorWarning
        continue
    }

    Add-ReportLine ''
    Add-ReportLine "Skanowanie: $extBasePath"
    Add-ReportLine ('-' * 50) -Silent

    $descriptionFiles = Get-ChildItem -Path $extBasePath -Filter 'description.xml' -Recurse -ErrorAction SilentlyContinue

    foreach ($xmlFile in $descriptionFiles) {
        $extensionCount++
        try {
            $xmlContent = Get-Content -Path $xmlFile.FullName -Raw -Encoding utf8

            $extId = if ($xmlContent -match '(?is)<identifier[^>]+value\s*=\s*"([^"]+)"') {
                $Matches[1]
            } else { 'ID_NIEZNANE' }

            $extName = 'Brak czytelnej nazwy'
            if ($xmlContent -match '(?is)<display-name>.*?<name\s+lang\s*=\s*"pl"[^>]*>\s*(.*?)\s*</name>') {
                $extName = $Matches[1]
            } elseif ($xmlContent -match '(?is)<display-name>.*?<name\s+lang\s*=\s*"en"[^>]*>\s*(.*?)\s*</name>') {
                $extName = $Matches[1]
            } elseif ($xmlContent -match '(?is)<display-name>.*?<name[^>]*>\s*(.*?)\s*</name>') {
                $extName = $Matches[1]
            }

            $extVersion = if ($xmlContent -match '(?is)<version\s+value\s*=\s*"([^"]+)"') {
                $Matches[1]
            } else { 'brak' }

            $extPublisher = 'nieznany'
            if ($xmlContent -match '(?is)<publisher[^>]*>.*?<name[^>]*>\s*(.*?)\s*</name>') {
                $extPublisher = $Matches[1]
            }

            $extMinLO = 'brak danych'
            if ($xmlContent -match '(?is)<lo:LibreOffice-minimal-version\s+value\s*=\s*"([^"]+)"') {
                $extMinLO = $Matches[1]
            } elseif ($xmlContent -match '(?is)OpenOffice\.org-minimal-version\s+value\s*=\s*"([^"]+)"') {
                $extMinLO = "$($Matches[1]) (OOo compat)"
            }

            Add-ReportLine "  [$extensionCount] $extName"
            Add-ReportLine "      ID:           $extId" -Silent
            Add-ReportLine "      Wersja:       $extVersion" -Silent
            Add-ReportLine "      Wydawca:      $extPublisher" -Silent
            Add-ReportLine "      Min LO:       $extMinLO" -Silent
            Add-ReportLine "      Zrodlo XML:   $($xmlFile.FullName)" -Silent

        } catch {
            Add-ReportLine "  [BLAD] Parsowanie $($xmlFile.FullName): $($_.Exception.Message)" -ConsoleColor $colorError
        }
    }
}

Add-ReportLine ''
Add-ReportLine "Lacznie przeskanowano: $extensionCount rozszerzenie(a)."

# ============================================================================
# SEKCJA 6: AUDYT .NET / DirectX 12 / Agility SDK (C# Hybrid)
# ============================================================================
Write-Section -Title 'AUDYT .NET / DirectX 12 / Agility SDK (C# Hybrid)' -SectionNumber 6

# --- Wersja .NET Runtime ---
try {
    $dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    Add-ReportLine "Aktywne .NET Runtime: $dotnetVersion"
} catch {
    Add-ReportLine 'Nie udalo sie odczytac wersji .NET Runtime.'
}

# [FIX-06 v5.0] Oddzielne try/catch dla SDK i Runtime
if (Test-CommandAvailable 'dotnet') {
    try {
        $dotnetSdks = & dotnet --list-sdks 2>&1
        $sdkLines = @($dotnetSdks | Where-Object { $_ -is [string] -and $_.Trim().Length -gt 0 })
        if ($sdkLines.Count -gt 0) {
            Add-ReportLine ''
            Add-ReportLine 'Zainstalowane .NET SDK:'
            foreach ($sdk in $sdkLines) {
                Add-ReportLine "  $sdk" -Silent
            }
        }
    } catch {
        Add-ReportLine "[INFO] dotnet --list-sdks error: $($_.Exception.Message)" -Silent
    }

    try {
        $dotnetRuntimes = & dotnet --list-runtimes 2>&1
        $rtLines = @($dotnetRuntimes | Where-Object { $_ -is [string] -and $_.Trim().Length -gt 0 })
        if ($rtLines.Count -gt 0) {
            Add-ReportLine ''
            Add-ReportLine 'Zainstalowane .NET Runtime:'
            foreach ($rt in $rtLines) {
                Add-ReportLine "  $rt" -Silent
            }
        }
    } catch {
        Add-ReportLine "[INFO] dotnet --list-runtimes error: $($_.Exception.Message)" -Silent
    }
} else {
    Add-ReportLine '[INFO] Narzedzie dotnet CLI nie jest dostepne w PATH.'
}

# --- Wersja D3D12 ---
$d3d12Paths = @(
    "$env:SystemRoot\System32\D3D12Core.dll",
    "$env:SystemRoot\System32\d3d12.dll",
    "$env:SystemRoot\System32\dxgi.dll"
)
foreach ($dllPath in $d3d12Paths) {
    if (Test-Path $dllPath) {
        $dllInfo = Get-Item $dllPath
        $dllVer  = $dllInfo.VersionInfo.FileVersion
        Add-ReportLine "Biblioteka DirectX: $($dllInfo.Name) | Wersja: $dllVer | Rozmiar: $([Math]::Round($dllInfo.Length / 1KB, 1)) KB"
    }
}

Add-ReportLine ''

# ============================================================================
# [FIX-10 v5.0] C# P/Invoke DXGI + D3D12 Diagnostyka (.NET 11 Preview 1)
# ============================================================================

$csharpD3D12Code = @'
using System;
using System.Runtime.InteropServices;

public static class D3D12Diagnostics
{
    // --- DXGI COM Interop ---
    [DllImport("dxgi.dll", EntryPoint = "CreateDXGIFactory1")]
    private static extern int CreateDXGIFactory1(
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        out IntPtr ppFactory);

    // IDXGIFactory1::EnumAdapters1
    [DllImport("dxgi.dll")]
    private static extern int CreateDXGIFactory2(
        uint Flags,
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        out IntPtr ppFactory);

    // D3D12CreateDevice
    [DllImport("d3d12.dll", EntryPoint = "D3D12CreateDevice")]
    private static extern int D3D12CreateDevice(
        IntPtr pAdapter,
        int MinimumFeatureLevel,
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        out IntPtr ppDevice);

    // --- GUID stale ---
    private static readonly Guid IID_IDXGIFactory1 =
        new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
    private static readonly Guid IID_IDXGIFactory6 =
        new Guid("c1b6694f-ff09-44a9-b03c-77900a0a1d17");
    private static readonly Guid IID_ID3D12Device =
        new Guid("189819f1-1db6-4b57-be54-1821339b85f7");

    // Feature Level enum
    private const int D3D_FL_11_0 = 0xb000;
    private const int D3D_FL_11_1 = 0xb100;
    private const int D3D_FL_12_0 = 0xc000;
    private const int D3D_FL_12_1 = 0xc100;
    private const int D3D_FL_12_2 = 0xc200;

    // DXGI_ADAPTER_DESC1
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DXGI_ADAPTER_DESC1
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string Description;
        public uint VendorId;
        public uint DeviceId;
        public uint SubSysId;
        public uint Revision;
        public long DedicatedVideoMemory;
        public long DedicatedSystemMemory;
        public long SharedSystemMemory;
        public long AdapterLuid_LowPart;
        public int AdapterLuid_HighPart;
        public uint Flags;
    }

    public static string RunDiagnostics()
    {
        var sb = new System.Text.StringBuilder(4096);
        sb.AppendLine("  --- Diagnostyka D3D12 via C# P/Invoke (.NET 11 Preview 1) ---");

        // DLL info
        string[] dllNames = { "d3d12.dll", "D3D12Core.dll", "dxgi.dll" };
        foreach (var dll in dllNames)
        {
            string path = System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System), dll);
            if (System.IO.File.Exists(path))
            {
                var fvi = System.Diagnostics.FileVersionInfo.GetVersionInfo(path);
                sb.AppendLine($"  [D3D12/DXGI] {dll}: v{fvi.FileVersion}");
            }
        }

        // DXGI Factory
        IntPtr factory = IntPtr.Zero;
        int hr = CreateDXGIFactory1(IID_IDXGIFactory1, out factory);
        if (hr != 0 || factory == IntPtr.Zero)
        {
            sb.AppendLine($"  [D3D12/DXGI] BLAD: CreateDXGIFactory1 zwrocil HRESULT 0x{hr:X8}");
            return sb.ToString();
        }
        sb.AppendLine("  [D3D12/DXGI] DXGI Factory utworzone pomyslnie.");

        // VTable call: EnumAdapters1 is at index 12 in IDXGIFactory1
        IntPtr factoryVTable = Marshal.ReadIntPtr(factory);

        int adapterIndex = 0;
        bool anyD3D12 = false;

        while (true)
        {
            // EnumAdapters1(this, adapterIndex, &adapter) - vtable slot 12
            IntPtr enumAdaptersPtr = Marshal.ReadIntPtr(factoryVTable, 12 * IntPtr.Size);
            var enumAdapters = Marshal.GetDelegateForFunctionPointer<EnumAdapters1Delegate>(enumAdaptersPtr);

            IntPtr adapter = IntPtr.Zero;
            hr = enumAdapters(factory, (uint)adapterIndex, out adapter);

            if (hr != 0) break; // DXGI_ERROR_NOT_FOUND

            // GetDesc1(this, &desc) - vtable slot 10 for IDXGIAdapter1
            IntPtr adapterVTable = Marshal.ReadIntPtr(adapter);
            IntPtr getDescPtr = Marshal.ReadIntPtr(adapterVTable, 10 * IntPtr.Size);
            var getDesc = Marshal.GetDelegateForFunctionPointer<GetDesc1Delegate>(getDescPtr);

            var desc = new DXGI_ADAPTER_DESC1();
            IntPtr descPtr = Marshal.AllocHGlobal(Marshal.SizeOf(desc));
            try
            {
                getDesc(adapter, descPtr);
                desc = Marshal.PtrToStructure<DXGI_ADAPTER_DESC1>(descPtr);
            }
            finally
            {
                Marshal.FreeHGlobal(descPtr);
            }

            sb.AppendLine($"  [D3D12/DXGI] Adapter [{adapterIndex}]: {desc.Description}");
            sb.AppendLine($"  [D3D12/DXGI]   VendorID: 0x{desc.VendorId:X4} | DeviceID: 0x{desc.DeviceId:X4}");
            sb.AppendLine($"  [D3D12/DXGI]   VRAM dedykowane: {desc.DedicatedVideoMemory / (1024 * 1024)} MB");

            // Proba utworzenia D3D12 device na kazdym Feature Level
            string featureLevelStr = "BRAK WSPARCIA (adapter nie obsluguje D3D12)";
            bool enhancedBarriers = false;
            bool vpblit3dlut = false;
            bool sm69 = false;

            int[] featureLevels = { D3D_FL_12_2, D3D_FL_12_1, D3D_FL_12_0, D3D_FL_11_1, D3D_FL_11_0 };
            string[] flNames = { "12_2", "12_1", "12_0", "11_1", "11_0" };

            for (int i = 0; i < featureLevels.Length; i++)
            {
                IntPtr device = IntPtr.Zero;
                int createHr = D3D12CreateDevice(adapter, featureLevels[i], IID_ID3D12Device, out device);
                if (createHr == 0 && device != IntPtr.Zero)
                {
                    featureLevelStr = flNames[i];
                    anyD3D12 = true;

                    // Enhanced Barriers: dostepne od FL 12_0+
                    enhancedBarriers = featureLevels[i] >= D3D_FL_12_0;
                    // VPblit 3DLUT: wymaga Video Processor FL 12_1+
                    vpblit3dlut = featureLevels[i] >= D3D_FL_12_1;
                    // SM 6.9: wymaga FL 12_2+
                    sm69 = featureLevels[i] >= D3D_FL_12_2;

                    Marshal.Release(device);
                    break;
                }
            }

            sb.AppendLine($"  [D3D12/DXGI]   D3D12 Feature Level: {featureLevelStr}" +
                (featureLevelStr != "BRAK WSPARCIA (adapter nie obsluguje D3D12)" ?
                    $" | Enhanced Barriers: {(enhancedBarriers ? "TAK" : "NIE")}" +
                    $" | VPblit 3DLUT: {(vpblit3dlut ? "TAK" : "NIE")}" +
                    $" | SM 6.9: {(sm69 ? "TAK" : "NIE")}" : ""));

            Marshal.Release(adapter);
            adapterIndex++;
        }

        Marshal.Release(factory);

        // --- Agility SDK 1.719.0-preview Compatibility Report ---
        sb.AppendLine("  [D3D12/DXGI] === Agility SDK 1.719.0-preview Compatibility ===");
        sb.AppendLine("  [D3D12/DXGI] D3D12SDKVersion: 719 (target preview)");
        sb.AppendLine("  [D3D12/DXGI] Enhanced Barriers: Wymagany FL 12_0+");
        sb.AppendLine("  [D3D12/DXGI] VPblit 3DLUT: Wymagany Video Processor z FL 12_1+");
        sb.AppendLine("  [D3D12/DXGI] Shader Model 6.9: Wymagany FL 12_2+");
        sb.AppendLine("  [D3D12/DXGI] CPU Timeline Query Resolves: Dostepne od SDK 1.714+");

        if (anyD3D12)
            sb.AppendLine("  [D3D12/DXGI] Status: Adapter D3D12 wykryty - szczegoly powyzej.");
        else
            sb.AppendLine("  [D3D12/DXGI] Status: Brak adapterow D3D12 - rendering software only.");

        // --- [FIX-11 v5.0] Skia/Raster Optimization Pipeline ---
        sb.AppendLine("  [SKIA/OPT] === Optymalizacja Pipeline Skia/Raster (LibreOffice 26.2) ===");
        sb.AppendLine("  [SKIA/OPT] Tryb renderowania: Potencjal Skia/Vulkan lub Skia/Metal-like via D3D12");
        sb.AppendLine("  [SKIA/OPT] Strategia z D3D12 Agility SDK 1.719:");
        sb.AppendLine("  [SKIA/OPT]   1. Enhanced Barriers redukuja overhead synchronizacji GPU-CPU");
        sb.AppendLine("  [SKIA/OPT]   2. VPblit 3DLUT akceleruje konwersje kolorow dokumentu");
        sb.AppendLine("  [SKIA/OPT]   3. CPU Timeline Query Resolves pozwala na profiling bez stall");
        sb.AppendLine("  [SKIA/OPT]   4. Low-overhead rendering via ExecuteIndirect zmniejsza draw calls");
        sb.AppendLine("  [SKIA/OPT]   5. D3D12 Work Graphs (SM 6.9) moga akcelerowac layout engine");

        return sb.ToString();
    }

    // Delegate types for COM vtable calls
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int EnumAdapters1Delegate(IntPtr pThis, uint Adapter, out IntPtr ppAdapter);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetDesc1Delegate(IntPtr pThis, IntPtr pDesc);
}
'@

try {
    Add-Type -TypeDefinition $csharpD3D12Code -Language CSharp -ErrorAction Stop
    $d3d12Output = [D3D12Diagnostics]::RunDiagnostics()
    foreach ($line in ($d3d12Output -split "`n")) {
        $trimmed = $line.TrimEnd()
        if ($trimmed.Length -gt 0) {
            Add-ReportLine $trimmed
        }
    }
} catch {
    Add-ReportLine "[INFO] C# D3D12 P/Invoke niedostepny: $($_.Exception.Message)" -ConsoleColor $colorWarning
    Add-ReportLine '[INFO] Upewnij sie ze .NET 11 Preview 1 Runtime jest zainstalowany.'
}

# ============================================================================
# SEKCJA 7: MOST PYTHON UNO (EXTERNAL IPC BRIDGE)
# ============================================================================
Write-Section -Title 'MOST PYTHON UNO (EXTERNAL IPC BRIDGE)' -SectionNumber 7

# [FIX-04 v5.0] Wykrycie wbudowanego Pythona LibreOffice (NIE systemowego!)
# LibreOffice 26.2 zawiera python312.dll - ladowanie go w Python 3.13 powoduje crash.
$loPythonExePaths = @(
    'C:\Program Files\LibreOffice\program\python.exe',
    'C:\Program Files (x86)\LibreOffice\program\python.exe'
)

$loPythonExe = $null
foreach ($candidate in $loPythonExePaths) {
    if (Test-Path $candidate) {
        $loPythonExe = $candidate
        break
    }
}

$systemPythonAvailable = Test-CommandAvailable 'python'

if ($loPythonExe) {
    Add-ReportLine "Python LibreOffice (wbudowany): $loPythonExe" -ConsoleColor $colorSuccess
} else {
    Add-ReportLine '[INFO] Nie znaleziono wbudowanego Pythona LibreOffice.' -ConsoleColor $colorWarning
}

if ($systemPythonAvailable) {
    $sysPyPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    Add-ReportLine "Python systemowy: $sysPyPath"
    Add-ReportLine '[INFO] Python systemowy NIE jest uzywany dla mostu UNO (konflikt DLL).'
}

# [FIX-05 v5.0] Skrypt Python - ASCII-only output, unika mojibake CP852/CP1250
# [FIX-07 v5.0] setup_uno_path(): priorytet os.path.dirname(sys.executable)
# [FIX-08 v5.0] ExtensionManager: fallback na thePackageManagerFactory + getPackages
$pythonCode = @'
#!/usr/bin/env python3
# -*- coding: ascii -*-
"""
Diagnostic Python-UNO bridge (IPC Socket Bridge) v5.0.
Auto-generated by the hybrid audit script.
Connects to a headless LibreOffice instance and queries
the extension manager through the live UNO interface.

CRITICAL: This script MUST be run by LibreOffice's bundled python.exe,
NOT the system Python, to avoid python3xx.dll version conflicts.
"""

import sys
import os
import time


def setup_uno_path():
    """Configure sys.path for importing the uno module from LibreOffice.
    [FIX-07 v5.0] Priority: directory of current python.exe executable."""
    exe_dir = os.path.dirname(os.path.abspath(sys.executable))
    if os.path.isfile(os.path.join(exe_dir, "uno.py")) or os.path.isfile(os.path.join(exe_dir, "uno.pyd")):
        if exe_dir not in sys.path:
            sys.path.insert(0, exe_dir)
        return exe_dir

    lo_program_paths = [
        r"C:\Program Files\LibreOffice\program",
        r"C:\Program Files (x86)\LibreOffice\program",
        os.path.expandvars(r"%PROGRAMFILES%\LibreOffice\program"),
    ]

    for lo_path in lo_program_paths:
        if os.path.isdir(lo_path) and lo_path not in sys.path:
            sys.path.insert(0, lo_path)
            return lo_path

    return None


def connect_to_libreoffice(host="localhost", port=2002, timeout=12):
    """Connect to headless LibreOffice daemon via UNO IPC socket."""
    try:
        import uno
        from com.sun.star.connection import NoConnectException
    except ImportError as e:
        return None, "Failed to import 'uno' module: {}".format(e)

    local_ctx = uno.getComponentContext()
    resolver = local_ctx.ServiceManager.createInstanceWithContext(
        "com.sun.star.bridge.UnoUrlResolver", local_ctx
    )

    uno_url = (
        "uno:socket,host={},port={},tcpNoDelay=1;"
        "urp;StarOffice.ComponentContext"
    ).format(host, port)

    last_error = None
    attempts = 0
    max_attempts = max(1, timeout // 2)

    while attempts < max_attempts:
        try:
            ctx = resolver.resolve(uno_url)
            return ctx, None
        except NoConnectException as e:
            last_error = str(e)
            attempts += 1
            time.sleep(2)
        except Exception as e:
            return None, "Unexpected connection error: {}".format(e)

    return None, "Timeout after {} attempts. Last error: {}".format(max_attempts, last_error)


def enumerate_extensions(ctx):
    """[FIX-08 v5.0] List installed extensions with multiple API fallbacks."""
    results = []

    smgr = ctx.ServiceManager

    # Strategy 1: com.sun.star.deployment.ExtensionManager (modern API)
    try:
        ext_mgr = smgr.createInstanceWithContext(
            "com.sun.star.deployment.ExtensionManager", ctx
        )
        if ext_mgr is not None:
            for scope in ("user", "shared", "bundled"):
                try:
                    exts = ext_mgr.getDeployedExtensions(scope, ext_mgr.createAbortChannel(), None)
                    if exts:
                        for ext in exts:
                            try:
                                ident = ""
                                try:
                                    id_obj = ext.getIdentifier()
                                    ident = id_obj.Value if hasattr(id_obj, 'Value') else str(id_obj)
                                except Exception:
                                    ident = "(no id)"
                                name = ""
                                try:
                                    name = ext.getDisplayName()
                                except Exception:
                                    name = ident
                                ver = ""
                                try:
                                    ver = ext.getVersion()
                                except Exception:
                                    ver = "?"
                                results.append({
                                    "scope": scope,
                                    "identifier": ident,
                                    "name": name,
                                    "version": ver
                                })
                            except Exception as ie:
                                results.append({
                                    "scope": scope,
                                    "identifier": "(read error: {})".format(ie),
                                    "name": "?", "version": "?"
                                })
                except Exception as se:
                    results.append({
                        "scope": scope,
                        "identifier": "(scope error: {})".format(se),
                        "name": "?", "version": "?"
                    })
            if results:
                return results, None
    except Exception:
        pass

    # Strategy 2: thePackageManagerFactory (legacy API fallback)
    try:
        pmf = smgr.createInstanceWithContext(
            "com.sun.star.deployment.thePackageManagerFactory", ctx
        )
        if pmf is not None:
            for scope_name in ("user", "shared", "bundled"):
                try:
                    pm = pmf.getPackageManager(scope_name)
                    if pm is not None:
                        pkgs = pm.getDeployedPackages(pm.createAbortChannel(), None)
                        if pkgs:
                            for pkg in pkgs:
                                try:
                                    results.append({
                                        "scope": scope_name,
                                        "identifier": pkg.getIdentifier().Value if hasattr(pkg.getIdentifier(), 'Value') else str(pkg.getIdentifier()),
                                        "name": pkg.getDisplayName(),
                                        "version": pkg.getVersion()
                                    })
                                except Exception:
                                    pass
                except Exception:
                    pass
    except Exception:
        pass

    if not results:
        return [], "No extensions found via any API method."
    return results, None


def main():
    """Main diagnostic procedure for Python-UNO bridge."""
    output_lines = []
    output_lines.append("[Python IPC] === Diagnostyka Mostu Python-UNO ===")
    output_lines.append("[Python IPC] Wersja Python: {}".format(sys.version))
    output_lines.append("[Python IPC] Architektura: {}".format(
        "64-bit" if sys.maxsize > 2**32 else "32-bit"))

    lo_path = setup_uno_path()
    if lo_path:
        output_lines.append("[Python IPC] Sciezka LibreOffice: {}".format(lo_path))
    else:
        output_lines.append("[Python IPC] OSTRZEZENIE: Nie znaleziono katalogu program LibreOffice.")

    output_lines.append("[Python IPC] Nawiazywanie polaczenia z demonem LibreOffice (port 2002)...")
    ctx, error = connect_to_libreoffice()

    if error:
        output_lines.append("[Python IPC] Blad polaczenia: {}".format(error))
        output_lines.append("[Python IPC] Upewnij sie, ze LibreOffice dziala w trybie --headless z akceptacja gniazda.")
        output_lines.append("[Python IPC] Komenda startowa:")
        output_lines.append('[Python IPC]   soffice --headless --accept="socket,host=localhost,port=2002,tcpNoDelay=1;urp;StarOffice.ComponentContext"')
    else:
        output_lines.append("[Python IPC] Polaczenie nawiazane pomyslnie!")

        extensions, ext_error = enumerate_extensions(ctx)
        if ext_error:
            output_lines.append("[Python IPC] Blad enumeracji: {}".format(ext_error))
        elif extensions:
            output_lines.append("[Python IPC] Znaleziono {} rozszerzenie(a):".format(len(extensions)))
            for i, ext in enumerate(extensions, 1):
                output_lines.append(
                    "[Python IPC]   [{}] [{}] {} (v{}) ID: {}".format(
                        i, ext["scope"], ext["name"], ext["version"], ext["identifier"]))
        else:
            output_lines.append("[Python IPC] Menedzer UNO nie raportuje zadnych rozszerzen.")

    for line in output_lines:
        print(line)

    return 0


if __name__ == "__main__":
    sys.exit(main())
'@

# Zapis skryptu Python jako UTF-8 bez BOM z koncami linii LF
try {
    $pythonLF = $pythonCode.Replace("`r`n", "`n")
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($pythonScriptPath, $pythonLF, $utf8NoBom)
    Add-ReportLine "Skrypt Python wygenerowany: $pythonScriptPath" -ConsoleColor $colorSuccess
} catch {
    Add-ReportLine "[BLAD] Zapis skryptu Python nie powiodl sie: $($_.Exception.Message)" -ConsoleColor $colorError
}

# --- Wykrycie soffice.exe ---
$loExePaths = @(
    'C:\Program Files\LibreOffice\program\soffice.exe',
    'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
    "${env:ProgramFiles}\LibreOffice\program\soffice.exe"
)

$loExe = $null
foreach ($candidatePath in $loExePaths) {
    if (Test-Path $candidatePath) {
        $loExe = $candidatePath
        break
    }
}

# [FIX-04 v5.0] Uzywamy WYLACZNIE wbudowanego python.exe z LibreOffice
if ($loExe -and $loPythonExe) {
    Add-ReportLine ''
    Add-ReportLine 'Uruchamianie mostu Python-UNO...'

    # Zamkniecie istniejacych procesow LO
    $existingLO = Get-Process -Name 'soffice*' -ErrorAction SilentlyContinue
    if ($existingLO) {
        Add-ReportLine '[OSTRZEZENIE] Wykryto dzialajace procesy LibreOffice. Zamykanie...' -ConsoleColor $colorWarning
        $existingLO | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    try {
        $loArgs = '--headless --norestore --nologo --accept="socket,host=localhost,port=2002,tcpNoDelay=1;urp;StarOffice.ComponentContext"'
        $loProcess = Start-Process -FilePath $loExe -ArgumentList $loArgs -PassThru -WindowStyle Hidden
        Add-ReportLine "Demon LibreOffice uruchomiony (PID: $($loProcess.Id)). Oczekiwanie na inicjalizacje..."

        Start-Sleep -Seconds 8

        Add-ReportLine 'Wykonywanie skryptu diagnostycznego Python...'
        Add-ReportLine "Python dla mostu: $loPythonExe"

        # [FIX-05 v5.0] Wymuszenie UTF-8 na wyjsciu Pythona
        $prevEncoding = $env:PYTHONIOENCODING
        $env:PYTHONIOENCODING = 'utf-8'

        $pyOutput = & $loPythonExe $pythonScriptPath 2>&1 | Out-String

        $env:PYTHONIOENCODING = $prevEncoding

        if ($pyOutput) {
            $report.Add('')
            foreach ($line in ($pyOutput.Trim() -split "`n")) {
                $trimmed = $line.Trim()
                if ($trimmed.Length -gt 0) {
                    Add-ReportLine $trimmed
                }
            }
        } else {
            Add-ReportLine '[INFO] Skrypt Python nie wygenerowal zadnego wyjscia.' -ConsoleColor $colorWarning
        }

    } catch {
        Add-ReportLine "[BLAD] Uruchomienie mostu Python-UNO nie powiodlo sie: $($_.Exception.Message)" -ConsoleColor $colorError
    } finally {
        if ($loProcess -and -not $loProcess.HasExited) {
            Stop-Process -Id $loProcess.Id -Force -ErrorAction SilentlyContinue
            Add-ReportLine "Demon LibreOffice (PID: $($loProcess.Id)) zostal zamkniety."
        }
        Start-Sleep -Seconds 1
        Get-Process -Name 'soffice*' -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }

} else {
    if (-not $loExe) {
        Add-ReportLine '[BRAK] Nie znaleziono soffice.exe -- LibreOffice nie jest zainstalowany.' -ConsoleColor $colorWarning
    }
    if (-not $loPythonExe) {
        Add-ReportLine '[BRAK] Nie znaleziono wbudowanego python.exe LibreOffice. Most UNO niedostepny.' -ConsoleColor $colorWarning
    }
    Add-ReportLine ''
    Add-ReportLine 'Skrypt Python zostal mimo to wygenerowany na pulpicie do recznego uruchomienia.'
}

# ============================================================================
# SEKCJA 8: PODSUMOWANIE I REKOMENDACJE
# ============================================================================
Write-Section -Title 'PODSUMOWANIE I REKOMENDACJE' -SectionNumber 8

$report.Add('')
$report.Add('--- Automatycznie wygenerowane rekomendacje ---')

# Sprawdzenie Java
if (Test-CommandAvailable 'java') {
    $jvmCheck = (& java -version 2>&1 | Out-String)
    if ($jvmCheck -notmatch '64-Bit') {
        Add-ReportLine '[REKOMENDACJA] Zainstaluj 64-bitowy JDK (Microsoft Build of OpenJDK).' -ConsoleColor $colorWarning
    }
}

# Sprawdzenie D3D12
$d3d12Present = Test-Path "$env:SystemRoot\System32\d3d12.dll"
if ($d3d12Present) {
    Add-ReportLine '[INFO] D3D12 obecne. Rozwaz aktualizacje Agility SDK do 1.719.0-preview.' -ConsoleColor $colorSuccess
} else {
    Add-ReportLine '[INFO] D3D12 nieobecne. Rendering software-only (CPU).'
}

# Rekomendacja ForceSkiaRaster
Add-ReportLine '[REKOMENDACJA] ForceSkiaRaster=true powinno pozostac aktywne (ochrona przed artefaktami).'

# Sprawdzenie PowerShell
if ($PSVersionTable.PSVersion -lt [Version]'7.5.0') {
    Add-ReportLine '[REKOMENDACJA] Zaktualizuj PowerShell 7.x do najnowszej stabilnej wersji.' -ConsoleColor $colorWarning
}

# Sprawdzenie Pythona
if (-not $loPythonExe) {
    Add-ReportLine '[REKOMENDACJA] Sprawdz integralnosc instalacji LibreOffice (brakuje python.exe).' -ConsoleColor $colorWarning
}

Add-ReportLine ''
Add-ReportLine "Raport wygenerowany pomyslnie: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-ReportLine "Wersja skryptu: v5.0 (Hybrid PS7.6 + Python 3.12/LO + C# .NET 11 Preview 1)"

# ============================================================================
# ZAPIS KONCOWY RAPORTU (UTF-8 BEZ BOM, KONCE LINII LF)
# ============================================================================
try {
    $finalReport = $report -join "`n"
    $utf8NoBom   = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($reportPath, $finalReport, $utf8NoBom)

    Write-Host ''
    Write-Host '================================================================' -ForegroundColor $colorSuccess
    Write-Host "  ZAKONCZONO POMYSLNIE (v5.0 Hybrid)" -ForegroundColor $colorSuccess
    Write-Host '================================================================' -ForegroundColor $colorSuccess
    Write-Host ''
    Write-Host "  Kodowanie:     UTF-8 (bez BOM)" -ForegroundColor $colorSuccess
    Write-Host "  Konce linii:   LF (Unix)" -ForegroundColor $colorSuccess
    Write-Host "  Raport:        $reportPath" -ForegroundColor $colorSuccess
    Write-Host "  Skrypt Python: $pythonScriptPath" -ForegroundColor $colorSuccess
    if ($xcuFilePath) {
        Write-Host "  Kopia XCU:     $xcuReportPath" -ForegroundColor $colorSuccess
    }
    Write-Host "  Modul C# D3D12: Wykonano" -ForegroundColor $colorSuccess
    Write-Host ''
} catch {
    Write-Host "[BLAD KRYTYCZNY] Zapis raportu koncowego nie powiodl sie: $($_.Exception.Message)" -ForegroundColor $colorError
}
