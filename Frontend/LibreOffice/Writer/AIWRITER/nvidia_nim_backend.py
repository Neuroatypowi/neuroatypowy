# -*- coding: utf-8 -*-
"""
nvidia_nim_backend.py - Backend NVIDIA NIM dla projektu AIWRITER
=================================================================

SCIEZKA INSTALACJI:
    %APPDATA%/LibreOffice/4/user/Scripts/python/AIWRITER/backends/nvidia_nim_backend.py

Model: Bielik-11B-v2.6-Instruct (polski model AI)
API: NVIDIA NIM (integrate.api.nvidia.com)

Autor: Stowarzyszenie Zwykle "Neuroatypowi"
Strona: https://neuroatypowi.org
Licencja: MIT
"""

from __future__ import print_function, absolute_import, division

import json
import time
import os
import re
import sys

# Python 2/3 compatibility
try:
    from urllib.request import Request, urlopen
    from urllib.error import HTTPError, URLError
except ImportError:
    from urllib2 import Request, urlopen, HTTPError, URLError

# =============================================================================
# KONFIGURACJA
# =============================================================================

DEFAULT_CONFIG = {
    "endpoint": "https://integrate.api.nvidia.com/v1/chat/completions",
    "model": "speakleash/bielik-11b-v2.6-instruct",
    "temperature": 0.3,
    "max_tokens": 2048,
    "timeout": 60,
    "max_retries": 5,
    "rate_limit_rpm": 40,
    "chunk_size": 3000,
}

SYSTEM_PROMPT_PLAIN_LANGUAGE = """Jestes ekspertem Prostego Jezyka polskiego (Plain Language).
Twoje zadanie: przeksztalcic tekst na prosty, zrozumialy jezyk.

ZASADY:
1. Krotkie zdania - max 15 slow
2. Jedno zdanie = jedna mysl
3. Polskie slowa zamiast obcych
4. Strona czynna zamiast biernej
5. Unikaj skrotow i zargonu

Zwroc TYLKO uproszczony tekst, bez komentarzy."""


# =============================================================================
# FUNKCJE POMOCNICZE DO LOKALIZACJI PLIKOW
# =============================================================================

def _get_script_directory():
    """Zwraca katalog w ktorym znajduje sie backend."""
    try:
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        # Fallback dla LibreOffice
        if os.name == 'nt':
            appdata = os.environ.get('APPDATA', '')
            return os.path.join(appdata, 'LibreOffice', '4', 'user', 
                               'Scripts', 'python', 'AIWRITER', 'backends')
        else:
            home = os.path.expanduser('~')
            return os.path.join(home, '.config', 'libreoffice', '4', 'user',
                               'Scripts', 'python', 'AIWRITER', 'backends')


def _get_aiwriter_directory():
    """Zwraca glowny katalog AIWRITER."""
    backend_dir = _get_script_directory()
    return os.path.dirname(backend_dir)


def _find_env_file():
    """Szuka pliku .env w roznych lokalizacjach."""
    search_paths = []
    
    # 1. Katalog AIWRITER
    aiwriter_dir = _get_aiwriter_directory()
    search_paths.append(os.path.join(aiwriter_dir, '.env'))
    
    # 2. Katalog backends
    search_paths.append(os.path.join(_get_script_directory(), '.env'))
    
    # 3. Katalog python Scripts
    search_paths.append(os.path.join(os.path.dirname(aiwriter_dir), '.env'))
    
    # 4. Katalog domowy
    home = os.path.expanduser('~')
    search_paths.append(os.path.join(home, '.env'))
    search_paths.append(os.path.join(home, '.aiwriter', '.env'))
    
    for path in search_paths:
        if os.path.exists(path):
            return path
    
    return None


def _load_env_file():
    """Wczytuje zmienne z pliku .env."""
    env_vars = {}
    env_path = _find_env_file()
    
    if env_path is None:
        return env_vars
    
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    # Remove quotes
                    if len(value) >= 2:
                        if (value[0] == '"' and value[-1] == '"') or \
                           (value[0] == "'" and value[-1] == "'"):
                            value = value[1:-1]
                    env_vars[key] = value
    except Exception:
        pass
    
    return env_vars


# =============================================================================
# KLASA GLOWNA: NvidiaNimBackend
# =============================================================================

