$basePath = "C:\Users\mszew\neuroatypowy"

$folders = @(
    "pdf/docs",
    "pdf/assets",
    "pdf/filters",
    "pdf/templates",
    "pdf/tools",
    "pdf/.github/workflows"
)

foreach ($folder in $folders) {
    $fullPath = Join-Path -Path $basePath -ChildPath $folder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath | Out-Null
        Write-Host "Utworzono katalog: $fullPath"
    } else {
        Write-Host "Katalog już istnieje: $fullPath"
    }
}

# Usuwanie nieaktualnych katalogów
if (Test-Path -Path "$basePath\neuroatypowy") {
    Remove-Item -Recurse -Force "$basePath\neuroatypowy"
    Write-Host "Usunięto nieaktualny katalog: neuroatypowy"
} else {
    Write-Host "Nie znaleziono katalogu neuroatypowy do usunięcia"
}

# Dodawanie wszystkich zmian do repozytorium Git
Write-Host "Dodawanie zmian do repozytorium Git..."
git add .

# Tworzenie commita z opisem
$commitMessage = "Aktualizacja struktury projektu $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "Tworzenie commita z wiadomością: $commitMessage"
git commit -m $commitMessage

# Wypychanie zmian na GitHub
Write-Host "Wypychanie zmian na GitHub..."
git push origin main
