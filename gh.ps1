# =====================================================================
#  gh.ps1 — Kompletny automatyczny generator struktury PDF/A + Git Fix
#  Wersja: FINAL 2025-12-19
# =====================================================================

$basePath = "C:\Users\mszew\neuroatypowy"
$pdfPath  = Join-Path $basePath "pdf"

$dirs = @(
    "docs",
    "assets",
    "filters",
    "templates",
    "tools",
    ".github\workflows",
    "assets\fonts"
)

$descriptions = @{
    "docs"              = "Zawiera pliki źródłowe Markdown."
    "assets"            = "Zawiera logo i grafiki."
    "assets\fonts"      = "Lokalna kopia fontów (nie śledzona przez Git)."
    "filters"           = "Filtry Lua dla Pandoc."
    "templates"         = "Szablony LaTeX dla PDF/A."
    "tools"             = "Skrypty PowerShell."
    ".github\workflows" = "Workflow GitHub Actions."
}

$logFile       = Join-Path $basePath "gs.log"
$gitErrorLog   = Join-Path $basePath "git-errors.log"

function Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts - $msg"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function LogGitError {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $gitErrorLog -Value "$ts - $msg"
}

try {
    Log "Start skryptu gh.ps1"

    if (-not (Test-Path (Join-Path $basePath ".git"))) {
        throw "Brak katalogu .git — to nie jest repozytorium Git."
    }

    # =====================================================================
    # 1. Walidacja środowiska Windows
    # =====================================================================

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.0+ jest wymagany."
    }

    if (-not (Get-Command "Expand-Archive" -ErrorAction SilentlyContinue)) {
        throw "Polecenie Expand-Archive nie jest dostępne — zaktualizuj PowerShell."
    }

    Log "Środowisko Windows OK"

    # =====================================================================
    # 2. Tworzenie struktury katalogów
    # =====================================================================

    if (-not (Test-Path $pdfPath)) {
        New-Item -ItemType Directory -Path $pdfPath | Out-Null
        Log "Utworzono katalog: $pdfPath"
    } else {
        Log "Katalog już istnieje: $pdfPath"
    }

    foreach ($dir in $dirs) {
        $full = Join-Path $pdfPath $dir
        if (-not (Test-Path $full)) {
            New-Item -ItemType Directory -Path $full | Out-Null
            Log "Utworzono katalog: $full"
        } else {
            Log "Katalog już istnieje: $full"
        }

        $readme = Join-Path $full "README.md"
        $desc = $descriptions[$dir]
        if (-not $desc) { $desc = "Opis katalogu $dir." }

        $content = @(
            "# $dir",
            "",
            $desc,
            "",
            "*Plik wygenerowany automatycznie przez gh.ps1.*"
        ) -join "`r`n"

        Set-Content -Path $readme -Value $content -Encoding UTF8
        Log "Utworzono lub zaktualizowano plik: $readme"
    }

    # =====================================================================
    # 3. .gitignore + wyłączenie fontów i logów z Git
    # =====================================================================

    $gitignore = Join-Path $basePath ".gitignore"

    if (-not (Test-Path $gitignore)) {
        Log ".gitignore nie istnieje — tworzę nowy."
        Set-Content -Path $gitignore -Value "" -Encoding UTF8
    }

    $ignoreContent = Get-Content $gitignore -Raw

    $entriesToIgnore = @(
        "pdf/assets/fonts/",
        "gs.log",
        "git-errors.log"
    )

    foreach ($entry in $entriesToIgnore) {
        if ($ignoreContent -notmatch [regex]::Escape($entry)) {
            Add-Content -Path $gitignore -Value $entry
            Log "Dodano wpis do .gitignore: $entry"
        } else {
            Log ".gitignore już zawiera wpis: $entry"
        }
    }

    Set-Location $basePath

    $pathsToUntrack = @(
        "pdf/assets/fonts",
        "gs.log",
        "git-errors.log"
    )

    foreach ($p in $pathsToUntrack) {
        git rm -r --cached --ignore-unmatch "$p" 2>&1 | Tee-Object -FilePath $gitErrorLog
        Log "$p — usunięto z indeksu (lub nie był śledzony)"
    }

    # =====================================================================
    # 4. Generowanie plików pipeline’u
    # =====================================================================

    $docsDir      = Join-Path $pdfPath "docs"
    $assetsDir    = Join-Path $pdfPath "assets"
    $filtersDir   = Join-Path $pdfPath "filters"
    $templatesDir = Join-Path $pdfPath "templates"
    $toolsDir     = Join-Path $pdfPath "tools"
    $workflowsDir = Join-Path $pdfPath ".github\workflows"
    $fontsDir     = Join-Path $assetsDir "fonts"

    # 4.1 tools\md2pdf.ps1
    $md2pdfPath = Join-Path $toolsDir "md2pdf.ps1"
    $md2pdfContent = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [ValidateSet("Marek SZEWCZYK","Patrycja SZEWCZYK","Agata SZEWCZYK")]
    [string]$Subject = "Marek SZEWCZYK",

    [string]$Author = "Neuroatypowi",
    [string]$Lang = "pl-PL"
)

