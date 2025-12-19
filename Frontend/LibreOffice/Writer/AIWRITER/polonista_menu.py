# -*- coding: utf-8 -*-
"""
AIWRITER > POLONISTA - Menu makr dla LibreOffice Writer
========================================================

SCIEZKA INSTALACJI:
    %APPDATA%/LibreOffice/4/user/Scripts/python/AIWRITER/polonista_menu.py

UZYCIE W LIBREOFFICE:
    Narzedzia > Makra > Uruchom makro > AIWRITER > polonista_menu

Autor: Stowarzyszenie Zwykle "Neuroatypowi"
Strona: https://neuroatypowi.org
Licencja: MIT

NAPRAWIONY BLAD KRYTYCZNY:
    Import backendu teraz dziala poprawnie w kontekscie LibreOffice
    poprzez jawne dodanie katalogu do sys.path
"""

from __future__ import print_function, absolute_import

import os
import sys

# =============================================================================
# KRYTYCZNA POPRAWKA: Dodaj katalog AIWRITER do sys.path
# =============================================================================
# W kontekscie LibreOffice, wzgledne importy nie dzialaja prawidlowo.
# Musimy jawnie dodac katalog zawierajacy backend do sciezki Pythona.

def _setup_import_path():
    """
    Konfiguruje sciezke importu dla LibreOffice.
    Ta funkcja MUSI byc wywolana PRZED jakimkolwiek importem z backends.
    """
    # Metoda 1: Uzyj __file__ jesli dostepny
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir not in sys.path:
            sys.path.insert(0, script_dir)
        return script_dir
    except NameError:
        pass
    
    # Metoda 2: Oblicz sciezke dla Windows
    if os.name == 'nt':
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            script_dir = os.path.join(appdata, 'LibreOffice', '4', 'user',
                                      'Scripts', 'python', 'AIWRITER')
            if os.path.exists(script_dir) and script_dir not in sys.path:
                sys.path.insert(0, script_dir)
            return script_dir
    
    # Metoda 3: Linux/macOS
    home = os.path.expanduser('~')
    script_dir = os.path.join(home, '.config', 'libreoffice', '4', 'user',
                              'Scripts', 'python', 'AIWRITER')
    if os.path.exists(script_dir) and script_dir not in sys.path:
        sys.path.insert(0, script_dir)
    return script_dir


# WYWOLAJ KONFIGURACJE SCIEZKI PRZED IMPORTAMI!
_AIWRITER_DIR = _setup_import_path()

# =============================================================================
# IMPORT BACKENDU - TERAZ POWINIEN DZIALAC
# =============================================================================

# Zmienna globalna dla backendu
_BACKEND = None
_BACKEND_ERROR = None

