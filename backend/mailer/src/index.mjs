import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { messageFor, recipientIds } from './message.mjs';

const POLL_MS = 60_000;
const LEASE_MS = 5 * 60_000;
const MAX_ATTEMPTS = 6;
const BATCH_SIZE = 2;

for (const name of ['FIREBASE_PROJECT_ID', 'SENDGRID_FROM_EMAIL',
  'SENDGRID_API_KEY_FILE', 'GOOGLE_APPLICATION_CREDENTIALS', 'APP_BASE_URL']) {
  if (!process.env[name]) throw new Error(`Missing configuration: ${name}`);
}
const apiKey = readFileSync(process.env.SENDGRID_API_KEY_FILE, 'utf8').trim();
if (!apiKey) throw new Error('SendGrid secret file is empty');

initializeApp({ credential: applicationDefault(), projectId: process.env.FIREBASE_PROJECT_ID });
const db = getFirestore();
let running = false;

function dueAt(doc) {
  return doc.get('nextAttemptAt')?.toMillis() ?? Number.POSITIVE_INFINITY;
}

async function dueTasks(state) {
  const result = await db.collectionGroup('emailOutbox')
    .where('deliveryState', '==', state)
    .where('nextAttemptAt', '<=', Timestamp.now())
    .orderBy('nextAttemptAt')
    .limit(BATCH_SIZE)
    .get();
  return result.docs;
}

async function claim(ref) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const task = snap.data();
    if (!['pending', 'processing'].includes(task.deliveryState) ||
        task.nextAttemptAt?.toMillis() > Date.now()) return null;
    if (task.attempts >= MAX_ATTEMPTS) {
      tx.update(ref, { deliveryState: 'failed', updatedAt: FieldValue.serverTimestamp() });
      return null;
    }
    const attempts = task.attempts + 1;
    tx.update(ref, {
      deliveryState: 'processing', attempts,
      nextAttemptAt: Timestamp.fromMillis(Date.now() + LEASE_MS),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ...task, attempts };
  });
}

async function sendMail(email, name, incidentId, incident, event) {
  const message = messageFor(incidentId, incident, event, name, process.env.APP_BASE_URL);
  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      personalizations: [{ to: [{ email }] }],
      from: { email: process.env.SENDGRID_FROM_EMAIL, name: 'CampusFix' },
      subject: message.subject,
      content: [{ type: 'text/plain', value: message.text }],
      custom_args: { incident_id: incidentId, event_id: event.id },
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (response.status !== 202) {
    const error = new Error(`sendgrid_${response.status}`);
    error.permanent = response.status >= 400 && response.status < 500 && response.status !== 429;
    throw error;
  }
}

async function processTask(ref, task) {
  const incidentId = task.incidentId;
  const eventId = task.eventId;
  if (typeof incidentId !== 'string' || typeof eventId !== 'string' ||
      ref.parent.parent?.id !== incidentId || ref.id !== eventId) {
    throw new Error('invalid_task_reference');
  }
  const incidentRef = db.collection('incidents').doc(incidentId);
  const [incidentSnap, eventSnap] = await Promise.all([
    incidentRef.get(), incidentRef.collection('history').doc(eventId).get(),
  ]);
  if (!incidentSnap.exists || !eventSnap.exists) throw new Error('missing_incident_or_event');
  const incident = incidentSnap.data();
  const event = { ...eventSnap.data(), id: eventId };
  if (event.fromStatus === event.toStatus) {
    await ref.update({ deliveryState: 'skipped', updatedAt: FieldValue.serverTimestamp() });
    return;
  }

  let ids = task.recipientIds;
  if (!Array.isArray(ids)) {
    const admins = await db.collection('users')
      .where('role', 'in', ['administrator', 'superAdministrator']).get();
    ids = recipientIds(incident, event, admins.docs.map((doc) => doc.id));
    await ref.update({ recipientIds: ids, updatedAt: FieldValue.serverTimestamp() });
  }
  const completed = new Set(task.completedRecipientIds ?? []);
  for (const uid of ids) {
    if (completed.has(uid)) continue;
    const profile = await db.collection('users').doc(uid).get();
    const email = profile.data()?.email;
    if (typeof email !== 'string' || !email.includes('@')) {
      throw new Error('recipient_email_unavailable');
    }
    await sendMail(email, profile.data()?.fullName, incidentId, incident, event);
    await ref.update({
      completedRecipientIds: FieldValue.arrayUnion(uid),
      updatedAt: FieldValue.serverTimestamp(),
    });
    completed.add(uid);
  }
  await ref.update({
    deliveryState: 'sent', sentAt: FieldValue.serverTimestamp(),
    lastError: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(),
  });
}

function safeError(error) {
  if (error?.code === 9 && /index/i.test(String(error.message))) {
    return 'missing_firestore_index';
  }
  if (error?.code === 7) return 'firestore_permission_denied';
  const message = String(error?.message ?? error);
  return /^(sendgrid_\d{3}|invalid_task_reference|missing_incident_or_event|recipient_email_unavailable)$/.test(message)
    ? message : 'temporary_delivery_error';
}

async function recordFailure(ref, task, error) {
  const terminal = error.permanent || task.attempts >= MAX_ATTEMPTS;
  const delay = Math.min(60 * 60_000, 30_000 * 2 ** Math.max(0, task.attempts - 1));
  await ref.update({
    deliveryState: terminal ? 'failed' : 'pending',
    nextAttemptAt: Timestamp.fromMillis(Date.now() + delay),
    lastError: safeError(error), updatedAt: FieldValue.serverTimestamp(),
  });
}

async function poll() {
  if (running) return;
  running = true;
  try {
    const due = [...await dueTasks('pending'), ...await dueTasks('processing')]
      .sort((a, b) => dueAt(a) - dueAt(b)).slice(0, BATCH_SIZE);
    for (const doc of due) {
      let task;
      try {
        task = await claim(doc.ref);
        if (task) await processTask(doc.ref, task);
      } catch (error) {
        console.error('Mail task failed', doc.ref.path, safeError(error));
        if (task) {
          try { await recordFailure(doc.ref, task, error); }
          catch (writeError) { console.error('Could not record mail failure', safeError(writeError)); }
        }
      }
    }
  } catch (error) {
    console.error('Mail queue unavailable', safeError(error));
  } finally {
    running = false;
  }
}

const server = createServer((request, response) => {
  response.writeHead(request.url === '/health' ? 200 : 404,
    { 'content-type': 'application/json' });
  response.end(JSON.stringify({ service: 'campusfix-mailer' }));
});
server.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
const timer = setInterval(() => { void poll(); }, POLL_MS);
void poll();
process.on('SIGTERM', () => { clearInterval(timer); server.close(); });