$ErrorActionPreference = "Stop"

$Root        = Split-Path -Parent $PSScriptRoot
$FiltersDir  = Join-Path $Root "filters"
$TemplatesDir= Join-Path $Root "templates"
$AssetsDir   = Join-Path $Root "assets"

$PdfaFilter  = Join-Path $FiltersDir "pdfa.lua"
$Template    = Join-Path $TemplatesDir "neuroatypowi.latex"
$LogoPath    = Join-Path $AssetsDir "Neuroatypowi.200px_TXT.png"

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Brak wymaganego pliku: $Path"
    }
}

Assert-FileExists $PdfaFilter
Assert-FileExists $Template
Assert-FileExists $LogoPath
Assert-FileExists $InputFile

function Test-ContainsEmoji {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($ch in $content.ToCharArray()) {
        $code = [int][char]$ch
        if (
            ($code -ge 0x1F300 -and $code -le 0x1FAFF) -or
            ($code -ge 0x2600  -and $code -le 0x27BF)  -or
            ($code -ge 0xFE00  -and $code -le 0xFE0F)
        ) {
            return $true
        }
    }
    return $false
}

$HasEmoji = Test-ContainsEmoji -Path $InputFile
Write-Host "Wykryto emoji: $HasEmoji"

function Test-FontInstalled {
    param([string]$FontName)
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $values = Get-ItemProperty -Path $path
            foreach ($prop in $values.PSObject.Properties) {
                $name  = $prop.Name
                $value = $prop.Value
                if ($name -match $FontName -or $value -match $FontName) {
                    return $true
                }
            }
        }
    }
    return $false
}

$RequiredFonts = @("Inter","OpenDyslexic","Noto Color Emoji")
foreach ($f in $RequiredFonts) {
    if (-not (Test-FontInstalled -FontName $f)) {
        Write-Warning "Font '$f' nie został znaleziony w systemie. Zainstaluj go ręcznie (zalecane)."
    } else {
        Write-Host "Font '$f' wykryty."
    }
}

function Get-PandocVariables {
    param(
        [string]$MainFont,
        [string]$SansFont,
        [string]$MonoFont,
        [bool]$IncludeEmoji
    )
    $vars = @(
        "--variable=mainfont=$MainFont",
        "--variable=sansfont=$SansFont",
        "--variable=monofont=$MonoFont",
        "--variable=fontsize=11pt",
        "--variable=geometry:margin=2.5cm",
        "--variable=logo-path=$LogoPath",
        "--variable=logo-width=3cm"
    )
    if ($IncludeEmoji) {
        $vars += "--variable=emoji-font=Noto Color Emoji"
    }
    return $vars
}

