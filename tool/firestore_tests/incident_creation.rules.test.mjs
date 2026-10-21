import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocFromServer,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const configuration = JSON.parse(
  readFileSync(new URL('../../firebase.json', import.meta.url), 'utf8'),
);
const { host, port } = configuration.emulators.firestore;
if (host !== '127.0.0.1' || process.env.FIRESTORE_EMULATOR_HOST !== `${host}:${port}`) {
  throw new Error('Run these tests with npm test and the configured local emulator.');
}

setLogLevel('silent');
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-campusfix',
    firestore: {
      host,
      port,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await Promise.all([
      ...[
        ['reporter-1', 'reporter'], ['reporter-2', 'reporter'],
        ['technician-1', 'technician'], ['administrator-1', 'administrator'],
      ].map(([userId, role]) => setDoc(doc(database, 'users', userId), {
        fullName: userId, email: `${userId}@campusfix.test`, role,
      })),
      setDoc(doc(database, 'categories/lighting'), { name: 'Lighting', isActive: true }),
    ]);
  });
});

after(async () => {
  if (environment) {
    await environment.clearFirestore();
    await environment.cleanup();
  }
});

/** Returns a caller-bound database without administrative credentials. */
function databaseFor(userId = 'reporter-1', claims = {}) {
  return environment.authenticatedContext(userId, {
    email: `${userId}@campusfix.test`, ...claims,
  }).firestore();
}

/** Builds raw request records so tests can tamper with each invariant directly. */
function creation(database, { id = 'report-1', sequence = 1, userId = 'reporter-1' } = {}) {
  return {
    id,
    incidentRef: doc(database, 'incidents', id),
    counterRef: doc(database, 'counters/incidents'),
    eventRef: doc(database, 'incidents', id, 'history/created'),
    incident: {
      sequenceNumber: sequence,
      title: 'Lámpara averiada',
      description: 'First line.\nSecond line.',
      categoryId: 'lighting',
      location: 'Building A',
      priority: null,
      status: 'REPORTADA',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdByUserId: userId,
      assignedTechnicianId: null,
      resolutionDescription: null,
    },
    counter: { lastSequenceNumber: sequence, lastIncidentId: id },
    event: {
      actorUserId: userId,
      createdAt: serverTimestamp(),
      action: 'created',
      fromStatus: null,
      toStatus: 'REPORTADA',
      fromTechnicianId: null,
      toTechnicianId: null,
      reason: null,
    },
  };
}

/** Stages all three records, or an intentionally incomplete attack request. */
function stage(writer, bundle, parts = ['incident', 'counter', 'event']) {
  for (const part of parts) writer.set(bundle[`${part}Ref`], bundle[part]);
}

async function commit(database, bundle = creation(database), parts) {
  const batch = writeBatch(database);
  stage(batch, bundle, parts);
  await batch.commit();
}

/** Inspects stored records independently of client read permissions. */
async function inspect(callback) {
  return environment.withSecurityRulesDisabled((context) => callback(context.firestore()));
}

async function assertNoCreation(id = 'report-1') {
  await inspect(async (database) => {
    for (const path of [`incidents/${id}`, `incidents/${id}/history/created`, 'counters/incidents']) {
      assert.equal((await getDoc(doc(database, path))).exists(), false, path);
    }
  });
}

/** Exercises the allowed read/write order using real client transactions. */
async function createInTransaction(database, id, userId = 'reporter-1') {
  const incidentRef = doc(database, 'incidents', id);
  const counterRef = doc(database, 'counters/incidents');
  for (let attempt = 0; attempt < 3; attempt++) {
    let attemptedSequence;
    try {
      return await runTransaction(database, async (transaction) => {
        attemptedSequence = undefined;
        const existing = await transaction.get(incidentRef);
        if (existing.exists()) return existing.data().sequenceNumber;
        await transaction.get(doc(database, 'users', userId));
        await transaction.get(doc(database, 'categories/lighting'));
        const counter = await transaction.get(counterRef);
        const sequence = counter.exists() ? counter.data().lastSequenceNumber + 1 : 1;
        attemptedSequence = sequence;
        stage(transaction, creation(database, { id, sequence, userId }));
        return sequence;
      });
    } catch (error) {
      if (attempt === 2 || attemptedSequence === undefined ||
          !['permission-denied', 'aborted'].includes(error.code)) throw error;
      let advanced = false;
      try {
        const fresh = await getDocFromServer(counterRef);
        advanced = !fresh.metadata.hasPendingWrites && !fresh.metadata.fromCache &&
          fresh.data()?.lastSequenceNumber >= attemptedSequence;
      } catch { /* Preserve the original failure when contention is unproven. */ }
      if (!advanced) throw error;
    }
  }
}

