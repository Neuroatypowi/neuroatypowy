# AIWRITER - Framework AI dla LibreOffice Writer

## Streszczenie

*AIWRITER to jak zestaw inteligentnych pomocników, którzy pomagają pisać lepsze dokumenty. Pierwszy pomocnik nazywa się POLONISTA - zamienia trudne urzędowe teksty na prosty język, zrozumiały dla każdego. Zaznaczasz tekst, klikasz przycisk, i tekst staje się prosty.*

![AIWRITER Logo](https://neuroatypowi.org/aiwriter-logo.png)

---

## Spis Treści

1. [Wymagania Systemowe](#1-wymagania-systemowe)
2. [Struktura Projektu](#2-struktura-projektu)
3. [Pobieranie](#3-pobieranie)
4. [Instalacja Windows](#4-instalacja-windows)
5. [Konfiguracja Klucza API](#5-konfiguracja-klucza-api)
6. [Użycie w LibreOffice](#6-użycie-w-libreoffice)
7. [Tworzenie Pakietu OXT](#7-tworzenie-pakietu-oxt)
8. [Rozwiązywanie Problemów](#8-rozwiązywanie-problemów)
9. [Licencja](#9-licencja)
10. [Bibliografia](#10-bibliografia)

---

## 1. Wymagania Systemowe

### 1.1 Wymagania Minimalne

| Składnik | Wymaganie | Uwagi |
|----------|-----------|-------|
| **System** | Windows 10/11 | x64 Bit (64-bitowy) |
| **LibreOffice** | 24.x lub 25.x | x64 Bit |
| **Python** | 3.8+ | Wbudowany w LibreOffice |
| **RAM** | 4 GB | 8 GB zalecane |
| **Internet** | Wymagany | Do komunikacji z API NVIDIA |
| **Konto NVIDIA** | Developer | Darmowe, https://developer.nvidia.com |

### 1.2 Wymagane Oprogramowanie

| Program | Wersja | Link do pobrania |
|---------|--------|------------------|
| LibreOffice | 25.2.x x64 | https://www.libreoffice.org/download/ |
| PowerShell | 5.1+ | Wbudowany w Windows |
| Git (opcjonalnie) | 2.40+ | https://git-scm.com/download/win |

### 1.3 Sprawdzenie Wersji LibreOffice

1. Otwórz LibreOffice Writer
2. Menu: **Pomoc** → **Informacje o LibreOffice**
3. Sprawdź:
   - Wersja: `25.x.x.x` lub `24.x.x.x`
   - Architektura: `x64` (64-bit)

---

## 2. Struktura Projektu

### 2.1 Struktura Katalogów AIWRITER

```
AIWRITER/                           # Główny katalog projektu
├── __init__.py                     # Definicja pakietu Python
├── polonista_menu.py               # Menu POLONISTA (makra LibreOffice)
├── .env                            # Klucz API (PRYWATNY - nie wysyłaj!)
├── .env.example                    # Szablon konfiguracji
├── .gitignore                      # Blokada plików prywatnych
├── install_aiwriter.ps1            # Skrypt instalacyjny Windows
├── README.md                       # Ta dokumentacja
│
└── backends/                       # Backendy AI
    ├── __init__.py                 # Rejestracja backendów
    └── nvidia_nim_backend.py       # Backend NVIDIA NIM (Bielik-11B)
```

### 2.2 Ścieżka Instalacji u Użytkownika

**Windows:**
```
C:\Users\<USERNAME>\AppData\Roaming\LibreOffice\4\user\Scripts\python\AIWRITER\
```

Lub używając zmiennej środowiskowej:
```
%APPDATA%\LibreOffice\4\user\Scripts\python\AIWRITER\
```

**Linux:**
```
~/.config/libreoffice/4/user/Scripts/python/AIWRITER/
```

**macOS:**
```
~/Library/Application Support/LibreOffice/4/user/Scripts/python/AIWRITER/
```

### 2.3 Struktura po Instalacji

```
%APPDATA%\LibreOffice\4\user\Scripts\python\
└── AIWRITER\
    ├── __init__.py                 # [WYMAGANY]
    ├── polonista_menu.py           # [WYMAGANY] - menu makr
    ├── .env                        # [WYMAGANY] - Twój klucz API
    ├── .env.example                # [OPCJONALNY] - szablon
    └── backends\
        ├── __init__.py             # [WYMAGANY]
        └── nvidia_nim_backend.py   # [WYMAGANY] - backend AI
```

---

## 3. Pobieranie

### 3.1 Z GitHub (Zalecane)

**Repozytorium:**
```
https://github.com/Neuroatypowi/AIWRITER
```

**Klonowanie Git:**
```bash
git clone https://github.com/Neuroatypowi/AIWRITER.git
```

**Pobieranie ZIP:**
1. Otwórz: https://github.com/Neuroatypowi/AIWRITER
2. Kliknij: **Code** → **Download ZIP**
3. Rozpakuj archiwum

### 3.2 Pliki do Pobrania

| Plik | Opis | Rozmiar |
|------|------|---------|
| `AIWRITER-main.zip` | Pełne źródła projektu | ~50 KB |
| `AIWRITER.oxt` | Rozszerzenie LibreOffice (jeśli dostępne) | ~30 KB |

---

## 4. Instalacja Windows

### 4.1 Metoda A: Skrypt Automatyczny (Zalecane)

**Krok 1:** Pobierz projekt z GitHub

**Krok 2:** Otwórz PowerShell jako Administrator
- Kliknij **Start**
- Wpisz `PowerShell`
- Kliknij prawym przyciskiem → **Uruchom jako administrator**

**Krok 3:** Przejdź do katalogu z projektem
```powershell
cd C:\Pobrane\AIWRITER
```

**Krok 4:** Uruchom skrypt instalacyjny
```powershell
.\install_aiwriter.ps1
```

**Krok 5:** Postępuj zgodnie z instrukcjami na ekranie

### 4.2 Metoda B: Instalacja Ręczna

**Krok 1:** Otwórz Eksplorator Windows

**Krok 2:** Przejdź do:
```
%APPDATA%\LibreOffice\4\user\Scripts\python\
```
(Wklej tę ścieżkę w pasek adresu)

**Krok 3:** Utwórz katalog `AIWRITER`

**Krok 4:** Skopiuj pliki:
```
AIWRITER\
├── __init__.py
├── polonista_menu.py
├── .env.example
└── backends\
    ├── __init__.py
    └── nvidia_nim_backend.py
```

**Krok 5:** Skopiuj `.env.example` jako `.env`

**Krok 6:** Edytuj `.env` i wklej klucz API

### 4.3 Weryfikacja Instalacji

1. Zamknij **WSZYSTKIE** okna LibreOffice
2. Poczekaj 10 sekund
3. Otwórz LibreOffice Writer
4. Menu: **Narzędzia** → **Makra** → **Uruchom makro**
5. Rozwiń: **Moje makra** → **AIWRITER**
6. Powinien być widoczny: **polonista_menu**

---

## 5. Konfiguracja Klucza API

### 5.1 Pobranie Klucza NVIDIA

1. Otwórz: https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct
2. Kliknij **"Get API Key"**
3. Zaloguj się lub utwórz konto NVIDIA (darmowe)
4. Skopiuj klucz (zaczyna się od `nvapi-`)

### 5.2 Zapisanie Klucza

1. Otwórz plik `.env` w Notatniku:
   ```
   %APPDATA%\LibreOffice\4\user\Scripts\python\AIWRITER\.env
   ```

2. Zamień zawartość na:
   ```ini
   NVIDIA_API_KEY=nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ
   ```

3. Zapisz plik (Ctrl+S)

### 5.3 Weryfikacja Klucza

1. W LibreOffice Writer uruchom makro:
2. **AIWRITER** → **polonista_menu** → **SprawdzKonfiguracje**
3. Powinien pojawić się komunikat "Konfiguracja OK"

---

## 6. Użycie w LibreOffice

### 6.1 Upraszczanie Zaznaczonego Tekstu

1. Otwórz dokument w Writer
2. **Zaznacz** trudny tekst
3. Menu: **Narzędzia** → **Makra** → **Uruchom makro**
4. Wybierz: **AIWRITER** → **polonista_menu** → **RedagujZaznaczenie**
5. Kliknij **Uruchom**
6. Tekst zostanie automatycznie uproszczony

### 6.2 Dostępne Funkcje POLONISTA

| Funkcja | Opis |
|---------|------|
| `RedagujZaznaczenie` | Upraszcza zaznaczony tekst |
| `RedagujCayDokument` | Upraszcza cały dokument |
| `PokazInformacje` | Wyświetla informacje o programie |
| `SprawdzKonfiguracje` | Sprawdza klucz API |
| `TestPolaczenia` | Testuje połączenie z NVIDIA |
| `OtworzStroneNVIDIA` | Otwiera stronę do pobrania klucza |
| `OtworzStroneNeuroatypowi` | Otwiera stronę projektu |

---

## 7. Tworzenie Pakietu OXT

### 7.1 Pliki do Spakowania jako AIWRITER.oxt

Pakiet `.oxt` to archiwum ZIP ze zmienioną nazwą rozszerzenia. Musi zawierać:

```
AIWRITER.oxt (ZIP)
├── META-INF/
│   └── manifest.xml                # [WYMAGANY] Manifest pakietu
├── description.xml                  # [WYMAGANY] Opis rozszerzenia
├── AIWRITER/
│   ├── __init__.py
│   ├── polonista_menu.py
│   └── backends/
│       ├── __init__.py
│       └── nvidia_nim_backend.py
├── registration/
│   └── license.txt                  # [OPCJONALNY] Licencja
└── icons/
    └── aiwriter.png                 # [OPCJONALNY] Ikona
```

### 7.2 Zawartość META-INF/manifest.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">
    <manifest:file-entry manifest:full-path="AIWRITER/" manifest:media-type="application/vnd.sun.star.framework-script"/>
    <manifest:file-entry manifest:full-path="AIWRITER/polonista_menu.py" manifest:media-type="application/vnd.sun.star.framework-script"/>
    <manifest:file-entry manifest:full-path="AIWRITER/backends/" manifest:media-type="application/vnd.sun.star.framework-script"/>
    <manifest:file-entry manifest:full-path="AIWRITER/backends/nvidia_nim_backend.py" manifest:media-type="application/vnd.sun.star.framework-script"/>
</manifest:manifest>
```

### 7.3 Zawartość description.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<description xmlns="http://openoffice.org/extensions/description/2006">
    <identifier value="org.neuroatypowi.aiwriter"/>
    <version value="2.1.0"/>
    <display-name>
        <name lang="pl">AIWRITER - Framework AI dla LibreOffice</name>
        <name lang="en">AIWRITER - AI Framework for LibreOffice</name>
    </display-name>
    <publisher>
        <name xlink:href="https://neuroatypowi.org" lang="pl">Stowarzyszenie Neuroatypowi</name>
    </publisher>
    <dependencies>
        <LibreOffice-minimal-version value="24.0"/>
    </dependencies>
</description>
```

### 7.4 Polecenia do Utworzenia OXT

**PowerShell:**
```powershell
# Przejdz do katalogu projektu
cd C:\Projekty\AIWRITER

# Utworz strukture OXT
mkdir OXT_BUILD\META-INF -Force
mkdir OXT_BUILD\AIWRITER\backends -Force

# Kopiuj pliki
Copy-Item manifest.xml OXT_BUILD\META-INF\
Copy-Item description.xml OXT_BUILD\
Copy-Item AIWRITER\*.py OXT_BUILD\AIWRITER\
Copy-Item AIWRITER\backends\*.py OXT_BUILD\AIWRITER\backends\

# Spakuj jako ZIP
Compress-Archive -Path OXT_BUILD\* -DestinationPath AIWRITER.zip -Force

# Zmien rozszerzenie na .oxt
Rename-Item AIWRITER.zip AIWRITER.oxt -Force
```

---

## 8. Rozwiązywanie Problemów

### Problem 1: "Backend NVIDIA NIM nie jest dostępny"

**Przyczyna:** Błąd importu modułu backends

**Rozwiązanie:**
1. Sprawdź czy wszystkie pliki są na miejscu:
   ```
   %APPDATA%\LibreOffice\4\user\Scripts\python\AIWRITER\
   ├── __init__.py
   ├── polonista_menu.py
   └── backends\
       ├── __init__.py
       └── nvidia_nim_backend.py
   ```
2. Upewnij się, że pliki mają kodowanie **UTF-8**
3. Zamknij **WSZYSTKIE** okna LibreOffice i poczekaj 10 sekund
4. Otwórz ponownie Writer

### Problem 2: Makra nie są widoczne

**Rozwiązanie:**
1. Sprawdź ścieżkę instalacji
2. Sprawdź czy nazwa katalogu to dokładnie `AIWRITER` (wielkość liter!)
3. Uruchom ponownie LibreOffice

### Problem 3: Błąd klucza API

**Rozwiązanie:**
1. Sprawdź czy klucz zaczyna się od `nvapi-`
2. Sprawdź czy w pliku `.env` nie ma spacji przed/po `=`
3. Sprawdź czy plik `.env` jest w katalogu `AIWRITER\`

### Problem 4: Błąd 429 (Rate Limit)

**Rozwiązanie:**
- Limit NVIDIA NIM: 40 zapytań/minutę
- Poczekaj 1-2 minuty przed kolejną próbą
- Przetwarzaj mniejsze fragmenty tekstu

---

## 9. Licencja

MIT License

Copyright (c) 2024 Stowarzyszenie Zwykłe "Neuroatypowi"

---

## 10. Bibliografia

| Cytowanie APA 7 | QR + Link |
|-----------------|-----------|
| NVIDIA. (2024). *NIM API Documentation*. NVIDIA Developer. https://docs.api.nvidia.com | tiny.pl/nvidia-nim |
| SpeakLeash. (2024). *Bielik-11B-v2.6-Instruct Model Card*. Hugging Face. https://huggingface.co/speakleash/bielik-11b-v2.6-instruct | tiny.pl/bielik |
| The Document Foundation. (2024). *LibreOffice Python Scripting Guide*. https://wiki.documentfoundation.org/Macros/Python_Guide | tiny.pl/lo-python |
| Plain Language Association. (2023). *Plain Language Guidelines*. https://plainlanguagenetwork.org | tiny.pl/plain |

---

**Autor:** Stowarzyszenie Zwykłe "Neuroatypowi"  
**Strona:** https://neuroatypowi.org  
**Kontakt:** kontakt@neuroatypowi.org  
**Wersja:** 2.1.0  
**Data:** 2024-12
