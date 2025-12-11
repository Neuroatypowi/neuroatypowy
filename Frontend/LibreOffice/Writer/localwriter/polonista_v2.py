# -*- coding: utf-8 -*-
"""
POLONISTA v2.0 - Asystent Prostego Jezyka dla LibreOffice Writer
Rozszerzenie projektu localwriter (github.com/balisujohn/localwriter)
Dostosowane do NVIDIA NIM API z modelem Bielik-11B

Stowarzyszenie Zwykle "Neuroatypowi" - https://neuroatypowi.org
Licencja: MIT

INSTALACJA:
Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/polonista.py
Linux:   ~/.config/libreoffice/4/user/Scripts/python/polonista.py
macOS:   ~/Library/Application Support/LibreOffice/4/user/Scripts/python/

UZYCIE:
1. Zaznacz tekst w dokumencie Writer
2. Menu: Narzedzia > Makra > Uruchom makro
3. Wybierz: Moje makra > polonista > RedagujZaznaczenie
4. Kliknij: Uruchom

KONFIGURACJA:
Edytuj funkcje get_api_key() ponizej i wklej swoj klucz API z build.nvidia.com
"""

from __future__ import print_function
import json
import time
import os

# Kompatybilnosc Python 2/3 dla urllib
try:
    from urllib.request import Request, urlopen
    from urllib.error import HTTPError, URLError
except ImportError:
    from urllib2 import Request, urlopen, HTTPError, URLError


# =============================================================================
# KONFIGURACJA - EDYTUJ TUTAJ
# =============================================================================

def get_api_key():
    """
    Zwraca klucz API NVIDIA NIM.
    
    INSTRUKCJA:
    1. Wejdz na https://build.nvidia.com
    2. Zaloguj sie lub utworz konto
    3. Wybierz model: speakleash/bielik-11b-v2.6-instruct
    4. Kliknij: Get API Key
    5. Skopiuj klucz zaczynajacy sie od nvapi-
    6. Wklej ponizej zamiast TUTAJ_WKLEJ_SWOJ_KLUCZ_API
    """
    return "nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ_API"


def get_endpoint():
    """Zwraca adres URL API NVIDIA NIM."""
    return "https://integrate.api.nvidia.com/v1/chat/completions"


def get_model():
    """Zwraca nazwe modelu Bielik."""
    return "speakleash/bielik-11b-v2.6-instruct"


def get_system_prompt():
    """
    Zwraca instrukcje systemowe dla modelu AI.
    Mozesz dostosowac do swoich potrzeb.
    """
    return """Jestes ekspertem Prostego Jezyka polskiego (Plain Language).
Twoje zadanie: uproscic tekst zachowujac jego sens.

Zasady:
- Krotkie zdania (max 15 slow)
- Polskie slowa zamiast obcych
- Strona czynna zamiast biernej
- Jedno zdanie = jedna mysl
- Unikaj skrotow i zargonu

Zwroc TYLKO uproszczony tekst, bez komentarzy."""


# =============================================================================
# FUNKCJE POMOCNICZE (prywatne)
# =============================================================================

def _validate_api_key(api_key):
    """Sprawdza poprawnosc klucza API."""
    if not api_key:
        return False, "Klucz API jest pusty"
    if "TUTAJ" in api_key or "WKLEJ" in api_key:
        return False, "Wklej swoj klucz API do funkcji get_api_key()"
    if not api_key.startswith("nvapi-"):
        return False, "Klucz API musi zaczynac sie od nvapi-"
    if len(api_key) < 20:
        return False, "Klucz API jest za krotki"
    return True, "OK"