/** Waits for both callers before a failed concurrency test can clear fixtures. */
async function concurrentResults(promises) {
  const outcomes = await Promise.allSettled(promises);
  const failures = outcomes.filter((result) => result.status === 'rejected');
  if (failures.length) throw new AggregateError(failures.map((result) => result.reason));
  return outcomes.map((result) => result.value);
}

test('A complete report counter and initial history commit atomically', async () => {
  const database = databaseFor();
  await assertSucceeds(commit(database));
  const confirmed = await assertSucceeds(getDocFromServer(doc(database, 'incidents/report-1')));
  assert.equal(confirmed.metadata.hasPendingWrites, false);
  assert.equal(confirmed.metadata.fromCache, false);
  assert.equal(confirmed.data().createdByUserId, 'reporter-1');
  assert.equal(confirmed.data().status, 'REPORTADA');
  assert.equal(confirmed.data().description, 'First line.\nSecond line.');
  assert(confirmed.data().createdAt instanceof Timestamp);
  assert(confirmed.data().createdAt.isEqual(confirmed.data().updatedAt));
  await inspect(async (admin) => {
    const counter = (await getDoc(doc(admin, 'counters/incidents'))).data();
    const history = (await getDocs(collection(admin, 'incidents/report-1/history'))).docs;
    assert.deepEqual(counter, { lastSequenceNumber: 1, lastIncidentId: 'report-1' });
    assert.equal(history.length, 1);
    assert.equal(history[0].id, 'created');
    assert.equal(history[0].data().actorUserId, 'reporter-1');
    assert(history[0].data().createdAt.isEqual(confirmed.data().createdAt));
  });
});

test('Creation transaction reads and matching retries are permitted without another increment', async () => {
  const database = databaseFor();
  assert.equal(await assertSucceeds(createInTransaction(database, 'report-1')), 1);
  const saved = (await getDocFromServer(doc(database, 'incidents/report-1'))).data();
  assert.equal(await assertSucceeds(createInTransaction(database, 'report-1')), 1);
  const recovered = (await getDocFromServer(doc(database, 'incidents/report-1'))).data();
  assert(saved.createdAt.isEqual(recovered.createdAt));
  assert(saved.updatedAt.isEqual(recovered.updatedAt));
  await inspect(async (admin) => {
    assert.equal((await getDoc(doc(admin, 'counters/incidents'))).data().lastSequenceNumber, 1);
    assert.equal((await getDocs(collection(admin, 'incidents/report-1/history'))).size, 1);
  });
});

test('Concurrent reporters obtain different sequences and one initial event each', async () => {
  const results = await concurrentResults([
    createInTransaction(databaseFor(), 'report-1'),
    createInTransaction(databaseFor('reporter-2'), 'report-2', 'reporter-2'),
  ]);
  assert.deepEqual(results.sort(), [1, 2]);
  await inspect(async (admin) => {
    assert.equal((await getDoc(doc(admin, 'counters/incidents'))).data().lastSequenceNumber, 2);
    for (const id of ['report-1', 'report-2']) {
      const events = await getDocs(collection(admin, `incidents/${id}/history`));
      assert.equal(events.size, 1);
      assert.equal(events.docs[0].id, 'created');
    }
  });
});

test('Concurrent retries of one ID cannot duplicate its counter or initial event', async () => {
  const results = await concurrentResults([
    createInTransaction(databaseFor(), 'report-1'),
    createInTransaction(databaseFor(), 'report-1'),
  ]);
  assert.deepEqual(results, [1, 1]);
  await inspect(async (admin) => {
    assert.equal((await getDoc(doc(admin, 'counters/incidents'))).data().lastSequenceNumber, 1);
    assert.equal((await getDocs(collection(admin, 'incidents'))).size, 1);
    assert.equal((await getDocs(collection(admin, 'incidents/report-1/history'))).size, 1);
  });
});

