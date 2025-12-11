# -*- coding: utf-8 -*-
"""
localwriter/polonista_menu.py
==============================

Integracja menu POLONISTA z LibreOffice Writer.
Dodaje menu "POLONISTA" na pasku menu z dostepnymi funkcjami.

INSTALACJA:
1. Skopiuj caly katalog localwriter do:
   Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/
   Linux:   ~/.config/libreoffice/4/user/Scripts/python/
   
2. Uruchom ponownie LibreOffice

3. Menu POLONISTA pojawi sie automatycznie
   (lub recznie: Narzedzia > Makra > Uruchom makro > localwriter > polonista_menu)

Autor: Stowarzyszenie Zwykle "Neuroatypowi"
Strona: https://neuroatypowi.org
Licencja: MIT
"""

from __future__ import print_function, absolute_import

import os
import sys

# Dodaj katalog nadrzedny do sciezki (dla importow)
try:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if script_dir not in sys.path:
        sys.path.insert(0, script_dir)
except:
    pass

# Import backendu NVIDIA NIM
try:
    from backends.nvidia_nim_backend import NvidiaNimBackend, get_backend
except ImportError:
    try:
        from .backends.nvidia_nim_backend import NvidiaNimBackend, get_backend
    except ImportError:
        # Fallback - backend w tym samym katalogu
        NvidiaNimBackend = None
        get_backend = None


# =============================================================================
# STALE KONFIGURACYJNE
# =============================================================================

POLONISTA_VERSION = "2.1"
POLONISTA_NAME = "POLONISTA"
POLONISTA_MENU_NAME = "POLONISTA"

# ID dla menu (musza byc unikalne)
MENU_CONTAINER_ID = "vnd.neuroatypowi.polonista:MenuContainer"


# =============================================================================
# FUNKCJE POMOCNICZE (prywatne)
# =============================================================================

def _get_desktop():
    """Pobiera instancje Desktop z LibreOffice."""
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext(
            "com.sun.star.frame.Desktop", ctx
        )
        return desktop
    except NameError:
        return None
    except Exception:
        return None


def _get_document():
    """Pobiera aktywny dokument Writer."""
    desktop = _get_desktop()
    if desktop is None:
        return None
    
    doc = desktop.getCurrentComponent()
    if doc is None:
        return None
    
    # Sprawdz czy to dokument Writer
    try:
        if not doc.supportsService("com.sun.star.text.TextDocument"):
            return None
    except:
        return None
    
    return doc


def _show_message(title, message, msg_type=0):
    """
    Wyswietla okno dialogowe.
    
    msg_type:
        0 = INFOBOX
        1 = WARNINGBOX
        2 = ERRORBOX
        3 = QUERYBOX
        4 = MESSBOX
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        toolkit = sm.createInstanceWithContext(
            "com.sun.star.awt.Toolkit", ctx
        )
        
        doc = _get_document()
        if doc is None:
            print(f"{title}: {message}")
            return None
        
        controller = doc.getCurrentController()
        if controller is None:
            print(f"{title}: {message}")
            return None
        
        frame = controller.getFrame()
        if frame is None:
            print(f"{title}: {message}")
            return None
        
        window = frame.getContainerWindow()
        if window is None:
            print(f"{title}: {message}")
            return None
        
        msgbox = toolkit.createMessageBox(
            window,
            msg_type,
            1,  # OK button
            str(title),
            str(message)
        )
        
        return msgbox.execute()
        
    except NameError:
        print(f"{title}: {message}")
        return None
    except Exception as e:
        print(f"{title}: {message} (Error: {e})")
        return None


def _show_input_dialog(title, prompt, default_value=""):
    """
    Wyswietla okno dialogowe z polem tekstowym.
    Zwraca wpisany tekst lub None jesli anulowano.
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        
        # Uzyj prostego InputBox
        basic_libs = sm.createInstanceWithContext(
            "com.sun.star.script.provider.MasterScriptProviderFactory", ctx
        )
        
        # Alternatywnie - uzyj okna dialogowego Toolkit
        # To wymaga wiecej kodu, wiec dla uproszczenia uzyjemy MessageBox
        # i zapytamy uzytkownika o potwierdzenie
        
        _show_message(title, prompt)
        return default_value
        
    except Exception as e:
        print(f"InputDialog error: {e}")
        return None


def _get_selection():
    """
    Pobiera zaznaczony tekst z dokumentu.
    
    Returns:
        Tuple (text_range, text_string) lub (None, error_message)
    """
    doc = _get_document()
    
    if doc is None:
        return None, "Otworz dokument Writer"
    
    try:
        selection = doc.getCurrentSelection()
        
        if selection is None:
            return None, "Zaznacz tekst do przetworzenia"
        
        if selection.getCount() == 0:
            return None, "Zaznacz tekst do przetworzenia"
        
        text_range = selection.getByIndex(0)
        text = text_range.getString()
        
        if not text or len(text.strip()) == 0:
            return None, "Zaznaczenie jest puste"
        
        return text_range, text
        
    except Exception as e:
        return None, f"Blad pobierania zaznaczenia: {str(e)}"


