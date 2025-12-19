# Skrypt PowerShell gh.ps1

$basePath = "C:\Users\mszew\neuroatypowy"
$pdfPath = Join-Path $basePath "pdf"

$dirs = @( "docs", "assets", "filters", "templates", "tools", ".github\workflows" )

$descriptions = @{
    "docs" = "Zawiera pliki źródłowe w formacie Markdown, podstawowe materiały do tworzenia dokumentów."
    "assets" = "Zawiera logo i grafiki wykorzystywane w projekcie, np. do dokumentów i stron."
    "filters" = "Zawiera filtry Lua używane przez Pandoc do przetwarzania dokumentów."
    "templates" = "Zawiera szablony LaTeX do generowania dokumentów PDF/A z zachowaniem stylów Neuroatypowi."
    "tools" = "Zawiera skrypty PowerShell wspomagające automatyzację i zarządzanie projektem."
    ".github\workflows" = "Zawiera definicje workflow GitHub Actions do automatyzacji CI/CD."
}

$logFile = Join-Path $basePath "ghlog.txt"

function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

try {
    Log-Message "Start skryptu gh.ps1"

    if (-not (Test-Path $pdfPath)) {
        New-Item -ItemType Directory -Path $pdfPath | Out-Null
        Log-Message "Utworzono katalog: $pdfPath"
    } else {
        Log-Message "Katalog już istnieje: $pdfPath"
    }

    foreach ($dir in $dirs) {
        $fullPath = Join-Path $pdfPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath | Out-Null
            Log-Message "Utworzono katalog: $fullPath"
        } else {
            Log-Message "Katalog już istnieje: $fullPath"
        }

        $readmePath = Join-Path $fullPath "README.md"
        $description = $descriptions[$dir]
        if (-not $description) { $description = "Opis katalogu $dir." }

        $contentLines = @(
            "# $dir",
            "",
            $description,
            "",
            "*Plik wygenerowany automatycznie przez skrypt gh.ps1.*"
        )
        $contentCRLF = ($contentLines -join "`r`n") + "`r`n"

        try {
            Set-Content -Path $readmePath -Value $contentCRLF -Encoding UTF8
            Log-Message "Utworzono lub zaktualizowano plik: $readmePath"
        } catch {
            Log-Message "Błąd zapisu pliku README.md: $readmePath - $_"
        }
    }

    $oldDir = Join-Path $basePath "neuroatypowy"
    if (Test-Path $oldDir) {
        try {
            Remove-Item -Path $oldDir -Recurse -Force
            Log-Message "Usunięto nieaktualny katalog: $oldDir"
        } catch {
            Log-Message "Błąd usuwania katalogu $oldDir - $_"
        }
    } else {
        Log-Message "Nie znaleziono katalogu neuroatypowy do usunięcia"
    }

    Set-Location $basePath
    git config user.name "Neuroatypowi Bot"
    git config user.email "bot@neuroatypowi.org"

    Log-Message "Dodawanie zmian do repozytorium Git..."
    git add . | Out-Null

    $commitMessage = "Aktualizacja struktury projektu $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git commit -m "$commitMessage" | Out-Null
    Log-Message "Commit utworzony: $commitMessage"

    Log-Message "Wypychanie zmian na GitHub..."
    git push | Out-Null
    Log-Message "Push zakończony sukcesem"

    Log-Message "Skrypt zakończył działanie."
} catch {
    Log-Message "Nieoczekiwany błąd: $_"
}