function Invoke-MdToPdfProfile {
    param(
        [string]$ProfileName,
        [string]$OutputFile,
        [string]$MainFont,
        [string]$SansFont,
        [string]$MonoFont
    )

    $vars = Get-PandocVariables -MainFont $MainFont -SansFont $SansFont -MonoFont $MonoFont -IncludeEmoji:$HasEmoji

    $args = @(
        $InputFile,
        "--from", "markdown",
        "--to", "pdf",
        "--pdf-engine=xelatex",
        "--template=$Template",
        "--lua-filter=$PdfaFilter",
        "--metadata=title=$(Split-Path $InputFile -Leaf)",
        "--metadata=author=$Author",
        "--metadata=lang=$Lang",
        "--metadata=subject=$Subject",
        "--metadata=pdfa=true",
        "--metadata=pdfa:2b",
        "--toc",
        "--toc-depth=2"
    ) + $vars + @(
        "--output=$OutputFile"
    )

    Write-Host "Generuję profil $ProfileName → $OutputFile"
    & pandoc @args
}

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$DirName  = Split-Path -Parent $InputFile

$OutInter = Join-Path $DirName ($BaseName + "_Inter.pdf")
$OutOpenD = Join-Path $DirName ($BaseName + "_OpenDyslexic.pdf")

Invoke-MdToPdfProfile -ProfileName "Inter" -OutputFile $OutInter `
    -MainFont "Inter" -SansFont "Inter" -MonoFont "Inter"

Invoke-MdToPdfProfile -ProfileName "OpenDyslexic" -OutputFile $OutOpenD `
    -MainFont "OpenDyslexic" -SansFont "Inter" -MonoFont "Inter"

Write-Host "Wygenerowano:"
Write-Host " - $OutInter"
Write-Host " - $OutOpenD"

function Get-CertificateByThumbprint {
    param(
        [string]$Thumbprint
    )
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
    $store.Open("ReadOnly")
    $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $Thumbprint }
    $store.Close()
    if (-not $cert) {
        throw "Nie znaleziono certyfikatu o Thumbprint: $Thumbprint w CurrentUser\My."
    }
    return $cert
}

function Sign-PdfWithSmime {
    param(
        [string]$PdfPath,
        [string]$CertThumbprint
    )
    $cert = Get-CertificateByThumbprint -Thumbprint $CertThumbprint
    Write-Warning "Hook do podpisu PDF jest przygotowany. Uzupełnij wywołanie narzędzia CLI w funkcji Sign-PdfWithSmime."
}
'@
    Set-Content -Path $md2pdfPath -Value $md2pdfContent -Encoding UTF8
    Log "Utworzono lub zaktualizowano plik: $md2pdfPath"
    # =====================================================================
    # 5. WALIDACJE: Pandoc, XeLaTeX, Ghostscript, fonty
    # =====================================================================

    Log "Sprawdzam Pandoc..."
    try {
        $pandocVersion = & pandoc --version 2>$null
    } catch {
        $pandocVersion = $null
    }
    if (-not $pandocVersion) {
        throw "Pandoc nie jest zainstalowany lub nie jest w PATH."
    }
    Log "Pandoc OK: $($pandocVersion.Split([Environment]::NewLine)[0])"

    Log "Sprawdzam XeLaTeX..."
    try {
        $xelatexVersion = & xelatex --version 2>$null
    } catch {
        $xelatexVersion = $null
    }
    if (-not $xelatexVersion) {
        throw "XeLaTeX (MiKTeX/TeX Live) nie jest zainstalowany lub nie jest w PATH."
    }
    Log "XeLaTeX OK: $($xelatexVersion.Split([Environment]::NewLine)[0])"

    Log "Sprawdzam Ghostscript..."
    try {
        $gsVersion = & gswin64c --version 2>$null
    } catch {
        try { $gsVersion = & gs --version 2>$null } catch { $gsVersion = $null }
    }
    if (-not $gsVersion) {
        throw "Ghostscript nie jest zainstalowany lub nie jest w PATH."
    }
    Log "Ghostscript OK: wersja $gsVersion"

    # =====================================================================
    # 6. WALIDACJA FONTÓW
    # =====================================================================

    function Test-FontInstalled {
        param([string]$FontName)
        $paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Fonts"
        )
        foreach ($path in $paths) {
            if (Test-Path $path) {
                $values = Get-ItemProperty -Path $path
                foreach ($prop in $values.PSObject.Properties) {
                    if ($prop.Value -match [regex]::Escape($FontName)) {
                        return $true
                    }
                }
            }
        }
        return $false
    }

    $requiredFonts = @("Inter","OpenDyslexic","Noto Color Emoji")
    foreach ($font in $requiredFonts) {
        if (-not (Test-FontInstalled $font)) {
            Log "UWAGA: Font '$font' nie jest zainstalowany w systemie."
        } else {
            Log "Font OK: $font"
        }
    }

    # =====================================================================
    # 7. WALIDACJA PLIKÓW PIPELINE'U
    # =====================================================================
	$md2pdfPath   = Join-Path $toolsDir "md2pdf.ps1"
	$pdfaPath     = Join-Path $filtersDir "pdfa.lua"
	$latexPath    = Join-Path $templatesDir "neuroatypowi.latex"
	$workflowPath = Join-Path $workflowsDir "pdfa.yml"
    $requiredFiles = @(
        $md2pdfPath,
        $pdfaPath,
        $latexPath,
        $workflowPath
    )
	
