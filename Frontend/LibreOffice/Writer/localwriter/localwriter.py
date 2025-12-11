# -*- coding: utf-8 -*-
"""
localwriter.py - Glowny modul projektu localwriter
===================================================

POPRAWIONA WERSJA z naprawionymi bledami i integracja POLONISTA.

Oryginalny projekt: github.com/balisujohn/localwriter
Poprawki i rozszerzenie: Stowarzyszenie Zwykle "Neuroatypowi"

NAPRAWIONE BLEDY:
1. result['choices'][0]['message']['content'] - dodano [0]
2. Inicjalizacja zmiennej redacted_paragraphs = []
3. Walidacja klucza API przed uzyciem
4. Obsluga bledow zamiast cichego fail
5. Inteligentne dzielenie tekstu na chunki

INSTALACJA:
Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/localwriter/
Linux:   ~/.config/libreoffice/4/user/Scripts/python/localwriter/
"""

from __future__ import print_function, absolute_import

import os
import sys
import re

# Dodaj katalog do sciezki
try:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if script_dir not in sys.path:
        sys.path.insert(0, script_dir)
except:
    pass

# Import backendu
try:
    from backends import get_backend, simplify, process_paragraphs
    from backends.nvidia_nim_backend import NvidiaNimBackend
    BACKEND_AVAILABLE = True
except ImportError:
    BACKEND_AVAILABLE = False
    NvidiaNimBackend = None


# =============================================================================
# WERSJA I STALE
# =============================================================================

__version__ = "2.1.0"
__author__ = "balisujohn + Neuroatypowi"


# =============================================================================
# FUNKCJE POMOCNICZE
# =============================================================================

def validate_api_key(api_key):
    """
    [POPRAWKA #3] Walidacja klucza API.
    
    Args:
        api_key: Klucz API do sprawdzenia
    
    Returns:
        Tuple (is_valid: bool, error_message: str)
    """
    if not api_key:
        return False, "Klucz API jest pusty"
    
    if not isinstance(api_key, str):
        return False, "Klucz API musi byc tekstem"
    
    api_key = api_key.strip()
    
    # Sprawdz placeholdery
    placeholder_patterns = [
        "TUTAJ", "WKLEJ", "YOUR_KEY", "API_KEY", "xxx", "..."
    ]
    for pattern in placeholder_patterns:
        if pattern.lower() in api_key.lower():
            return False, f"Klucz API zawiera placeholder: {pattern}"
    
    # Sprawdz prefix dla NVIDIA
    if not api_key.startswith("nvapi-"):
        return False, "Klucz NVIDIA musi zaczynac sie od 'nvapi-'"
    
    # Sprawdz minimalna dlugosc
    if len(api_key) < 20:
        return False, "Klucz API jest za krotki"
    
    # Sprawdz dozwolone znaki
    key_body = api_key[6:]  # Po "nvapi-"
    if not re.match(r'^[A-Za-z0-9_-]+$', key_body):
        return False, "Klucz API zawiera niedozwolone znaki"
    
    return True, "OK"


