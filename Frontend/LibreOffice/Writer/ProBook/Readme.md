<!-- ═══════════════════════════════════════════════════════════════════ -->
<!--  README.md — FALSYFIKACJA HP WIN11 26H2                          -->
<!--  Projekt: Audyt_LibreOffice_Hybrydowy.ps1                        -->
<!--  Licencja: MIT · Data: 2026-03-06 · Wersja: 5.0                 -->
<!-- ═══════════════════════════════════════════════════════════════════ -->


<div align="center">

# 🖥️ Audyt LibreOffice — Skrypt Hybrydowy

### 🔍 FALSYFIKACJA HP WIN11 26H2

**Wersja 5.0** · PowerShell 7.6 + Python 3.12 + C# (.NET 11)

[![Licencja: MIT](https://img.shields.io/badge/Licencja-MIT-green.svg)](#-licencja)
[![PowerShell 7.6](https://img.shields.io/badge/PowerShell-7.6_RC1-blue.svg)](#-co-jest-potrzebne)
[![.NET 11](https://img.shields.io/badge/.NET-11_Preview_1-purple.svg)](#-co-jest-potrzebne)
[![LibreOffice 26.2](https://img.shields.io/badge/LibreOffice-26.2.1.2-green.svg)](#-co-jest-potrzebne)

</div>

&nbsp;

---

&nbsp;

## 📋 Spis treści

- [🎯 Co robi ten program](#-co-robi-ten-program)
- [🖼️ Piktogramy i symbole](#️-piktogramy-i-symbole)
- [💻 Co jest potrzebne](#-co-jest-potrzebne)
- [🚀 Jak uruchomić](#-jak-uruchomić)
- [📊 Co sprawdza skrypt — sekcje](#-co-sprawdza-skrypt--sekcje)
- [📝 Przykład raportu](#-przykład-raportu)
- [🔄 Historia zmian](#-historia-zmian)
- [🐛 Znane problemy](#-znane-problemy)
- [❓ Pytania i odpowiedzi](#-pytania-i-odpowiedzi)
- [📜 Licencja](#-licencja)

&nbsp;

---

&nbsp;

## 🎯 Co robi ten program

> **Krótko:** Ten skrypt sprawdza stan komputera i programu LibreOffice.
> Tworzy raport. Raport mówi, co działa dobrze, a co trzeba naprawić. 🩺📄

&nbsp;

Ten program to **narzędzie do sprawdzania komputera**.

Działa jak lekarz, który bada pacjenta.

&nbsp;

Program sprawdza:

- 🔧 **Części komputera** — jaki masz procesor, pamięć, dysk.

- 📦 **Zainstalowane programy** — co jest na komputerze.

- ☕ **Java** — czy masz dobrą wersję (64-bit).

- 📝 **LibreOffice** — jak jest ustawiony twój program biurowy.

- 🧩 **Dodatki** — jakie rozszerzenia masz w LibreOffice.

- 🎮 **Karta graficzna** — czy wspiera DirectX 12.

- 🐍 **Most Python-UNO** — łączy się z LibreOffice od wewnątrz.

&nbsp;

Program jest **hybrydowy**.

To znaczy, że używa trzech języków naraz:

| Język | Do czego służy |
|:------|:---------------|
| 🔵 **PowerShell 7.6** | Główny język. Zbiera dane z systemu. |
| 🟡 **Python 3.12** | Łączy się z LibreOffice (most UNO). |
| 🟣 **C# / .NET 11** | Sprawdza kartę graficzną (DirectX 12). |

&nbsp;

---

&nbsp;

## 🖼️ Piktogramy i symbole

Poniżej znajdują się symbole, które pomagają zrozumieć znaczenie ikon w projekcie.

Każdy symbol ma opis słowny.

&nbsp;

### Symbole emoji jako AAC

| Symbol | Znaczenie | Opis prosty |
|:------:|:----------|:------------|
| ▶️ | **Start** | Uruchom program |
| 💾 | **Zapisz** | Zapisz plik na dysku |
| ❌ | **Błąd** | Coś poszło nie tak |
| ✅ | **Sukces** | Wszystko działa dobrze |
| ⚠️ | **Uwaga** | Bądź ostrożny |
| 📋 | **Raport** | Wynik sprawdzenia |
| 🔍 | **Szukaj** | Program szuka informacji |
| ⏳ | **Czekaj** | Program pracuje, poczekaj |
| 🛑 | **Stop** | Zatrzymaj program |
| ℹ️ | **Informacja** | Wiadomość dla użytkownika |

&nbsp;

### Ikony SVG dla kluczowych akcji

Poniższe ikony można użyć w interfejsie lub dokumentacji.

GitHub wyświetli je w podglądzie.

&nbsp;

**▶️ START — Uruchom skrypt:**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#22c55e" stroke="#166534" stroke-width="2"/>
  <polygon points="24,16 24,48 50,32" fill="white"/>
</svg>
```

<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDY0IDY0Ij4KICA8Y2lyY2xlIGN4PSIzMiIgY3k9IjMyIiByPSIzMCIgZmlsbD0iIzIyYzU1ZSIgc3Ryb2tlPSIjMTY2NTM0IiBzdHJva2Utd2lkdGg9IjIiLz4KICA8cG9seWdvbiBwb2ludHM9IjI0LDE2IDI0LDQ4IDUwLDMyIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4=" alt="Ikona START — zielone kółko z białym trójkątem (play)" width="64" height="64" />

&nbsp;

**💾 ZAPISZ — Plik zapisany na dysku:**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect x="2" y="2" width="60" height="60" rx="6" fill="#3b82f6" stroke="#1e40af" stroke-width="2"/>
  <rect x="14" y="2" width="28" height="22" rx="2" fill="#bfdbfe" stroke="#1e40af" stroke-width="1"/>
  <rect x="12" y="34" width="40" height="22" rx="2" fill="white" stroke="#1e40af" stroke-width="1"/>
  <rect x="34" y="6" width="6" height="14" rx="1" fill="#1e40af"/>
</svg>
```

<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDY0IDY0Ij4KICA8cmVjdCB4PSIyIiB5PSIyIiB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHJ4PSI2IiBmaWxsPSIjM2I4MmY2IiBzdHJva2U9IiMxZTQwYWYiIHN0cm9rZS13aWR0aD0iMiIvPgogIDxyZWN0IHg9IjE0IiB5PSIyIiB3aWR0aD0iMjgiIGhlaWdodD0iMjIiIHJ4PSIyIiBmaWxsPSIjYmZkYmZlIiBzdHJva2U9IiMxZTQwYWYiIHN0cm9rZS13aWR0aD0iMSIvPgogIDxyZWN0IHg9IjEyIiB5PSIzNCIgd2lkdGg9IjQwIiBoZWlnaHQ9IjIyIiByeD0iMiIgZmlsbD0id2hpdGUiIHN0cm9rZT0iIzFlNDBhZiIgc3Ryb2tlLXdpZHRoPSIxIi8+CiAgPHJlY3QgeD0iMzQiIHk9IjYiIHdpZHRoPSI2IiBoZWlnaHQ9IjE0IiByeD0iMSIgZmlsbD0iIzFlNDBhZiIvPgo8L3N2Zz4=" alt="Ikona ZAPISZ — niebieski kwadrat z dyskietką" width="64" height="64" />

&nbsp;

**❌ BŁĄD — Coś nie działa:**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#ef4444" stroke="#991b1b" stroke-width="2"/>
  <line x1="20" y1="20" x2="44" y2="44" stroke="white" stroke-width="5" stroke-linecap="round"/>
  <line x1="44" y1="20" x2="20" y2="44" stroke="white" stroke-width="5" stroke-linecap="round"/>
</svg>
```

<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDY0IDY0Ij4KICA8Y2lyY2xlIGN4PSIzMiIgY3k9IjMyIiByPSIzMCIgZmlsbD0iI2VmNDQ0NCIgc3Ryb2tlPSIjOTkxYjFiIiBzdHJva2Utd2lkdGg9IjIiLz4KICA8bGluZSB4MT0iMjAiIHkxPSIyMCIgeDI9IjQ0IiB5Mj0iNDQiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iNSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgPGxpbmUgeDE9IjQ0IiB5MT0iMjAiIHgyPSIyMCIgeTI9IjQ0IiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgo8L3N2Zz4=" alt="Ikona BŁĄD — czerwone kółko z białym krzyżykiem (X)" width="64" height="64" />

&nbsp;

**✅ SUKCES — Wszystko dobrze:**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#22c55e" stroke="#166534" stroke-width="2"/>
  <polyline points="18,34 28,44 46,22" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDY0IDY0Ij4KICA8Y2lyY2xlIGN4PSIzMiIgY3k9IjMyIiByPSIzMCIgZmlsbD0iIzIyYzU1ZSIgc3Ryb2tlPSIjMTY2NTM0IiBzdHJva2Utd2lkdGg9IjIiLz4KICA8cG9seWxpbmUgcG9pbnRzPSIxOCwzNCAyOCw0NCA0NiwyMiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSI1IiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KPC9zdmc+" alt="Ikona SUKCES — zielone kółko z białym ptaszkiem (check)" width="64" height="64" />

&nbsp;

**⚠️ UWAGA — Ostrzeżenie:**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <polygon points="32,4 60,58 4,58" fill="#f59e0b" stroke="#92400e" stroke-width="2" stroke-linejoin="round"/>
  <line x1="32" y1="22" x2="32" y2="40" stroke="#92400e" stroke-width="4" stroke-linecap="round"/>
  <circle cx="32" cy="49" r="3" fill="#92400e"/>
</svg>
```

<img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDY0IDY0Ij4KICA8cG9seWdvbiBwb2ludHM9IjMyLDQgNjAsNTggNCw1OCIgZmlsbD0iI2Y1OWUwYiIgc3Ryb2tlPSIjOTI0MDBlIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KICA8bGluZSB4MT0iMzIiIHkxPSIyMiIgeDI9IjMyIiB5Mj0iNDAiIHN0cm9rZT0iIzkyNDAwZSIgc3Ryb2tlLXdpZHRoPSI0IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICA8Y2lyY2xlIGN4PSIzMiIgY3k9IjQ5IiByPSIzIiBmaWxsPSIjOTI0MDBlIi8+Cjwvc3ZnPg==" alt="Ikona UWAGA — żółty trójkąt z wykrzyknikiem" width="64" height="64" />

&nbsp;

---

&nbsp;

## 💻 Co jest potrzebne

Zanim uruchomisz skrypt, upewnij się, że masz te rzeczy.

Skrypt sprawdzi sam, ale lepiej wiedzieć wcześniej.

&nbsp;

### Wymagane programy

| Program | Wersja | Gdzie pobrać |
|:--------|:-------|:-------------|
| ▶️ **PowerShell** | 7.6 RC1 lub nowszy | `winget install Microsoft.PowerShell` |
| 📝 **LibreOffice** | 26.2.1.2 (X86_64) | [libreoffice.org](https://www.libreoffice.org/) |
| 🐍 **Python** | 3.13+ (64-bit) — opcjonalny | [python.org](https://www.python.org/) |

&nbsp;

### Wymagany system

| Element | Wartość |
|:--------|:--------|
| 🪟 **System** | Windows 11 (23H2 lub 26H2) |
| ⚙️ **.NET** | 11.0 Preview 1 (do sekcji DirectX) |
| 🖥️ **Architektura** | x64 (64-bit) |

&nbsp;

> ℹ️ **Uwaga:** Python jest potrzebny tylko do sekcji 7 (most UNO).
> Bez Pythona skrypt działa, ale pomija tę sekcję.

&nbsp;

---

&nbsp;

## 🚀 Jak uruchomić

Wykonaj te kroki po kolei.

Każdy krok to jedna czynność.

&nbsp;

### Krok 1 — Zamknij LibreOffice 🛑

Zamknij wszystkie okna LibreOffice.

Sprawdź w Menedżerze zadań, czy proces `soffice.bin` nie działa.

&nbsp;

### Krok 2 — Otwórz PowerShell ▶️

Kliknij prawym przyciskiem na menu Start.

Wybierz **Terminal (Administrator)**.

Upewnij się, że to PowerShell 7 (`pwsh`), nie stary PowerShell 5.

&nbsp;

### Krok 3 — Przejdź do folderu 📁

Wpisz polecenie, które wskazuje folder ze skryptem:

```powershell
cd $HOME\Downloads
```

&nbsp;

### Krok 4 — Uruchom skrypt ▶️

Wpisz:

```powershell
.\Audyt_LibreOffice_Hybrydowy.ps1
```

&nbsp;

### Krok 5 — Poczekaj ⏳

Skrypt pracuje od 30 sekund do 2 minut.

Na ekranie zobaczysz postęp pracy.

Kolory znaczą:

- 🟦 **Niebieski** — nagłówek sekcji.
- 🟩 **Zielony** — sukces, dobrze.
- 🟨 **Żółty** — uwaga, możliwy problem.
- 🟥 **Czerwony** — błąd, coś nie działa.

&nbsp;

### Krok 6 — Sprawdź wynik 📋

Po zakończeniu na Pulpicie pojawią się pliki:

| Plik | Co zawiera |
|:-----|:-----------|
| 💾 `Raport_Serwisowy_XXXXXXXX.txt` | Główny raport z audytu |
| 🐍 `diagnoza_uno_XXXXXXXX.py` | Skrypt Pythona (do mostu UNO) |
| 📄 `Raport_XCU_XXXXXXXX.txt` | Kopia ustawień LibreOffice |

&nbsp;

> ✅ **Sukces!** Jeśli na końcu zobaczysz zielony napis `ZAKOŃCZONO POMYŚLNIE`,
> to wszystko działa dobrze.

&nbsp;

---

&nbsp;

## 📊 Co sprawdza skrypt — sekcje

Skrypt ma 8 sekcji.

Każda sekcja sprawdza inną część komputera.

&nbsp;

### Sekcja 1 — 🔧 Części komputera

Sprawdza: producent, model, numer seryjny, procesor, pamięć RAM, dyski, karta graficzna.

> Przykład z testu: HP ProBook 6570b, Intel i3-2370M, 8 GB RAM, Intel HD 3000.

&nbsp;

### Sekcja 2 — 📦 Zainstalowane programy

Szuka programów w rejestrze systemu.

Pokazuje wersje dla obu architektur (x86 i x64).

&nbsp;

### Sekcja 3 — ☕ Test Javy

Sprawdza, czy Java jest 64-bitowa.

Robi to przez analizę wyjścia błędów (STDERR).

To się nazywa **falsyfikacja architektury**.

&nbsp;

### Sekcja 4 — 📝 Ustawienia LibreOffice

Czyta plik `registrymodifications.xcu`.

Sprawdza ważne ustawienia:

- Czy Skia jest włączone.
- Czy ForceSkiaRaster jest aktywne.
- Język interfejsu.
- Automatyczne zapisywanie.
- Ustawienia PDF.

&nbsp;

### Sekcja 5 — 🧩 Rozszerzenia LibreOffice

Szuka plików `.oxt` w folderach użytkownika i systemu.

Używa silnika wyrażeń regularnych PowerShell 7.

&nbsp;

### Sekcja 6 — 🎮 DirectX 12 i .NET (moduł C#)

To jest część hybrydowa.

Skrypt wstrzykuje kod C# przez `Add-Type`.

Kod C# robi:

- Tworzy fabrykę DXGI.
- Sprawdza każdą kartę graficzną.
- Testuje poziomy DirectX 12 (Feature Level).
- Sprawdza funkcje z Agility SDK 1.719.0-preview:
  - Enhanced Barriers
  - VPblit 3DLUT
  - Shader Model 6.9

&nbsp;

### Sekcja 7 — 🐍 Most Python-UNO

Uruchamia LibreOffice w trybie ukrytym (headless).

LibreOffice nasłuchuje na porcie 2002.

Skrypt Pythona łączy się przez gniazdo (socket).

Pobiera informacje o wersjach i rozszerzeniach.

&nbsp;

### Sekcja 8 — 📋 Podsumowanie

Zbiera wyniki ze wszystkich sekcji.

Daje zalecenia:

- ⚠️ Zostaw `ForceSkiaRaster=true` jeśli GPU nie wspiera Vulkan.
- ℹ️ Rozważ aktualizację Agility SDK jeśli D3D12 jest obecny.

&nbsp;

---

&nbsp;

## 📝 Przykład raportu

Poniżej jest fragment raportu z prawdziwego testu.

Test został wykonany 6 marca 2026 roku.

Komputer: **HP ProBook 6570b**.

&nbsp;

```
================================================================
  ZAAWANSOWANY HYBRYDOWY SKRYPT DIAGNOSTYCZNY I AUDYTOWY v5.0
  Srodowisko: Windows 11 / LibreOffice 26.2 / PowerShell 7.6
  Hybrid: PS7.6 RC1 + Python 3.12/LO + C# (.NET 11 Prev.1)
================================================================

--- SEKCJA 1: IDENTYFIKACJA SPRZETOWA ---
  Producent:         Hewlett-Packard
  Model:             HP ProBook 6570b
  Procesor:          Intel(R) Core(TM) i3-2370M CPU @ 2.40GHz
  RAM zainstalowany: 8 GB (2 modul(y))
  GPU: Intel(R) HD Graphics 3000 | VRAM: 2108 MB

--- SEKCJA 6: AUDYT .NET / DirectX 12 ---
  [D3D12/DXGI] Adapter [0]: Intel(R) HD Graphics 3000
  [D3D12/DXGI] D3D12 Feature Level: BRAK WSPARCIA
  [D3D12/DXGI] Adapter [1]: Microsoft Basic Render Driver
  [D3D12/DXGI] D3D12 Feature Level: 12_1
  [D3D12/DXGI] Enhanced Barriers: TAK
  [D3D12/DXGI] VPblit 3DLUT: TAK

--- SEKCJA 7: MOST PYTHON UNO ---
  [Python IPC] Wersja Python: 3.12.12
  [Python IPC] Polaczenie nawiazane pomyslnie!

================================================================
  ZAKONCZONO POMYSLNIE (v5.0 Hybrid)
================================================================
```

&nbsp;

---

&nbsp;

## 🔄 Historia zmian

Skrypt przeszedł przez wiele wersji.

Każda wersja naprawiała błędy z poprzedniej.

&nbsp;

| Wersja | Data | Co się zmieniło |
|:------:|:----:|:----------------|
| **v1.0** | 2026-03-06 | ▶️ Pierwsza wersja. 8 sekcji podstawowych. Podstawowy audyt sprzętowy i programowy. |
| **v2.0** | 2026-03-06 | 🐛 Naprawiono 8 błędów z logu v1.0. Dodano `[AllowEmptyString()]` do funkcji `Add-ReportLine`. Poprawiono parsowanie polskich znaków (UTF-8). |
| **v3.0** | 2026-03-06 | 🔧 Usunięto polskie znaki diakrytyczne z konsoli (kompatybilność). Ujednolicono format zmiennych `${var}`. |
| **v4.0** | 2026-03-06 | 🎮 Dodano moduł C# z diagnostyką D3D12/DXGI. Wstrzykiwanie kodu przez `Add-Type`. Obsługa Agility SDK 1.719.0-preview. |
| **v5.0** | 2026-03-06 | ✅ Wersja finalna. Użycie wbudowanego Pythona LibreOffice (3.12) zamiast systemowego (3.13). Naprawiono konflikty DLL. Pełna integracja trzech języków. |

&nbsp;

---

&nbsp;

## 🐛 Znane problemy

&nbsp;

### ⚠️ Intel HD Graphics 3000 nie wspiera D3D12

To jest normalne. To stara karta graficzna (2011 rok).

Skrypt wykrywa to i mówi: `BRAK WSPARCIA`.

Microsoft Basic Render Driver (programowy) wspiera D3D12 FL 12_1.

&nbsp;

### ⚠️ Skia/Raster zamiast Skia/Vulkan

Na komputerach bez Vulkan, LibreOffice używa Skia/Raster.

To jest **prawidłowe** i **bezpieczne**.

Nie próbuj wymuszać Vulkan — może powodować puste menu.

&nbsp;

### ⚠️ Python UNO — „No extensions found"

Most Python-UNO łączy się poprawnie.

Ale czasem nie może wylistować rozszerzeń przez API.

Sekcja 5 (Regex parser) działa niezależnie.

&nbsp;

---

&nbsp;

## ❓ Pytania i odpowiedzi

&nbsp;

**🤔 Czy ten skrypt zmieni coś na moim komputerze?**

Nie. Skrypt tylko **czyta** informacje.

Nie zmienia ustawień. Nie instaluje niczego.

Nie usuwa plików.

&nbsp;

**🤔 Czy potrzebuję uprawnień administratora?**

Nie. Skrypt działa bez uprawnień administratora.

Ale niektóre informacje mogą być pełniejsze z uprawnieniami.

&nbsp;

**🤔 Gdzie znajdę raport?**

Na Pulpicie (Desktop).

Nazwa pliku zaczyna się od `Raport_Serwisowy_`.

&nbsp;

**🤔 Co jeśli nie mam .NET 11 Preview?**

Skrypt nadal działa.

Pominie sekcję 6 (DirectX 12) i pokaże ostrzeżenie.

&nbsp;

**🤔 Dlaczego skrypt używa Pythona z LibreOffice, a nie systemowego?**

Python systemowy (3.13) ma inne biblioteki DLL.

Python wbudowany w LibreOffice (3.12) ma dostęp do UNO.

Używanie systemowego Pythona powoduje konflikty.

&nbsp;

---

&nbsp;

## 🏗️ Struktura plików

```
📁 FALSYFIKACJA-HP-WIN11-26H2/
│
├── 📄 README.md                              ← Ten plik
├── 📄 LICENSE                                 ← Licencja MIT
│
├── 🔵 Audyt_LibreOffice_Hybrydowy.ps1        ← Główny skrypt (v5.0)
│
├── 📁 logi/
│   ├── 📄 Audyt_LibreOffice_Hybrydowy.log     ← Log z v5.0 (finalny)
│   ├── 📄 Audyt_LibreOffice_Hybrydowy_ps1.log ← Log z v2.0
│   └── 📄 Audyt_LibreOffice_Hybrydowy_log.txt ← Log z v1.0
│
├── 📁 raporty/
│   ├── 📄 Raport_Serwisowy_20260306.txt       ← Przykładowy raport
│   ├── 📄 Raport_XCU_20260306.txt             ← Kopia konfiguracji LO
│   └── 🐍 diagnoza_uno_20260306.py            ← Wygenerowany skrypt Python
│
└── 📁 dokumentacja/
    └── 📄 Zaawansowane_Informacje_o_LibreOffice.md
```

&nbsp;

---

&nbsp;

## 🌐 Informacje o dostępności

Ten plik README został napisany zgodnie z zasadami dostępności:

- **Basic English** — proste słowa, krótkie zdania.
- **ISO 24495-1** — jasna struktura, nagłówki, logiczny porządek.
- **ETR (Easy-to-Read)** — duże odstępy, wypunktowania, jeden pomysł na akapit.
- **AAC** — emoji jako symbole wspomagające, ikony SVG z opisami.

Każdy obraz ma tekst alternatywny (`alt`).

Każda tabela ma nagłówki.

Każda sekcja ma emoji na początku dla łatwej nawigacji.

&nbsp;

---

&nbsp;

## ⚖️ Licencja

```
MIT License

Copyright (c) 2026

Każdy może używać, kopiować i zmieniać ten program.
Za darmo. Bez ograniczeń.
Wystarczy zachować informację o licencji.
```

Pełny tekst: [LICENSE](./LICENSE)

&nbsp;

---

&nbsp;

<div align="center">

Zrobione z ❤️ dla społeczności LibreOffice.

**HP ProBook 6570b** · Windows 11 · LibreOffice 26.2.1.2

*Ostatnia aktualizacja: 7 marca 2026*

</div>
