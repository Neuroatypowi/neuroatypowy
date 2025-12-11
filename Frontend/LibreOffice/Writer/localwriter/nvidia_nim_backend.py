# -*- coding: utf-8 -*-
"""
nvidia_nim_backend.py - Backend NVIDIA NIM dla projektu localwriter
====================================================================

Plik do wgrania w:
    localwriter/backends/nvidia_nim_backend.py

Repozytorium: github.com/balisujohn/localwriter
Rozszerzenie: POLONISTA - Asystent Prostego Jezyka
Autor: Stowarzyszenie Zwykle "Neuroatypowi"
Strona: https://neuroatypowi.org
Licencja: MIT

INSTALACJA:
1. Sklonuj repozytorium localwriter
2. Skopiuj ten plik do: localwriter/backends/nvidia_nim_backend.py
3. Zarejestruj backend w localwriter/backends/__init__.py
4. Utworz plik .env z kluczem NVIDIA_API_KEY

WYMAGANIA:
- Python 3.7+
- Klucz API NVIDIA NIM: https://build.nvidia.com
"""

from __future__ import print_function, absolute_import, division

import json
import time
import os
import re
from typing import Optional, Tuple, Dict, Any, List

# Kompatybilnosc Python 2/3
try:
    from urllib.request import Request, urlopen
    from urllib.error import HTTPError, URLError
except ImportError:
    from urllib2 import Request, urlopen, HTTPError, URLError


# =============================================================================
# KONFIGURACJA DOMYSLNA
# =============================================================================

DEFAULT_CONFIG = {
    "endpoint": "https://integrate.api.nvidia.com/v1/chat/completions",
    "model": "speakleash/bielik-11b-v2.6-instruct",
    "temperature": 0.3,
    "max_tokens": 2048,
    "timeout": 60,
    "max_retries": 5,
    "rate_limit_rpm": 40,
    "chunk_size": 3000,  # Max znakow na zapytanie
}

SYSTEM_PROMPT_PLAIN_LANGUAGE = """Jestes ekspertem Prostego Jezyka polskiego (Plain Language).
Twoje zadanie: przeksztalcic tekst na prosty, zrozumialy jezyk.

ZASADY PROSTEGO JEZYKA:
1. Krotkie zdania - maksymalnie 15 slow
2. Jedno zdanie = jedna mysl
3. Polskie slowa zamiast obcych (np. "spotkanie" zamiast "meeting")
4. Strona czynna zamiast biernej (np. "minister podpisal" zamiast "zostalo podpisane")
5. Konkretne przykladyki zamiast abstrakcji
6. Unikaj skrotow - pisz pelne nazwy
7. Unikaj zargonu prawnego i urzedowego
8. Pisz do odbiorcy bezposrednio ("Musisz..." zamiast "Nalezy...")

FORMATOWANIE:
- Zachowaj strukture akapitow
- Nie dodawaj komentarzy ani objasnienia
- Zwroc TYLKO uproszczony tekst

Uproscij ponizszy tekst:"""


# =============================================================================
# KLASA GLOWNA: NvidiaNimBackend
# =============================================================================