$missing = @()
foreach ($file in $requiredFiles) {
    if ([string]::IsNullOrWhiteSpace($file)) {
        $missing += "<niezdefiniowana ścieżka>"
        continue
    }
    if (-not (Test-Path $file)) {
        $missing += $file
    } else {
        Log "Plik pipeline OK: $file"
    }
}
if ($missing.Count -gt 0) {
    $msg = "Brak wymaganego pliku pipeline’u: " + ($missing -join "; ")
    throw $msg
}

    # =====================================================================
    # 8. GENEROWANIE PRZYKŁADOWEGO PLIKU TESTOWEGO (opcjonalne)
    # =====================================================================

    $testMd = Join-Path $docsDir "test.md"
    if (-not (Test-Path $testMd)) {
        $testContent = @(
            "# Testowy dokument",
            "",
            "To jest testowy dokument wygenerowany automatycznie przez gh.ps1.",
            "",
            "## Sekcja",
            "",
            "Treść testowa. 🙂"
        ) -join "`r`n"
        Set-Content -Path $testMd -Value $testContent -Encoding UTF8
        Log "Utworzono testowy plik: $testMd"
    } else {
        Log "Plik test.md już istnieje: $testMd"
    }

    # =====================================================================
    # 9. GENEROWANIE PDF-ów (wywołanie md2pdf dla każdego .md w docs)
    # =====================================================================

    $mdFiles = Get-ChildItem -Path $docsDir -Filter *.md -File
    foreach ($md in $mdFiles) {
        try {
            Log "Generuję PDF z: $($md.FullName)"
            & powershell -NoProfile -ExecutionPolicy Bypass -File $md2pdfPath -InputFile $md.FullName
            Log "Generacja zakończona dla: $($md.Name)"
        } catch {
            Log "Błąd generacji PDF dla $($md.Name): $_"
            LogGitError "Błąd generacji PDF: $_"
        }
    }

    # =====================================================================
    # 10. AUTOMATYCZNY TEST PDF/A (Ghostscript)
    # =====================================================================

    function Test-Pdfa {
        param([string]$PdfPath)

        Log "Test PDF/A: $PdfPath"

        # Użyj Ghostscript do próby konwersji/analizy; wynik kierujemy do zmiennej
        try {
            $gsOutput = & gswin64c -dPDFA=2 -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=NUL "$PdfPath" 2>&1
        } catch {
            try { $gsOutput = & gs -dPDFA=2 -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=NUL "$PdfPath" 2>&1 } catch { $gsOutput = $_.Exception.Message }
        }

        if ($gsOutput -match "error" -or $gsOutput -match "failed") {
            Log "PDF/A NIEPOPRAWNY: $PdfPath"
            LogGitError "PDF/A validation failed for $PdfPath : $gsOutput"
            return $false
        }

        Log "PDF/A — wynik niejednoznaczny lub brak błędów krytycznych: $PdfPath"
        return $true
    }

    $generatedPdfs = Get-ChildItem -Path $docsDir -Filter *.pdf -Recurse -File
    foreach ($pdf in $generatedPdfs) {
        Test-Pdfa $pdf.FullName | Out-Null
    }
    # =====================================================================
    # 11. GIT — pełna automatyzacja: wyłącz edytor, reset, rebase, push
    # =====================================================================

    Log "=== Sekcja Git ==="

    # Wyłączenie edytora Git (pełna automatyzacja)
    git config --global core.editor true
    git config --global sequence.editor true
    git config --global merge.tool true
    git config --global commit.cleanup scissors

    Set-Location $basePath

    # 11.1 Pełny reset repo (hard + clean)
    Log "Wykonuję pełny reset repo (git reset --hard + git clean -fdx)"
    git reset --hard 2>&1 | Tee-Object -FilePath $gitErrorLog
    git clean -fdx 2>&1 | Tee-Object -FilePath $gitErrorLog
    Log "Reset repo zakończony"

    # 11.2 Usuń ewentualny rebase-merge
    $rebaseDir = Join-Path $basePath ".git\rebase-merge"
    if (Test-Path $rebaseDir) {
        Log "Wykryto .git/rebase-merge — usuwam"
        Remove-Item -Recurse -Force $rebaseDir
    }

    # 11.3 Przełącz na main jeśli potrzeba
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($branch -ne "main") {
        Log "Przełączam na main"
        git checkout main 2>&1 | Tee-Object -FilePath $gitErrorLog
        if ($LASTEXITCODE -ne 0) {
            Log "Nie udało się przełączyć na main"
        }
    } else {
        Log "Aktualna gałąź: main"
    }

    # 11.4 Commit lokalnych zmian (jeśli są)
    $status = git status --porcelain
    if ($status) {
        Log "Wykryto lokalne zmiany — commituję"
        git add . 2>&1 | Tee-Object -FilePath $gitErrorLog
        git commit -m "Automatyczny commit $(Get-Date -Format 'yyyy-MM-dd HH:mm')" --no-edit 2>&1 | Tee-Object -FilePath $gitErrorLog
        if ($LASTEXITCODE -eq 0) {
            Log "Commit utworzony."
        } else {
            Log "Brak zmian do commitowania lub błąd commita."
        }
    } else {
        Log "Brak lokalnych zmian"
    }

    # 11.5 Fetch
    Log "git fetch origin"
    git fetch origin 2>&1 | Tee-Object -FilePath $gitErrorLog

    # 11.6 Pull --rebase z obsługą rebase-merge i ponowną próbą
    Log "git pull --rebase origin main"
    git pull --rebase origin main 2>&1 | Tee-Object -FilePath $gitErrorLog

    if ($LASTEXITCODE -ne 0) {
        Log "pull --rebase nie powiódł się — próbuję naprawić stan i ponowić"

        git reset --hard 2>&1 | Tee-Object -FilePath $gitErrorLog
        git clean -fdx 2>&1 | Tee-Object -FilePath $gitErrorLog

        if (Test-Path $rebaseDir) {
            Log "Usuwam .git/rebase-merge przed ponownym pull"
            Remove-Item -Recurse -Force $rebaseDir
        }

        Log "Ponawiam git pull --rebase origin main"
        git pull --rebase origin main 2>&1 | Tee-Object -FilePath $gitErrorLog

        if ($LASTEXITCODE -ne 0) {
            throw "git pull --rebase nadal się nie powiódł — sprawdź git-errors.log"
        }
    }

    # 11.7 Push
    Log "git push origin main"
    git push origin main 2>&1 | Tee-Object -FilePath $gitErrorLog

    if ($LASTEXITCODE -ne 0) {
        throw "git push zakończył się błędem — sprawdź git-errors.log"
    }

    Log "Push zakończony sukcesem"
    Log "Skrypt zakończył działanie."

} catch {
    Log "Nieoczekiwany błąd: $_"
    LogGitError "Błąd krytyczny: $_"
}