test('Authentication and the stored reporter role are mandatory for every creation', async () => {
  for (const database of [
    environment.unauthenticatedContext().firestore(),
    databaseFor('technician-1', { role: 'reporter' }),
    databaseFor('administrator-1'),
    databaseFor('missing-profile'),
  ]) await assertFails(commit(database));
  await assertNoCreation();
});

test('Forging another author or history actor rejects the entire operation', async () => {
  const database = databaseFor();
  for (const part of ['incident', 'event']) {
    const bundle = creation(database);
    bundle[part][part === 'incident' ? 'createdByUserId' : 'actorUserId'] = 'reporter-2';
    await assertFails(commit(database, bundle));
  }
  await assertNoCreation();
});

test('Only an existing active category with a valid name permits creation', async () => {
  const database = databaseFor();
  for (const category of [
    { name: 'Lighting', isActive: false }, { name: 'Lighting', isActive: 'true' },
    { isActive: true }, { name: 1, isActive: true }, { name: ' \n\t ', isActive: true },
  ]) {
    await inspect((admin) => setDoc(doc(admin, 'categories/lighting'), category));
    await assertFails(commit(database));
  }
  await inspect((admin) => deleteDoc(doc(admin, 'categories/lighting')));
  await assertFails(commit(database));
  await assertNoCreation();
});

test('Missing required report fields and extra fields are rejected', async () => {
  const database = databaseFor();
  for (const field of Object.keys(creation(database).incident)) {
    const bundle = creation(database);
    delete bundle.incident[field];
    await assertFails(commit(database, bundle));
  }
  const bundle = creation(database);
  bundle.incident.role = 'administrator';
  await assertFails(commit(database, bundle));
  await assertNoCreation();
});

test('Blank text invalid IDs and incorrect field types are rejected', async () => {
  const database = databaseFor();
  for (const field of ['title', 'description', 'location']) {
    for (const value of ['', ' \t\n ', null, 7, true]) {
      const bundle = creation(database);
      bundle.incident[field] = value;
      await assertFails(commit(database, bundle));
    }
  }
  for (const value of ['', ' ', ' lighting', 'a/b', '.', '..', '__reserved__', null, 1]) {
    const bundle = creation(database);
    bundle.incident.categoryId = value;
    await assertFails(commit(database, bundle));
  }
  await assertNoCreation();
});

test('A new report cannot select its priority technician resolution or advanced state', async () => {
  const database = databaseFor();
  for (const [field, value] of [
    ['status', 'EN_ATENCION'], ['status', 'reported'], ['priority', 'ALTA'],
    ['assignedTechnicianId', 'technician-1'], ['resolutionDescription', 'Resolved'],
  ]) {
    const bundle = creation(database);
    bundle.incident[field] = value;
    await assertFails(commit(database, bundle));
  }
  await assertNoCreation();
});

test('Incident dates must equal the server request time', async () => {
  const database = databaseFor();
  for (const field of ['createdAt', 'updatedAt']) {
    for (const value of [Timestamp.fromMillis(1), null, '2026-10-21', 1]) {
      const bundle = creation(database);
      bundle.incident[field] = value;
      await assertFails(commit(database, bundle));
    }
  }
  await assertNoCreation();
});

test('Every incomplete combination of the three writes is rejected atomically', async () => {
  const database = databaseFor();
  for (const parts of [
    ['incident'], ['counter'], ['event'], ['incident', 'counter'],
    ['incident', 'event'], ['counter', 'event'],
  ]) {
    await assertFails(commit(database, creation(database), parts));
    await assertNoCreation();
  }
});

test('Initial history requires the complete immutable event schema', async () => {
  const database = databaseFor();
  for (const field of Object.keys(creation(database).event)) {
    const bundle = creation(database);
    delete bundle.event[field];
    await assertFails(commit(database, bundle));
  }
  for (const [field, value] of [
    ['action', 'progressAdded'], ['createdAt', Timestamp.fromMillis(1)],
    ['fromStatus', 'REPORTADA'], ['toStatus', 'ASIGNADA'],
    ['fromTechnicianId', 'technician-1'], ['toTechnicianId', 'technician-1'],
    ['reason', 'Injected reason'], ['extra', true],
  ]) {
    const bundle = creation(database);
    bundle.event[field] = value;
    await assertFails(commit(database, bundle));
  }
  await assertNoCreation();
});

