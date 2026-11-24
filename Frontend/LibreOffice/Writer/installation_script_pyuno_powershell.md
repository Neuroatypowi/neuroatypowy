# Installing PyUNO Falsification Libraries for LibreOffice 26.8 (Windows PowerShell 5.1)

This guide covers the complete installation, verification, runtime configuration, and troubleshooting workflow for `installation_script_pyuno_powershell.ps1`.

## Verified Target Environment

- **OS:** Windows 10 / 11 (64-bit, verified on build `19044`)
- **Shell:** Windows PowerShell 5.1 (standard built-in shell; Administrator privileges are **not** required)
- **Office Suite:** LibreOffice `26.8.3.1` (64-bit) installed in `C:\Program Files\LibreOffice\`
- **Embedded Python:** `Python 3.13.18` (verified) — script is also compatible with `Python 3.12.x` LibreOffice builds
- **Network Access:** HTTPS (TLS 1.2) access to `bootstrap.pypa.io`, `pypi.org`, and `github.com`

## Recommended Execution

Always run the saved `.ps1` file directly rather than copying code from rendered web Markdown (which can strip line breaks or comment `#` characters):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installation_script_pyuno_powershell.ps1"
```

> **Interactive Console Compatibility:** The script is hardened to also work when pasted directly into an interactive Windows PowerShell 5.1 window (no `#Requires` directive, single-line `} else {` and `} finally {` blocks, pure 7-bit ASCII encoding).

## Pipeline Overview

1. **Step 0 — Session Isolation & Launcher Discovery:**
   - Verifies PowerShell 5.1+ and enables TLS 1.2.
   - Clears `PYTHONHOME` and `PYTHONPATH` in the active session to prevent collisions with system-wide Python installations.
   - Locates `C:\Program Files\LibreOffice\program\python.exe` and prints its exact version.
2. **Step 1 — `pip` Verification & Bootstrap:**
   - Checks whether `pip` is available in LibreOffice's embedded Python.
   - Because Windows LibreOffice builds omit `ensurepip`, downloads `https://bootstrap.pypa.io/get-pip.py` to `%TEMP%` and installs `pip` into user site-packages (`--user`) if missing.
3. **Step 2 — Core Binary Wheels (`--only-binary :all:`):**
   - Installs/upgrades `pymupdf`, `fonttools`, `spacy~=3.8.7`, `holidays`, `python-dateutil`, `python-stdnum`, `pyphen`, `beautifulsoup4`, and `pillow`.
   - Passes `"--only-binary"` and `":all:"` as two separate arguments to prevent the Windows PowerShell 5.1 native-command colon-splatting bug.
   - Requires zero C/C++ compilers (no Visual Studio Build Tools needed).