def smart_chunk_text(text, max_chunk_size=3000):
    """
    [POPRAWKA #5] Inteligentne dzielenie tekstu na czesci.
    
    Zamiast naiwnego podzialu przez '\\n\\n', dzieli tekst
    zachowujac strukture zdan i akapitow.
    
    Args:
        text: Tekst do podzialu
        max_chunk_size: Maksymalna dlugosc pojedynczego chunka
    
    Returns:
        Lista chunkow tekstowych
    """
    if not text:
        return []
    
    text = text.strip()
    
    # Jesli tekst jest krotki, zwroc jako jeden chunk
    if len(text) <= max_chunk_size:
        return [text]
    
    chunks = []
    current_pos = 0
    
    while current_pos < len(text):
        # Okresl koniec potencjalnego chunka
        end_pos = min(current_pos + max_chunk_size, len(text))
        
        # Jesli to ostatni fragment
        if end_pos >= len(text):
            chunk = text[current_pos:].strip()
            if chunk:
                chunks.append(chunk)
            break
        
        # Znajdz najlepszy punkt podzialu
        chunk_text = text[current_pos:end_pos]
        best_split = -1
        
        # Priorytet 1: Podwojny enter (koniec akapitu)
        split_pos = chunk_text.rfind("\n\n")
        if split_pos > max_chunk_size * 0.3:
            best_split = split_pos
            separator_len = 2
        
        # Priorytet 2: Pojedynczy enter
        if best_split == -1:
            split_pos = chunk_text.rfind("\n")
            if split_pos > max_chunk_size * 0.5:
                best_split = split_pos
                separator_len = 1
        
        # Priorytet 3: Koniec zdania
        if best_split == -1:
            # Szukaj od konca: . ! ?
            for punct in [". ", "! ", "? ", ".\n", "!\n", "?\n"]:
                split_pos = chunk_text.rfind(punct)
                if split_pos > max_chunk_size * 0.5:
                    best_split = split_pos + 1  # Wlacz znak interpunkcji
                    separator_len = 1
                    break
        
        # Priorytet 4: Przecinek lub srednik
        if best_split == -1:
            for punct in [", ", "; ", ",\n", ";\n"]:
                split_pos = chunk_text.rfind(punct)
                if split_pos > max_chunk_size * 0.5:
                    best_split = split_pos + 1
                    separator_len = 1
                    break
        
        # Priorytet 5: Spacja (ostatecznosc)
        if best_split == -1:
            split_pos = chunk_text.rfind(" ")
            if split_pos > 0:
                best_split = split_pos
                separator_len = 1
            else:
                # Twardy podzial
                best_split = max_chunk_size
                separator_len = 0
        
        # Dodaj chunk
        chunk = text[current_pos:current_pos + best_split].strip()
        if chunk:
            chunks.append(chunk)
        
        current_pos = current_pos + best_split + separator_len
    
    return chunks


def process_document_text(full_text, backend=None, progress_callback=None):
    """
    Przetwarza pelny tekst dokumentu.
    
    Args:
        full_text: Caly tekst dokumentu
        backend: Instancja backendu (opcjonalna)
        progress_callback: Funkcja callback dla postepy
    
    Returns:
        Tuple (success: bool, result: str)
    """
    if not full_text or not full_text.strip():
        return False, "Tekst jest pusty"
    
    # Uzyj backendu jesli dostepny
    if backend is None and BACKEND_AVAILABLE:
        from backends import get_backend
        backend = get_backend()
    
    if backend is None:
        return False, "Backend nie jest dostepny"
    
    # Przetwarzaj dlugi tekst
    return backend.simplify_long_text(
        full_text, 
        progress_callback=progress_callback
    )


def extract_paragraphs(text):
    """
    Wyodrebnia akapity z tekstu.
    
    [POPRAWKA #2] - prawidlowa inicjalizacja zmiennej
    
    Args:
        text: Tekst zrodlowy
    
    Returns:
        Lista akapitow
    """
    # POPRAWKA: Zmienna musi byc zainicjalizowana
    paragraphs = []  # <-- POPRAWKA #2
    
    if not text:
        return paragraphs
    
    # Podziel przez podwojne entery
    raw_paragraphs = text.split("\n\n")
    
    for para in raw_paragraphs:
        para = para.strip()
        if para:
            paragraphs.append(para)
    
    # Jesli nie ma podwojnych enterow, probuj pojedyncze
    if len(paragraphs) <= 1 and "\n" in text:
        paragraphs = []
        for line in text.split("\n"):
            line = line.strip()
            if line:
                paragraphs.append(line)
    
    # Jesli nadal pusto, zwroc caly tekst jako jeden akapit
    if not paragraphs and text.strip():
        paragraphs = [text.strip()]
    
    return paragraphs