test('The initial event uses the reserved created ID and cannot be duplicated', async () => {
  const database = databaseFor();
  const bundle = creation(database);
  bundle.eventRef = doc(database, 'incidents/report-1/history/other');
  await assertFails(commit(database, bundle));
  const batch = writeBatch(database);
  stage(batch, creation(database));
  batch.set(doc(database, 'incidents/report-1/history/extra'), creation(database).event);
  await assertFails(batch.commit());
  await assertNoCreation();
});

test('Counter schema and first sequence are validated independently', async () => {
  const database = databaseFor();
  for (const sequence of [0, -1, 1.5, '1', 2, 9007199254740992]) {
    await assertFails(commit(database, creation(database, { sequence })));
  }
  for (const field of ['lastSequenceNumber', 'lastIncidentId']) {
    const bundle = creation(database);
    delete bundle.counter[field];
    await assertFails(commit(database, bundle));
  }
  const bundle = creation(database);
  bundle.counter.extra = true;
  await assertFails(commit(database, bundle));
  await assertNoCreation();
});

test('Counter references must match the report ID and sequence exactly', async () => {
  const database = databaseFor();
  for (const value of ['another-report', 'a/b', ' report-1', '__reserved__', '', null, 1]) {
    const bundle = creation(database);
    bundle.counter.lastIncidentId = value;
    await assertFails(commit(database, bundle));
  }
  const bundle = creation(database);
  bundle.incident.sequenceNumber = 2;
  await assertFails(commit(database, bundle));
  await assertNoCreation();
});

test('An existing valid counter advances by exactly one', async () => {
  await inspect((admin) => setDoc(doc(admin, 'counters/incidents'), {
    lastSequenceNumber: 7, lastIncidentId: 'previous',
  }));
  const database = databaseFor();
  for (const sequence of [0, 1, 6, 7, 9]) {
    await assertFails(commit(database, creation(database, { sequence })));
  }
  await assertSucceeds(commit(database, creation(database, { sequence: 8 })));
  assert.equal((await getDocFromServer(doc(database, 'incidents/report-1'))).data().sequenceNumber, 8);
});

test('Malformed existing counters cannot be repaired by resetting the sequence', async () => {
  const database = databaseFor();
  for (const counter of [
    {}, { lastSequenceNumber: 0, lastIncidentId: 'previous' },
    { lastSequenceNumber: '1', lastIncidentId: 'previous' },
    { lastSequenceNumber: 1.5, lastIncidentId: 'previous' },
    { lastSequenceNumber: 1 }, { lastSequenceNumber: 1, lastIncidentId: ' ' },
    { lastSequenceNumber: 1, lastIncidentId: 'previous', extra: true },
  ]) {
    await inspect((admin) => setDoc(doc(admin, 'counters/incidents'), counter));
    await assertFails(commit(database, creation(database, { sequence: 2 })));
    await inspect(async (admin) => {
      assert.deepEqual((await getDoc(doc(admin, 'counters/incidents'))).data(), counter);
      assert.equal((await getDoc(doc(admin, 'incidents/report-1'))).exists(), false);
    });
  }
});

test('The maximum exactly representable web sequence is accepted without overflow', async () => {
  const database = databaseFor();
  await inspect((admin) => setDoc(doc(admin, 'counters/incidents'), {
    lastSequenceNumber: 9007199254740990, lastIncidentId: 'previous',
  }));
  await assertSucceeds(commit(database, creation(database, { sequence: 9007199254740991 })));
  await assertFails(commit(database, creation(database, { id: 'overflow', sequence: 9007199254740992 })));
});

test('An unchanged counter cannot authorize a report using an already recorded number', async () => {
  await inspect((admin) => setDoc(doc(admin, 'counters/incidents'), {
    lastSequenceNumber: 1, lastIncidentId: 'report-1',
  }));
  const database = databaseFor();
  await assertFails(commit(database, creation(database), ['incident', 'event']));
});

test('A counter cannot advance by referencing an existing incident', async () => {
  const database = databaseFor();
  await commit(database);
  await assertFails(setDoc(doc(database, 'counters/incidents'), {
    lastSequenceNumber: 2, lastIncidentId: 'report-1',
  }));
  await assertFails(deleteDoc(doc(database, 'counters/incidents')));
});