class NvidiaNimBackend:
    """Backend NVIDIA NIM z modelem Bielik-11B."""
    
    def __init__(self, config=None):
        self.config = dict(DEFAULT_CONFIG)
        if config:
            self.config.update(config)
        
        self._api_key = None
        self._last_request_time = 0
        self._request_count = 0
        self._env_path = None
        
        self._load_api_key()
    
    def _load_api_key(self):
        """Wczytuje klucz API."""
        # 1. Plik .env
        env_vars = _load_env_file()
        if 'NVIDIA_API_KEY' in env_vars:
            self._api_key = env_vars['NVIDIA_API_KEY']
            self._env_path = _find_env_file()
            if 'NVIDIA_ENDPOINT' in env_vars:
                self.config['endpoint'] = env_vars['NVIDIA_ENDPOINT']
            if 'NVIDIA_MODEL' in env_vars:
                self.config['model'] = env_vars['NVIDIA_MODEL']
            return
        
        # 2. Zmienna srodowiskowa
        env_key = os.environ.get('NVIDIA_API_KEY')
        if env_key:
            self._api_key = env_key
            return
        
        self._api_key = None
    
    def get_api_key(self):
        return self._api_key
    
    def get_env_path(self):
        return self._env_path or _find_env_file()
    
    def validate_api_key(self):
        """Sprawdza poprawnosc klucza API."""
        if not self._api_key:
            return False, "Brak klucza API. Utworz plik .env z NVIDIA_API_KEY=nvapi-xxx"
        
        if "TUTAJ" in self._api_key or "WKLEJ" in self._api_key:
            return False, "Klucz API zawiera placeholder - wklej prawdziwy klucz"
        
        if not self._api_key.startswith("nvapi-"):
            return False, "Klucz API musi zaczynac sie od nvapi-"
        
        if len(self._api_key) < 20:
            return False, "Klucz API jest za krotki"
        
        return True, "OK"
    
    def _wait_for_rate_limit(self):
        """Rate limiting - max 40 RPM."""
        min_interval = 60.0 / self.config['rate_limit_rpm']
        now = time.time()
        elapsed = now - self._last_request_time
        if elapsed < min_interval:
            time.sleep(min_interval - elapsed)
        self._last_request_time = time.time()
        self._request_count += 1
    
    def _make_request(self, messages, retry_count=0):
        """Wykonuje zapytanie do API."""
        is_valid, msg = self.validate_api_key()
        if not is_valid:
            return False, "[BLAD] " + msg
        
        self._wait_for_rate_limit()
        
        payload = {
            "model": self.config['model'],
            "messages": messages,
            "temperature": self.config['temperature'],
            "max_tokens": self.config['max_tokens'],
            "stream": False
        }
        
        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + self._api_key,
            "User-Agent": "AIWRITER-POLONISTA/2.1"
        }
        
        data = json.dumps(payload).encode('utf-8')
        
        try:
            req = Request(self.config['endpoint'], data=data, headers=headers)
            response = urlopen(req, timeout=self.config['timeout'])
            result = json.loads(response.read().decode('utf-8'))
            
            # POPRAWIONE PARSOWANIE - choices[0]
            if 'choices' not in result or len(result['choices']) == 0:
                return False, "[BLAD] Nieprawidlowa odpowiedz API"
            
            choice = result['choices'][0]
            if 'message' not in choice or 'content' not in choice['message']:
                return False, "[BLAD] Brak content w odpowiedzi"
            
            content = choice['message']['content']
            if content is None:
                return False, "[BLAD] Odpowiedz jest pusta"
            
            return True, content.strip()
            
        except HTTPError as e:
            if e.code == 429:
                if retry_count < self.config['max_retries']:
                    time.sleep((2 ** retry_count) + 1)
                    return self._make_request(messages, retry_count + 1)
                return False, "[BLAD 429] Limit zapytan - poczekaj minute"
            elif e.code == 401:
                return False, "[BLAD 401] Nieprawidlowy klucz API"
            elif e.code == 403:
                return False, "[BLAD 403] Brak dostepu do API"
            elif e.code == 404:
                return False, "[BLAD 404] Model nie znaleziony"
            else:
                return False, "[BLAD HTTP {}]".format(e.code)
                
        except URLError as e:
            return False, "[BLAD] Brak polaczenia z internetem"
            
        except Exception as e:
            return False, "[BLAD] {}: {}".format(type(e).__name__, str(e))
    
    def simplify_text(self, text, system_prompt=None):
        """Upraszcza tekst."""
        if not text or not text.strip():
            return False, "[BLAD] Tekst jest pusty"
        
        prompt = system_prompt or SYSTEM_PROMPT_PLAIN_LANGUAGE
        messages = [
            {"role": "system", "content": prompt},
            {"role": "user", "content": text.strip()}
        ]
        return self._make_request(messages)
    
    def simplify_long_text(self, text, system_prompt=None, progress_callback=None):
        """Upraszcza dlugi tekst dzielac go na czesci."""
        if not text or not text.strip():
            return False, "[BLAD] Tekst jest pusty"
        
        text = text.strip()
        chunk_size = self.config['chunk_size']
        
        if len(text) <= chunk_size:
            return self.simplify_text(text, system_prompt)
        
        chunks = self._smart_chunk_text(text, chunk_size)
        results = []
        
        for i, chunk in enumerate(chunks):
            success, result = self.simplify_text(chunk, system_prompt)
            if not success:
                partial = "\n\n".join(results)
                return False, partial + "\n\n[BLAD w czesci {}/{}] {}".format(
                    i+1, len(chunks), result)
            results.append(result)
            if progress_callback:
                try:
                    progress_callback(i+1, len(chunks), "\n\n".join(results))
                except:
                    pass
        
        return True, "\n\n".join(results)
    
    def _smart_chunk_text(self, text, max_size):
        """Inteligentne dzielenie tekstu."""
        chunks = []
        current_pos = 0
        
        while current_pos < len(text):
            end_pos = min(current_pos + max_size, len(text))
            
            if end_pos >= len(text):
                chunk = text[current_pos:].strip()
                if chunk:
                    chunks.append(chunk)
                break
            
            chunk_text = text[current_pos:end_pos]
            best_split = -1
            separator_len = 0
            
            # Priorytet 1: Podwojny enter
            split_pos = chunk_text.rfind("\n\n")
            if split_pos > max_size * 0.3:
                best_split = split_pos
                separator_len = 2
            
            # Priorytet 2: Pojedynczy enter
            if best_split == -1:
                split_pos = chunk_text.rfind("\n")
                if split_pos > max_size * 0.5:
                    best_split = split_pos
                    separator_len = 1
            
            # Priorytet 3: Koniec zdania
            if best_split == -1:
                for punct in [". ", "! ", "? "]:
                    split_pos = chunk_text.rfind(punct)
                    if split_pos > max_size * 0.5:
                        best_split = split_pos + 1
                        separator_len = 1
                        break
            
            # Priorytet 4: Spacja
            if best_split == -1:
                split_pos = chunk_text.rfind(" ")
                if split_pos > 0:
                    best_split = split_pos
                    separator_len = 1
                else:
                    best_split = max_size
                    separator_len = 0
            
            chunk = text[current_pos:current_pos + best_split].strip()
            if chunk:
                chunks.append(chunk)
            current_pos = current_pos + best_split + separator_len
        
        return [c for c in chunks if c]
    
    def test_connection(self):
        """Testuje polaczenie z API."""
        test_text = "To jest skomplikowane zdanie testowe."
        success, result = self.simplify_text(test_text)
        if success:
            return True, "Polaczenie dziala!\n\nWyslano: {}\nOtrzymano: {}".format(
                test_text, result)
        return False, "Polaczenie nie dziala.\n\n" + result
    
    def get_info(self):
        """Informacje o backendzie."""
        api_key = self._api_key or ""
        masked = "BRAK"
        if api_key and len(api_key) > 14:
            masked = api_key[:10] + "..." + api_key[-4:]
        
        return {
            "name": "NVIDIA NIM Backend (Bielik-11B)",
            "version": "2.1",
            "model": self.config['model'],
            "endpoint": self.config['endpoint'],
            "api_key_status": masked,
            "env_path": self.get_env_path(),
            "rate_limit_rpm": self.config['rate_limit_rpm'],
            "request_count": self._request_count,
        }


# =============================================================================
# GLOBALNA INSTANCJA (SINGLETON)
# =============================================================================

_backend_instance = None

def get_backend():
    """Zwraca globalna instancje backendu."""
    global _backend_instance
    if _backend_instance is None:
        _backend_instance = NvidiaNimBackend()
    return _backend_instance


def reset_backend():
    """Resetuje backend (wymusza ponowne wczytanie konfiguracji)."""
    global _backend_instance
    _backend_instance = None


def simplify(text):
    """Uproszczona funkcja do upraszczania tekstu."""
    backend = get_backend()
    success, result = backend.simplify_text(text)
    return result


# =============================================================================
# TEST
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("NVIDIA NIM Backend - Test")
    print("=" * 60)
    backend = NvidiaNimBackend()
    info = backend.get_info()
    for k, v in info.items():
        print("  {}: {}".format(k, v))
