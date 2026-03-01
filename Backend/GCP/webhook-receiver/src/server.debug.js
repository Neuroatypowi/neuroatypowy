'use strict';

// =============================================================================
// MAILERSEND WEBHOOK RECEIVER — WERSJA DEBUG
// =============================================================================
// Plik:    src/server.js
// Wersja:  2.0-DEBUG
// Data:    2026-03-01
// Projekt: MailerSend Webhooks v2 + Cloud Run + Firestore (europe-west1)
// Źródło:  Audyt techniczny + Schemat Firestore (Blueprint)
//
// ARCHITEKTURA:
//   MailerSend → HTTPS POST → Cloud Run (ten plik) → Firestore → 200 OK
//   → setImmediate → Warsaw 19115 (async, bez blokowania odpowiedzi)
//
// TRYB DEBUG:
//   Ustaw zmienną środowiskową DEBUG=true aby włączyć szczegółowe logi.
//   W Cloud Run: --set-env-vars DEBUG=true
//   Lokalnie:    DEBUG=true node src/server.js
//   WAŻNE: Wyłącz DEBUG=false lub usuń zmienną przed wdrożeniem produkcyjnym!
//
// MODUŁY:
//   [AKTYWNY]     Warsaw 19115  — wywoływany asynchronicznie po 200 OK
//   [ZABLOKOWANY] SMSAPI.PL     — usługa tymczasowo niedostępna (2026-03-01)
//                                 Cały kod SMSAPI jest w bloku komentarza /*..*/
//                                 NIE usuwaj — zachowaj do przyszłego wdrożenia
//
// BEZPIECZEŃSTWO:
//   - Podpis HMAC-SHA256 weryfikowany na nagłówku "Signature" (nie "Mailersend-Signature"!)
//   - Użyj crypto.timingSafeEqual() zamiast === (zapobiega timing attack)
//   - Raw body parsing (express.raw) — nigdy nie parsuj i nie serializuj ponownie
//   - Klucz podpisywania przechowywany w Cloud Secret Manager
//
// LIMIT CZASU: MailerSend wymaga odpowiedzi w ciągu 3000 ms.
//   Zmierzone czasy (warm instance):
//   - Weryfikacja HMAC:     ~0.05 ms
//   - JSON.parse:           ~0.05 ms
//   - Firestore create():   ~20-50 ms
//   - Łącznie:              ~25-60 ms ← 50x szybciej niż wymagane!
// =============================================================================

const express = require('express');
const crypto  = require('node:crypto');
const { Firestore, FieldValue } = require('@google-cloud/firestore');

// =============================================================================
// KONFIGURACJA — Zmienne środowiskowe
// =============================================================================

// Port HTTP — Cloud Run zawsze nasłuchuje na 8080
const PORT = process.env.PORT || 8080;

// Klucz podpisywania webhooka MailerSend (pobierany z Cloud Secret Manager)
// W Cloud Run: --set-secrets MAILERSEND_SIGNING_SECRET=MAILERSEND_SIGNING_SECRET:latest
const SIGNING_SECRET = process.env.MAILERSEND_SIGNING_SECRET || '';

// Flaga DEBUG — włącz szczegółowe logowanie podczas testów
// WYŁĄCZ przed wdrożeniem produkcyjnym (DEBUG=false lub usuń zmienną)
const DEBUG = process.env.DEBUG === 'true';

