$logFile = "C:\Users\mszew\neuroatypowy\gs.log"

function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $message
}

$basePath = "C:\Users\mszew\neuroatypowy"

$folders = @(
    "pdf/docs",
    "pdf/assets",
    "pdf/filters",
    "pdf/templates",
    "pdf/tools",
    "pdf/.github/workflows"
)

try {
    foreach ($folder in $folders) {
        $fullPath = Join-Path -Path $basePath -ChildPath $folder
        if (-not (Test-Path -Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath | Out-Null
            Log-Message "Utworzono katalog: $fullPath"
        } else {
            Log-Message "Katalog już istnieje: $fullPath"
        }
    }

    # Usuwanie nieaktualnych katalogów
    $oldFolder = Join-Path -Path $basePath -ChildPath "neuroatypowy"
    if (Test-Path -Path $oldFolder) {
        Remove-Item -Recurse -Force $oldFolder
        Log-Message "Usunięto nieaktualny katalog: neuroatypowy"
    } else {
        Log-Message "Nie znaleziono katalogu neuroatypowy do usunięcia"
    }

    # Dodawanie wszystkich zmian do repozytorium Git
    Log-Message "Dodawanie zmian do repozytorium Git..."
    git add . 2>&1 | ForEach-Object { Log-Message "git add: $_" }

    # Tworzenie commita z opisem
    $commitMessage = "Aktualizacja struktury projektu $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Log-Message "Tworzenie commita z wiadomością: $commitMessage"
    git commit -m "$commitMessage" 2>&1 | ForEach-Object { Log-Message "git commit: $_" }

    # Wypychanie zmian na GitHub
    Log-Message "Wypychanie zmian na GitHub..."
    git push origin main 2>&1 | ForEach-Object { Log-Message "git push: $_" }
}
catch {
    Log-Message "Wystąpił błąd: $_"
}

Log-Message "Skrypt zakończył działanie."