def parse_api_response(response_json):
    """
    [POPRAWKA #1] Poprawne parsowanie odpowiedzi API.
    
    Oryginalny blad:
        result['choices']['message']['content']  # ZLE
    
    Poprawka:
        result['choices'][0]['message']['content']  # DOBRZE
    
    Args:
        response_json: Odpowiedz JSON z API
    
    Returns:
        Tuple (success: bool, content: str)
    """
    try:
        # Sprawdz czy mamy 'choices'
        if 'choices' not in response_json:
            return False, "Brak 'choices' w odpowiedzi API"
        
        choices = response_json['choices']
        
        # Sprawdz czy 'choices' nie jest pusty
        if not choices or len(choices) == 0:
            return False, "Lista 'choices' jest pusta"
        
        # POPRAWKA #1: Pobierz PIERWSZY element [0]
        first_choice = choices[0]
        
        # Sprawdz czy mamy 'message'
        if 'message' not in first_choice:
            return False, "Brak 'message' w odpowiedzi API"
        
        message = first_choice['message']
        
        # Sprawdz czy mamy 'content'
        if 'content' not in message:
            return False, "Brak 'content' w odpowiedzi API"
        
        content = message['content']
        
        if content is None:
            return False, "Odpowiedz API jest null"
        
        return True, str(content).strip()
        
    except KeyError as e:
        return False, f"Brak klucza w odpowiedzi: {e}"
    except IndexError as e:
        return False, f"Blad indeksu w odpowiedzi: {e}"
    except Exception as e:
        return False, f"Blad parsowania: {type(e).__name__}: {e}"


def show_error_dialog(error_message, title="localwriter - Blad"):
    """
    [POPRAWKA #4] Wyswietla blad zamiast cichego fail.
    
    Args:
        error_message: Tresc komunikatu bledu
        title: Tytul okna dialogowego
    """
    try:
        # Probuj wyswietlic dialog LibreOffice
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        toolkit = sm.createInstanceWithContext(
            "com.sun.star.awt.Toolkit", ctx
        )
        desktop = sm.createInstanceWithContext(
            "com.sun.star.frame.Desktop", ctx
        )
        
        doc = desktop.getCurrentComponent()
        if doc:
            controller = doc.getCurrentController()
            if controller:
                frame = controller.getFrame()
                if frame:
                    window = frame.getContainerWindow()
                    if window:
                        msgbox = toolkit.createMessageBox(
                            window, 2, 1,  # ERRORBOX, OK
                            str(title), 
                            str(error_message)
                        )
                        msgbox.execute()
                        return
        
        # Fallback do print
        print(f"[BLAD] {title}: {error_message}")
        
    except NameError:
        # XSCRIPTCONTEXT nie dostepny (poza LibreOffice)
        print(f"[BLAD] {title}: {error_message}")
    except Exception as e:
        print(f"[BLAD] {title}: {error_message}")
        print(f"       (Dodatkowo: {e})")


# =============================================================================
# FUNKCJE GLOWNE - MAKRA
# =============================================================================

def SimplifySelection(*args):
    """
    Upraszcza zaznaczony tekst w dokumencie Writer.
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext(
            "com.sun.star.frame.Desktop", ctx
        )
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            show_error_dialog("Otworz dokument Writer")
            return
        
        if not doc.supportsService("com.sun.star.text.TextDocument"):
            show_error_dialog("To nie jest dokument Writer")
            return
        
        selection = doc.getCurrentSelection()
        if selection is None or selection.getCount() == 0:
            show_error_dialog("Zaznacz tekst do uproszczenia")
            return
        
        text_range = selection.getByIndex(0)
        original_text = text_range.getString()
        
        if not original_text or not original_text.strip():
            show_error_dialog("Zaznaczenie jest puste")
            return
        
        # Uzyj backendu
        if not BACKEND_AVAILABLE:
            show_error_dialog(
                "Backend nie jest dostepny.\n"
                "Sprawdz instalacje plikow w katalogu backends/"
            )
            return
        
        backend = get_backend()
        success, result = backend.simplify_text(original_text)
        
        if success:
            text_range.setString(result)
        else:
            show_error_dialog(result)
            
    except NameError:
        print("[BLAD] SimplifySelection: Uruchom w LibreOffice")
    except Exception as e:
        show_error_dialog(f"Nieoczekiwany blad:\n{type(e).__name__}: {e}")


def SimplifyDocument(*args):
    """
    Upraszcza caly dokument Writer.
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext(
            "com.sun.star.frame.Desktop", ctx
        )
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            show_error_dialog("Otworz dokument Writer")
            return
        
        if not doc.supportsService("com.sun.star.text.TextDocument"):
            show_error_dialog("To nie jest dokument Writer")
            return
        
        text = doc.getText()
        full_text = text.getString()
        
        if not full_text or not full_text.strip():
            show_error_dialog("Dokument jest pusty")
            return
        
        if not BACKEND_AVAILABLE:
            show_error_dialog("Backend nie jest dostepny")
            return
        
        backend = get_backend()
        success, result = backend.simplify_long_text(full_text)
        
        if success:
            text.setString(result)
        else:
            show_error_dialog(result)
            
    except NameError:
        print("[BLAD] SimplifyDocument: Uruchom w LibreOffice")
    except Exception as e:
        show_error_dialog(f"Nieoczekiwany blad:\n{type(e).__name__}: {e}")