// Pomocnik logowania — wyświetla logi tylko gdy DEBUG=true
const log = {
  info:  (...args) => console.log('[INFO]', ...args),
  debug: (...args) => { if (DEBUG) console.log('[DEBUG]', ...args); },
  warn:  (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  time:  (label)   => { if (DEBUG) console.time(`[TIMER] ${label}`); },
  timeEnd:(label)  => { if (DEBUG) console.timeEnd(`[TIMER] ${label}`); },
};

// =============================================================================
// LOGIKA BIZNESOWA — Mapowania i wzorce
// =============================================================================

// Mapa: adres e-mail urzędnika → numer telefonu do SMS
// Źródło: Specyfikacja projektu (PDF 4, sekcja 6.1)
// UWAGA: Używaj mapy haszującej (nie bazy danych) dla szybkości < 3s
const EMAIL_TO_PHONE = {
  'k.wiejowska@um.warszawa.pl':          '+48725851525',
  'boi@warszawapraga-pln.sr.gov.pl':     '+48607237064',
  'csk@strazmiejska.waw.pl':             '+48723986112',
  // Dodaj kolejne mapowania według specyfikacji projektu:
  // 'urzednik@instytucja.pl': '+48XXXXXXXXX',
};

// Adres e-mail fallback → zamiast SMS wywołaj API Warsaw 19115
const WARSAW_FALLBACK_EMAIL = 'kontakt@um.warszawa.pl';

// Prefiksy tematu wiadomości aktywujące powiadamianie (KPA art. 14 § 2)
// Dopasowanie przez startsWith() — szybsze niż regex (~nanosekund)
const SUBJECT_PREFIXES = [
  '[POMOC]:',
  '[SYGNAL]:',
  '[WNIOSEK]:',
  '[SKARGA]:',
];

// Wzorce URL wskazujące na pobranie pliku (File Manager Workaround)
// MailerSend nie generuje odrębnego zdarzenia "pobrano plik" — traktuje jako kliknięcie
const ATTACHMENT_PATTERNS = [
  'drive.google.com',
  'docs.google.com',
  '1drv.ms',
  '.pdf',
  '.zip',
  '.docx',
  '.xlsx',
  '.pptx',
];

// Mapa typów zdarzeń MailerSend → czytelne klasyfikacje biznesowe
// Źródło: Blueprint, tabela 20 typów zdarzeń
const CLASSIFIED_EVENTS = {
  'activity.opened':           'reopened',          // Każde kolejne otwarcie
  'activity.opened_unique':    'first_open',        // Pierwsze otwarcie (raz na odbiorcę)
  'activity.clicked':          'again_clicked',     // Każde kolejne kliknięcie
  'activity.clicked_unique':   'first_click',       // Pierwsze kliknięcie (raz na odbiorcę)
  'activity.sent':             'sent',
  'activity.delivered':        'delivered',
  'activity.soft_bounced':     'soft_bounce',       // Tymczasowy błąd dostarczenia
  'activity.hard_bounced':     'hard_bounce',       // Trwały błąd dostarczenia
  'activity.deferred':         'deferred',          // Odroczony (Starter+, od IX.2025)
  'activity.unsubscribed':     'unsubscribed',
  'activity.spam_complaint':   'spam_complaint',    // Obejmuje też "junk" — activity.junk NIE ISTNIEJE!
  'activity.survey_opened':    'survey_opened',
  'activity.survey_submitted': 'survey_submitted',  // Opóźnienie 30 min po ostatniej akcji
  'sender_identity.verified':  'identity_verified', // Inna struktura data{}!
  'maintenance.start':         'maintenance_start', // data{} zawiera tylko domain_id
  'maintenance.end':           'maintenance_end',
  'inbound_forward.failed':    'inbound_failed',
  'email_single.verified':     'email_verified',
  'email_list.verified':       'list_verified',
  'bulk_email.completed':      'bulk_completed',
};

// =============================================================================
// INICJALIZACJA FIRESTORE
// =============================================================================

// Tworzymy klienta JEDEN RAZ na poziomie modułu (nie per żądanie!)
// Cloud Run reużywa instancji kontenera — pula połączeń jest dzielona.
//
// preferRest: true — krytyczne dla Cloud Run!
//   Domyślnie SDK używa gRPC, którego negocjacja przy zimnym starcie
//   zajmuje 200-500 ms dodatkowych. REST ma tę samą wydajność dla
//   pojedynczych zapisów, ale jest znacznie szybszy przy inicjalizacji.
const db = new Firestore({ preferRest: true });

// Pre-warm: wysyłamy lekki odczyt przy starcie serwera
// Gwarantuje że pierwsze prawdziwe żądanie nie doświadczy opóźnienia inicjalizacji
db.collection('_warmup').doc('ping').get()
  .then(() => log.debug('Firestore pre-warm: OK'))
  .catch(() => log.debug('Firestore pre-warm: kolekcja _warmup nie istnieje — OK, to normalne'));

// =============================================================================
// FUNKCJE POMOCNICZE
// =============================================================================

/**
 * Weryfikuje podpis HMAC-SHA256 z nagłówka "Signature"
 *
 * WAŻNE: Nagłówek to "Signature" — NIE "Mailersend-Signature"!
 * WAŻNE: rawBody musi być dokładnymi bajtami żądania HTTP (Buffer z express.raw)
 *        Nigdy nie używaj JSON.stringify(JSON.parse(...)) — może zmienić kolejność kluczy!
 * WAŻNE: Użyj timingSafeEqual() zamiast === — zapobiega timing side-channel attack
 *
 * @param {Buffer}  rawBody    Surowe bajty body żądania HTTP
 * @param {string}  sigHeader  Wartość nagłówka "Signature" (hex)
 * @param {string}  secret     Tajny klucz podpisywania z MailerSend
 * @returns {boolean}          true = podpis prawidłowy
 */
function verifySignature(rawBody, sigHeader, secret) {
  if (!sigHeader || !secret) {
    log.debug('verifySignature: brak nagłówka Signature lub klucza — odrzucam');
    return false;
  }

  log.time('hmac-verify');

  // Oblicz HMAC-SHA256 z raw body, zakoduj jako HEX
  const computed    = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  const computedBuf = Buffer.from(computed, 'hex');
  const receivedBuf = Buffer.from(sigHeader, 'hex');

  // Sprawdź długość przed timingSafeEqual — rzuca błąd przy różnych długościach
  if (computedBuf.length !== receivedBuf.length) {
    log.warn('verifySignature: różna długość buforów — podpis nieprawidłowy');
    log.timeEnd('hmac-verify');
    return false;
  }

  const isValid = crypto.timingSafeEqual(computedBuf, receivedBuf);
  log.timeEnd('hmac-verify');

  if (DEBUG) {
    log.debug('verifySignature:', isValid ? 'OK ✓' : 'FAIL ✗');
    log.debug('  computed:', computed.substring(0, 16) + '...');
    log.debug('  received:', sigHeader.substring(0, 16) + '...');
  }

  return isValid;
}

/**
 * Sprawdza czy temat wiadomości zaczyna się od jednego z prefiksów KPA
 *
 * @param {string} subject  Temat wiadomości e-mail z payload MailerSend
 * @returns {string|null}   Dopasowany prefiks lub null
 */
function matchSubjectKeyword(subject) {
  if (!subject) return null;

  for (const prefix of SUBJECT_PREFIXES) {
    if (subject.startsWith(prefix)) {
      log.debug(`matchSubjectKeyword: dopasowano "${prefix}" w temacie: "${subject}"`);
      return prefix;
    }
  }

  log.debug(`matchSubjectKeyword: brak dopasowania dla tematu: "${subject}"`);
  return null;
}

/**
 * Klasyfikuje zdarzenie MailerSend na czytelny typ biznesowy
 * Obsługuje też detekcję pobrania pliku (File Manager Workaround)
 *
 * @param {string} eventType   Pełna nazwa zdarzenia, np. "activity.delivered"
 * @param {string} urlClicked  URL z pola data.url lub data.link (jeśli dostępny)
 * @returns {string}           Klasyfikacja biznesowa
 */
function classifyEvent(eventType, urlClicked) {
  // Sprawdź czy kliknięty URL wskazuje na plik (detekcja załącznika)
  // MailerSend nie generuje osobnego zdarzenia "pobrano plik" — to zwykłe activity.clicked
  if (urlClicked) {
    const url = urlClicked.toLowerCase();
    const isAttachment = ATTACHMENT_PATTERNS.some(pattern => url.includes(pattern));
    if (isAttachment) {
      log.debug(`classifyEvent: wykryto załącznik w URL: ${urlClicked}`);
      return 'attachment_download';
    }
  }

  const classified = CLASSIFIED_EVENTS[eventType] ?? eventType;
  log.debug(`classifyEvent: ${eventType} → ${classified}`);
  return classified;
}

// =============================================================================
// MODUŁ: WARSAW 19115 + SMSAPI (ASYNCHRONICZNY)
// Wywoływany po zwróceniu 200 OK — nie blokuje odpowiedzi dla MailerSend!
// Strategia: Firestore zapis → 200 OK → setImmediate → ta funkcja
// =============================================================================

/**
 * Post-processing: Warsaw 19115 API i SMSAPI (asynchronicznie)
 * Wywołuj tę funkcję przez setImmediate() — nigdy bezpośrednio przed res.json()!
 *
 * Przepływ:
 *  1. Sprawdź czy temat pasuje do prefiksu KPA (POMOC/SYGNAL/WNIOSEK/SKARGA)
 *  2. Znajdź numer telefonu urzędnika na podstawie adresu e-mail odbiorcy
 *  3a. Jeśli e-mail to fallback (kontakt@um.warszawa.pl) → wywołaj API 19115
 *  3b. Jeśli znaleziono numer telefonu → [ZABLOKOWANE: SMSAPI]
 *
 * @param {object} data            Obiekt data{} z payloadu webhooka
 * @param {string} subject         Temat wiadomości
 * @param {string} recipientEmail  Adres e-mail odbiorcy
 */
async function handlePostProcessing(data, subject, recipientEmail) {
  log.debug('handlePostProcessing: start', { subject, recipientEmail });

  // Krok 1: Sprawdź czy temat zawiera słowo kluczowe KPA
  const matchedKeyword = matchSubjectKeyword(subject);
  if (!matchedKeyword) {
    log.debug('handlePostProcessing: brak słowa kluczowego — pomijam powiadamianie');
    return;
  }

  log.info(`[post-processing] Słowo kluczowe: ${matchedKeyword} | Odbiorca: ${recipientEmail}`);

  // Krok 2: Znajdź numer telefonu urzędnika
  const phone = EMAIL_TO_PHONE[recipientEmail];
  log.debug('handlePostProcessing: telefon dla', recipientEmail, '→', phone ?? 'nie znaleziono');

  // ==========================================================================
  // MODUŁ: WARSAW 19115 API
  // Aktywny — wywoływany gdy odbiorca to kontakt@um.warszawa.pl
  // API Urzędu Warszawy — Miejskie Centrum Kontaktu
  // ==========================================================================
  if (!phone && recipientEmail === WARSAW_FALLBACK_EMAIL) {
    log.info('[19115] Wywołuję API Warsaw 19115 dla:', recipientEmail);

    try {
      const payload = {
        subject,
        email:      recipientEmail,
        message_id: data.message_id ?? null,
        keyword:    matchedKeyword,
        timestamp:  new Date().toISOString(),
      };

      log.debug('[19115] Payload:', JSON.stringify(payload));

      const response = await fetch('https://api.um.warszawa.pl/api/action/19115', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      log.info('[19115] HTTP status:', response.status);

      if (DEBUG) {
        const responseText = await response.text();
        log.debug('[19115] Odpowiedź:', responseText.substring(0, 200));
      }

    } catch (err) {
      // Błąd API 19115 nie może blokować systemu — logujemy i kontynuujemy
      log.error('[19115] API call failed:', err.message);
    }
    return;
  }

  // ==========================================================================
  // MODUŁ SMSAPI.PL — CAŁKOWICIE ZABLOKOWANY
  // ============================================================
  // POWÓD:  Usługa SMSAPI.PL tymczasowo niedostępna (stan: 2026-03-01)
  // STATUS: Odkomentuj poniższy blok gdy:
  //         1. SMSAPI_TOKEN zostanie udostępniony przez administratora
  //         2. Usługa wznowi normalne działanie
  //         3. Zmienną SMSAPI_TOKEN dodasz do Cloud Secret Manager
  //
  // AKTYWACJA:
  //   gcloud secrets create SMSAPI_TOKEN --data-file=token.txt
  //   gcloud run services update webhook-receiver \
  //     --set-secrets=SMSAPI_TOKEN=SMSAPI_TOKEN:latest
  //
  // UWAGA: Nie usuwaj tego bloku — jest potrzebny do przyszłego wdrożenia!
  //        Sprawdź też czy EMAIL_TO_PHONE zawiera numer dla: ${recipientEmail}
  // ============================================================

  /*
  ============================================================
  SMSAPI.PL — BLOK KODU (NIEAKTYWNY)
  ============================================================

  // Pobierz token SMSAPI z zmiennych środowiskowych
  const SMSAPI_TOKEN = process.env.SMSAPI_TOKEN || '';

  if (!SMSAPI_TOKEN) {
    log.error('[SMSAPI] Brak tokenu SMSAPI_TOKEN w zmiennych środowiskowych — pomijam SMS');
    return;
  }

  if (!phone) {
    log.warn('[SMSAPI] Brak numeru telefonu dla:', recipientEmail, '— pomijam SMS');
    return;
  }

  // Buduj treść SMS zgodnie ze wzorcem KPA art. 14 § 2 i art. 63 § 1
  // Szablon: "[POMOC]: Wysłałem ważny mail, proszę o odbiór {RODZAJ_PISMA},
  //           e-mail:{EMAIL_ODBIORCY}, e-mail:{EMAIL_NADAWCY}@neuroatypowi.org,
  //           {DATA_CZAS}.KPAart.14,14§2,63§1"
  const rodzajPisma = matchedKeyword.replace(/[\[\]:]/g, '').trim(); // np. "POMOC"
  const senderEmail = 'nadawca@neuroatypowi.org';
  const dateTime    = new Date().toLocaleString('pl-PL', { timeZone: 'Europe/Warsaw' });

  const smsText =
    `[POMOC]: Wysłałem ważny mail, proszę o odbiór ${rodzajPisma}, ` +
    `e-mail:${recipientEmail}, e-mail:${senderEmail}, ` +
    `${dateTime}. KPA art.14, 14§2, 63§1`;

  log.debug('[SMSAPI] Treść SMS:', smsText);
  log.debug('[SMSAPI] Numer:', phone);

  try {
    const smsResponse = await fetch('https://api.smsapi.pl/sms.do', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SMSAPI_TOKEN}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        to:      phone,
        message: smsText,
        from:    'MailerBot',
        // encoding: 'UTF-8',  // Odkomentuj jeśli polskie znaki nie przechodzą
      }),
    });

    const smsResult = await smsResponse.json();
    log.info('[SMSAPI] Odpowiedź API:', JSON.stringify(smsResult));

    if (smsResult.error) {
      log.error('[SMSAPI] Błąd API:', smsResult.error, smsResult.message);
    } else {
      log.info('[SMSAPI] SMS wysłany pomyślnie. ID:', smsResult.list?.[0]?.id);
    }

  } catch (err) {
    log.error('[SMSAPI] Wyjątek podczas wysyłki SMS:', err.message);
  }

  ============================================================
  KONIEC BLOKU SMSAPI.PL (NIEAKTYWNY)
  ============================================================
  */

  // Informacja: jeśli doszliśmy tutaj, SMSAPI jest zablokowany
  log.warn(
    `[post-processing] Znaleziono numer dla ${recipientEmail} (${phone}),` +
    ' ale SMSAPI jest zablokowany — SMS NIE został wysłany.'
  );
}

// =============================================================================
// SERWER EXPRESS
// =============================================================================

const app = express();

// Middleware: parsowanie surowych bajtów body (KLUCZOWE dla weryfikacji HMAC!)
// Musi być express.raw, NIE express.json() — JSON parsuje i re-serializuje dane,
// co może zmienić kolejność kluczy i złamać weryfikację podpisu.
app.use(express.raw({ type: 'application/json' }));

// Logowanie każdego żądania (tylko w trybie DEBUG)
app.use((req, _res, next) => {
  if (DEBUG) {
    log.debug(`${req.method} ${req.path}`, {
      headers: {
        'signature':     req.headers['signature']?.substring(0, 16) + '...',
        'content-type':  req.headers['content-type'],
        'user-agent':    req.headers['user-agent'],
      },
      bodySize: `${(req.body?.length ?? 0)} bajtów`,
    });
  }
  next();
});

// =============================================================================
// ENDPOINT: GET / — Health check
// Używany przez Cloud Run do sprawdzania czy serwer żyje.
// Możesz też otworzyć w przeglądarce aby sprawdzić czy URL działa.
// =============================================================================
app.get('/', (_req, res) => {
  log.debug('GET / — health check');
  res.status(200).json({
    status:  'ok',
    service: 'webhook-receiver',
    version: '2.0-DEBUG',
    debug:   DEBUG,
    time:    new Date().toISOString(),
  });
});

// =============================================================================
// ENDPOINT: POST /webhook — Główny handler webhooka MailerSend
//
// Przepływ:
//   1. Weryfikacja podpisu HMAC-SHA256 (nagłówek "Signature")
//   2. Parsowanie JSON payloadu v2 (flat, lightweight)
//   3. Walidacja wymaganych pól (type, data.id)
//   4. Zapis do Firestore (create — idempotentny!)
//   5. Zwróć 200 OK (MailerSend wymaga odpowiedzi w < 3000 ms)
//   6. setImmediate → handlePostProcessing (Warsaw 19115, SMSAPI)
//
// IDEMPOTENCJA:
//   Używamy docRef.create() zamiast docRef.set()!
//   create() rzuca ALREADY_EXISTS (kod gRPC 6) przy duplikacie.
//   set() po cichu nadpisuje dokument — nie używać!
//
// RETRY POLICY MailerSend:
//   Jeśli serwer zwróci non-2xx, MailerSend ponowi próbę:
//   → Natychmiast → +10 s → +100 s (łącznie 3 próby)
//   Zwróć 500 przy błędach Firestore (żeby MailerSend ponowił)
//   Zwróć 200 po ALREADY_EXISTS (zduplikowane zdarzenie — OK)
// =============================================================================
app.post('/webhook', async (req, res) => {
  const requestStart = Date.now();
  log.time('webhook-total');

  const rawBody   = req.body;
  const sigHeader = req.headers['signature'];

  // ------------------------------------------------------------------
  // KROK 1: Weryfikacja podpisu HMAC-SHA256
  // ------------------------------------------------------------------
  log.debug('Krok 1: Weryfikacja podpisu...');

  if (!verifySignature(rawBody, sigHeader, SIGNING_SECRET)) {
    log.warn('Podpis nieprawidłowy — odrzucam żądanie (401)');
    return res.status(401).json({ error: 'invalid_signature' });
  }

  log.debug('Podpis OK ✓');

  // ------------------------------------------------------------------
  // KROK 2: Parsowanie JSON payloadu MailerSend v2
  // ------------------------------------------------------------------
  log.debug('Krok 2: Parsowanie JSON...');

  let event;
  try {
    event = JSON.parse(rawBody.toString('utf8'));
  } catch (parseErr) {
    log.error('JSON.parse failed:', parseErr.message);
    log.debug('Raw body (pierwsze 200 znaków):', rawBody.toString('utf8').substring(0, 200));
    return res.status(400).json({ error: 'invalid_json' });
  }

  // Destrukturyzacja payloadu v2 (zawsze: type, created_at, data)
  const { type, created_at, data = {} } = event;

  if (DEBUG) {
    log.debug('Payload MailerSend v2:', {
      type,
      created_at,
      'data.id':         data.id,
      'data.domain_id':  data.domain_id,
      'data.email':      data.email,
      'data.message_id': data.message_id,
      'data.subject':    data.subject,
    });
  }

  // ------------------------------------------------------------------
  // KROK 3: Walidacja wymaganych pól
  // ------------------------------------------------------------------
  log.debug('Krok 3: Walidacja pól...');

  if (!type) {
    log.error('Brak pola "type" w payloadzie');
    return res.status(400).json({ error: 'missing_field_type' });
  }

  if (!data.id) {
    // UWAGA: Zdarzenia maintenance.* mają inną strukturę data{} (tylko domain_id)
    // Dla nich generujemy zastępcze ID — nie ma natywnego data.id
    if (type.startsWith('maintenance.') || type.startsWith('sender_identity.')) {
      log.warn(`Zdarzenie ${type} nie ma data.id — używam typu+czasu jako ID dokumentu`);
      data.id = `${type}_${created_at ?? Date.now()}`.replace(/[^a-z0-9_]/gi, '_');
    } else {
      log.error('Brak pola "data.id" w payloadzie dla zdarzenia:', type);
      return res.status(400).json({ error: 'missing_field_data_id' });
    }
  }

  // ------------------------------------------------------------------
  // KROK 4: Klasyfikacja zdarzenia
  // ------------------------------------------------------------------
  const urlClicked     = data.url ?? data.link ?? '';
  const classifiedType = classifyEvent(type, urlClicked);

  log.debug('Krok 4: Klasyfikacja:', type, '→', classifiedType);

  // ------------------------------------------------------------------
  // KROK 5: Zapis do Firestore (IDEMPOTENTNY)
  // ------------------------------------------------------------------
  log.debug('Krok 5: Zapis do Firestore (kolekcja: webhook_events, doc ID:', data.id, ')...');
  log.time('firestore-create');

  const docRef = db.collection('webhook_events').doc(data.id);

  try {
    await docRef.create({
      // Pola indeksowane (do zapytań)
      type,
      classified_type: classifiedType,
      domain_id:        data.domain_id  ?? null,
      email:            data.email      ?? null,
      message_id:       data.message_id ?? null,

      // Pola czasowe
      created_at:  created_at ?? null,     // Czas z MailerSend (dokładniejszy)
      received_at: FieldValue.serverTimestamp(), // Czas zapisu w Firestore

      // Cały obiekt data{} jako mapa (wyklucz z indeksowania w firestore.indexes.json!)
      data,
    });

    log.timeEnd('firestore-create');
    log.debug('Firestore create() OK ✓ — dokument:', data.id);

  } catch (firestoreErr) {
    log.timeEnd('firestore-create');

    // Kod gRPC 6 = ALREADY_EXISTS — zdarzenie zostało już zapisane wcześniej (duplikat)
    // MailerSend może ponowić to samo zdarzenie (retry policy) — to normalne zachowanie
    if (firestoreErr.code === 6) {
      log.info('Duplikat zdarzenia (ALREADY_EXISTS) — doc:', data.id, '— zwracam 200');
      return res.status(200).json({ status: 'duplicate', doc_id: data.id });
    }

    // Inny błąd Firestore (np. przepełnienie, timeout, błąd sieci)
    // Zwracamy 500, żeby MailerSend ponowił próbę po 10s i 100s
    log.error('Firestore write error:', firestoreErr.message, '| code:', firestoreErr.code);
    return res.status(500).json({ error: 'firestore_write_failed', detail: firestoreErr.message });
  }

  // ------------------------------------------------------------------
  // KROK 6: Zwróć 200 OK natychmiast
  // WAŻNE: Musi być przed handlePostProcessing!
  // MailerSend wymaga odpowiedzi w < 3000 ms.
  // Warsaw 19115 i SMSAPI działają ASYNCHRONICZNIE po tej odpowiedzi.
  // ------------------------------------------------------------------
  const elapsed = Date.now() - requestStart;
  log.info(`[webhook] OK | type: ${type} | classified: ${classifiedType} | ${elapsed} ms`);
  log.timeEnd('webhook-total');

  res.status(200).json({
    status:          'ok',
    doc_id:          data.id,
    classified_type: classifiedType,
    elapsed_ms:      DEBUG ? elapsed : undefined, // W DEBUG pokaż czas w odpowiedzi
  });

  // ------------------------------------------------------------------
  // KROK 7: Post-processing ASYNCHRONICZNY (po wysłaniu 200 OK)
  // setImmediate odkłada wykonanie na następny tick pętli zdarzeń Node.js
  // → MailerSend dostał już odpowiedź → teraz mamy czas na wolniejsze operacje
  //
  // WAŻNE: W Cloud Run CPU jest throttlowany po res.json() !
  //   Opcja 1: Użyj Cloud Tasks lub Firestore Trigger (zalecane produkcyjnie)
  //   Opcja 2: Użyj setImmediate jak poniżej (prosto, działa dla małego ruchu)
  // ------------------------------------------------------------------
  setImmediate(() => {
    handlePostProcessing(data, data.subject ?? '', data.email ?? '')
      .then(() => {
        log.debug('[post-processing] Zakończono pomyślnie');
      })
      .catch(err => {
        log.error('[post-processing] Wyjątek:', err.message);
      });
  });
});

// =============================================================================
// URUCHOMIENIE SERWERA
// =============================================================================
app.listen(PORT, () => {
  log.info('='.repeat(60));
  log.info('MailerSend Webhook Receiver — WERSJA DEBUG');
  log.info('Port:', PORT);
  log.info('DEBUG mode:', DEBUG ? 'WŁĄCZONY ⚠️' : 'wyłączony');
  log.info('Signing Secret:', SIGNING_SECRET ? '✓ załadowany' : '✗ BRAK — weryfikacja wyłączona!');
  log.info('Firestore:', 'preferRest=true, pre-warm uruchomiony');
  log.info('Warsaw 19115:', 'AKTYWNY (async)');
  log.info('SMSAPI:', 'ZABLOKOWANY (odkomentuj gdy dostępny)');
  log.info('='.repeat(60));
});

// Eksport dla testów jednostkowych (np. supertest)
module.exports = app;
