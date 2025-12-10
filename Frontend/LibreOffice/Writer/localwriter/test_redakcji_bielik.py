import os
import requests
from typing import Dict, Any, Optional

# Poprawiony import klas błędów oraz InferenceClient
from huggingface_hub import HfHubHTTPError, InferenceTimeoutError, InferenceClient 

# ZARZĄDZANIE TOKENEM HUGGING FACE API
# Zalecane jest użycie zmiennej środowiskowej dla bezpieczeństwa
HF_TOKEN = os.getenv("HF_TOKEN")
if not HF_TOKEN:
    raise ValueError("Brak tokenu Hugging Face API. Ustaw zmienną środowiskową HF_TOKEN.")

# Inicjalizacja InferenceClient z tokenem i opcjonalnym timeoutem
# Domyślny timeout można ustawić globalnie lub dla każdego wywołania
client = InferenceClient(token=HF_TOKEN, timeout=120) # Ustawienie globalnego timeoutu na 120 sekund

# Definicja modelu
MODEL_ID = "speakleash/Bielik-11B-v2.3-Instruct"

def redaguj_tekst(tekst_wejsciowy: str) -> str:
    """
    Redaguje tekst wejściowy do formalnego języka polskiego przy użyciu modelu Bielik-11B-v2.3-Instruct.
    """
    prompt = f"""<|im_start|>system
Jesteś asystentem językowym, który specjalizuje się w redagowaniu tekstów na formalny język polski. Twoim zadaniem jest przekształcenie podanego tekstu, tak aby był zgodny z zasadami poprawnej polszczyzny, unikał kolokwializmów, był zwięzły i klarowny, a także dostosowany do kontekstu formalnego. Zwróć uwagę na interpunkcję, gramatykę i styl. Zachowaj oryginalne znaczenie tekstu, skupiając się wyłącznie na jego formie.
<|im_end|>
<|im_start|>user
{tekst_wejsciowy}<|im_end|>
<|im_start|>assistant
"""

    try:
        # Wywołanie inferencji za pomocą InferenceClient
        # Timeout może być również ustawiony tutaj, np. client.text_generation(..., timeout=90)
        response = client.text_generation(
            prompt=prompt,
            model=MODEL_ID,
            max_new_tokens=500,
            temperature=0.7,
            repetition_penalty=1.1,
            do_sample=True
        )
        return response
    except InferenceTimeoutError:
        # Obsługa błędu przekroczenia czasu inferencji
        print(f"Błąd: Żądanie inferencji przekroczyło limit czasu dla modelu {MODEL_ID}.")
        return "Wystąpił błąd przekroczenia czasu inferencji. Proszę spróbować ponownie."
    except HfHubHTTPError as e:
        # Obsługa błędów HTTP z API Hugging Face
        print(f"Błąd HTTP podczas wywoływania API Hugging Face: {e}")
        return f"Wystąpił błąd komunikacji z API: {e.response.status_code} - {e.response.text}"
    except requests.exceptions.ConnectionError:
        # Obsługa błędów połączenia sieciowego
        print("Błąd: Nie można nawiązać połączenia z API Hugging Face. Sprawdź połączenie internetowe.")
        return "Wystąpił błąd połączenia sieciowego. Proszę sprawdzić dostęp do internetu."
    except Exception as e:
        # Ogólna obsługa innych nieprzewidzianych błędów
        print(f"Wystąpił nieoczekiwany błąd podczas redagowania tekstu: {e}")
        return f"Wystąpił nieoczekiwany błąd: {e}"

# PRZYKŁAD UŻYCIA
if __name__ == "__main__":
    tekst_do_redakcji = "Siemka, z tej strony Janek. Chciałbym się zapytać, czy mógłbyś mi ogarnąć ten dokument na jutro? Jest mega ważny."
    
    redagowany_tekst = redaguj_tekst(tekst_do_redakcji)
    print("\nTekst oryginalny:")
    print(tekst_do_redakcji)
    print("\nTekst zredagowany:")
    print(redagowany_tekst)

    tekst_do_redakcji_2 = "Cześć! Pisałem do Ciebie w sprawie tego projektu, wiesz, o co chodzi. Trzeba to szybko zrobić, bo deadline goni. Daj znać, jak to widzisz."
    redagowany_tekst_2 = redaguj_tekst(tekst_do_redakcji_2)
    print("\nTekst oryginalny 2:")
    print(tekst_do_redakcji_2)
    print("\nTekst zredagowany 2:")
    print(redagowany_tekst_2)