def ShowInfo(*args):
    """
    Wyswietla informacje o programie.
    """
    info = f"""localwriter v{__version__}
z rozszerzeniem POLONISTA

NAPRAWIONE BLEDY:
1. Parsowanie odpowiedzi API [0]
2. Inicjalizacja zmiennych
3. Walidacja klucza API
4. Obsluga bledow
5. Inteligentne dzielenie tekstu

Backend: {'OK' if BACKEND_AVAILABLE else 'BRAK'}

Oryginal: github.com/balisujohn/localwriter
Poprawki: Stowarzyszenie Neuroatypowi
Strona: https://neuroatypowi.org"""
    
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        toolkit = sm.createInstanceWithContext(
            "com.sun.star.awt.Toolkit", ctx
        )
        desktop = sm.createInstanceWithContext(
            "com.sun.star.frame.Desktop", ctx
        )
        
        doc = desktop.getCurrentComponent()
        if doc:
            controller = doc.getCurrentController()
            if controller:
                frame = controller.getFrame()
                if frame:
                    window = frame.getContainerWindow()
                    if window:
                        msgbox = toolkit.createMessageBox(
                            window, 0, 1,
                            "O programie localwriter",
                            info
                        )
                        msgbox.execute()
                        return
        
        print(info)
        
    except NameError:
        print(info)
    except Exception:
        print(info)


# =============================================================================
# EKSPORT MAKR
# =============================================================================

g_exportedScripts = (
    SimplifySelection,
    SimplifyDocument,
    ShowInfo,
)


# =============================================================================
# TRYB TESTOWY
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print(f"localwriter v{__version__} - Test")
    print("=" * 60)
    print()
    
    # Test walidacji klucza
    print("Test walidacji klucza API:")
    test_keys = [
        "",
        "abc",
        "nvapi-test",
        "nvapi-TUTAJ_WKLEJ",
        "nvapi-" + "a" * 50,
    ]
    for key in test_keys:
        valid, msg = validate_api_key(key)
        status = "OK" if valid else f"BLAD: {msg}"
        display_key = key[:20] + "..." if len(key) > 20 else key
        print(f"  '{display_key}' -> {status}")
    
    print()
    
    # Test dzielenia tekstu
    print("Test dzielenia tekstu:")
    test_text = "Pierwsze zdanie. Drugie zdanie. Trzecie zdanie.\n\nNowy akapit tutaj."
    chunks = smart_chunk_text(test_text, 30)
    print(f"  Wejscie: {len(test_text)} znakow")
    print(f"  Chunki: {len(chunks)}")
    for i, chunk in enumerate(chunks):
        print(f"    {i+1}: '{chunk[:30]}...' ({len(chunk)} zn.)")
    
    print()
    
    # Test parsowania odpowiedzi
    print("Test parsowania odpowiedzi API:")
    test_responses = [
        {"choices": [{"message": {"content": "OK"}}]},
        {"choices": []},
        {"error": "test"},
        {"choices": [{"message": {}}]},
    ]
    for resp in test_responses:
        success, content = parse_api_response(resp)
        print(f"  {resp} -> {'OK: ' + content if success else 'BLAD: ' + content}")
    
    print()
    print("=" * 60)
