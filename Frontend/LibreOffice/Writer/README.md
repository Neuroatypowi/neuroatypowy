# LibreOffice 26.8 PyUNO Document Falsification Toolkit (Windows)

Production-tested Python environment bootstrapper and empirical configuration guide for deterministic document falsification in **LibreOffice Writer 26.8** on Windows 10/11 (64-bit) using **Windows PowerShell 5.1**.

Built to verify Polish plain-language (`Jasnopis`), ETR-adapted layouts, typographic line-breaking (`U+00A0`), static font embedding (no `fvar`), PDF/UA accessibility, and Polish legal/administrative data integrity directly inside LibreOffice's embedded Python runtime.

## Verified Environment

| Component | Verified Value |
| --- | --- |
| Operating System | Windows 10 / 11 x86_64 (verified on build `19044`) |
| Shell | Windows PowerShell 5.1 (no Administrator rights required) |
| Office Suite | LibreOffice `26.8.3.1` x86_64 (`Build ID: 861effc5289d539f15c4c18d1ba8579ffd78728b`) |
| Embedded Python | `3.13.18` (also compatible with `3.12.x` LibreOffice builds) |
| Install Location | `%APPDATA%\Python\Python3XX\site-packages` (user site-packages) |

## Quick Start

Save `installation_script_pyuno_powershell.ps1` locally and run it from Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installation_script_pyuno_powershell.ps1"
```

A successful run ends with `ENVIRONMENT_READY` and `>>> DEPLOYMENT AND VERIFICATION SUCCEEDED: ENVIRONMENT READY <<<`.

## Installed Verification Stack

| Package | Verified Version | Purpose in Falsification Pipeline |
| --- | --- | --- |
| `uno` (PyUNO) | Built-in (`LO 26.8`) | UNO DOM inspection, style auditing, and `writer_pdf_Export` PDF/UA rendering |
| `pymupdf` | `2.1` | Physical line length (`<= 80` chars), trailing orphan detection, PDF/UA tags (`/StructTreeRoot`, `/Lang`), image dimensions |
| `fonttools` | `4.68.0` | Embedded font stream inspection, OpenType `fvar` variable-font rejection, `OS/2.usWeightClass` verification |
| `spacy` + `pl_core_news_md` | `3.8.18` + `3.8.0` | Polish sentence splitting, FOG-PL lemmatization, UD morphology (`Person=0`, `Voice=Pass`, `VerbForm=Vnoun`/`Part`/`Conv`) |
| `pyphen` | `0.18.1` | Polish (`pl_PL`) hyphenation and syllable counting |
| `holidays` | `0.109` | Polish statutory public holidays verification (14 days in 2026) |
| `python-dateutil` | `2.9.0.post0` | Robust date parsing and interval validation |
| `python-stdnum` | `2.2` | Polish identifier checksum validation (`PESEL`, `NIP`, `REGON`) |
| `num2words` | `0.5.14` | Polish currency (`PLN`) and ordinal number-to-words conversion (`--no-deps`) |
| `beautifulsoup4` / `pillow` | `4.15.0` / `13.0.0` | XML/HTML inspection and EXIF-free image preprocessing |

## Critical Empirical Safeguards (LibreOffice 26.8 & PowerShell 5.1)

1. **`uno._uno_import` vs. `spaCy` / `tqdm` (`ImportError: No module named 'envwrap'`)**
   LibreOffice's `uno.py` replaces `builtins.__import__` with `_uno_import`, which converts `ModuleNotFoundError` into a generic `ImportError`. This breaks optional fallback imports inside `tqdm` (`from envwrap import envwrap`) loaded by `spaCy`.
   - **External CLI scripts:** Always import `spacy` and all third-party libraries **before** `import uno`.
   - **Internal Writer macros** (where `uno` is already loaded by the host process): Temporarily restore `builtins.__import__ = uno._builtin_import` inside a `try...finally` block while importing `spacy`.
2. **PowerShell 5.1 Colon-Splatting Bug (`no such option: -o`)**
   Passing `"--only-binary=:all:"` to a native executable in Windows PowerShell 5.1 corrupts argument parsing. Always pass `"--only-binary", ":all:"` as two separate array elements.
3. **Bypassing `WinError 5` Source Builds on Windows LibreOffice Python**
   - Install `num2words==0.5.14` with `--no-deps` and `--only-binary :all:` to skip compiling `docopt` from `.tar.gz`.
   - Install `pl_core_news_md` directly from its GitHub Releases `.whl` URL (with an idempotency check) to bypass `python -m spacy download`, which fails on LibreOffice's `sys.executable`.
4. **Never Launch Embedded `python.exe` with `-I`**
   Isolated mode (`-I`) removes `%APPDATA%\Python\Python3XX\site-packages` from `sys.path` and immediately causes `ModuleNotFoundError`.
5. **Avoid Standard Library Filename Shadowing**
   Never name helper scripts `inspect.py` (or other stdlib names). `PyMuPDF` imports `inspect` during initialization; a local `inspect.py` causes a circular `AttributeError`.
6. **`Atkinson Hyperlegible Next` (Weight 500 & 130% Leading) in `.fodt` / Writer 26.8**
   - Install static `.ttf`/`.otf` font files only (no OpenType `fvar` table).
   - Setting `fo:font-weight="500"` on `'Atkinson Hyperlegible Next'` silently falls back to `Regular` on PDF export. Declare `'Atkinson Hyperlegible Next Medium'` (`fo:font-weight="normal"`) for weight 500, and `'Atkinson Hyperlegible Next'` (`fo:font-weight="bold"`) for weight 700.
   - Because `Atkinson Hyperlegible Next` has a ~1.3 em natural line box, proportional `fo:line-height="130%"` renders at ~16 pt for 9.5 pt text. Use `style:line-height-at-least="12.35pt"` (for 9.5 pt text) for true 130% leading without clipping Polish diacritics.

## Repository Files

- `README.md` — Bilingual project overview (English + Polish ETR-adapted summary).
- `installation_script_pyuno_powershell.md` — Detailed installation, runtime rules, and troubleshooting guide.
- `installation_script_pyuno_powershell.ps1` — Self-contained, idempotent Windows PowerShell 5.1 installer and end-to-end verifier.

---

## Wersja po polsku (tekst łatwy do czytania)

Ten pakiet instaluje narzędzia Pythona dla programu LibreOffice Writer 26.8.
Narzędzia sprawdzają błędy w plikach tekstowych i w plikach PDF.
Ten skrypt działa na systemie Windows 10 oraz Windows 11.

### Co musisz mieć na komputerze

- Program LibreOffice 26.8 (wersja 64-bitowa) na dysku C.
- Program Windows PowerShell 5.1 (jest już w systemie Windows).
- Dostęp do internetu podczas instalacji plików.

Nie potrzebujesz konta administratora.

### Jak uruchomić instalację

1. Pobierz plik `installation_script_pyuno_powershell.ps1` na komputer.
2. Otwórz program Windows PowerShell w folderze z tym plikiem.
3. Wklej polecenie poniżej i naciśnij klawisz Enter.
4. Poczekaj na zielony napis `ENVIRONMENT_READY` na końcu testu.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installation_script_pyuno_powershell.ps1"
```

### Cztery ważne zasady podczas pracy

- W skrypcie wpisuj `import spacy` zawsze przed `import uno`.
- Uruchamiaj Pythona bez flagi `-I`, bo inaczej znikną pakiety.
- Nie nazywaj żadnego pliku `inspect.py`, bo to psuje `PyMuPDF`.
- Dla wagi 500 wpisz nazwę czcionki `Atkinson Hyperlegible Next Medium`.

### Ważna uwaga o standardzie ETR

Ten opis stosuje zasady tekstu łatwego do czytania (ETR).
Nie sprawdził go jeszcze konsultant ETR.
Dlatego nie jest to oficjalny dokument z certyfikatem ETR.