def _get_backend_instance():
    """Zwraca instancje backendu NVIDIA NIM."""
    if get_backend is not None:
        return get_backend()
    elif NvidiaNimBackend is not None:
        return NvidiaNimBackend()
    else:
        return None


# =============================================================================
# FUNKCJE PUBLICZNE - MAKRA LIBREOFFICE
# =============================================================================

def RedagujZaznaczenie(*args):
    """
    [POLONISTA] Upraszcza zaznaczony tekst
    
    Glowna funkcja POLONISTA - przeksztalca zaznaczony tekst
    na Prosty Jezyk uzywajac modelu Bielik AI.
    """
    # Pobierz zaznaczenie
    text_range, text = _get_selection()
    
    if text_range is None:
        _show_message(POLONISTA_NAME, text, 1)  # Warning
        return
    
    # Pobierz backend
    backend = _get_backend_instance()
    
    if backend is None:
        _show_message(
            POLONISTA_NAME + " - Blad",
            "Backend NVIDIA NIM nie jest dostepny.\n\n"
            "Sprawdz czy plik nvidia_nim_backend.py jest w katalogu backends/",
            2  # Error
        )
        return
    
    # Walidacja klucza API
    is_valid, msg = backend.validate_api_key()
    if not is_valid:
        _show_message(
            POLONISTA_NAME + " - Konfiguracja",
            f"Problem z kluczem API:\n\n{msg}\n\n"
            "Utworz plik .env z NVIDIA_API_KEY=nvapi-twoj-klucz",
            1  # Warning
        )
        return
    
    # Wywolaj API
    success, result = backend.simplify_text(text)
    
    if success:
        # Zamien tekst na uproszczony
        text_range.setString(result)
        # Opcjonalnie: pokaz potwierdzenie
        # _show_message(POLONISTA_NAME, "Tekst zostal uproszczony!", 0)
    else:
        _show_message(POLONISTA_NAME + " - Blad", result, 2)


def RedagujCayDokument(*args):
    """
    [POLONISTA] Upraszcza caly dokument
    
    Przetwarza caly tekst dokumentu, akapit po akapicie.
    UWAGA: Moze to zajac sporo czasu dla dlugich dokumentow.
    """
    doc = _get_document()
    
    if doc is None:
        _show_message(POLONISTA_NAME, "Otworz dokument Writer", 1)
        return
    
    backend = _get_backend_instance()
    
    if backend is None:
        _show_message(
            POLONISTA_NAME + " - Blad",
            "Backend NVIDIA NIM nie jest dostepny.",
            2
        )
        return
    
    # Walidacja klucza API
    is_valid, msg = backend.validate_api_key()
    if not is_valid:
        _show_message(POLONISTA_NAME + " - Konfiguracja", msg, 1)
        return
    
    # Pobierz caly tekst
    try:
        text = doc.getText()
        full_text = text.getString()
        
        if not full_text or len(full_text.strip()) == 0:
            _show_message(POLONISTA_NAME, "Dokument jest pusty", 1)
            return
        
        # Ostrzezenie przed dluga operacja
        if len(full_text) > 5000:
            _show_message(
                POLONISTA_NAME,
                f"Dokument ma {len(full_text)} znakow.\n"
                "Przetwarzanie moze zajac kilka minut.\n\n"
                "Kliknij OK aby kontynuowac.",
                0
            )
        
        # Przetwarzaj dlugi tekst
        success, result = backend.simplify_long_text(full_text)
        
        if success:
            text.setString(result)
            _show_message(POLONISTA_NAME, "Caly dokument zostal uproszczony!", 0)
        else:
            _show_message(POLONISTA_NAME + " - Blad", result, 2)
            
    except Exception as e:
        _show_message(
            POLONISTA_NAME + " - Blad",
            f"Blad przetwarzania dokumentu:\n{str(e)}",
            2
        )


def PokazInformacje(*args):
    """
    [POLONISTA] O programie
    
    Wyswietla informacje o wersji i konfiguracji POLONISTA.
    """
    backend = _get_backend_instance()
    
    info_text = f"""POLONISTA v{POLONISTA_VERSION}
Asystent Prostego Jezyka dla LibreOffice Writer

OPIS:
POLONISTA upraszcza tekst do formy zrozumialej
dla kazdego, uzywajac polskiego modelu AI Bielik.

UZYCIE:
1. Zaznacz tekst w dokumencie
2. Menu: POLONISTA > Upresc zaznaczenie
3. Tekst zostanie automatycznie uproszczony

"""
    
    if backend is not None:
        backend_info = backend.get_info()
        info_text += f"""KONFIGURACJA:
Model: {backend_info.get('model', 'N/A')}
Klucz API: {backend_info.get('api_key_status', 'N/A')}
Zapytan wykonanych: {backend_info.get('request_count', 0)}

"""
    else:
        info_text += """KONFIGURACJA:
[BLAD] Backend NVIDIA NIM nie jest dostepny

"""
    
    info_text += """AUTOR:
Stowarzyszenie Zwykle "Neuroatypowi"
https://neuroatypowi.org

LICENCJA: MIT"""
    
    _show_message("O programie " + POLONISTA_NAME, info_text)