test('Two new reports cannot share one counter increment or sequence', async () => {
  const database = databaseFor();
  const first = creation(database);
  const second = creation(database, { id: 'report-2' });
  const batch = writeBatch(database);
  stage(batch, first);
  stage(batch, second, ['incident', 'event']);
  await assertFails(batch.commit());
  await assertNoCreation();
  await inspect(async (admin) => {
    assert.equal((await getDoc(doc(admin, 'incidents/report-2'))).exists(), false);
  });
});

test('History cannot be appended later to an existing report or left under a missing parent', async () => {
  const database = databaseFor();
  await commit(database);
  await inspect((admin) => deleteDoc(doc(admin, 'incidents/report-1/history/created')));
  await assertFails(setDoc(doc(database, 'incidents/report-1/history/created'), creation(database).event));
  await assertFails(setDoc(doc(database, 'incidents/missing/history/created'), creation(database).event));
});

test('An orphan initial event cannot be overwritten while creating its parent', async () => {
  await inspect((admin) => setDoc(doc(admin, 'incidents/report-1/history/created'), {
    actorUserId: 'reporter-2', action: 'created',
  }));
  const database = databaseFor();
  await assertFails(commit(database));
});

test('Created reports and history cannot be edited deleted or replaced by any role', async () => {
  await commit(databaseFor());
  for (const userId of ['reporter-1', 'reporter-2', 'technician-1', 'administrator-1']) {
    const database = databaseFor(userId);
    await assertFails(updateDoc(doc(database, 'incidents/report-1'), { title: 'Rewritten' }));
    await assertFails(deleteDoc(doc(database, 'incidents/report-1')));
    await assertFails(updateDoc(doc(database, 'incidents/report-1/history/created'), { action: 'closed' }));
    await assertFails(deleteDoc(doc(database, 'incidents/report-1/history/created')));
  }
});

test('Creation reads allow the owner while denying unrelated direct reads and queries', async () => {
  const database = databaseFor();
  await assertSucceeds(getDoc(doc(database, 'incidents/missing')));
  await commit(database);
  await assertSucceeds(getDocFromServer(doc(database, 'incidents/report-1')));
  for (const other of [
    databaseFor('reporter-2'), databaseFor('technician-1'),
    environment.unauthenticatedContext().firestore(),
  ]) await assertFails(getDoc(doc(other, 'incidents/report-1')));
  await assertSucceeds(getDoc(doc(databaseFor('administrator-1'), 'incidents/report-1')));
  await assertFails(getDocs(collection(database, 'incidents')));
  await assertSucceeds(getDocs(query(collection(database, 'incidents'), where('createdByUserId', '==', 'reporter-1'))));
  await assertFails(getDocs(query(collection(database, 'incidents'), where('createdByUserId', '==', 'reporter-2'))));
  await assertSucceeds(getDoc(doc(database, 'incidents/report-1/history/created')));
});

test('Only reporters may read the creation counter and alternate counters stay denied', async () => {
  for (const database of [
    databaseFor('technician-1'), databaseFor('administrator-1'),
    environment.unauthenticatedContext().firestore(),
  ]) await assertFails(getDoc(doc(database, 'counters/incidents')));
  const database = databaseFor();
  await assertSucceeds(getDoc(doc(database, 'counters/incidents')));
  await assertFails(getDocs(collection(database, 'counters')));
  await assertFails(setDoc(doc(database, 'counters/other'), { lastSequenceNumber: 1 }));
});

test('A report cannot be combined with unauthorized profile role escalation', async () => {
  const database = databaseFor();
  const batch = writeBatch(database);
  stage(batch, creation(database));
  batch.update(doc(database, 'users/reporter-1'), { role: 'administrator' });
  await assertFails(batch.commit());
  await assertNoCreation();
});

test('Creation does not grant writes to progress evidence or unrelated collections', async () => {
  const database = databaseFor();
  for (const path of [
    'incidents/report-1/progress/entry', 'incidents/report-1/evidence/photo', 'unrelated/record',
  ]) {
    const batch = writeBatch(database);
    stage(batch, creation(database));
    batch.set(doc(database, path), { injected: true });
    await assertFails(batch.commit());
  }
  await assertNoCreation();
});
