import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, writeBatch, serverTimestamp, Timestamp, setLogLevel, deleteDoc } from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8085') throw new Error('Local Firestore emulator required.');
setLogLevel('silent');
let environment;
const database = (uid) => environment.authenticatedContext(uid, { email: `${uid}@test.invalid` }).firestore();
before(async () => {
  environment = await initializeTestEnvironment({ projectId: 'demo-campusfix', firestore: {
    host: '127.0.0.1', port: 8085, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  } });
});
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([ ...[['owner', 'reporter'], ['other', 'reporter'], ['tech', 'technician'], ['other-tech', 'technician'], ['admin', 'administrator']]
      .map(([uid, role]) => setDoc(doc(db, 'users', uid), { fullName: uid, email: `${uid}@test.invalid`, role })),
      setDoc(doc(db, 'incidents/case'), { createdByUserId: 'owner', assignedTechnicianId: 'tech', status: 'EN_ATENCION',
        title: 'Case', description: 'Broken light', categoryId: 'lighting', location: 'A', sequenceNumber: 1,
        priority: null, resolutionDescription: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now() }),
    ]);
  });
});
after(async () => { await environment.clearFirestore(); await environment.cleanup(); });

const progress = (uid = 'tech', description = 'Inspection complete') => ({ authorUserId: uid, createdAt: serverTimestamp(), description });
const history = (uid = 'tech', reason = 'Inspection complete') => ({ actorUserId: uid, createdAt: serverTimestamp(), action: 'progressAdded',
  fromStatus: 'EN_ATENCION', toStatus: 'EN_ATENCION', fromTechnicianId: null, toTechnicianId: null, reason });
const evidence = (uid, id = 'photo', progressId = null) => ({ uploadedByUserId: uid, createdAt: serverTimestamp(), provider: 'local',
  assetId: `case/${id}`, url: `/incidents/case/evidence/${id}`, fileName: 'photo.png', contentType: 'image/png', sizeBytes: 3000000, progressId });
function batchFor(uid, { photo = false, changeProgress = {}, changeHistory = {} } = {}) {
  const db = database(uid); const batch = writeBatch(db);
  batch.set(doc(db, 'incidents/case/progress/p1'), { ...progress(uid), ...changeProgress });
  batch.set(doc(db, 'incidents/case/history/p1'), { ...history(uid), ...changeHistory });
  if (photo) batch.set(doc(db, 'incidents/case/evidence/photo'), evidence(uid, 'photo', 'p1'));
  return batch;
}

test('Assigned technician commits progress, history and optional evidence atomically', async () => {
  await assertSucceeds(batchFor('tech', { photo: true }).commit());
  for (const path of ['progress/p1', 'history/p1', 'evidence/photo']) {
    assert.equal((await getDoc(doc(database('owner'), `incidents/case/${path}`))).exists(), true);
  }
});
test('Reporters, administrators and unassigned technicians cannot add progress', async () => {
  for (const uid of ['owner', 'other', 'admin', 'other-tech']) await assertFails(batchFor(uid).commit());
});
test('Attention state is required even for the assigned technician', async () => {
  for (const status of ['REPORTADA', 'ASIGNADA', 'RESUELTA', 'CERRADA']) {
    await environment.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'incidents/case'), { status }, { merge: true }));
    await assertFails(batchFor('tech').commit());
  }
});
test('Standalone progress and history writes are rejected', async () => {
  await assertFails(setDoc(doc(database('tech'), 'incidents/case/progress/p1'), progress()));
  await assertFails(setDoc(doc(database('tech'), 'incidents/case/history/p1'), history()));
});
test('Forged authors, blank descriptions, mismatched history and extra fields are rejected', async () => {
  for (const change of [ { changeProgress: { authorUserId: 'other-tech' } }, { changeProgress: { description: '  ' } },
    { changeHistory: { reason: 'Different' } }, { changeHistory: { action: 'resolved' } },
    { changeProgress: { arbitrary: true } }, { changeHistory: { createdAt: Timestamp.fromMillis(1) } } ]) {
    await assertFails(batchFor('tech', change).commit());
  }
});
test('Only the reporter owner attaches initial photographs with validated paths and sizes', async () => {
  await assertSucceeds(setDoc(doc(database('owner'), 'incidents/case/evidence/photo'), evidence('owner')));
  for (const uid of ['other', 'tech', 'admin']) {
    await assertFails(setDoc(doc(database(uid), `incidents/case/evidence/${uid}`), evidence(uid, uid)));
  }
  for (const change of [ { sizeBytes: 3000001 }, { sizeBytes: 0 }, { contentType: 'image/svg+xml' },
    { url: 'https://external.invalid/photo' }, { assetId: 'foreign/photo' }, { uploadedByUserId: 'other' } ]) {
    await assertFails(setDoc(doc(database('owner'), 'incidents/case/evidence/invalid'), { ...evidence('owner', 'invalid'), ...change }));
  }
});
test('Technician evidence requires a newly created atomic progress entry', async () => {
  await assertFails(setDoc(doc(database('tech'), 'incidents/case/evidence/photo'), evidence('tech', 'photo', 'p1')));
  await assertSucceeds(batchFor('tech').commit());
  await assertFails(setDoc(doc(database('tech'), 'incidents/case/evidence/photo'), evidence('tech', 'photo', 'p1')));
});
test('Progress, history and evidence remain immutable and foreign reads are denied', async () => {
  await assertSucceeds(batchFor('tech', { photo: true }).commit());
  for (const path of ['progress/p1', 'history/p1', 'evidence/photo']) {
    const target = doc(database('tech'), `incidents/case/${path}`);
    await assertFails(setDoc(target, { arbitrary: true }, { merge: true }));
    await assertFails(deleteDoc(target));
    await assertFails(getDoc(doc(database('other'), `incidents/case/${path}`)));
    await assertSucceeds(getDoc(doc(database('admin'), `incidents/case/${path}`)));
  }
});
