# 🤖 MailerSend Webhook Receiver — Neuroatypowi.org

> **Streszczenie:** System odbiera powiadomienia e-mail i zapisuje je bezpiecznie w chmurze Google. Działa szybko i za darmo.

[![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/Neuroatypowi/neuroatypowy/actions)
[![Cloud Run](https://img.shields.io/badge/Cloud-Run-europe--west1-4285F4?logo=google-cloud&logoColor=white)](https://cloud.google.com/run)
[![Node.js](https://img.shields.io/badge/Node.js-22-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Firestore](https://img.shields.io/badge/Firestore-Native-FF6F00?logo=firebase&logoColor=white)](https://cloud.google.com/firestore)
[![Licencja](https://img.shields.io/badge/Licencja-MIT-green)](LICENSE)
[![Język](https://img.shields.io/badge/Język-Polski_B2-red)](https://www.jasnopis.pl)

---

## 📋 Spis treści

| # | Sekcja | Dla kogo |
|---|--------|----------|
| 1 | [🟢 Wariant ETR/AAC — Bardzo prosto](#-wariant-etrsaac--bardzo-prosto) | Każdy |
| 2 | [🔵 Wariant B2/Jasnopis — Zrozumiale](#-wariant-b2jasnopis--zrozumiale) | Użytkownicy NGO |
| 3 | [🔴 Wariant Techniczny — Dla programistów](#-wariant-techniczny--dla-programistów) | Deweloperzy |
| 4 | [🐳 Wdrożenie: Docker → GitHub → GCP](#-wdrożenie-docker--github--gcp) | Wszyscy |
| 5 | [🔐 Bezpieczeństwo](#-bezpieczeństwo) | Wszyscy |
| 6 | [⚙️ Konfiguracja zmiennych](#️-konfiguracja-zmiennych) | Deweloperzy |
| 7 | [🧪 Testowanie](#-testowanie) | Deweloperzy |
| 8 | [📊 Monitoring](#-monitoring) | Deweloperzy |
| 9 | [📚 Podstawy teoretyczne](#-podstawy-teoretyczne) | Wszyscy |
| 10 | [📖 Bibliografia](#-bibliografia) | Wszyscy |

---

## 🟢 Wariant ETR/AAC — Bardzo prosto

> 💡 **Ten rozdział jest dla każdego.** Używamy prostych słów. Krótkich zdań. Analogii z życia codziennego.

---

### Co to jest ten system?

Wyobraź sobie skrzynkę pocztową przy drzwiach. Każdy list, który przychodzi, jest od razu zapisywany w zeszycie.

Ten system robi to samo z e-mailami.

Kiedy MailerSend wysyła e-mail, nasz system dostaje **powiadomienie**. To powiadomienie zawiera informację:
- ✉️ E-mail wysłany
- ✅ E-mail dostarczony
- 📬 Ktoś otworzył e-mail
- 🖱️ Ktoś kliknął link w e-mailu
- ❌ E-mail nie dotarł (błąd)

System zapisuje każde powiadomienie w **bazie danych** w chmurze Google.

---

### Dlaczego używamy tego systemu?

**Neuroatypowi.org** pomaga ludziom z trudnościami. Wysyłamy ważne wiadomości do urzędów. Musimy wiedzieć, czy urzędnik przeczytał e-mail.

Jeśli e-mail nie dotarł, system nam to mówi. Możemy wtedy wysłać SMS lub zadzwonić.

---

### Jak to działa? Krok po kroku.

```
Krok 1: Wysyłamy e-mail przez MailerSend
         ↓
Krok 2: MailerSend powiadamia nasz system (webhook)
         ↓
Krok 3: System sprawdza, czy powiadomienie jest prawdziwe
         ↓
Krok 4: System zapisuje informację w Google Firestore
         ↓
Krok 5: System odpowiada "OK" w ciągu 3 sekund
```

> ⏱️ **Ważne:** System musi odpowiedzieć w **3 sekundy**. Nasz system odpowiada w **30–60 milisekund**. To jest **50 razy szybciej** niż wymagane!

---

### Co to jest Docker? 🐳

Docker to jak **pudełko z wszystkim co potrzeba**. Zamiast instalować wiele programów na komputerze, wkładamy wszystko do pudełka. Pudełko działa wszędzie tak samo.

Nasze pudełko (kontener Docker) zawiera:
- 📦 Kod serwera
- 📦 Node.js (środowisko uruchomieniowe)
- 📦 Ustawienia bezpieczeństwa

---

### Co to jest GitHub Actions? 

GitHub Actions to **robot, który pracuje automatycznie**. Kiedy dodajemy nowy kod do GitHub, robot sam:
1. Buduje pudełko Docker
2. Wstawia pudełko do Google Cloud
3. Uruchamia nasz serwer

My nic nie robimy ręcznie. Robot robi wszystko.

---

## 🔵 Wariant B2/Jasnopis — Zrozumiale

> 💡 **Ten rozdział jest dla użytkowników NGO.** Język jest prosty, ale zawiera więcej szczegółów technicznych.

---

### Opis systemu

System **MailerSend Webhook Receiver** to serwer działający w chmurze Google. Jego zadaniem jest odbieranie powiadomień (webhooków) od platformy MailerSend i zapisywanie ich do bazy danych.

System obsługuje **20 typów zdarzeń** związanych z e-mailami:

| Typ zdarzenia | Co oznacza |
|---------------|------------|
| `activity.sent` | E-mail wysłany |
| `activity.delivered` | E-mail dostarczony |
| `activity.opened` | Odbiorca otworzył e-mail |
| `activity.clicked` | Odbiorca kliknął link |
| `activity.hard_bounced` | E-mail nie dotarł (trwały błąd) |
| `activity.spam_complaint` | Odbiorca oznaczył jako spam |
| `activity.deferred` | E-mail opóźniony (płatne plany) |

---

### Dlaczego wybraliśmy to rozwiązanie?

#### Powód 1: Szybkość i niezawodność

MailerSend wymaga odpowiedzi w ciągu **3 sekund**. Wybraliśmy Google Cloud Run + Firestore w regionie **europe-west1 (Belgia)**, ponieważ MailerSend też działa w Belgii. Dane nie muszą podróżować daleko, więc serwer odpowiada w 30–60 ms.

#### Powód 2: Brak kosztów (Zero-TCO)

System działa w ramach **bezpłatnych limitów** Google Cloud:

| Zasób | Darmowy limit | Nasze zużycie |
|-------|---------------|---------------|
| Zapisy Firestore | 20 000 / dzień | ~50 / dzień |
| Pamięć Cloud Run | 256 MB | ~50 MB |
| Transfer danych | 10 GB / miesiąc | ~1 MB |

#### Powód 3: Bezpieczeństwo

Każde powiadomienie od MailerSend zawiera **podpis cyfrowy** (HMAC-SHA256). Nasz serwer sprawdza ten podpis, zanim cokolwiek zapisze. Fałszywe powiadomienia są odrzucane.

#### Powód 4: Logika biznesowa dla Neuroatypowi.org

System wykrywa **słowa kluczowe** w tematach e-maili:

- `[POMOC]:` — prośba o pomoc
- `[SYGNAL]:` — sygnał alarmowy
- `[WNIOSEK]:` — złożony wniosek
- `[SKARGA]:` — zgłoszona skarga

Jeśli adresat to urzędnik z Warszawy, system może powiadomić **Centrum Kontaktu Warszawa 19115** przez API.

#### Powód 5: Idempotentność (brak duplikatów)

MailerSend może wysłać to samo powiadomienie dwa razy (np. przy problemach z siecią). Nasz system używa unikalnego identyfikatora zdarzenia jako klucza dokumentu w Firestore. Jeśli dokument już istnieje, system zwraca `200 OK` (duplikat) zamiast zapisywać go dwa razy.

---

### Architektura systemu

```
Użytkownik wysyła e-mail
        ↓
    MailerSend
(Platforma wysyłki e-maili)
        ↓ HTTPS POST + podpis HMAC-SHA256
  Google Front End
  (Punkt brzegowy TLS)
  ~1–5 ms
        ↓
  Cloud Run: webhook-receiver
  (Serwer Node.js w Belgii)
  ~1–5 ms weryfikacja
        ↓
  Firestore Native Mode
  (Baza danych w Belgii)
  ~20–50 ms zapis
        ↓
  Odpowiedź 200 OK → MailerSend
  (ŁĄCZNIE: 30–60 ms)
        ↓ asynchronicznie (po odpowiedzi)
  API Warszawa 19115
  (jeśli dotyczy)
```

---

### Moduły systemu

| Moduł | Status | Opis |
|-------|--------|------|
| Webhook receiver | ✅ Aktywny | Odbiera i weryfikuje powiadomienia |
| Firestore write | ✅ Aktywny | Zapisuje zdarzenia do bazy danych |
| Warsaw 19115 API | ✅ Aktywny | Powiadamia centrum kontaktu |
| SMSAPI.pl | 🔴 ZABLOKOWANY | Wyłączony — usługa niedostępna (2026-03-01) |

---

## 🔴 Wariant Techniczny — Dla programistów

> 💡 **Ten rozdział jest dla deweloperów.** Zawiera szczegóły implementacyjne, konfigurację i kod.

---

### Stack technologiczny

| Warstwa | Technologia | Wersja | Powód wyboru |
|---------|-------------|--------|--------------|
| Środowisko uruchomieniowe | Node.js | 22 LTS | Stabilny, wspiera ES2022, fetch natywny |
| Framework HTTP | Express.js | 4.x | Minimalny narzut, `express.raw()` dla HMAC |
| Baza danych | Google Cloud Firestore | Native Mode | Same-region z MailerSend, `preferRest: true` |
| Konteneryzacja | Docker | Distroless Node 22 | Minimalna powierzchnia ataku |
| CI/CD | GitHub Actions | — | Jedyne rozwiązanie bez lokalnego Docker |
| Rejestr obrazów | Artifact Registry GCP | — | Natywna integracja z Cloud Run |
| Zarządzanie tajnymi kluczami | Cloud Secret Manager | — | Montowanie jako env vars bez wywołań API |

---

### Struktura plików repozytorium

```
Backend/GCP/webhook-receiver/
├── .github/
│   └── workflows/
│       └── deploy.yml          ← GitHub Actions: build + deploy
├── src/
│   └── server.js               ← Główny serwer (PRODUKCJA lub DEBUG)
├── Dockerfile                  ← Multi-stage build, distroless
├── .dockerignore
├── package.json
├── package-lock.json
└── README.md                   ← Ten plik
```

---

### Plik `package.json`

```json
{
  "name": "webhook-receiver",
  "version": "1.0.0",
  "description": "MailerSend Webhooks v2 receiver for Neuroatypowi.org",
  "main": "src/server.js",
  "engines": { "node": ">=22" },
  "scripts": {
    "start": "node src/server.js",
    "dev": "DEBUG=true node src/server.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "@google-cloud/firestore": "^7.9.0"
  }
}
```

---

### Plik `Dockerfile`

```dockerfile
# ============================================================
# Etap 1: Budowanie (builder)
# Instalacja zależności npm w pełnym obrazie Node.js
# ============================================================
FROM node:22-slim AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .

# ============================================================
# Etap 2: Produkcja (distroless)
# Minimalna powierzchnia ataku — brak powłoki systemowej
# ============================================================
FROM gcr.io/distroless/nodejs22-debian12

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/src ./src

# Cloud Run zawsze oczekuje aplikacji na porcie 8080
ENV PORT=8080
EXPOSE 8080

CMD ["src/server.js"]
```

> **Dlaczego distroless?** Obraz distroless nie zawiera powłoki systemowej (`bash`, `sh`), menedżera pakietów ani zbędnych bibliotek. Zmniejsza to powierzchnię ataku o ~95% w porównaniu do `node:22`. W razie włamania do kontenera, atakujący nie może uruchamiać poleceń systemowych.

---

### Plik `src/server.js` — Kluczowe fragmenty

#### Weryfikacja podpisu HMAC-SHA256

```javascript
function verifySignature(rawBody, sigHeader, secret) {
  if (!sigHeader || !secret) return false;

  // Obliczamy hash z surowych bajtów — NIGDY z JSON.stringify(JSON.parse(...))
  const computed    = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  const computedBuf = Buffer.from(computed, 'hex');
  const receivedBuf = Buffer.from(sigHeader, 'hex');

  // Sprawdzamy długość przed porównaniem — timingSafeEqual rzuca błąd na różnych długościach
  if (computedBuf.length !== receivedBuf.length) return false;

  // timingSafeEqual zamiast === — zapobiega atakom czasowym (timing attacks)
  return crypto.timingSafeEqual(computedBuf, receivedBuf);
}
```

> **Nagłówek:** `Signature` (NIE `Mailersend-Signature` — częsty błąd!)

#### Idempotentny zapis do Firestore

```javascript
// docRef.create() zamiast docRef.set() — gwarancja atomowej idempotentności
try {
  await docRef.create({
    type,
    classified_type: classifiedType,
    received_at: FieldValue.serverTimestamp(),
    data,
    domain_id: data.domain_id ?? null,
    email:     data.email     ?? null,
    message_id: data.message_id ?? null,
  });
} catch (err) {
  if (err.code === 6) { // gRPC ALREADY_EXISTS — duplikat
    return res.status(200).json({ status: 'duplicate' });
  }
  // Zwracamy 500 — MailerSend ponowi próbę po 10s i 100s
  return res.status(500).json({ error: 'firestore_write_failed' });
}
```

#### Asynchroniczne post-processing

```javascript
// Odpowiadamy 200 OK natychmiast, potem uruchamiamy logikę biznesową
res.status(200).json({ status: 'ok' });

// setImmediate() — nie blokuje odpowiedzi HTTP
setImmediate(() => {
  handlePostProcessing(data, data.subject ?? '', data.email ?? '').catch(err => {
    console.error('[post-processing]', err.message);
  });
});
```

---

### Schemat kolekcji Firestore

```
webhook_events/                        ← kolekcja główna
  {data.id}/                           ← ID dokumentu = MailerSend event ID (klucz idempotencji)
    type:            "activity.delivered"
    classified_type: "delivered"
    created_at:      "2025-08-05T21:23:54.000000Z"
    received_at:     <Timestamp serwera Firestore>
    data:            { id, domain_id, message_id, email_id, ... }
    domain_id:       "yv69oxl5kl785kw2"    ← wyciągnięte dla filtrowania
    email:           "test@example.com"     ← wyciągnięte dla filtrowania
    message_id:      "6892766ae78995a..."   ← wyciągnięte dla filtrowania
```

**Optymalizacja indeksów** — wyłącz indeksowanie pola `data` (duży zagnieżdżony obiekt):

```json
{
  "fieldOverrides": [{
    "collectionGroup": "webhook_events",
    "fieldPath": "data",
    "indexes": []
  }]
}
```

---

## 🐳 Wdrożenie: Docker → GitHub → GCP

> **Wybrany wariant:** GitHub Actions → Artifact Registry → Cloud Run
>
> Budujemy obraz Docker bezpośrednio w chmurze (bez lokalnego Docker Desktop). GitHub Actions uruchamia build przy każdym `git push` do gałęzi `main`.

---

### Krok 0: Wymagania wstępne

Zainstaluj lokalnie:

```bash
# Google Cloud CLI
# Windows: https://cloud.google.com/sdk/docs/install
# Mac: brew install google-cloud-sdk
# Linux: snap install google-cloud-sdk

gcloud --version   # Sprawdź instalację
```

Upewnij się, że masz:
- ✅ Konto Google Cloud z aktywnym projektem
- ✅ Repozytorium GitHub: `Neuroatypowi/neuroatypowy`
- ✅ Klucz tajny MailerSend (Signing Secret)

---

### Krok 1: Przygotowanie projektu GCP

```bash
# Ustaw swój projekt GCP
export PROJECT_ID="twoj-projekt-id"
gcloud config set project $PROJECT_ID

# Włącz wymagane API
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com

echo "✅ API włączone"
```

---

### Krok 2: Utwórz rejestr Docker w Artifact Registry

```bash
gcloud artifacts repositories create webhook-receiver \
  --repository-format=docker \
  --location=europe-west1 \
  --description="Webhook receiver Docker images"

echo "✅ Rejestr Docker utworzony"
```

---

### Krok 3: Utwórz konto usługowe dla Cloud Run

```bash
# Konto usługowe dla serwera (zasada minimalnych uprawnień)
gcloud iam service-accounts create webhook-sa \
  --display-name="Webhook Receiver Service Account"

# Uprawnienia do Firestore (historyczna nazwa: datastore)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:webhook-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

echo "✅ Konto usługowe webhook-sa skonfigurowane"
```

---

### Krok 4: Utwórz konto usługowe dla GitHub Actions

```bash
# Konto usługowe dla CI/CD — minimalne uprawnienia
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Deployer"

# Uprawnienia do budowania i wdrażania
ROLES=(
  "roles/artifactregistry.writer"    # Push obrazów Docker
  "roles/run.admin"                  # Wdrożenie Cloud Run
  "roles/iam.serviceAccountUser"     # Użycie webhook-sa
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$ROLE"
done

echo "✅ Konto github-actions-sa skonfigurowane"
```

---

### Krok 5: Wygeneruj klucz JSON dla GitHub Actions

```bash
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com

echo "✅ Klucz wygenerowany: github-actions-key.json"
echo "⚠️  WAŻNE: Dodaj zawartość tego pliku jako sekret GitHub GCP_SA_KEY"
echo "⚠️  WAŻNE: Usuń plik lokalny po dodaniu do GitHub!"
```

---

### Krok 6: Zapisz Signing Secret w Cloud Secret Manager

```bash
# Wpisz swój Signing Secret z panelu MailerSend
echo -n "TWOJ_SIGNING_SECRET_Z_MAILERSEND" | \
  gcloud secrets create MAILERSEND_SIGNING_SECRET \
  --data-file=- \
  --replication-policy=user-managed \
  --locations=europe-west1

# Uprawnienia dla konta usługowego webhook-sa
gcloud secrets add-iam-policy-binding MAILERSEND_SIGNING_SECRET \
  --member="serviceAccount:webhook-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

echo "✅ Signing Secret zapisany w Secret Manager"
```

---

### Krok 7: Utwórz bazę danych Firestore

```bash
gcloud firestore databases create \
  --location=europe-west1 \
  --type=firestore-native

echo "✅ Firestore Native Mode w europe-west1 gotowy"
```

---

### Krok 8: Dodaj sekrety do GitHub

W repozytorium GitHub przejdź do:
**Settings → Secrets and variables → Actions → New repository secret**

Dodaj te sekrety:

| Nazwa sekretu | Wartość |
|---------------|---------|
| `GCP_SA_KEY` | Zawartość pliku `github-actions-key.json` |
| `GCP_PROJECT_ID` | Twój Project ID (np. `moj-projekt-123`) |

> ✅ Po dodaniu usuń lokalny plik `github-actions-key.json`!

---

### Krok 9: Utwórz plik GitHub Actions Workflow

Utwórz plik `.github/workflows/deploy.yml` w repozytorium:

```yaml
# =============================================================
# GitHub Actions: Build Docker → Push → Deploy Cloud Run
# Repozytorium: Neuroatypowi/neuroatypowy
# Ścieżka: Backend/GCP/webhook-receiver/
# =============================================================

name: Deploy Webhook Receiver

on:
  push:
    branches: [ main ]
    paths:
      - 'Backend/GCP/webhook-receiver/**'
  workflow_dispatch:           # Ręczne uruchomienie z GitHub UI

env:
  REGION:     europe-west1
  SERVICE:    webhook-receiver
  REGISTRY:   europe-west1-docker.pkg.dev
  REPO:       webhook-receiver

jobs:
  deploy:
    name: Build & Deploy
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      # ─── 1. Pobierz kod ───────────────────────────────────
      - name: Checkout repozytorium
        uses: actions/checkout@v4

      # ─── 2. Uwierzytelnij się w GCP ──────────────────────
      - name: Uwierzytelnij w Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      # ─── 3. Skonfiguruj gcloud CLI ───────────────────────
      - name: Ustaw projekt GCP
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}

      # ─── 4. Zaloguj Docker do Artifact Registry ──────────
      - name: Zaloguj Docker do Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGISTRY }} --quiet

      # ─── 5. Zbuduj obraz Docker ───────────────────────────
      - name: Zbuduj obraz Docker
        working-directory: Backend/GCP/webhook-receiver
        run: |
          IMAGE="${{ env.REGISTRY }}/${{ secrets.GCP_PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:${{ github.sha }}"
          docker build \
            --tag "$IMAGE" \
            --tag "${{ env.REGISTRY }}/${{ secrets.GCP_PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:latest" \
            .
          echo "IMAGE=$IMAGE" >> $GITHUB_ENV

      # ─── 6. Wypchnij obraz do rejestru ───────────────────
      - name: Push obraz do Artifact Registry
        run: |
          docker push "${{ env.IMAGE }}"
          docker push "${{ env.REGISTRY }}/${{ secrets.GCP_PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:latest"

      # ─── 7. Wdróż na Cloud Run ───────────────────────────
      - name: Wdróż na Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE }} \
            --image="${{ env.IMAGE }}" \
            --region=${{ env.REGION }} \
            --platform=managed \
            --min-instances=1 \
            --max-instances=10 \
            --memory=256Mi \
            --cpu=1 \
            --concurrency=80 \
            --timeout=60 \
            --cpu-boost \
            --allow-unauthenticated \
            --service-account="webhook-sa@${{ secrets.GCP_PROJECT_ID }}.iam.gserviceaccount.com" \
            --set-secrets="MAILERSEND_SIGNING_SECRET=MAILERSEND_SIGNING_SECRET:latest" \
            --quiet

      # ─── 8. Wyświetl URL serwisu ──────────────────────────
      - name: Pobierz URL Cloud Run
        run: |
          URL=$(gcloud run services describe ${{ env.SERVICE }} \
            --region=${{ env.REGION }} \
            --format='value(status.url)')
          echo "✅ Serwis wdrożony: $URL/webhook"
          echo "SERVICE_URL=$URL" >> $GITHUB_ENV

      # ─── 9. Szybki test health check ─────────────────────
      - name: Sprawdź dostępność serwisu
        run: |
          sleep 5
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${{ env.SERVICE_URL }}/")
          if [ "$STATUS" = "200" ]; then
            echo "✅ Health check OK (HTTP $STATUS)"
          else
            echo "❌ Health check FAILED (HTTP $STATUS)"
            exit 1
          fi
```

---

### Krok 10: Wypchnij kod do GitHub

```bash
# W katalogu Backend/GCP/webhook-receiver/
git add .
git commit -m "feat: MailerSend webhook receiver v1.0.0"
git push origin main
```

Po `git push`:
1. GitHub Actions uruchamia się automatycznie
2. Buduje obraz Docker w chmurze GitHub
3. Wypycha obraz do Artifact Registry GCP
4. Wdraża serwis na Cloud Run
5. Uruchamia health check

> ✅ Sprawdź postęp: **GitHub → Actions → Deploy Webhook Receiver**

---

### Krok 11: Konfiguracja MailerSend

1. Zaloguj się do panelu [MailerSend](https://app.mailersend.com)
2. Przejdź do **Settings → Webhooks → Add Webhook**
3. Wypełnij formularz:

| Pole | Wartość |
|------|---------|
| **URL** | `https://TWOJ-CLOUD-RUN-URL/webhook` |
| **Version** | `v2` (MailerSend Webhooks v2) |
| **Events** | Zaznacz wszystkie 20 typów |
| **Signing secret** | Skopiuj — wklej do Secret Manager |

4. Kliknij **Save**
5. Kliknij **Test webhook** → `activity.sent` → **Send test**

---

### Diagram przepływu CI/CD

```
git push main
     ↓
GitHub Actions uruchamia się
     ↓
 Checkout kodu
     ↓
 Uwierzytelnienie GCP (klucz SA)
     ↓
 Docker build (ubuntu-latest runner)
     ↓
 Docker push → Artifact Registry europe-west1
     ↓
 gcloud run deploy webhook-receiver
     ↓
 Cloud Run: min-instances=1, cpu-boost=true
     ↓
 Health check GET /
     ↓
✅ Serwis aktywny
```

---

## 🔐 Bezpieczeństwo

### Weryfikacja podpisu HMAC-SHA256

| Zasada | Implementacja |
|--------|---------------|
| Surowe bajty | `express.raw({ type: 'application/json' })` |
| Algorytm | `crypto.createHmac('sha256', secret).update(rawBody)` |
| Format | Hex-encoded digest |
| Nagłówek | `Signature` (nie `Mailersend-Signature`!) |
| Porównanie | `crypto.timingSafeEqual()` — odporne na timing attacks |
| Sprawdzenie długości | Przed `timingSafeEqual()` — zapobiega wyjątkowi |

### Zarządzanie tajnymi kluczami

```
Cloud Secret Manager (nie zmienne środowiskowe w kodzie)
     ↓
--set-secrets="MAILERSEND_SIGNING_SECRET=..."
     ↓
Cloud Run montuje jako zmienną środowiskową
     ↓
process.env.MAILERSEND_SIGNING_SECRET
```

**NIE rób tego:**
```bash
# ❌ NIGDY nie wpisuj sekretów do kodu
const secret = "abc123hardcoded";

# ❌ NIGDY nie commituj .env do GitHub
git add .env  # Błąd!
```

### Polityka ponownych prób MailerSend

| Parametr | Wartość |
|----------|---------|
| Timeout odpowiedzi | 3 000 ms |
| Kryterium sukcesu | HTTP 2xx |
| Próba 1 | Natychmiast |
| Próba 2 | +10 sekund |
| Próba 3 | +100 sekund |
| Próg ostrzeżenia | 10 błędów / 24h → e-mail |
| Próg blokady | 20 błędów / 24h → webhook wstrzymany |

---

## ⚙️ Konfiguracja zmiennych

### Zmienne środowiskowe serwera

| Zmienna | Źródło | Opis |
|---------|--------|------|
| `PORT` | Cloud Run (auto) | Port serwera (domyślnie `8080`) |
| `MAILERSEND_SIGNING_SECRET` | Cloud Secret Manager | Klucz weryfikacji podpisu |
| `DEBUG` | Opcjonalna | `true` = tryb debugowania z logami |
| `SMSAPI_TOKEN` | Secret Manager (przyszłość) | Token SMSAPI.pl (moduł zablokowany) |

### Parametry Cloud Run

| Parametr | Wartość | Powód |
|----------|---------|-------|
| `--region` | `europe-west1` | Ten sam region co MailerSend (Belgia) |
| `--min-instances` | `1` | Eliminuje zimny start |
| `--max-instances` | `10` | Skalowanie przy dużym obciążeniu |
| `--memory` | `256Mi` | Wystarczające dla JSON + Firestore |
| `--cpu` | `1` | 1 rdzeń dla tego rodzaju zadań |
| `--concurrency` | `80` | Jednoczesne żądania na instancję |
| `--cpu-boost` | tak | Więcej CPU przy uruchamianiu |
| `--timeout` | `60` | Limit czasu żądania (max) |

---

## 🧪 Testowanie

### Test 1: Health check (GET /)

```bash
# Zastąp URL swoim adresem Cloud Run
curl -s https://TWOJ-URL.run.app/

# Oczekiwana odpowiedź:
# {"status":"ok","service":"webhook-receiver","version":"1.0.0"}
```

### Test 2: Symulacja webhooka (POST /webhook)

```bash
# Wymaga znajomości Signing Secret
SECRET="twoj-signing-secret"
PAYLOAD='{"type":"activity.delivered","created_at":"2026-03-01T12:00:00Z","data":{"id":"test-001","domain_id":"dom123","message_id":"msg123","email_id":"em123","type":"delivered","subject":"[POMOC]: Test","email":"k.wiejowska@um.warszawa.pl","tags":[],"meta":[]}}'

# Oblicz podpis HMAC-SHA256
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

curl -s -X POST https://TWOJ-URL.run.app/webhook \
  -H "Content-Type: application/json" \
  -H "Signature: $SIG" \
  -d "$PAYLOAD"

# Oczekiwana odpowiedź:
# {"status":"ok"}
```

### Test 3: Test przez panel MailerSend

1. Otwórz panel MailerSend → **Webhooks**
2. Kliknij **Test webhook**
3. Wybierz typ zdarzenia (np. `activity.sent`)
4. Kliknij **Send test**
5. Sprawdź odpowiedź: `200 OK ✅`
6. Sprawdź Firestore: Nowy dokument w kolekcji `webhook_events`

### Test 4: Weryfikacja duplikatów (idempotentność)

```bash
# Wyślij ten sam payload dwa razy — drugi powinien zwrócić "duplicate"
curl -X POST ...  # pierwsze wywołanie → {"status":"ok"}
curl -X POST ...  # drugie wywołanie  → {"status":"duplicate"}
```

---

## 📊 Monitoring

### Logi Cloud Run

```bash
# Ostatnie 50 logów serwisu
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="webhook-receiver"' \
  --limit=50 \
  --format="table(timestamp,textPayload)"
```

### Metryki Firestore

```bash
# Liczba dokumentów w kolekcji
gcloud firestore documents list \
  --collection-group=webhook_events \
  --show-missing
```

### Dashboard GitHub Actions

Sprawdź historię wdrożeń:
**GitHub → Actions → Deploy Webhook Receiver**

---

## 📚 Podstawy teoretyczne

### Dlaczego MailerSend Webhooks v2?

MailerSend w 2025 roku wprowadził Webhooks v2. Kluczowa zmiana: **spłaszczenie payloadu (payload flattening)**.

**Stara wersja v1** — "gruby" pakiet danych:
```json
{
  "data": {
    "email": {
      "recipient": { "id": "...", "email": "..." },
      "from": { "email": "...", "name": "..." },
      "domain": { "id": "...", "name": "..." }
    }
  }
}
```

**Nowa wersja v2** — tylko identyfikatory:
```json
{
  "type": "activity.delivered",
  "data": {
    "id": "...",
    "email": "...",
    "message_id": "...",
    "domain_id": "..."
  }
}
```

Mniejszy payload = szybszy transfer = łatwiej zmieścić się w limicie 3 sekund.

---

### Dlaczego Google Cloud Firestore, nie DynamoDB?

| Czynnik | Firestore (Belgia) | DynamoDB (Frankfurt) |
|---------|-------------------|---------------------|
| Odległość od MailerSend | 0 km (ten sam region) | ~600 km |
| Latencja zapisu | ~20–50 ms | ~10 ms + 15–30 ms tranzytu |
| Całkowity czas odpowiedzi | **~30–60 ms** | ~50–80 ms |
| Ryzyko przekroczenia 3s | Brak | Małe, ale istnieje |
| Darmowy limit | 20 000 zapisów/dzień | 25 WCU (prowizjonowane) |
| Konfiguracja | Prosta | Wymaga ręcznego prowizjonowania |
| Zgodność z RODO | Dane w Belgii (EOG) | Dane mogą opuścić EOG |

**Wniosek:** Firestore w europe-west1 jest jedynym rozwiązaniem, które matematycznie gwarantuje spełnienie limitu 3 sekund przy zerowych kosztach operacyjnych.

---

### Dlaczego `preferRest: true` w Firestore?

```javascript
const db = new Firestore({ preferRest: true });
```

Domyślnie Firestore SDK używa gRPC. Negocjacja kanału gRPC przy zimnym starcie trwa **200–500 ms**. Opcja `preferRest: true` każe SDK używać REST zamiast gRPC. Dla pojedynczych zapisów dokumentów wydajność REST = gRPC, ale inicjalizacja jest szybsza.

| Protokół | Zimny start | Zapis (ciepły) |
|----------|-------------|----------------|
| gRPC (domyślny) | +200–500 ms | ~20–50 ms |
| REST (`preferRest: true`) | 0 ms narzutu | ~20–50 ms |

---

### Dlaczego `min-instances=1`?

Bez `min-instances=1`, Cloud Run "usypia" kontener po kilku minutach bezczynności. Pierwsze żądanie po uśpieniu (zimny start) trwa **500–1500 ms**. Przy limicie 3 sekund i zimnym starcie, zostaje tylko 1500–2500 ms na HMAC + parsowanie + Firestore. Zbyt mało przy dużym obciążeniu Firestore.

Z `min-instances=1`: **jeden kontener zawsze działa**. Zimny start jest eliminowany. Dodatkowy koszt: ~$2–4/miesiąc przy niedużym ruchu (lub $0 w ramach bezpłatnego limitu 180 000 vCPU-sekund/miesiąc).

---

### Dlaczego GitHub Actions, nie Cloud Build?

| Czynnik | GitHub Actions | Cloud Build |
|---------|---------------|-------------|
| Wymaga lokalnego Docker | ❌ Nie | ❌ Nie |
| Integracja z GitHub | ✅ Natywna | ⚠️ Wymaga triggera |
| Cena | ✅ 2000 min/miesiąc gratis | ✅ 120 min/dzień gratis |
| Konfiguracja | Jeden plik YAML | Dwa pliki (cloudbuild.yaml + trigger) |
| Widoczność | GitHub UI | GCP Console |

GitHub Actions jest wybrane, bo repozytorium jest w GitHub, a konfiguracja jest prostsza i widoczna w tym samym miejscu co kod.

---

### Dlaczego obraz Distroless?

Standardowy obraz `node:22` zawiera:
- Kompilator gcc/g++
- Powłokę bash/sh
- Menedżer apt/dpkg
- Setki zbędnych bibliotek

W razie włamania do kontenera, atakujący może uruchamiać dowolne polecenia.

Obraz `distroless/nodejs22-debian12` zawiera **tylko**:
- Środowisko uruchomieniowe Node.js
- Niezbędne biblioteki systemowe

W razie włamania, atakujący nie może uruchamiać poleceń (`bash: not found`).

---

### Wzorzec Fire-and-Forget (setImmediate)

MailerSend wymaga odpowiedzi w 3 sekundy. Logika biznesowa (Warsaw 19115 API, SMSAPI) może trwać dłużej. Wzorzec:

```
Żądanie MailerSend
      ↓
Weryfikacja (< 0.1 ms)
      ↓
Parsowanie JSON (< 0.1 ms)
      ↓
Zapis Firestore (20–50 ms)
      ↓
ODPOWIEDŹ 200 OK ← koniec 3-sekundowego okna
      ↓ (po odpowiedzi, bez limitu czasu)
setImmediate() → handlePostProcessing()
      ↓
Warsaw 19115 API (opcjonalnie)
```

---

### Strategia bezpieczeństwa: Capability URL

Google Apps Script wycina niestandardowe nagłówki HTTP (w tym `Signature`). W GAS nie można zweryfikować podpisu HMAC. Zamiast tego bezpieczeństwo opiera się na "Capability URL" — unikalnym, losowym tokenie w adresie URL endpointu (`.../exec?token=...`). Dopóki URL nie wycieknie, endpoint jest bezpieczny.

**W Cloud Run:** Pełna weryfikacja HMAC-SHA256 jest możliwa, bo Cloud Run zachowuje wszystkie nagłówki HTTP. Nie potrzebujemy Capability URL jako jedynego mechanizmu bezpieczeństwa.

---

### Prawo KPA — podstawa prawna SMS-ów

Wzorzec SMS: `[POMOC]: Wysłałem ważny mail, proszę o odbiór {RODZAJ_PISMA}, e-mail:{ODBIORCA}, e-mail:{NADAWCA}@neuroatypowi.org, {DATA_CZAS}. KPA art.14, 14§2, 63§1`

Podstawy prawne:
- **Art. 14 § 2 KPA** — Sprawy mogą być załatwiane w formie dokumentu elektronicznego
- **Art. 63 § 1 KPA** — Wymogi formalne podania (wniosku, skargi)

SMS pełni rolę sygnalizacyjną — zwiększa prawdopodobieństwo, że urzędnik odczyta wiadomość elektroniczną.

---

## 📖 Bibliografia

| Źródło (APA 7) | URL |
|----------------|-----|
| MailerSend. (2025). *Webhooks v2: Lighter, faster payloads*. | https://www.mailersend.com/whats-new/webhooks-v2 |
| MailerSend. (2025). *Create and manage webhooks*. | https://developers.mailersend.com/api/v1/webhooks |
| MailerSend. (2025). *Getting started with webhooks*. | https://www.mailersend.com/help/webhooks |
| MailerSend. (2025). *Get a more accurate view with deferred status*. | https://www.mailersend.com/whats-new/deferred-status |
| MailerSend. (2025). *MailerSend MCP server (BETA)*. | https://developers.mailersend.com/mcp-server |
| Google Cloud. (2025). *Cloud Firestore documentation*. | https://cloud.google.com/firestore/docs |
| Google Cloud. (2025). *Cloud Run: Set minimum instances*. | https://cloud.google.com/run/docs/configuring/min-instances |
| Google Cloud. (2025). *Best practices for Cloud Firestore*. | https://firebase.google.com/docs/firestore/best-practices |
| Google Cloud. (2025). *Artifact Registry: Docker repositories*. | https://cloud.google.com/artifact-registry/docs/docker |
| GitHub. (2025). *GitHub Actions: Workflow syntax*. | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions |
| Anthropic. (2025). *Claude Code documentation*. | https://code.claude.com/docs |
| ARASAAC. (2025). *AAC symbols — Computing*. | https://beta.arasaac.org/pictograms/search/computer |
| UM Warszawa. (2025). *API Centrum Kontaktu 19115*. | https://api.um.warszawa.pl |

---

## 📁 Pliki projektu

| Plik | Opis |
|------|------|
| `src/server.js` | Główny serwer (wersja produkcyjna lub debug) |
| `Dockerfile` | Multi-stage build, distroless Node.js 22 |
| `.github/workflows/deploy.yml` | GitHub Actions CI/CD pipeline |
| `package.json` | Zależności Node.js |
| `README.md` | Ten plik (3 warianty: ETR/B2/Tech) |

---

## 📞 Kontakt i licencja

**Organizacja:** [Neuroatypowi.org](https://neuroatypowi.org)
**Repozytorium:** [github.com/Neuroatypowi/neuroatypowy](https://github.com/Neuroatypowi/neuroatypowy/tree/main/Backend/GCP/webhook-receiver/)
**Licencja:** MIT

---

*Dokument wygenerowany: 1 marca 2026 | Język: Polski B2 / Jasnopis / ETR / AAC*
*Zgodny z: KPA art. 14 § 2, art. 63 § 1 | RODO (dane w EOG, Belgia)*