def SprawdzKonfiguracje(*args):
    """
    [POLONISTA] Sprawdz konfiguracje
    
    Weryfikuje poprawnosc klucza API i polaczenia.
    """
    backend = _get_backend_instance()
    
    if backend is None:
        _show_message(
            POLONISTA_NAME + " - Konfiguracja",
            "Backend NVIDIA NIM nie jest dostepny.\n\n"
            "Sprawdz czy pliki sa poprawnie zainstalowane:\n"
            "- backends/__init__.py\n"
            "- backends/nvidia_nim_backend.py",
            2
        )
        return
    
    is_valid, msg = backend.validate_api_key()
    
    if is_valid:
        info = backend.get_info()
        _show_message(
            POLONISTA_NAME + " - Konfiguracja OK",
            f"Konfiguracja poprawna!\n\n"
            f"Model: {info.get('model')}\n"
            f"Klucz API: {info.get('api_key_status')}\n"
            f"Limit: {info.get('rate_limit_rpm')} zapytan/min",
            0
        )
    else:
        _show_message(
            POLONISTA_NAME + " - Blad konfiguracji",
            f"Problem z kluczem API:\n\n{msg}\n\n"
            "INSTRUKCJA:\n"
            "1. Utworz plik .env w katalogu ze skryptami\n"
            "2. Dodaj linie: NVIDIA_API_KEY=nvapi-twoj-klucz\n"
            "3. Uruchom ponownie LibreOffice",
            1
        )


def TestPolaczenia(*args):
    """
    [POLONISTA] Testuj polaczenie
    
    Wykonuje testowe zapytanie do API NVIDIA NIM.
    """
    backend = _get_backend_instance()
    
    if backend is None:
        _show_message(
            POLONISTA_NAME + " - Test",
            "Backend NVIDIA NIM nie jest dostepny.",
            2
        )
        return
    
    _show_message(
        POLONISTA_NAME,
        "Wykonuje test polaczenia...\n\n"
        "To moze zajac kilka sekund.",
        0
    )
    
    success, result = backend.test_connection()
    
    if success:
        _show_message(POLONISTA_NAME + " - Test OK", result, 0)
    else:
        _show_message(POLONISTA_NAME + " - Test nieudany", result, 2)


def OtwsStrone(*args):
    """
    [POLONISTA] Strona projektu
    
    Otwiera strone internetowa projektu w przegladarce.
    """
    import webbrowser
    try:
        webbrowser.open("https://neuroatypowi.org")
        _show_message(
            POLONISTA_NAME,
            "Otwieram strone neuroatypowi.org w przegladarce...",
            0
        )
    except Exception as e:
        _show_message(
            POLONISTA_NAME + " - Blad",
            f"Nie mozna otworzyc przegladarki:\n{str(e)}\n\n"
            "Odwiedz recznie: https://neuroatypowi.org",
            1
        )


def PobierzKluczAPI(*args):
    """
    [POLONISTA] Pobierz klucz API
    
    Otwiera strone NVIDIA do pobrania klucza API.
    """
    import webbrowser
    url = "https://build.nvidia.com/speakleash/bielik-11b-v2-6-instruct"
    try:
        webbrowser.open(url)
        _show_message(
            POLONISTA_NAME,
            "Otwieram strone NVIDIA...\n\n"
            "INSTRUKCJA:\n"
            "1. Zaloguj sie lub utworz konto NVIDIA\n"
            "2. Kliknij 'Get API Key'\n"
            "3. Skopiuj klucz (zaczyna sie od nvapi-)\n"
            "4. Wklej do pliku .env jako:\n"
            "   NVIDIA_API_KEY=nvapi-twoj-klucz",
            0
        )
    except Exception as e:
        _show_message(
            POLONISTA_NAME + " - Blad",
            f"Odwiedz recznie:\n{url}",
            1
        )


# =============================================================================
# EKSPORT MAKR DLA LIBREOFFICE
# =============================================================================

g_exportedScripts = (
    RedagujZaznaczenie,
    RedagujCayDokument,
    PokazInformacje,
    SprawdzKonfiguracje,
    TestPolaczenia,
    OtwsStrone,
    PobierzKluczAPI,
)


# =============================================================================
# TRYB TESTOWY
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print(f"POLONISTA Menu Module v{POLONISTA_VERSION}")
    print("=" * 60)
    print()
    print("Ten modul jest przeznaczony do uruchomienia w LibreOffice.")
    print()
    print("Dostepne funkcje (makra):")
    for func in g_exportedScripts:
        print(f"  - {func.__name__}: {func.__doc__.split(chr(10))[1].strip()}")
    print()
    print("=" * 60)
