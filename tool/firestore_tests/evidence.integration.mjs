import assert from 'node:assert/strict';
import { mkdtemp, rm, cp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, setDoc, getDocFromServer, collection,
  onSnapshot, serverTimestamp, writeBatch, terminate } from 'firebase/firestore';
import { seedDemo, changeDemoState } from '../../services/local_evidence/src/demo_fixtures.mjs';
import { readConfig } from '../../services/local_evidence/src/config.mjs';
import { startEvidenceService } from '../../services/local_evidence/src/server.mjs';

process.env.LOCAL_EVIDENCE_EMULATORS = 'true';
process.env.LOCAL_EVIDENCE_PROJECT_ID = 'demo-campusfix';
const config = readConfig();
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8085' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') {
  throw new Error('Run this workflow through the configured local emulator command.');
}
const parent = resolve(tmpdir());
const root = await mkdtemp(join(parent, 'campusfix-integration-'));
let server;
const clients = [];
const close = async () => { if (server?.listening) await new Promise((resolve) => { server.close(resolve); server.closeIdleConnections(); }); };
try {
  const bytes = await seedDemo(join(root, 'original'));
  async function user(uid) {
    const app = initializeApp({ apiKey: 'demo-api-key', projectId: 'demo-campusfix', appId: 'demo' }, uid);
    const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
    const db = getFirestore(app); connectFirestoreEmulator(db, '127.0.0.1', 8085);
    clients.push({ app, db });
    const result = await signInWithEmailAndPassword(auth, `${uid}@campusfix.test`, 'CampusFixDemo123!');
    return { db, token: await result.user.getIdToken() };
  }
  const reporter = await user('reporter-demo');
  const technician = await user('technician-demo');
  const other = await user('other-demo');
  let storage = join(root, 'original');
  const start = async () => { server = await startEvidenceService({ ...config, port: 0, storageDirectory: storage }); };
  await start();
  const request = (actor, id, { method = 'GET', progressId, body } = {}) => fetch(
    `http://127.0.0.1:${server.address().port}/incidents/demo-assigned/evidence/${id}`,
    { method, body, headers: { Authorization: `Bearer ${actor.token}`, ...(body ? {
      'Content-Type': 'image/png', 'X-File-Name': 'fixture.png', ...(progressId ? { 'X-Progress-Id': progressId } : {}),
    } : {}) } });
  const response = await request(reporter, 'report-photo', { method: 'PUT', body: bytes });
  assert.equal(response.status, 200); const reference = await response.json();
  const fields = (({ id: _, progressId: __, ...rest }) => rest)(reference);
  await setDoc(doc(reporter.db, 'incidents/demo-assigned/evidence/report-photo'), {
    ...fields, provider: 'local', createdAt: serverTimestamp(), uploadedByUserId: 'reporter-demo', progressId: null,
  });
  assert.equal((await request(other, 'report-photo')).status, 403);
  assert.equal((await request(technician, 'report-photo')).status, 200);
  const retry = await request(reporter, 'report-photo', { method: 'PUT', body: bytes });
  assert.deepEqual(await retry.json(), reference);

  const photo = await request(technician, 'progress-photo', { method: 'PUT', body: bytes, progressId: 'progress-1' });
  assert.equal(photo.status, 200); const progressReference = await photo.json();
  const observed = new Promise((resolve, reject) => {
    const deadline = setTimeout(() => { cancel(); reject(new Error('Live progress did not arrive.')); }, 10000);
    const cancel = onSnapshot(collection(reporter.db, 'incidents/demo-assigned/progress'), (snapshot) => {
      if (snapshot.docs.some((row) => row.id === 'progress-1')) { clearTimeout(deadline); cancel(); resolve(); }
    }, (error) => { clearTimeout(deadline); reject(error); });
  });
  const batch = writeBatch(technician.db);
  batch.set(doc(technician.db, 'incidents/demo-assigned/progress/progress-1'), {
    authorUserId: 'technician-demo', description: 'Inspección completada', createdAt: serverTimestamp(),
  });
  batch.set(doc(technician.db, 'incidents/demo-assigned/history/progress-1'), {
    actorUserId: 'technician-demo',
    createdAt: serverTimestamp(), action: 'progressAdded', fromStatus: 'EN_ATENCION', toStatus: 'EN_ATENCION',
    fromTechnicianId: null, toTechnicianId: null, reason: 'Inspección completada',
  });
  batch.set(doc(technician.db, 'incidents/demo-assigned/evidence/progress-photo'), {
    ...(({ id: _, ...rest }) => rest)(progressReference), provider: 'local', uploadedByUserId: 'technician-demo', createdAt: serverTimestamp(),
  });
  await batch.commit(); await observed;
  assert.equal((await getDocFromServer(doc(reporter.db, 'incidents/demo-assigned/history/progress-1'))).data().action, 'progressAdded');
  assert.equal((await request(reporter, 'progress-photo')).status, 200);
  await changeDemoState({ status: 'RESUELTA' });
  assert.equal((await request(technician, 'blocked-photo', { method: 'PUT', body: bytes, progressId: 'p2' })).status, 403);
  await changeDemoState({ assignedTechnicianId: 'other-tech-demo' });
  assert.equal((await request(technician, 'report-photo')).status, 403);

  await close();
  const clone = join(root, 'clone'); await cp(storage, clone, { recursive: true }); storage = clone; await start();
  const cloned = await request(reporter, 'report-photo');
  assert.equal(cloned.status, 200); assert.deepEqual(Buffer.from(await cloned.arrayBuffer()), bytes);
  console.log('Verified: real Firebase sessions, protected uploads/downloads, atomic progress/history/evidence, live updates, revocation and cloned storage.');
} finally {
  await close();
  for (const { db, app } of clients) { await terminate(db); await deleteApp(app); }
  assert.equal(dirname(resolve(root)), parent); assert.ok(basename(root).startsWith('campusfix-integration-'));
  await rm(root, { recursive: true, force: true });
}
