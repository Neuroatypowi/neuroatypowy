# POLONISTA v2.0 — Poradnik Instalacji i Użytkowania

**Asystent Prostego Języka dla LibreOffice Writer z integracją NVIDIA Bielik-11B**

---

## Streszczenie (Executive Summary)

*POLONISTA działa jak tłumacz, który zamienia trudne teksty na proste. Tak jak Google Translate tłumaczy między językami, POLONISTA "tłumaczy" skomplikowany tekst urzędowy na język zrozumiały dla każdego.*

**Co robi program:** Zaznaczasz tekst → Klikasz przycisk → Tekst staje się prostszy.

**Dla kogo:** Dla osób piszących dokumenty, które muszą być zrozumiałe dla wszystkich — urzędnicy, lekarze, prawnicy, nauczyciele.

---

## Spis Treści

1. [Wymagania systemowe](#1-wymagania-systemowe)
2. [Pobieranie klucza API](#2-pobieranie-klucza-api)
3. [Instalacja makra](#3-instalacja-makra)
4. [Konfiguracja klucza API](#4-konfiguracja-klucza-api)
5. [Użytkowanie programu](#5-uzytkowanie-programu)
6. [Rozwiązywanie problemów](#6-rozwiazywanie-problemow)
7. [Proponowane zmiany dla localwriter](#7-proponowane-zmiany-dla-localwriter)
8. [Dokumentacja techniczna](#8-dokumentacja-techniczna)
9. [Bibliografia](#9-bibliografia)

---

## 1. Wymagania systemowe

### Co musisz mieć

| Element | Wymaganie | Sprawdzenie |
|---------|-----------|-------------|
| System operacyjny | Windows 10/11 | Menu Start → Ustawienia → System → Informacje |
| LibreOffice Writer | Wersja 7.0 lub nowsza | Pomoc → O programie LibreOffice |
| Internet | Stałe połączenie | Otwórz przeglądarkę i wejdź na google.pl |
| Konto NVIDIA | Bezpłatne | Zarejestruj na build.nvidia.com |

### Co NIE jest potrzebne

- ❌ Karta graficzna NVIDIA (model działa w chmurze)
- ❌ Instalacja Pythona (LibreOffice ma wbudowanego)
- ❌ Dodatkowe biblioteki lub pakiety
- ❌ Uprawnienia administratora (opcjonalnie)

---

## 2. Pobieranie klucza API

### Krok po kroku

**Krok 1:** Otwórz przeglądarkę i wejdź na adres:
```
https://build.nvidia.com
```

**Krok 2:** Kliknij przycisk **"Sign In"** (Zaloguj się) w prawym górnym rogu.

**Krok 3:** Utwórz konto lub zaloguj się przez:
- Google
- GitHub  
- Email firmowy

**Krok 4:** W wyszukiwarce wpisz: `bielik`

**Krok 5:** Wybierz model: **speakleash/bielik-11b-v2.6-instruct**

**Krok 6:** Kliknij przycisk **"Get API Key"** (Pobierz klucz API)

**Krok 7:** Skopiuj klucz. Wygląda tak:
```
nvapi-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Ważne:** Klucz zaczyna się od `nvapi-`. Zachowaj go — będzie potrzebny w następnym kroku.

---

## 3. Instalacja makra

### Gdzie umieścić plik

**Krok 1:** Pobierz plik `polonista.py` ze strony neuroatypowi.org

**Krok 2:** Otwórz Eksplorator plików (Windows + E)

**Krok 3:** W pasku adresu wklej:
```
%APPDATA%\LibreOffice\4\user\Scripts\python
```

**Krok 4:** Naciśnij Enter

**Uwaga:** Jeśli folder `python` nie istnieje, utwórz go:
1. Kliknij prawym przyciskiem myszy
2. Wybierz: Nowy → Folder
3. Nazwij folder: `python`

**Krok 5:** Skopiuj plik `polonista.py` do tego folderu

**Krok 6:** Zamknij WSZYSTKIE okna LibreOffice

**Krok 7:** Otwórz LibreOffice Writer ponownie

---

## 4. Konfiguracja klucza API

### Edycja pliku polonista.py

**Krok 1:** Otwórz folder z makrem (patrz sekcja 3)

**Krok 2:** Kliknij prawym przyciskiem na plik `polonista.py`

**Krok 3:** Wybierz: **Otwórz za pomocą → Notatnik**

**Krok 4:** Znajdź linię (około linia 55):
```python
return "nvapi-TUTAJ_WKLEJ_SWOJ_KLUCZ_API"
```

**Krok 5:** Zamień `TUTAJ_WKLEJ_SWOJ_KLUCZ_API` na swój prawdziwy klucz:
```python
return "nvapi-twoj-prawdziwy-klucz-tutaj"
```

**Krok 6:** Zapisz plik (Ctrl + S)

**Krok 7:** Zamknij Notatnik

**Krok 8:** Uruchom ponownie LibreOffice Writer

---

## 5. Użytkowanie programu

### Jak upraszczać tekst

**Krok 1:** Otwórz dokument w LibreOffice Writer

**Krok 2:** Zaznacz tekst do uproszczenia (przeciągnij myszką)

**Krok 3:** Menu: **Narzędzia → Makra → Uruchom makro...**

**Krok 4:** W oknie "Wybór makra":
- Rozwiń: **Moje makra**
- Rozwiń: **polonista**
- Kliknij: **RedagujZaznaczenie**

**Krok 5:** Kliknij przycisk: **Uruchom**

**Krok 6:** Poczekaj 3-10 sekund

**Krok 7:** Zaznaczony tekst zostanie zastąpiony uproszczoną wersją

### Dostępne funkcje (makra)

| Funkcja | Opis | Kiedy użyć |
|---------|------|------------|
| **RedagujZaznaczenie** | Upraszcza zaznaczony tekst | Główna funkcja — używaj najczęściej |
| **PokazInformacje** | Wyświetla informacje o programie | Gdy chcesz sprawdzić wersję |
| **SprawdzKonfiguracje** | Sprawdza czy klucz API jest poprawny | Przy pierwszym uruchomieniu |
| **TestPolaczenia** | Testuje połączenie z serwerem | Gdy coś nie działa |

---

## 6. Rozwiązywanie problemów

### Problem 1: Makro nie jest widoczne w LibreOffice

**Objaw:** W oknie "Uruchom makro" nie ma folderu `polonista`

**Przyczyna:** Plik jest w złym miejscu lub LibreOffice nie odświeżył cache

**Rozwiązanie:**
1. Sprawdź czy plik jest w:
   `%APPDATA%\LibreOffice\4\user\Scripts\python\polonista.py`
2. Zamknij WSZYSTKIE okna LibreOffice
3. Poczekaj 10 sekund
4. Otwórz LibreOffice Writer

### Problem 2: Funkcje makra nie są widoczne w polu "Nazwa makra"

**Objaw:** Folder `polonista` jest widoczny, ale po prawej stronie lista jest pusta

**Przyczyna:** Błąd składni w pliku Python lub nieprawidłowe kodowanie pliku

**Rozwiązanie:**
1. Pobierz ponownie plik `polonista.py` ze strony neuroatypowi.org
2. Upewnij się, że plik jest zapisany jako UTF-8
3. Sprawdź czy nie ma polskich znaków w ścieżce do pliku
4. Usuń stary plik i wgraj nowy

### Problem 3: Błąd "Nieprawidłowy klucz API"

**Objaw:** Po uruchomieniu makra pojawia się komunikat o błędzie klucza

**Przyczyna:** Klucz nie został wklejony lub jest nieprawidłowy

**Rozwiązanie:**
1. Otwórz plik polonista.py w Notatniku
2. Sprawdź czy klucz zaczyna się od `nvapi-`
3. Sprawdź czy nie ma spacji przed ani po kluczu
4. Sprawdź czy klucz jest w cudzysłowach: `"nvapi-xxx"`

### Problem 4: Błąd "Limit zapytań"

**Objaw:** Komunikat "[BLAD] Limit zapytan (429)"

**Przyczyna:** Wysłano za dużo zapytań w krótkim czasie

**Rozwiązanie:**
1. Poczekaj 1-2 minuty
2. Spróbuj ponownie
3. Upraszczaj mniejsze fragmenty tekstu

### Problem 5: Brak połączenia z internetem

**Objaw:** Komunikat "[BLAD] Brak polaczenia z internetem"

**Przyczyna:** Komputer nie ma dostępu do internetu lub firewall blokuje połączenie

**Rozwiązanie:**
1. Sprawdź połączenie internetowe (otwórz google.pl w przeglądarce)
2. Sprawdź czy firewall nie blokuje LibreOffice
3. Wyłącz VPN jeśli jest włączony

---

## 7. Proponowane zmiany dla localwriter

### Przegląd projektu localwriter

Projekt **localwriter** (github.com/balisujohn/localwriter) to rozszerzenie LibreOffice Writer umożliwiające lokalne przetwarzanie tekstu przez modele AI. 

### Zidentyfikowane błędy i ograniczenia

#### Błąd 1: Nieprawidłowe parsowanie odpowiedzi API

**Lokalizacja:** Kod integracji z OpenAI-compatible API

**Problem:**
```python
# BŁĘDNY KOD (oryginał)
result['choices']['message']['content']
```

**Poprawka:**
```python
# POPRAWNY KOD
result['choices'][0]['message']['content']
```

**Wyjaśnienie:** Pole `choices` jest tablicą (list), nie słownikiem. Trzeba użyć indeksu `[0]` aby pobrać pierwszy element.

#### Błąd 2: Brak inicjalizacji zmiennej

**Lokalizacja:** Funkcja przetwarzania akapitów

**Problem:**
```python
# BŁĘDNY KOD
redacted_paragraphs =  # Brak inicjalizacji
for p in paragraphs:
    redacted_paragraphs.append(process(p))
```

**Poprawka:**
```python
# POPRAWNY KOD
redacted_paragraphs = []  # Inicjalizacja pustej listy
for p in paragraphs:
    redacted_paragraphs.append(process(p))
```

#### Błąd 3: Brak walidacji klucza API

**Problem:** Kod nie sprawdza czy klucz API jest prawidłowy przed wysłaniem zapytania.

**Proponowane rozwiązanie:**
```python
def validate_api_key(api_key):
    """Walidacja klucza API przed użyciem."""
    if not api_key:
        return False, "Klucz API jest pusty"
    if not api_key.startswith(("sk-", "nvapi-")):
        return False, "Nieprawidłowy format klucza"
    if len(api_key) < 20:
        return False, "Klucz za krótki"
    return True, "OK"
```

#### Błąd 4: Ciche błędy bez informacji dla użytkownika

**Problem:** Funkcje zwracają pusty string przy błędzie zamiast informować użytkownika.

**Proponowane rozwiązanie:**
```python
# Zamiast:
except Exception:
    return ""

# Użyć:
except Exception as e:
    show_error_dialog("Błąd: " + str(e))
    return None
```

#### Błąd 5: Niewłaściwy podział tekstu

**Problem:** Podział przez `"\n\n"` nie działa dla dokumentów bez podwójnych nowych linii.

**Proponowane rozwiązanie:**
```python
def smart_chunk_text(text, max_chars=3000):
    """Inteligentny podział tekstu na kawałki."""
    # Próbuj podzielić przez akapity
    paragraphs = text.split("\n\n")
    if len(paragraphs) == 1:
        # Jeśli nie ma akapitów, podziel przez zdania
        paragraphs = re.split(r'(?<=[.!?])\s+', text)
    
    chunks = []
    current = ""
    for p in paragraphs:
        if len(current) + len(p) < max_chars:
            current += p + "\n\n"
        else:
            if current:
                chunks.append(current.strip())
            current = p + "\n\n"
    if current:
        chunks.append(current.strip())
    return chunks
```

### Proponowana integracja z NVIDIA NIM

#### Nowy plik: nvidia_nim_backend.py

```python
# -*- coding: utf-8 -*-
"""
Backend NVIDIA NIM dla localwriter
Dodaje wsparcie dla polskiego modelu Bielik-11B
"""

NVIDIA_NIM_CONFIG = {
    "endpoint": "https://integrate.api.nvidia.com/v1/chat/completions",
    "model": "speakleash/bielik-11b-v2.6-instruct",
    "rate_limit": 40,  # requests per minute
    "max_tokens": 2048
}

def create_nvidia_payload(text, system_prompt, temperature=0.3):
    """Tworzy payload dla NVIDIA NIM API."""
    return {
        "model": NVIDIA_NIM_CONFIG["model"],
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "temperature": temperature,
        "max_tokens": NVIDIA_NIM_CONFIG["max_tokens"],
        "stream": False
    }

def handle_rate_limit(attempt, max_retries=5):
    """Obsługuje błąd 429 z exponential backoff."""
    if attempt < max_retries:
        wait_time = (2 ** attempt) + 1
        time.sleep(wait_time)
        return True
    return False
```

#### Modyfikacja main.py

Dodać na początku pliku:
```python
# Import backendu NVIDIA (opcjonalny)
try:
    from nvidia_nim_backend import NVIDIA_NIM_CONFIG, create_nvidia_payload
    NVIDIA_AVAILABLE = True
except ImportError:
    NVIDIA_AVAILABLE = False
```

Dodać opcję w ustawieniach:
```python
def get_available_backends():
    """Zwraca listę dostępnych backendów."""
    backends = ["ollama", "text-generation-webui"]
    if NVIDIA_AVAILABLE:
        backends.append("nvidia-nim")
    return backends
```

### Podsumowanie propozycji dla localwriter

| Kategoria | Zmiana | Priorytet |
|-----------|--------|-----------|
| Bug fix | Poprawka parsowania choices[0] | Krytyczny |
| Bug fix | Inicjalizacja zmiennych | Krytyczny |
| Feature | Walidacja klucza API | Wysoki |
| Feature | Informacyjne komunikaty błędów | Wysoki |
| Feature | Inteligentny podział tekstu | Średni |
| Feature | Backend NVIDIA NIM | Średni |
| Feature | Wsparcie języka polskiego | Niski |

---

## 8. Dokumentacja techniczna

### Architektura POLONISTA

```
+------------------+     +------------------+     +------------------+
|  LibreOffice     |     |    POLONISTA     |     |   NVIDIA NIM     |
|  Writer          | --> |    Python Macro  | --> |   API Cloud      |
|  (Zaznaczenie)   |     |    (polonista.py)|     |   (Bielik-11B)   |
+------------------+     +------------------+     +------------------+
        |                        |                        |
        v                        v                        v
   Tekst źródłowy        Wywołanie HTTP/REST       Przetwarzanie AI
                               |                        |
                               v                        v
                         Parsowanie JSON           Tekst uproszczony
                               |                        |
                               +------------------------+
                               |
                               v
                      Zamiana tekstu w dokumencie
```

### Specyfikacja API NVIDIA NIM

| Parametr | Wartość |
|----------|---------|
| Endpoint | https://integrate.api.nvidia.com/v1/chat/completions |
| Model | speakleash/bielik-11b-v2.6-instruct |
| Metoda | POST |
| Content-Type | application/json |
| Authorization | Bearer {api_key} |
| Rate Limit | 40 żądań/minutę |
| Max Tokens (output) | 2048 |
| Max Tokens (input) | ~4096 |
| Timeout | 60 sekund |

### Format zapytania

```json
{
  "model": "speakleash/bielik-11b-v2.6-instruct",
  "messages": [
    {
      "role": "system",
      "content": "Instrukcje systemowe..."
    },
    {
      "role": "user", 
      "content": "Tekst do uproszczenia..."
    }
  ],
  "temperature": 0.3,
  "max_tokens": 2048,
  "stream": false
}
```

### Format odpowiedzi

```json
{
  "id": "chat-xxx",
  "object": "chat.completion",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Uproszczony tekst..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 100,
    "total_tokens": 250
  }
}
```

### Kody błędów HTTP

| Kod | Znaczenie | Rozwiązanie |
|-----|-----------|-------------|
| 200 | Sukces | - |
| 400 | Błędne zapytanie | Sprawdź format JSON |
| 401 | Błąd autoryzacji | Sprawdź klucz API |
| 403 | Brak dostępu | Sprawdź uprawnienia konta |
| 404 | Nie znaleziono | Sprawdź nazwę modelu |
| 429 | Limit zapytań | Poczekaj i spróbuj ponownie |
| 500 | Błąd serwera | Spróbuj później |
| 503 | Serwis niedostępny | Spróbuj później |

---

## 9. Bibliografia

### Źródła

| Cytowanie APA 7 | Łącze |
|-----------------|-------|
| NVIDIA Corporation. (2024). *NVIDIA NIM API documentation*. https://docs.nvidia.com/nim/ | https://tiny.pl/nvidia-nim |
| SpeakLeash. (2024). *Bielik-11B: Polish language model*. Hugging Face. https://huggingface.co/speakleash/bielik-11b-v2.6-instruct | https://tiny.pl/bielik |
| Balis, J. (2024). *localwriter: LibreOffice extension for local AI*. GitHub. https://github.com/balisujohn/localwriter | https://tiny.pl/localwriter |
| The Document Foundation. (2024). *LibreOffice Python scripting guide*. https://wiki.documentfoundation.org/Macros/Python_Guide | https://tiny.pl/lo-python |
| ISO. (2023). *ISO 24495-1:2023 Plain language — Part 1: Governing principles and guidelines*. International Organization for Standardization. | https://tiny.pl/iso-plain |

---

## Informacje o dokumencie

| Pole | Wartość |
|------|---------|
| Wersja | 2.0 |
| Data | 2025-12-11 |
| Autor | Stowarzyszenie Zwykłe "Neuroatypowi" |
| Licencja | MIT |
| Kontakt | https://neuroatypowi.org |
| Repozytorium | https://github.com/neuroatypowi/polonista |

---

*Dokument przygotowany zgodnie z normą ISO 24495-1:2023 (Prosty Język) z wykorzystaniem zasad dostępności poznawczej.*
