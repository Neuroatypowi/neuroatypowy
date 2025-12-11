# -*- coding: utf-8 -*-
"""
POLONISTA v2.1 - Asystent Prostego Jezyka dla LibreOffice Writer
Rozszerzenie projektu localwriter (github.com/balisujohn/localwriter)
Dostosowane do NVIDIA NIM API z modelem Bielik-11B

Stowarzyszenie Zwykle "Neuroatypowi" - https://neuroatypowi.org
Licencja: MIT

INSTALACJA:
Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/polonista.py
Linux:   ~/.config/libreoffice/4/user/Scripts/python/polonista.py
macOS:   ~/Library/Application Support/LibreOffice/4/user/Scripts/python/

KONFIGURACJA KLUCZA API:
Utworz plik .env w tym samym katalogu co polonista.py z zawartoscia:
NVIDIA_API_KEY=nvapi-twoj-klucz-api-tutaj

UZYCIE:
1. Zaznacz tekst w dokumencie Writer
2. Menu: Narzedzia > Makra > Uruchom makro
3. Wybierz: Moje makra > polonista > RedagujZaznaczenie
4. Kliknij: Uruchom
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
# KONFIGURACJA
# =============================================================================

def _get_script_directory():
    """Zwraca katalog w ktorym znajduje sie ten skrypt."""
    try:
        # Probuj uzyc __file__ jesli dostepny
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        # Fallback dla LibreOffice
        if os.name == 'nt':  # Windows
            return os.path.join(os.environ.get('APPDATA', ''), 
                               'LibreOffice', '4', 'user', 'Scripts', 'python')
        else:  # Linux/macOS
            return os.path.expanduser('~/.config/libreoffice/4/user/Scripts/python')


def _load_env_file():
    """
    Wczytuje zmienne z pliku .env.
    Zwraca slownik z kluczami i wartosciami.
    """
    env_vars = {}
    script_dir = _get_script_directory()
    env_path = os.path.join(script_dir, '.env')
    
    if not os.path.exists(env_path):
        return env_vars
    
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Pomijaj komentarze i puste linie
                if not line or line.startswith('#'):
                    continue
                # Parsuj KEY=VALUE
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    # Usun cudzyslowy jesli sa
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    env_vars[key] = value
    except Exception as e:
        pass  # Cicha obsluga bledow
    
    return env_vars


def get_api_key():
    """
    Pobiera klucz API z pliku .env lub zmiennej srodowiskowej.
    
    Kolejnosc szukania:
    1. Plik .env w katalogu skryptu (NVIDIA_API_KEY)
    2. Zmienna srodowiskowa NVIDIA_API_KEY
    3. Domyslna wartosc (placeholder)
    """
    # 1. Sprawdz plik .env
    env_vars = _load_env_file()
    if 'NVIDIA_API_KEY' in env_vars:
        return env_vars['NVIDIA_API_KEY']
    
    # 2. Sprawdz zmienna srodowiskowa
    env_key = os.environ.get('NVIDIA_API_KEY', '')
    if env_key:
        return env_key
    
    # 3. Zwroc placeholder
    return "nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ_API"


def get_endpoint():
    """Zwraca adres URL API NVIDIA NIM."""
    env_vars = _load_env_file()
    return env_vars.get('NVIDIA_ENDPOINT', 
                        "https://integrate.api.nvidia.com/v1/chat/completions")


def get_model():
    """Zwraca nazwe modelu Bielik."""
    env_vars = _load_env_file()
    return env_vars.get('NVIDIA_MODEL', 
                        "speakleash/bielik-11b-v2.6-instruct")


def get_system_prompt():
    """
    Zwraca instrukcje systemowe dla modelu AI.
    Mozesz dostosowac w pliku .env jako SYSTEM_PROMPT.
    """
    env_vars = _load_env_file()
    default_prompt = """Jestes ekspertem Prostego Jezyka polskiego (Plain Language).
Twoje zadanie: uproscic tekst zachowujac jego sens.

Zasady:
- Krotkie zdania (max 15 slow)
- Polskie slowa zamiast obcych
- Strona czynna zamiast biernej
- Jedno zdanie = jedna mysl
- Unikaj skrotow i zargonu

Zwroc TYLKO uproszczony tekst, bez komentarzy."""
    
    return env_vars.get('SYSTEM_PROMPT', default_prompt)


# =============================================================================
# FUNKCJE POMOCNICZE (prywatne)
# =============================================================================

def _validate_api_key(api_key):
    """Sprawdza poprawnosc klucza API."""
    if not api_key:
        return False, "Klucz API jest pusty. Utworz plik .env z NVIDIA_API_KEY=nvapi-xxx"
    if "TUTAJ" in api_key or "WKLEJ" in api_key:
        return False, "Utworz plik .env i wklej klucz API jako NVIDIA_API_KEY=nvapi-xxx"
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
        "User-Agent": "POLONISTA/2.1 LibreOffice"
    }
    
    data = json.dumps(payload).encode("utf-8")
    
    # Wywolanie API z obsluga bledow
    for attempt in range(max_retries):
        try:
            req = Request(get_endpoint(), data=data, headers=headers)
            response = urlopen(req, timeout=60)
            result = json.loads(response.read().decode("utf-8"))
            
            # Parsowanie odpowiedzi - POPRAWIONE
            if "choices" in result and len(result["choices"]) > 0:
                choice = result["choices"][0]
                if "message" in choice and "content" in choice["message"]:
                    return True, choice["message"]["content"].strip()
            
            return False, "[BLAD] Nieprawidlowa odpowiedz z serwera"
            
        except HTTPError as e:
            if e.code == 429:
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
    """
    try:
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
        
        msgbox = toolkit.createMessageBox(
            window, 
            0,  # INFOBOX
            1,  # OK button
            title, 
            message
        )
        msgbox.execute()
        
    except NameError:
        print(title + ": " + message)
    except Exception as e:
        print(title + ": " + message)