class NvidiaNimBackend:
    """
    Backend do komunikacji z NVIDIA NIM API.
    Obsluguje model Bielik-11B do upraszczania tekstu.
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        Inicjalizacja backendu.
        
        Args:
            config: Slownik z konfiguracjka (opcjonalnie)
        """
        self.config = {**DEFAULT_CONFIG}
        if config:
            self.config.update(config)
        
        self._api_key: Optional[str] = None
        self._last_request_time: float = 0
        self._request_count: int = 0
        
        # Wczytaj klucz API
        self._load_api_key()
    
    # -------------------------------------------------------------------------
    # KONFIGURACJA I KLUCZ API
    # -------------------------------------------------------------------------
    
    def _get_env_file_paths(self) -> List[str]:
        """Zwraca liste mozliwych lokalizacji pliku .env."""
        paths = []
        
        # 1. Katalog biezacy
        paths.append(os.path.join(os.getcwd(), ".env"))
        
        # 2. Katalog tego skryptu
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            paths.append(os.path.join(script_dir, ".env"))
            # Katalog nadrzedny (localwriter/)
            paths.append(os.path.join(os.path.dirname(script_dir), ".env"))
        except:
            pass
        
        # 3. Katalog domowy uzytkownika
        home = os.path.expanduser("~")
        paths.append(os.path.join(home, ".env"))
        paths.append(os.path.join(home, ".polonista", ".env"))
        
        # 4. LibreOffice Scripts (Windows)
        if os.name == 'nt':
            appdata = os.environ.get('APPDATA', '')
            if appdata:
                paths.append(os.path.join(
                    appdata, 'LibreOffice', '4', 'user', 'Scripts', 'python', '.env'
                ))
        
        # 5. LibreOffice Scripts (Linux/macOS)
        else:
            paths.append(os.path.join(
                home, '.config', 'libreoffice', '4', 'user', 'Scripts', 'python', '.env'
            ))
        
        return paths
    
    def _parse_env_file(self, filepath: str) -> Dict[str, str]:
        """Parsuje plik .env i zwraca slownik zmiennych."""
        env_vars = {}
        
        if not os.path.exists(filepath):
            return env_vars
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    
                    # Pomijaj komentarze i puste linie
                    if not line or line.startswith('#'):
                        continue
                    
                    # Parsuj KEY=VALUE
                    if '=' not in line:
                        continue
                    
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Usun cudzyslowy
                    if len(value) >= 2:
                        if (value[0] == '"' and value[-1] == '"') or \
                           (value[0] == "'" and value[-1] == "'"):
                            value = value[1:-1]
                    
                    env_vars[key] = value
                    
        except Exception as e:
            pass
        
        return env_vars
    
    def _load_api_key(self) -> None:
        """Wczytuje klucz API z pliku .env lub zmiennych srodowiskowych."""
        
        # 1. Sprawdz pliki .env
        for env_path in self._get_env_file_paths():
            env_vars = self._parse_env_file(env_path)
            if 'NVIDIA_API_KEY' in env_vars:
                self._api_key = env_vars['NVIDIA_API_KEY']
                
                # Wczytaj tez inne opcjonalne zmienne
                if 'NVIDIA_ENDPOINT' in env_vars:
                    self.config['endpoint'] = env_vars['NVIDIA_ENDPOINT']
                if 'NVIDIA_MODEL' in env_vars:
                    self.config['model'] = env_vars['NVIDIA_MODEL']
                
                return
        
        # 2. Sprawdz zmienna srodowiskowa
        env_key = os.environ.get('NVIDIA_API_KEY')
        if env_key:
            self._api_key = env_key
            return
        
        # 3. Brak klucza
        self._api_key = None
    
    def set_api_key(self, api_key: str) -> None:
        """Ustawia klucz API programowo."""
        self._api_key = api_key
    
    def get_api_key(self) -> Optional[str]:
        """Zwraca aktualny klucz API."""
        return self._api_key
    
    def validate_api_key(self) -> Tuple[bool, str]:
        """
        Sprawdza poprawnosc klucza API.
        
        Returns:
            Tuple (is_valid: bool, message: str)
        """
        if not self._api_key:
            return False, "Brak klucza API. Utworz plik .env z NVIDIA_API_KEY=nvapi-xxx"
        
        if "TUTAJ" in self._api_key or "WKLEJ" in self._api_key:
            return False, "Klucz API zawiera placeholder. Wklej prawdziwy klucz."
        
        if not self._api_key.startswith("nvapi-"):
            return False, "Klucz API musi zaczynac sie od 'nvapi-'"
        
        if len(self._api_key) < 20:
            return False, "Klucz API jest za krotki"
        
        # Sprawdz format - tylko alfanumeryczne i myslniki po prefixie
        key_body = self._api_key[6:]  # Po "nvapi-"
        if not re.match(r'^[A-Za-z0-9_-]+$', key_body):
            return False, "Klucz API zawiera niedozwolone znaki"
        
        return True, "OK"
    
    # -------------------------------------------------------------------------
    # RATE LIMITING
    # -------------------------------------------------------------------------
    
    def _wait_for_rate_limit(self) -> None:
        """Czeka jesli potrzebne dla zachowania limitu 40 RPM."""
        min_interval = 60.0 / self.config['rate_limit_rpm']  # ~1.5 sekundy
        
        now = time.time()
        elapsed = now - self._last_request_time
        
        if elapsed < min_interval:
            wait_time = min_interval - elapsed
            time.sleep(wait_time)
        
        self._last_request_time = time.time()
        self._request_count += 1
    
    # -------------------------------------------------------------------------
    # WYWOLANIE API
    # -------------------------------------------------------------------------
    
    def _make_request(
        self, 
        messages: List[Dict[str, str]], 
        retry_count: int = 0
    ) -> Tuple[bool, str]:
        """
        Wykonuje pojedyncze zapytanie do API.
        
        Args:
            messages: Lista wiadomosci [{role, content}, ...]
            retry_count: Numer aktualnej proby (dla rekurencji)
        
        Returns:
            Tuple (success: bool, result: str)
        """
        # Walidacja
        is_valid, msg = self.validate_api_key()
        if not is_valid:
            return False, f"[BLAD] {msg}"
        
        # Rate limiting
        self._wait_for_rate_limit()
        
        # Przygotowanie payload
        payload = {
            "model": self.config['model'],
            "messages": messages,
            "temperature": self.config['temperature'],
            "max_tokens": self.config['max_tokens'],
            "stream": False
        }
        
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._api_key}",
            "User-Agent": "POLONISTA/2.1 localwriter-nvidia-backend"
        }
        
        data = json.dumps(payload).encode('utf-8')
        
        try:
            req = Request(
                self.config['endpoint'],
                data=data,
                headers=headers
            )
            
            response = urlopen(req, timeout=self.config['timeout'])
            result = json.loads(response.read().decode('utf-8'))
            
            # Parsowanie odpowiedzi - POPRAWIONE
            if 'choices' not in result:
                return False, "[BLAD] Brak 'choices' w odpowiedzi API"
            
            if len(result['choices']) == 0:
                return False, "[BLAD] Pusta lista 'choices' w odpowiedzi API"
            
            choice = result['choices'][0]
            
            if 'message' not in choice:
                return False, "[BLAD] Brak 'message' w odpowiedzi API"
            
            if 'content' not in choice['message']:
                return False, "[BLAD] Brak 'content' w odpowiedzi API"
            
            content = choice['message']['content']
            
            if content is None:
                return False, "[BLAD] Odpowiedz API jest pusta (null)"
            
            return True, content.strip()
            
        except HTTPError as e:
            error_body = ""
            try:
                error_body = e.read().decode('utf-8')
            except:
                pass
            
            if e.code == 429:
                # Rate limit - exponential backoff
                if retry_count < self.config['max_retries']:
                    wait_time = (2 ** retry_count) + 1
                    time.sleep(wait_time)
                    return self._make_request(messages, retry_count + 1)
                return False, f"[BLAD 429] Przekroczono limit zapytan. Poczekaj minute."
            
            elif e.code == 401:
                return False, "[BLAD 401] Nieprawidlowy klucz API"
            
            elif e.code == 403:
                return False, "[BLAD 403] Brak dostepu do API lub modelu"
            
            elif e.code == 404:
                return False, f"[BLAD 404] Model nie znaleziony: {self.config['model']}"
            
            elif e.code >= 500:
                # Blad serwera - sprobuj ponownie
                if retry_count < self.config['max_retries']:
                    wait_time = (2 ** retry_count) + 1
                    time.sleep(wait_time)
                    return self._make_request(messages, retry_count + 1)
                return False, f"[BLAD {e.code}] Blad serwera NVIDIA"
            
            else:
                return False, f"[BLAD HTTP {e.code}] {error_body[:200]}"
                
        except URLError as e:
            return False, f"[BLAD] Brak polaczenia z internetem: {str(e.reason)}"
            
        except json.JSONDecodeError as e:
            return False, f"[BLAD] Nieprawidlowa odpowiedz JSON: {str(e)}"
            
        except Exception as e:
            return False, f"[BLAD] {type(e).__name__}: {str(e)}"
    
    # -------------------------------------------------------------------------
    # INTERFEJS PUBLICZNY
    # -------------------------------------------------------------------------
    
    def simplify_text(
        self, 
        text: str, 
        system_prompt: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Upraszcza tekst uzywajac modelu Bielik.
        
        Args:
            text: Tekst do uproszczenia
            system_prompt: Opcjonalny wlasny prompt systemowy
        
        Returns:
            Tuple (success: bool, result: str)
        """
        if not text or len(text.strip()) == 0:
            return False, "[BLAD] Tekst jest pusty"
        
        prompt = system_prompt or SYSTEM_PROMPT_PLAIN_LANGUAGE
        
        messages = [
            {"role": "system", "content": prompt},
            {"role": "user", "content": text.strip()}
        ]
        
        return self._make_request(messages)
    
    def simplify_long_text(
        self, 
        text: str, 
        system_prompt: Optional[str] = None,
        progress_callback: Optional[callable] = None
    ) -> Tuple[bool, str]:
        """
        Upraszcza dlugi tekst dzielac go na czesci.
        
        Args:
            text: Dlugi tekst do uproszczenia
            system_prompt: Opcjonalny wlasny prompt systemowy
            progress_callback: Funkcja wywoływana po kazdym chunku
                              callback(current_chunk, total_chunks, partial_result)
        
        Returns:
            Tuple (success: bool, result: str)
        """
        if not text or len(text.strip()) == 0:
            return False, "[BLAD] Tekst jest pusty"
        
        text = text.strip()
        chunk_size = self.config['chunk_size']
        
        # Jesli tekst jest krotki, przetwarzaj normalnie
        if len(text) <= chunk_size:
            return self.simplify_text(text, system_prompt)
        
        # Podziel tekst na chunki
        chunks = self._smart_chunk_text(text, chunk_size)
        total_chunks = len(chunks)
        results = []
        
        for i, chunk in enumerate(chunks):
            success, result = self.simplify_text(chunk, system_prompt)
            
            if not success:
                # Zwroc czesciowy wynik z bledem
                partial = "\n\n".join(results)
                return False, f"{partial}\n\n[BLAD w czesci {i+1}/{total_chunks}] {result}"
            
            results.append(result)
            
            # Callback dla progress bar
            if progress_callback:
                try:
                    progress_callback(i + 1, total_chunks, "\n\n".join(results))
                except:
                    pass
        
        return True, "\n\n".join(results)
    
    def _smart_chunk_text(self, text: str, max_size: int) -> List[str]:
        """
        Inteligentnie dzieli tekst na czesci.
        
        Priorytet podzialu:
        1. Podwojny enter (akapity)
        2. Pojedynczy enter
        3. Koniec zdania (. ! ?)
        4. Przecinek lub srednik
        5. Spacja
        """
        chunks = []
        current_pos = 0
        
        while current_pos < len(text):
            # Okresl koniec tego chunka
            end_pos = min(current_pos + max_size, len(text))
            
            # Jesli to ostatni chunk, dodaj reszte
            if end_pos >= len(text):
                chunks.append(text[current_pos:].strip())
                break
            
            # Szukaj najlepszego punktu podzialu
            chunk_text = text[current_pos:end_pos]
            
            # Priorytet 1: Podwojny enter (akapit)
            split_pos = chunk_text.rfind("\n\n")
            if split_pos > max_size * 0.3:
                chunks.append(text[current_pos:current_pos + split_pos].strip())
                current_pos = current_pos + split_pos + 2
                continue
            
            # Priorytet 2: Pojedynczy enter
            split_pos = chunk_text.rfind("\n")
            if split_pos > max_size * 0.5:
                chunks.append(text[current_pos:current_pos + split_pos].strip())
                current_pos = current_pos + split_pos + 1
                continue
            
            # Priorytet 3: Koniec zdania
            for punct in [". ", "! ", "? "]:
                split_pos = chunk_text.rfind(punct)
                if split_pos > max_size * 0.5:
                    chunks.append(text[current_pos:current_pos + split_pos + 1].strip())
                    current_pos = current_pos + split_pos + 2
                    break
            else:
                # Priorytet 4: Przecinek lub srednik
                for punct in [", ", "; "]:
                    split_pos = chunk_text.rfind(punct)
                    if split_pos > max_size * 0.5:
                        chunks.append(text[current_pos:current_pos + split_pos + 1].strip())
                        current_pos = current_pos + split_pos + 2
                        break
                else:
                    # Priorytet 5: Spacja
                    split_pos = chunk_text.rfind(" ")
                    if split_pos > 0:
                        chunks.append(text[current_pos:current_pos + split_pos].strip())
                        current_pos = current_pos + split_pos + 1
                    else:
                        # Ostatecznosc: twardy podzial
                        chunks.append(chunk_text.strip())
                        current_pos = end_pos
        
        return [c for c in chunks if c]  # Usun puste
    
    def chat(
        self, 
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        system_prompt: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Ogolny chat z modelem (nie tylko upraszczanie).
        
        Args:
            user_message: Wiadomosc uzytkownika
            conversation_history: Opcjonalna historia konwersacji
            system_prompt: Opcjonalny prompt systemowy
        
        Returns:
            Tuple (success: bool, response: str)
        """
        messages = []
        
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        if conversation_history:
            messages.extend(conversation_history)
        
        messages.append({"role": "user", "content": user_message})
        
        return self._make_request(messages)
    
    def test_connection(self) -> Tuple[bool, str]:
        """
        Testuje polaczenie z API.
        
        Returns:
            Tuple (success: bool, message: str)
        """
        test_text = "To jest bardzo skomplikowane zdanie testowe."
        success, result = self.simplify_text(test_text)
        
        if success:
            return True, f"Polaczenie dziala!\n\nWyslano: {test_text}\nOtrzymano: {result}"
        else:
            return False, f"Polaczenie nie dziala.\n\n{result}"
    
    def get_info(self) -> Dict[str, Any]:
        """Zwraca informacje o konfiguracji backendu."""
        api_key = self._api_key or ""
        masked_key = "BRAK"
        if api_key and len(api_key) > 14:
            masked_key = api_key[:10] + "..." + api_key[-4:]
        
        return {
            "name": "NVIDIA NIM Backend",
            "version": "2.1",
            "model": self.config['model'],
            "endpoint": self.config['endpoint'],
            "api_key_status": masked_key,
            "rate_limit_rpm": self.config['rate_limit_rpm'],
            "request_count": self._request_count,
        }


# =============================================================================
# FUNKCJE POMOCNICZE (dla zgodnosci z localwriter)
# =============================================================================

# Globalna instancja backendu
_backend_instance: Optional[NvidiaNimBackend] = None

def get_backend() -> NvidiaNimBackend:
    """Zwraca globalna instancje backendu (singleton)."""
    global _backend_instance
    if _backend_instance is None:
        _backend_instance = NvidiaNimBackend()
    return _backend_instance


def simplify(text: str) -> str:
    """
    Uproszczona funkcja do upraszczania tekstu.
    Zgodnosc z interfejsem localwriter.
    
    Args:
        text: Tekst do uproszczenia
    
    Returns:
        Uproszczony tekst lub komunikat bledu
    """
    backend = get_backend()
    success, result = backend.simplify_text(text)
    return result


def process_paragraphs(paragraphs: List[str]) -> List[str]:
    """
    Przetwarza liste akapitow.
    Zgodnosc z interfejsem localwriter.
    
    Args:
        paragraphs: Lista akapitow do uproszczenia
    
    Returns:
        Lista uproszczonych akapitow
    """
    backend = get_backend()
    results = []
    
    for para in paragraphs:
        if not para or not para.strip():
            results.append(para)
            continue
        
        success, result = backend.simplify_text(para)
        if success:
            results.append(result)
        else:
            # W przypadku bledu, zachowaj oryginal
            results.append(para)
    
    return results


# =============================================================================
# TRYB TESTOWY
# =============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("NVIDIA NIM Backend v2.1 - Test")
    print("=" * 70)
    print()
    
    backend = NvidiaNimBackend()
    info = backend.get_info()
    
    print("Konfiguracja:")
    for key, value in info.items():
        print(f"  {key}: {value}")
    print()
    
    # Walidacja klucza
    is_valid, msg = backend.validate_api_key()
    print(f"Klucz API: {'OK' if is_valid else 'BLAD - ' + msg}")
    print()
    
    if is_valid:
        print("Testowanie polaczenia...")
        success, result = backend.test_connection()
        print(result)
        print()
        
        if success:
            print("-" * 70)
            print("Test dlugiego tekstu:")
            long_text = """
            Implementacja algorytmu wykorzystuje zaawansowane techniki 
            przetwarzania jezyka naturalnego w celu optymalizacji 
            procesu ekstrakcji informacji z nieustrukturyzowanych 
            zrodel danych. Metodologia opiera sie na wielowarstwowym 
            modelu transformerowym, ktory zostal wytrenowany na 
            obszernym korpusie tekstow w jezyku polskim.
            """
            success, result = backend.simplify_text(long_text)
            print(f"Oryginal: {long_text.strip()}")
            print()
            print(f"Uproszczony: {result}")
    
    print()
    print("=" * 70)