def _call_nvidia_api(text, max_retries=3):
    """
    Wysyla tekst do API NVIDIA NIM i zwraca odpowiedz.
    
    Args:
        text: Tekst do uproszczenia
        max_retries: Maksymalna liczba prob przy bledzie 429
    
    Returns:
        tuple: (sukces: bool, wynik: str)
    """
    api_key = get_api_key()
    
    # Walidacja klucza
    is_valid, msg = _validate_api_key(api_key)
    if not is_valid:
        return False, "[BLAD] " + msg
    
    # Walidacja tekstu
    if not text or len(text.strip()) == 0:
        return False, "[BLAD] Tekst jest pusty"
    
    # Przygotowanie zapytania
    payload = {
        "model": get_model(),
        "messages": [
            {"role": "system", "content": get_system_prompt()},
            {"role": "user", "content": text.strip()}
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
        "stream": False
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + api_key,
        "User-Agent": "POLONISTA/2.0 LibreOffice"
    }
    
    data = json.dumps(payload).encode("utf-8")
    
    # Wywolanie API z obsluga bledow
    for attempt in range(max_retries):
        try:
            req = Request(get_endpoint(), data=data, headers=headers)
            response = urlopen(req, timeout=60)
            result = json.loads(response.read().decode("utf-8"))
            
            # Parsowanie odpowiedzi - POPRAWIONE (blad z oryginalnego kodu)
            if "choices" in result and len(result["choices"]) > 0:
                choice = result["choices"][0]
                if "message" in choice and "content" in choice["message"]:
                    return True, choice["message"]["content"].strip()
            
            return False, "[BLAD] Nieprawidlowa odpowiedz z serwera"
            
        except HTTPError as e:
            if e.code == 429:
                # Rate limit - czekaj i probuj ponownie
                wait_time = (2 ** attempt) + 1
                if attempt < max_retries - 1:
                    time.sleep(wait_time)
                    continue
                return False, "[BLAD] Limit zapytan (429) - poczekaj minute"
            elif e.code == 401:
                return False, "[BLAD] Nieprawidlowy klucz API (401)"
            elif e.code == 403:
                return False, "[BLAD] Brak dostepu do API (403)"
            elif e.code == 404:
                return False, "[BLAD] Model nie znaleziony (404)"
            else:
                return False, "[BLAD] HTTP " + str(e.code)
                
        except URLError as e:
            return False, "[BLAD] Brak polaczenia z internetem"
            
        except Exception as e:
            return False, "[BLAD] " + str(type(e).__name__) + ": " + str(e)
    
    return False, "[BLAD] Przekroczono limit prob"


def _show_message(title, message):
    """
    Wyswietla okno dialogowe w LibreOffice.
    Uzywa XSCRIPTCONTEXT jesli dostepny, inaczej print.
    """
    try:
        # Probuj uzyc LibreOffice API
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        toolkit = sm.createInstanceWithContext("com.sun.star.awt.Toolkit", ctx)
        desktop = sm.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            print(title + ": " + message)
            return
            
        controller = doc.getCurrentController()
        if controller is None:
            print(title + ": " + message)
            return
            
        frame = controller.getFrame()
        if frame is None:
            print(title + ": " + message)
            return
            
        window = frame.getContainerWindow()
        if window is None:
            print(title + ": " + message)
            return
        
        # Typ okna: INFOBOX=0, WARNINGBOX=1, ERRORBOX=2, QUERYBOX=3
        msgbox = toolkit.createMessageBox(
            window, 
            0,  # INFOBOX
            1,  # OK button
            title, 
            message
        )
        msgbox.execute()
        
    except NameError:
        # XSCRIPTCONTEXT nie jest dostepny (uruchomienie poza LibreOffice)
        print(title + ": " + message)
    except Exception as e:
        print(title + ": " + message)
        print("(Blad wyswietlania okna: " + str(e) + ")")


def _get_selected_text():
    """
    Pobiera zaznaczony tekst z aktywnego dokumentu Writer.
    
    Returns:
        tuple: (selection_object, text) lub (None, error_message)
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            return None, "Otworz dokument Writer"
        
        # Sprawdz czy to dokument tekstowy
        if not doc.supportsService("com.sun.star.text.TextDocument"):
            return None, "To nie jest dokument Writer"
        
        selection = doc.getCurrentSelection()
        if selection is None:
            return None, "Zaznacz tekst do uproszczenia"
        
        if selection.getCount() == 0:
            return None, "Zaznacz tekst do uproszczenia"
        
        text_range = selection.getByIndex(0)
        text = text_range.getString()
        
        if not text or len(text.strip()) == 0:
            return None, "Zaznaczenie jest puste"
        
        return text_range, text
        
    except NameError:
        return None, "Makro musi byc uruchomione w LibreOffice"
    except Exception as e:
        return None, "Blad: " + str(e)


# =============================================================================
# FUNKCJE PUBLICZNE (MAKRA) - WIDOCZNE W LIBREOFFICE
# =============================================================================

def RedagujZaznaczenie(*args):
    """
    GLOWNE MAKRO POLONISTA
    
    Upraszcza zaznaczony tekst przy uzyciu modelu Bielik AI.
    
    Uzycie:
    1. Zaznacz tekst w dokumencie
    2. Uruchom to makro
    3. Tekst zostanie zastapiony uproszczona wersja
    """
    # Pobierz zaznaczony tekst
    text_range, text = _get_selected_text()
    
    if text_range is None:
        _show_message("POLONISTA", text)  # text zawiera komunikat bledu
        return
    
    # Wywolaj API
    success, result = _call_nvidia_api(text)
    
    if success:
        # Zastap zaznaczony tekst wynikiem
        text_range.setString(result)
    else:
        _show_message("POLONISTA - Blad", result)


def PokazInformacje(*args):
    """
    Wyswietla informacje o POLONISTA.
    """
    info = """POLONISTA v2.0
Asystent Prostego Jezyka

UZYCIE:
1. Zaznacz tekst w dokumencie
2. Uruchom makro RedagujZaznaczenie
3. Tekst zostanie uproszczony

MODEL: NVIDIA Bielik-11B
API: build.nvidia.com

Stowarzyszenie Neuroatypowi
https://neuroatypowi.org"""
    
    _show_message("O programie POLONISTA", info)


def SprawdzKonfiguracje(*args):
    """
    Sprawdza poprawnosc konfiguracji API.
    """
    api_key = get_api_key()
    is_valid, msg = _validate_api_key(api_key)
    
    if is_valid:
        # Pokaz tylko czesc klucza dla bezpieczenstwa
        masked_key = api_key[:10] + "..." + api_key[-4:]
        info = "Konfiguracja poprawna!\n\nKlucz API: " + masked_key
        info += "\nModel: " + get_model()
        info += "\nEndpoint: OK"
    else:
        info = "BLAD KONFIGURACJI\n\n" + msg
        info += "\n\nInstrukcja:\n"
        info += "1. Wejdz na https://build.nvidia.com\n"
        info += "2. Zaloguj sie\n"
        info += "3. Wybierz model Bielik\n"
        info += "4. Skopiuj klucz API\n"
        info += "5. Wklej w pliku polonista.py"
    
    _show_message("POLONISTA - Konfiguracja", info)


def TestPolaczenia(*args):
    """
    Testuje polaczenie z API NVIDIA NIM.
    """
    _show_message("POLONISTA", "Testowanie polaczenia z API...")
    
    test_text = "To jest bardzo skomplikowane zdanie testowe."
    success, result = _call_nvidia_api(test_text)
    
    if success:
        msg = "Polaczenie dziala!\n\nWyslano: " + test_text
        msg += "\n\nOdpowiedz: " + result[:200]
        if len(result) > 200:
            msg += "..."
    else:
        msg = "Polaczenie nie dziala.\n\n" + result
    
    _show_message("POLONISTA - Test", msg)


# =============================================================================
# EKSPORT MAKR DLA LIBREOFFICE
# =============================================================================

# Ta zmienna mowi LibreOffice ktore funkcje maja byc widoczne jako makra.
# WAZNE: Musi byc krotka (tuple) z referencjami do funkcji.
g_exportedScripts = (
    RedagujZaznaczenie,
    PokazInformacje,
    SprawdzKonfiguracje,
    TestPolaczenia,
)


# =============================================================================
# TRYB TESTOWY (uruchomienie poza LibreOffice)
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("POLONISTA v2.0 - Tryb testowy")
    print("=" * 60)
    print()
    
    # Test walidacji klucza
    api_key = get_api_key()
    is_valid, msg = _validate_api_key(api_key)
    print("Klucz API: " + ("OK" if is_valid else "BLAD - " + msg))
    print()
    
    if is_valid:
        print("Testowanie API...")
        test = "Implementacja algorytmu wykorzystuje zaawansowane techniki."
        success, result = _call_nvidia_api(test)
        print("Wyslano: " + test)
        print("Wynik:   " + result)
    else:
        print("Wklej prawidlowy klucz API aby przetestowac polaczenie.")
    
    print()
    print("=" * 60)
