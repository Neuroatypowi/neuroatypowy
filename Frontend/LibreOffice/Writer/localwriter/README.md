# POLONISTA + localwriter - Kompletny Przewodnik Instalacji

## Streszczenie

*POLONISTA to jak tłumacz, który zamienia trudne urzędowe teksty na prosty język, zrozumiały dla każdego. Działa wewnątrz programu LibreOffice Writer - zaznaczasz trudny tekst, klikasz przycisk, i tekst staje się prosty.*

---

## Spis Treści

1. [Wymagania](#1-wymagania)
2. [Struktura Plików](#2-struktura-plików)
3. [Instalacja Krok po Kroku](#3-instalacja-krok-po-kroku)
4. [Konfiguracja Klucza API](#4-konfiguracja-klucza-api)
5. [Użycie w LibreOffice](#5-użycie-w-libreoffice)
6. [Komendy GitHub CLI](#6-komendy-github-cli)
7. [Rozwiązywanie Problemów](#7-rozwiązywanie-problemów)
8. [Bibliografia](#8-bibliografia)

---

## 1. Wymagania

| Składnik | Wersja | Link |
|----------|--------|------|
| LibreOffice | 7.0+ | https://www.libreoffice.org |
| Python | 3.7+ (wbudowany w LO) | - |
| Konto NVIDIA | Developer | https://developer.nvidia.com |
| Git (opcjonalnie) | 2.40+ | https://git-scm.com |
| GitHub CLI (opcjonalnie) | 2.83+ | https://cli.github.com |

---

## 2. Struktura Plików

### 2.1 Katalog docelowy

**Windows:**
```
%APPDATA%\LibreOffice\4\user\Scripts\python\
└── localwriter\
    ├── __init__.py
    ├── localwriter.py
    ├── polonista_menu.py
    ├── .env                    ← TWÓJ KLUCZ API (NIE WYSYŁAJ DO GITHUB!)
    ├── .env.example
    ├── .gitignore
    └── backends\
        ├── __init__.py
        └── nvidia_nim_backend.py
```

**Linux/macOS:**
```
~/.config/libreoffice/4/user/Scripts/python/localwriter/
```

### 2.2 Opis plików

| Plik | Opis |
|------|------|
| `localwriter.py` | Główny moduł z poprawionymi błędami |
| `polonista_menu.py` | Menu POLONISTA dla LibreOffice |
| `backends/nvidia_nim_backend.py` | Backend NVIDIA NIM z modelem Bielik |
| `backends/__init__.py` | Rejestracja backendów |
| `.env` | Twój klucz API (POUFNY!) |
| `.env.example` | Szablon pliku .env |
| `.gitignore` | Blokuje wysyłanie .env do GitHub |

---

## 3. Instalacja Krok po Kroku

### Krok 1: Pobierz pliki

**Opcja A - Z GitHub:**
```powershell
# PowerShell (Windows)
cd $env:APPDATA\LibreOffice\4\user\Scripts\python
git clone https://github.com/Neuroatypowi/neuroatypowy.git localwriter
```

**Opcja B - Ręcznie:**
1. Pobierz pliki z repozytorium
2. Rozpakuj do katalogu:
   ```
   C:\Users\TWOJA_NAZWA\AppData\Roaming\LibreOffice\4\user\Scripts\python\localwriter\
   ```

### Krok 2: Utwórz plik .env

1. Skopiuj plik `.env.example` jako `.env`
2. Otwórz `.env` w Notatniku
3. Wklej swój klucz API (patrz sekcja 4)

### Krok 3: Uruchom ponownie LibreOffice

1. Zamknij **WSZYSTKIE** okna LibreOffice
2. Poczekaj 10 sekund
3. Otwórz LibreOffice Writer

### Krok 4: Sprawdź instalację

1. Menu: **Narzędzia** → **Makra** → **Uruchom makro**
2. Rozwiń: **Moje makra** → **localwriter**
3. Powinny być widoczne funkcje:
   - `polonista_menu` (6 funkcji)
   - `localwriter` (3 funkcje)

---

## 4. Konfiguracja Klucza API

### 4.1 Pobierz klucz NVIDIA

1. Otwórz: https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct
2. Kliknij **"Get API Key"**
3. Zaloguj się lub utwórz konto NVIDIA
4. Skopiuj klucz (zaczyna się od `nvapi-`)

### 4.2 Zapisz klucz w pliku .env

Utwórz plik `.env` w katalogu `localwriter\`:

```ini
# POLONISTA - Konfiguracja
NVIDIA_API_KEY=nvapi-TUTAJ_WKLEJ_SWÓJ_KLUCZ
```

**WAŻNE:** 
- Klucz musi zaczynać się od `nvapi-`
- Bez spacji przed i po znaku `=`
- Bez cudzysłowów wokół klucza

### 4.3 Weryfikacja

W LibreOffice uruchom makro:
- **polonista_menu** → **SprawdzKonfiguracje**

---

## 5. Użycie w LibreOffice

### 5.1 Upraszczanie zaznaczonego tekstu

1. Otwórz dokument Writer
2. **Zaznacz** trudny tekst
3. Menu: **Narzędzia** → **Makra** → **Uruchom makro**
4. Wybierz: **Moje makra** → **localwriter** → **polonista_menu**
5. Wybierz funkcję: **RedagujZaznaczenie**
6. Kliknij: **Uruchom**

### 5.2 Dostępne funkcje

| Funkcja | Opis |
|---------|------|
| `RedagujZaznaczenie` | Upraszcza zaznaczony tekst |
| `RedagujCayDokument` | Upraszcza cały dokument |
| `PokazInformacje` | Wyświetla informacje o programie |
| `SprawdzKonfiguracje` | Sprawdza klucz API |
| `TestPolaczenia` | Testuje połączenie z NVIDIA |
| `PobierzKluczAPI` | Otwiera stronę NVIDIA |

---

## 6. Komendy GitHub CLI

### 6.1 Instalacja GitHub CLI

```powershell
# PowerShell jako Administrator
msiexec /i gh_2.83.2_windows_amd64.msi /quiet /norestart
```

### 6.2 Autoryzacja

```powershell
# Logowanie do GitHub
gh auth login --web --git-protocol https
```

### 6.3 Force Push do repozytorium

```powershell
# Przejdź do katalogu projektu
cd C:\Users\mszew\neuroatypowy

# Inicjalizacja Git (jeśli nowe repo)
git init
git branch -M main

# Dodaj remote
git remote add origin https://github.com/Neuroatypowi/neuroatypowy.git

# Upewnij się że .env NIE jest w Git
git rm --cached .env 2>$null

# Dodaj wszystkie pliki
git add --all

# Commit z opisem
git commit -m "POLONISTA v2.1: Integracja NVIDIA NIM + poprawki localwriter"

# Force Push
git push --force origin main
```

### 6.4 Kompletny skrypt jednokomendowy

```powershell
# UWAGA: Uruchom jako Administrator
# To nadpisze CAŁE zdalne repozytorium!

cd C:\Users\mszew\neuroatypowy; `
git init; `
git branch -M main; `
git remote remove origin 2>$null; `
git remote add origin https://github.com/Neuroatypowi/neuroatypowy.git; `
git rm --cached .env 2>$null; `
git add --all; `
git commit -m "POLONISTA v2.1 $(Get-Date -Format 'yyyy-MM-dd HH:mm')"; `
git push --force origin main
```

### 6.5 Klonowanie repozytorium

```powershell
# HTTPS
gh repo clone Neuroatypowi/neuroatypowy

# SSH
git clone git@github.com:Neuroatypowi/neuroatypowy.git
```

---

## 7. Rozwiązywanie Problemów

### Problem 1: Makra nie są widoczne

**Rozwiązanie:**
1. Sprawdź ścieżkę instalacji
2. Zamknij WSZYSTKIE okna LibreOffice
3. Poczekaj 10 sekund
4. Otwórz ponownie

### Problem 2: Funkcje nie pojawiają się w makrze

**Rozwiązanie:**
1. Sprawdź czy pliki mają kodowanie UTF-8
2. Sprawdź czy ścieżka NIE zawiera polskich znaków
3. Pobierz pliki ponownie

### Problem 3: Błąd "Nieprawidłowy klucz API"

**Rozwiązanie:**
1. Sprawdź czy klucz zaczyna się od `nvapi-`
2. Sprawdź czy nie ma spacji
3. Sprawdź czy plik `.env` jest w katalogu `localwriter\`

### Problem 4: Błąd 429 (Rate Limit)

**Rozwiązanie:**
1. Poczekaj 1-2 minuty
2. Przetwarzaj mniejsze fragmenty tekstu
3. Limit: 40 zapytań na minutę

### Problem 5: Brak połączenia z internetem

**Rozwiązanie:**
1. Sprawdź połączenie internetowe
2. Wyłącz VPN
3. Sprawdź firewall

---

## 8. Bibliografia

| Cytowanie APA 7 | Źródło |
|-----------------|--------|
| NVIDIA. (2024). *NIM API Documentation*. NVIDIA Developer. https://docs.api.nvidia.com | https://tiny.pl/nvidia-nim |
| SpeakLeash. (2024). *Bielik-11B-v2.6-Instruct Model Card*. Hugging Face. https://huggingface.co/speakleash/bielik-11b-v2.6-instruct | https://tiny.pl/bielik |
| The Document Foundation. (2024). *LibreOffice Python Scripting Guide*. LibreOffice Documentation. https://wiki.documentfoundation.org/Macros/Python_Guide | https://tiny.pl/lo-python |
| Plain Language Association International. (2023). *Plain Language Guidelines*. PLAIN. https://plainlanguagenetwork.org | https://tiny.pl/plain |

---

## Licencja

MIT License - Stowarzyszenie Zwykłe "Neuroatypowi"

https://neuroatypowi.org

---

*Ostatnia aktualizacja: 2024-12*
