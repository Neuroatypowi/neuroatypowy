'use strict';

const express = require('express');
const crypto  = require('node:crypto');
const { Firestore, FieldValue } = require('@google-cloud/firestore');

const PORT           = process.env.PORT || 8080;
const SIGNING_SECRET = process.env.MAILERSEND_SIGNING_SECRET || '';

const EMAIL_TO_PHONE = {
  'k.wiejowska@um.warszawa.pl':          '+48725851525',
  'boi@warszawapraga-pln.sr.gov.pl':     '+48607237064',
  'csk@strazmiejska.waw.pl':             '+48723986112',
};
const WARSAW_FALLBACK_EMAIL = 'kontakt@um.warszawa.pl';

const SUBJECT_PREFIXES = ['[POMOC]:', '[SYGNAL]:', '[WNIOSEK]:', '[SKARGA]:'];

const ATTACHMENT_PATTERNS = [
  'drive.google.com', 'docs.google.com', '1drv.ms',
  '.pdf', '.zip', '.docx', '.xlsx', '.pptx',
];

const CLASSIFIED_EVENTS = {
  'activity.opened':          'reopened',
  'activity.opened_unique':   'first_open',
  'activity.clicked':         'again_clicked',
  'activity.clicked_unique':  'first_click',
  'activity.sent':            'sent',
  'activity.delivered':       'delivered',
  'activity.soft_bounced':    'soft_bounce',
  'activity.hard_bounced':    'hard_bounce',
  'activity.deferred':        'deferred',
  'activity.unsubscribed':    'unsubscribed',
  'activity.spam_complaint':  'spam_complaint',
  'activity.survey_opened':   'survey_opened',
  'activity.survey_submitted':'survey_submitted',
};

const db = new Firestore({ preferRest: true });
db.collection('_warmup').doc('ping').get().catch(() => {});

function verifySignature(rawBody, sigHeader, secret) {
  if (!sigHeader || !secret) return false;
  const computed    = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  const computedBuf = Buffer.from(computed, 'hex');
  const receivedBuf = Buffer.from(sigHeader, 'hex');
  if (computedBuf.length !== receivedBuf.length) return false;
  return crypto.timingSafeEqual(computedBuf, receivedBuf);
}

function matchSubjectKeyword(subject) {
  if (!subject) return null;
  for (const prefix of SUBJECT_PREFIXES) {
    if (subject.startsWith(prefix)) return prefix;
  }
  return null;
}

function classifyEvent(eventType, urlClicked) {
  if (urlClicked) {
    const url = urlClicked.toLowerCase();
    if (ATTACHMENT_PATTERNS.some(p => url.includes(p))) return 'attachment_download';
  }
  return CLASSIFIED_EVENTS[eventType] ?? eventType;
}

async function handlePostProcessing(data, subject, recipientEmail) {
  const matchedKeyword = matchSubjectKeyword(subject);
  if (!matchedKeyword) return;

  const phone = EMAIL_TO_PHONE[recipientEmail];

  if (!phone && recipientEmail === WARSAW_FALLBACK_EMAIL) {
    try {
      await fetch('https://api.um.warszawa.pl/api/action/19115', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subject,
          email:      recipientEmail,
          message_id: data.message_id ?? null,
          keyword:    matchedKeyword,
          timestamp:  new Date().toISOString(),
        }),
      });
    } catch (err) {
      console.error('[19115] API call failed:', err.message);
    }
    return;
  }

  /*
  ============================================================
  SMSAPI.PL — MODUL CAŁKOWICIE ZABLOKOWANY
  Powód: usługa tymczasowo niedostępna (stan na 2026-03-01).
  Odkomentuj gdy SMSAPI_TOKEN będzie dostępny i usługa wznowi
  działanie. Nie usuwaj tego bloku — zachowaj do przyszłego
  wdrożenia.
  ============================================================

  const SMSAPI_TOKEN = process.env.SMSAPI_TOKEN || '';
  if (!SMSAPI_TOKEN) {
    console.error('[SMSAPI] Brak tokenu SMSAPI_TOKEN — pomiń.');
    return;
  }

  const rodzajPisma = matchedKeyword.replace(/[\[\]:]/g, '').trim();
  const senderEmail = 'nadawca@neuroatypowi.org';
  const dateTime    = new Date().toISOString();
  const smsText     =
    `[POMOC]: Wysłałem ważny mail, proszę o odbiór ${rodzajPisma}, ` +
    `e-mail:${recipientEmail}, e-mail:${senderEmail}, ` +
    `${dateTime}. KPA art.14, 14§2, 63§1`;

  try {
    const response = await fetch('https://api.smsapi.pl/sms.do', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SMSAPI_TOKEN}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        to:      phone,
        message: smsText,
        from:    'MailerBot',
      }),
    });
    const result = await response.json();
    console.log('[SMSAPI] SMS sent:', JSON.stringify(result));
  } catch (err) {
    console.error('[SMSAPI] Send error:', err.message);
  }

  ============================================================
  KONIEC BLOKU SMSAPI
  ============================================================
  */
}

const app = express();
app.use(express.raw({ type: 'application/json' }));

app.get('/', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'webhook-receiver', version: '1.0.0' });
});

app.post('/webhook', async (req, res) => {
  const rawBody   = req.body;
  const sigHeader = req.headers['signature'];

  if (!verifySignature(rawBody, sigHeader, SIGNING_SECRET)) {
    return res.status(401).json({ error: 'invalid_signature' });
  }

  let event;
  try {
    event = JSON.parse(rawBody.toString('utf8'));
  } catch {
    return res.status(400).json({ error: 'invalid_json' });
  }

  const { type, created_at, data = {} } = event;

  if (!type || !data.id) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }

  const urlClicked      = data.url ?? data.link ?? '';
  const classifiedType  = classifyEvent(type, urlClicked);
  const docRef          = db.collection('webhook_events').doc(data.id);

  try {
    await docRef.create({
      type,
      classified_type: classifiedType,
      created_at:      created_at ?? null,
      received_at:     FieldValue.serverTimestamp(),
      data,
      domain_id:       data.domain_id  ?? null,
      email:           data.email      ?? null,
      message_id:      data.message_id ?? null,
    });
  } catch (err) {
    if (err.code === 6) {
      return res.status(200).json({ status: 'duplicate' });
    }
    console.error('[Firestore] Write error:', err.message);
    return res.status(500).json({ error: 'firestore_write_failed' });
  }

  res.status(200).json({ status: 'ok' });

  setImmediate(() => {
    handlePostProcessing(data, data.subject ?? '', data.email ?? '').catch(err => {
      console.error('[post-processing] Error:', err.message);
    });
  });
});

app.listen(PORT, () => {
  console.log(`[server] Webhook receiver started on port ${PORT}`);
});

module.exports = app;
