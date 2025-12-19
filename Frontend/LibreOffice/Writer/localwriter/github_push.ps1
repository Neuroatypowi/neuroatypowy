# =============================================================================
# POLONISTA - Skrypt GitHub CLI dla Windows PowerShell
# =============================================================================
# Zapisz jako: C:\Users\mszew\neuroatypowy\github_push.ps1
# Uruchom jako Administrator w PowerShell
# =============================================================================

# Konfiguracja
$LocalPath = "C:\Users\mszew\neuroatypowy"
$RepoName = "Neuroatypowi/neuroatypowy"
$RepoURL = "https://github.com/Neuroatypowi/neuroatypowy.git"
$RepoSSH = "git@github.com:Neuroatypowi/neuroatypowy.git"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "POLONISTA - GitHub Push Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# KROK 1: Sprawdz czy GitHub CLI jest zainstalowany
# -----------------------------------------------------------------------------
Write-Host "[1/7] Sprawdzanie GitHub CLI..." -ForegroundColor Yellow

$ghVersion = $null
try {
    $ghVersion = gh --version 2>$null
} catch {}

if (-not $ghVersion) {
    Write-Host "[BLAD] GitHub CLI nie jest zainstalowane!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instalacja:" -ForegroundColor Yellow
    Write-Host "  msiexec /i gh_2.83.2_windows_amd64.msi /quiet /norestart" -ForegroundColor White
    Write-Host ""
    Write-Host "Lub pobierz z: https://cli.github.com/" -ForegroundColor White
    exit 1
}

Write-Host "  GitHub CLI: $($ghVersion[0])" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 2: Sprawdz czy Git jest zainstalowany
# -----------------------------------------------------------------------------
Write-Host "[2/7] Sprawdzanie Git..." -ForegroundColor Yellow

$gitVersion = $null
try {
    $gitVersion = git --version 2>$null
} catch {}

if (-not $gitVersion) {
    Write-Host "[BLAD] Git nie jest zainstalowany!" -ForegroundColor Red
    Write-Host "Pobierz z: https://git-scm.com/download/win" -ForegroundColor White
    exit 1
}

Write-Host "  $gitVersion" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 3: Autoryzacja GitHub CLI
# -----------------------------------------------------------------------------
Write-Host "[3/7] Sprawdzanie autoryzacji GitHub..." -ForegroundColor Yellow

$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Wymagana autoryzacja. Uruchamiam login..." -ForegroundColor Yellow
    Write-Host ""
    gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BLAD] Autoryzacja nie powiodla sie!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  Autoryzacja: OK" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 4: Przejdz do katalogu lokalnego
# -----------------------------------------------------------------------------
Write-Host "[4/7] Przechodzenie do katalogu..." -ForegroundColor Yellow

if (-not (Test-Path $LocalPath)) {
    Write-Host "[BLAD] Katalog nie istnieje: $LocalPath" -ForegroundColor Red
    exit 1
}

Set-Location $LocalPath
Write-Host "  Katalog: $LocalPath" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 5: Inicjalizacja Git (jesli potrzebna)
# -----------------------------------------------------------------------------
Write-Host "[5/7] Inicjalizacja repozytorium Git..." -ForegroundColor Yellow

if (-not (Test-Path ".git")) {
    Write-Host "  Tworzenie nowego repozytorium Git..." -ForegroundColor Yellow
    git init
    git branch -M main
} else {
    Write-Host "  Repozytorium Git istnieje" -ForegroundColor Green
}

# Czyszczenie zablokowanego rebase (jeśli istnieje)
$rebaseMergePath = Join-Path ".git" "rebase-merge"
if (Test-Path $rebaseMergePath) {
    Write-Host "  [UWAGA] Wykryto zablokowany rebase. Czyszczenie..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $rebaseMergePath -Recurse -Force
        Write-Host "  Usunięto katalog rebase-merge" -ForegroundColor Green
    } catch {
        Write-Host "  [BŁĄD] Nie można usunąć rebase-merge: $_" -ForegroundColor Red
    }
}

# Upewnij sie ze .gitignore istnieje
if (-not (Test-Path ".gitignore")) {
    Write-Host "  [UWAGA] Brak pliku .gitignore!" -ForegroundColor Yellow
    Write-Host "  Utworz plik .gitignore przed wyslaniem!" -ForegroundColor Yellow
}

# Sprawdz czy .env nie jest w staging
$envInGit = git ls-files .env 2>$null
if ($envInGit) {
    Write-Host "  [UWAGA] Usuwam .env z Git tracking..." -ForegroundColor Yellow
    git rm --cached .env 2>$null
}

# -----------------------------------------------------------------------------
# KROK 6: Dodaj remote origin (jesli nie istnieje)
# -----------------------------------------------------------------------------
Write-Host "[6/7] Konfiguracja remote origin..." -ForegroundColor Yellow

$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Host "  Remote istnieje: $existingRemote" -ForegroundColor Green
    Write-Host "  Aktualizuje URL..." -ForegroundColor Yellow
    git remote set-url origin $RepoURL
} else {
    Write-Host "  Dodawanie remote origin..." -ForegroundColor Yellow
    git remote add origin $RepoURL
}

Write-Host "  Remote URL: $RepoURL" -ForegroundColor Green

# -----------------------------------------------------------------------------
# KROK 7: Commit i Force Push
# -----------------------------------------------------------------------------
Write-Host "[7/7] Wysylanie do GitHub (Force Push)..." -ForegroundColor Yellow
Write-Host ""

# Dodaj wszystkie pliki
git add --all

# Sprawdz czy sa zmiany do commit
$status = git status --porcelain
if ($status) {
    # Utworz commit z data i czasem
    $commitMsg = "POLONISTA: Aktualizacja $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git commit -m $commitMsg
    Write-Host "  Commit: $commitMsg" -ForegroundColor Green
} else {
    Write-Host "  Brak zmian do commit" -ForegroundColor Yellow
}

# Force push do GitHub
Write-Host ""
Write-Host "  Wykonuje: git push --force origin main" -ForegroundColor Cyan
Write-Host ""

git push --force origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "SUKCES! Pliki wyslane do GitHub." -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Repozytorium: https://github.com/$RepoName" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "[BLAD] Push nie powiodl sie!" -ForegroundColor Red
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mozliwe rozwiazania:" -ForegroundColor Yellow
    Write-Host "1. Sprawdz czy masz uprawnienia do repozytorium" -ForegroundColor White
    Write-Host "2. Uruchom: gh auth login" -ForegroundColor White
    Write-Host "3. Sprawdz polaczenie internetowe" -ForegroundColor White
    exit 1
}