def _get_selected_text():
    """
    Pobiera zaznaczony tekst z aktywnego dokumentu Writer.
    """
    try:
        ctx = XSCRIPTCONTEXT.getComponentContext()
        sm = ctx.getServiceManager()
        desktop = sm.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
        
        doc = desktop.getCurrentComponent()
        if doc is None:
            return None, "Otworz dokument Writer"
        
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
    """
    text_range, text = _get_selected_text()
    
    if text_range is None:
        _show_message("POLONISTA", text)
        return
    
    success, result = _call_nvidia_api(text)
    
    if success:
        text_range.setString(result)
    else:
        _show_message("POLONISTA - Blad", result)


def PokazInformacje(*args):
    """
    Wyswietla informacje o POLONISTA.
    """
    env_path = os.path.join(_get_script_directory(), '.env')
    env_status = "ZNALEZIONY" if os.path.exists(env_path) else "BRAK"
    
    info = """POLONISTA v2.1
Asystent Prostego Jezyka

UZYCIE:
1. Zaznacz tekst w dokumencie
2. Uruchom makro RedagujZaznaczenie
3. Tekst zostanie uproszczony

MODEL: """ + get_model() + """

Plik .env: """ + env_status + """
Sciezka: """ + env_path + """

Stowarzyszenie Neuroatypowi
https://neuroatypowi.org"""
    
    _show_message("O programie POLONISTA", info)


def SprawdzKonfiguracje(*args):
    """
    Sprawdza poprawnosc konfiguracji API.
    """
    api_key = get_api_key()
    is_valid, msg = _validate_api_key(api_key)
    env_path = os.path.join(_get_script_directory(), '.env')
    
    if is_valid:
        masked_key = api_key[:10] + "..." + api_key[-4:]
        info = "Konfiguracja poprawna!\n\n"
        info += "Klucz API: " + masked_key + "\n"
        info += "Model: " + get_model() + "\n"
        info += "Endpoint: OK\n"
        info += "Plik .env: " + env_path
    else:
        info = "BLAD KONFIGURACJI\n\n" + msg
        info += "\n\nInstrukcja:\n"
        info += "1. Utworz plik .env w katalogu:\n"
        info += "   " + _get_script_directory() + "\n"
        info += "2. Dodaj linie:\n"
        info += "   NVIDIA_API_KEY=nvapi-twoj-klucz\n"
        info += "3. Zapisz plik i uruchom ponownie"
    
    _show_message("POLONISTA - Konfiguracja", info)


def TestPolaczenia(*args):
    """
    Testuje polaczenie z API NVIDIA NIM.
    """
    test_text = "To jest bardzo skomplikowane zdanie testowe."
    success, result = _call_nvidia_api(test_text)
    
    if success:
        msg = "Polaczenie dziala!\n\n"
        msg += "Wyslano: " + test_text + "\n\n"
        msg += "Odpowiedz: " + result[:200]
        if len(result) > 200:
            msg += "..."
    else:
        msg = "Polaczenie nie dziala.\n\n" + result
    
    _show_message("POLONISTA - Test", msg)


def UtworzPlikEnv(*args):
    """
    Tworzy szablon pliku .env w katalogu skryptu.
    """
    script_dir = _get_script_directory()
    env_path = os.path.join(script_dir, '.env')
    
    if os.path.exists(env_path):
        _show_message("POLONISTA", "Plik .env juz istnieje:\n" + env_path)
        return
    
    template = """# POLONISTA - Konfiguracja API
# Wklej swoj klucz API z https://build.nvidia.com

NVIDIA_API_KEY=nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ

# Opcjonalne ustawienia (domyslne wartosci):
# NVIDIA_ENDPOINT=https://integrate.api.nvidia.com/v1/chat/completions
# NVIDIA_MODEL=speakleash/bielik-11b-v2.6-instruct
"""
    
    try:
        with open(env_path, 'w', encoding='utf-8') as f:
            f.write(template)
        _show_message("POLONISTA", "Utworzono plik .env:\n" + env_path + 
                     "\n\nEdytuj plik i wklej swoj klucz API.")
    except Exception as e:
        _show_message("POLONISTA - Blad", "Nie mozna utworzyc pliku:\n" + str(e))


# =============================================================================
# EKSPORT MAKR DLA LIBREOFFICE
# =============================================================================

g_exportedScripts = (
    RedagujZaznaczenie,
    PokazInformacje,
    SprawdzKonfiguracje,
    TestPolaczenia,
    UtworzPlikEnv,
)


# =============================================================================
# TRYB TESTOWY
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("POLONISTA v2.1 - Tryb testowy")
    print("=" * 60)
    print()
    print("Katalog skryptu:", _get_script_directory())
    print("Plik .env:", os.path.join(_get_script_directory(), '.env'))
    print()
    
    api_key = get_api_key()
    is_valid, msg = _validate_api_key(api_key)
    print("Klucz API:", "OK" if is_valid else "BLAD - " + msg)
    print()
    
    if is_valid:
        print("Testowanie API...")
        test = "Implementacja algorytmu wykorzystuje zaawansowane techniki."
        success, result = _call_nvidia_api(test)
        print("Wyslano:", test)
        print("Wynik:  ", result)
    
    print()
    print("=" * 60)