4. **Step 3 — Special Dependency Handling (`WinError 5` Workarounds):**
   - Installs `num2words==0.5.14` with `--no-deps` and `--only-binary :all:` so `pip` does not attempt to build `docopt` from a `.tar.gz` source archive.
   - Checks via `importlib.metadata` whether `pl_core_news_md` `3.8.0` is already installed; if absent, downloads and installs the `.whl` directly from GitHub Releases (skipping redundant 49.5 MB downloads on re-runs and avoiding `spacy download`'s `sys.executable` `WinError 5`).
5. **Step 4 — End-to-End PyUNO & Library Verification:**
   - Writes a temporary ASCII script `%TEMP%\verify_pyuno_env.py`, executes it via LibreOffice's `python.exe`, and deletes it in a `finally` block.
   - Imports all third-party libraries **before** `import uno`, confirms `UNO_HOOK_SAFE: True`, tests Polish morphology (`Person=0`), 2026 Polish holidays (14 days), Polish `num2words` (`PLN` + ordinals), `pyphen` (`pl_PL`), and `PESEL`/`NIP`/`REGON` validation.

## Expected Verification Output

```text
--- PYUNO ENVIRONMENT VERIFICATION REPORT ---
PYTHON_VERSION : 3.13.18
PREFIX_PATH    : C:\Program Files\LibreOffice\program\\python-core-3.13.18
USER_SITE      : C:\Users\<USER>\AppData\Roaming\Python\Python313\site-packages
UNO_FILE       : C:\Program Files\LibreOffice\program\uno.py
UNO_HOOK_SAFE  : True
PYMUPDF_VER    : 2.1
FONTTOOLS_VER  : 4.68.0
SPACY_VER      : 3.8.18
SPACY_MODEL    : core_news_md 3.8.0
SPACY_MORPH    : Wykonano -> Aspect=Perf|Mood=Ind|Person=0|Tense=Past|VerbForm=Fin|Voice=Act
HOLIDAYS_2026  : 14 Polish public holidays
DATEUTIL_VER   : 2.9.0.post0
NUM2WORDS_VER  : 0.5.14
PLN_TEST       : tysiąc dwieście trzydzieści cztery złote, pięćdziesiąt sześć groszy
ORDINAL_TEST   : dwudziesty pierwszy
SYLLABLES_TEST : od-po-wie-dzial-ność
PESEL_TEST     : True | NIP/REGON modules loaded: True
BS4_VER        : 4.15.0
PILLOW_VER     : 13.0.0
ENVIRONMENT_READY

>>> DEPLOYMENT AND VERIFICATION SUCCEEDED: ENVIRONMENT READY <<<
```

## Critical Runtime & Writer 26.8 Configuration Rules

### 1. Safe `spaCy` Import Inside Internal Writer Macros
External CLI scripts simply import `spacy` before `uno`. When running a macro directly from **Tools → Macros** inside an open LibreOffice Writer window (where `uno` is already imported by the host), wrap third-party imports like this:

```python
import builtins
import uno

_uno_hook = builtins.__import__
builtins.__import__ = uno._builtin_import
try:
    import pymupdf
    import fontTools
    import spacy
finally:
    builtins.__import__ = _uno_hook
```

### 2. Optional Fallback Path for Internal Writer Macros
If an internal Writer macro does not automatically include `%APPDATA%\Python\Python3XX\site-packages` on `sys.path`, either append `site.getusersitepackages()` in the macro or install packages directly into LibreOffice's macro `pythonpath`:

```powershell
$LoPy = "C:\Program Files\LibreOffice\program\python.exe"
$LoPyPath = "$env:APPDATA\LibreOffice\4\user\Scripts\python\pythonpath"
New-Item -ItemType Directory -Force -Path $LoPyPath | Out-Null
& $LoPy -m pip install --target $LoPyPath --only-binary ":all:" pymupdf fonttools "spacy~=3.8.7"
```

### 3. `Atkinson Hyperlegible Next` (Weight 500) & Leading in `.fodt` for Writer 26.8
Empirical PDF export testing on LibreOffice Writer `26.8.3.1` established two required XML rules:
- **Medium (500) vs. Bold (700):** `fo:font-weight="500"` on `'Atkinson Hyperlegible Next'` falls back to `Regular` in exported PDFs. Declare two `<style:font-face>` entries:
  - `'Atkinson Hyperlegible Next Medium'` with `fo:font-weight="normal"` for body text (embeds `AtkinsonHyperlegibleNext-Medium`).
  - `'Atkinson Hyperlegible Next'` with `fo:font-weight="bold"` for headings/emphasis (embeds `AtkinsonHyperlegibleNext-Bold`).
- **True 130% Line Height:** Proportional `fo:line-height="130%"` multiplies the font's ~1.3 em natural line box (~16 pt at 9.5 pt). Use `style:line-height-at-least="12.35pt"` for 9.5 pt text to achieve true 130% leading without clipping Polish diacritics.

## Troubleshooting

| Symptom | Root Cause | Fix |
| --- | --- | --- |
| `ImportError: No module named 'envwrap'` during `import spacy` | `import uno` ran before `import spacy`, letting `uno._uno_import` convert `ModuleNotFoundError` into `ImportError` inside `tqdm`. | Import `spacy` before `uno` in CLI scripts, or apply the `uno._builtin_import` guard above inside Writer macros. |
| `no such option: -o` from `pip` | PowerShell 5.1 mangled `"--only-binary=:all:"` due to the colon. | Pass `"--only-binary", ":all:"` as two separate arguments. |
| `ModuleNotFoundError: No module named 'pymupdf'` | LibreOffice's `python.exe` was invoked with `-I` (isolated mode). | Remove `-I` so user site-packages remain on `sys.path`. |
| `AttributeError: partially initialized module 'pymupdf'` | A script in the current working directory is named `inspect.py`. | Rename the local script (e.g., `pdffonts.py`). |
| `WinError 5` during `num2words` or `spacy download` | Source build of `docopt` or subprocess call to LibreOffice's `sys.executable`. | Always install `num2words==0.5.14` with `--no-deps` and install `pl_core_news_md` directly from its `.whl` URL. |
| `The term 'else' is not recognized` / `#Requires` error | Pasting multi-line `} \n else {` or `#Requires` directly into an interactive PowerShell 5.1 prompt. | Run via `-File ".\installation_script_pyuno_powershell.ps1"` or use the hardened script provided in this repository. |