def _load_backend():
    """
    Laduje backend NVIDIA NIM.
    Zwraca (backend, error_message).
    """
    global _BACKEND, _BACKEND_ERROR
    
    if _BACKEND is not None:
        return _BACKEND, None
    
    if _BACKEND_ERROR is not None:
        return None, _BACKEND_ERROR
    
    # Proba 1: Import jako pakiet
    try:
        from backends.nvidia_nim_backend import NvidiaNimBackend, get_backend
        _BACKEND = get_backend()
        return _BACKEND, None
    except ImportError as e1:
        pass
    
    # Proba 2: Import bezposredni z katalogu backends
    try:
        backends_dir = os.path.join(_AIWRITER_DIR, 'backends')
        if backends_dir not in sys.path:
            sys.path.insert(0, backends_dir)
        
        from nvidia_nim_backend import NvidiaNimBackend, get_backend
        _BACKEND = get_backend()
        return _BACKEND, None
    except ImportError as e2:
        pass
    
    # Proba 3: Dynamiczny import
    try:
        backend_file = os.path.join(_AIWRITER_DIR, 'backends', 'nvidia_nim_backend.py')
        if os.path.exists(backend_file):
            import importlib.util
            spec = importlib.util.spec_from_file_location("nvidia_nim_backend", backend_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            _BACKEND = module.get_backend()
            return _BACKEND, None
    except Exception as e3:
        pass
    
    # Wszystkie proby zawiodly
    error_msg = """Backend NVIDIA NIM nie moze byc zaladowany.

Sprawdz czy pliki istnieja:
1. {}/backends/__init__.py
2. {}/backends/nvidia_nim_backend.py

Katalog AIWRITER: {}
sys.path: {}""".format(_AIWRITER_DIR, _AIWRITER_DIR, _AIWRITER_DIR, 
                       '\n'.join(sys.path[:5]))
    
    _BACKEND_ERROR = error_msg
    return None, error_msg


# =============================================================================
# STALE
# =============================================================================

POLONISTA_VERSION = "2.1"
POLONISTA_NAME = "POLONISTA"
AIWRITER_NAME = "AIWRITER"


# =============================================================================
# FUNKCJE DIALOGOWE
# =============================================================================

def _show_message(title, message, msg_type=0):
    """
    Wyswietla okno dialogowe.
    msg_type: 0=INFO, 1=WARNING, 2=ERROR
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        toolkit = sm.createInstanceWithContext("com.sun.star.awt.Toolkit", ctx)
        desktop = sm.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            print("{}: {}".format(title, message))
            return
        
        controller = doc.getCurrentController()
        if controller is None:
            print("{}: {}".format(title, message))
            return
        
        frame = controller.getFrame()
        if frame is None:
            print("{}: {}".format(title, message))
            return
        
        window = frame.getContainerWindow()
        if window is None:
            print("{}: {}".format(title, message))
            return
        
        msgbox = toolkit.createMessageBox(window, msg_type, 1, 
                                          str(title), str(message))
        msgbox.execute()
        
    except NameError:
        print("{}: {}".format(title, message))
    except Exception as e:
        print("{}: {} (Error: {})".format(title, message, e))


def _get_document():
    """Pobiera aktywny dokument Writer."""
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            return None
        
        if not doc.supportsService("com.sun.star.text.TextDocument"):
            return None
        
        return doc
    except:
        return None


def _get_selection():
    """
    Pobiera zaznaczony tekst.
    Zwraca (text_range, text_string) lub (None, error_message).
    """
    doc = _get_document()
    if doc is None:
        return None, "Otworz dokument Writer"
    
    try:
        selection = doc.getCurrentSelection()
        if selection is None or selection.getCount() == 0:
            return None, "Zaznacz tekst do przetworzenia"
        
        text_range = selection.getByIndex(0)
        text = text_range.getString()
        
        if not text or not text.strip():
            return None, "Zaznaczenie jest puste"
        
        return text_range, text
    except Exception as e:
        return None, "Blad: {}".format(str(e))


# =============================================================================
# MAKRA PUBLICZNE - WIDOCZNE W LIBREOFFICE
# =============================================================================

def RedagujZaznaczenie(*args):
    """
    [POLONISTA] Uprascja zaznaczony tekst do Prostego Jezyka.
    """
    # Sprawdz zaznaczenie
    text_range, text = _get_selection()
    if text_range is None:
        _show_message(POLONISTA_NAME, text, 1)
        return
    
    # Zaladuj backend
    backend, error = _load_backend()
    if backend is None:
        _show_message(POLONISTA_NAME + " - Blad", error, 2)
        return
    
    # Walidacja klucza API
    is_valid, msg = backend.validate_api_key()
    if not is_valid:
        _show_message(POLONISTA_NAME + " - Konfiguracja", 
                     "Problem z kluczem API:\n\n" + msg, 1)
        return
    
    # Wywolaj API
    success, result = backend.simplify_text(text)
    
    if success:
        text_range.setString(result)
    else:
        _show_message(POLONISTA_NAME + " - Blad", result, 2)


def RedagujCayDokument(*args):
    """
    [POLONISTA] Upraszcza caly dokument.
    """
    doc = _get_document()
    if doc is None:
        _show_message(POLONISTA_NAME, "Otworz dokument Writer", 1)
        return
    
    backend, error = _load_backend()
    if backend is None:
        _show_message(POLONISTA_NAME + " - Blad", error, 2)
        return
    
    is_valid, msg = backend.validate_api_key()
    if not is_valid:
        _show_message(POLONISTA_NAME + " - Konfiguracja", msg, 1)
        return
    
    try:
        text = doc.getText()
        full_text = text.getString()
        
        if not full_text or not full_text.strip():
            _show_message(POLONISTA_NAME, "Dokument jest pusty", 1)
            return
        
        if len(full_text) > 5000:
            _show_message(POLONISTA_NAME, 
                         "Dokument ma {} znakow.\nPrzetwarzanie moze zajac kilka minut.".format(
                             len(full_text)), 0)
        
        success, result = backend.simplify_long_text(full_text)
        
        if success:
            text.setString(result)
            _show_message(POLONISTA_NAME, "Dokument zostal uproszczony!", 0)
        else:
            _show_message(POLONISTA_NAME + " - Blad", result, 2)
            
    except Exception as e:
        _show_message(POLONISTA_NAME + " - Blad", 
                     "Blad przetwarzania: {}".format(str(e)), 2)


def PokazInformacje(*args):
    """
    [POLONISTA] Wyswietla informacje o programie.
    """
    backend, error = _load_backend()
    
    info = """{} v{}
Submenu projektu {}

OPIS:
Upraszcza tekst do Prostego Jezyka
uzywajac polskiego modelu AI Bielik.

UZYCIE:
1. Zaznacz tekst w dokumencie
2. Uruchom makro RedagujZaznaczenie
3. Tekst zostanie automatycznie uproszczony

""".format(POLONISTA_NAME, POLONISTA_VERSION, AIWRITER_NAME)
    
    if backend is not None:
        bi = backend.get_info()
        info += """KONFIGURACJA:
Model: {}
Klucz API: {}
Plik .env: {}
Zapytan: {}
""".format(bi.get('model', 'N/A'), bi.get('api_key_status', 'N/A'),
           bi.get('env_path', 'N/A'), bi.get('request_count', 0))
    else:
        info += """KONFIGURACJA:
[BLAD] Backend niedostepny

Katalog AIWRITER: {}
""".format(_AIWRITER_DIR)
    
    info += """
AUTOR:
Stowarzyszenie Zwykle "Neuroatypowi"
https://neuroatypowi.org"""
    
    _show_message("O programie " + POLONISTA_NAME, info)


def SprawdzKonfiguracje(*args):
    """
    [POLONISTA] Sprawdza konfiguracje i klucz API.
    """
    backend, error = _load_backend()
    
    if backend is None:
        _show_message(POLONISTA_NAME + " - Blad konfiguracji", error, 2)
        return
    
    is_valid, msg = backend.validate_api_key()
    
    if is_valid:
        info = backend.get_info()
        _show_message(POLONISTA_NAME + " - Konfiguracja OK",
                     """Konfiguracja poprawna!

Model: {}
Klucz API: {}
Plik .env: {}
Limit: {} zapytan/min""".format(
                         info.get('model'),
                         info.get('api_key_status'),
                         info.get('env_path'),
                         info.get('rate_limit_rpm')), 0)
    else:
        env_path = backend.get_env_path() or os.path.join(_AIWRITER_DIR, '.env')
        _show_message(POLONISTA_NAME + " - Blad konfiguracji",
                     """Problem z kluczem API:

{}

INSTRUKCJA:
1. Utworz plik .env w:
   {}
2. Dodaj linie:
   NVIDIA_API_KEY=nvapi-twoj-klucz
3. Uruchom ponownie LibreOffice""".format(msg, env_path), 1)


def TestPolaczenia(*args):
    """
    [POLONISTA] Testuje polaczenie z API NVIDIA.
    """
    backend, error = _load_backend()
    
    if backend is None:
        _show_message(POLONISTA_NAME + " - Test", error, 2)
        return
    
    _show_message(POLONISTA_NAME, "Wykonuje test polaczenia...", 0)
    
    success, result = backend.test_connection()
    
    if success:
        _show_message(POLONISTA_NAME + " - Test OK", result, 0)
    else:
        _show_message(POLONISTA_NAME + " - Test nieudany", result, 2)


def OtworzStroneNVIDIA(*args):
    """
    [POLONISTA] Otwiera strone NVIDIA do pobrania klucza API.
    """
    import webbrowser
    url = "https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct"
    try:
        webbrowser.open(url)
        _show_message(POLONISTA_NAME,
                     """Otwieram strone NVIDIA...

INSTRUKCJA:
1. Zaloguj sie lub utworz konto
2. Kliknij 'Get API Key'
3. Skopiuj klucz (nvapi-...)
4. Wklej do pliku .env""", 0)
    except:
        _show_message(POLONISTA_NAME + " - Blad",
                     "Odwiedz recznie:\n" + url, 1)


def OtworzStroneNeuroatypowi(*args):
    """
    [POLONISTA] Otwiera strone projektu.
    """
    import webbrowser
    try:
        webbrowser.open("https://neuroatypowi.org")
    except:
        _show_message(POLONISTA_NAME, "Odwiedz: https://neuroatypowi.org", 0)


# =============================================================================
# EKSPORT MAKR DLA LIBREOFFICE
# =============================================================================

g_exportedScripts = (
    RedagujZaznaczenie,
    RedagujCayDokument,
    PokazInformacje,
    SprawdzKonfiguracje,
    TestPolaczenia,
    OtworzStroneNVIDIA,
    OtworzStroneNeuroatypowi,
)


# =============================================================================
# TEST
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("{} > {} v{}".format(AIWRITER_NAME, POLONISTA_NAME, POLONISTA_VERSION))
    print("=" * 60)
    print("Katalog AIWRITER:", _AIWRITER_DIR)
    print("sys.path:", sys.path[:3])
    print()
    print("Dostepne makra:")
    for func in g_exportedScripts:
        doc = func.__doc__ or ""
        desc = doc.split('\n')[1].strip() if doc else ""
        print("  - {}: {}".format(func.__name__, desc))
    print()
    
    # Test ladowania backendu
    backend, error = _load_backend()
    if backend:
        print("Backend: OK")
        print("Info:", backend.get_info())
    else:
        print("Backend: BLAD")
        print(error)
