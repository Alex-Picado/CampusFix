import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDocFromServer, getDocs, onSnapshot, orderBy,
  query, setDoc, setLogLevel, Timestamp, updateDoc, where,
} from 'firebase/firestore';

const configuration = JSON.parse(readFileSync(new URL('../../firebase.json', import.meta.url), 'utf8'));
const { host, port } = configuration.emulators.firestore;
if (host !== '127.0.0.1' || process.env.FIRESTORE_EMULATOR_HOST !== `${host}:${port}`) {
  throw new Error('Run these tests with npm test and the configured local emulator.');
}
setLogLevel('silent');
let environment;
const createdAt = Timestamp.fromMillis(1_000_000);

function databaseFor(userId = 'reporter-1', claims = {}) {
  return environment.authenticatedContext(userId, {
    email: `${userId}@campusfix.test`, ...claims,
  }).firestore();
}

function ownQuery(database, userId = 'reporter-1') {
  return query(collection(database, 'incidents'),
    where('createdByUserId', '==', userId), orderBy('createdAt', 'desc'));
}

function inspect(callback) {
  return environment.withSecurityRulesDisabled((context) => callback(context.firestore()));
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-campusfix', firestore: {
      host, port,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await inspect(async (database) => {
    await Promise.all([
      ...[
        ['reporter-1', 'reporter'], ['reporter-2', 'reporter'],
        ['technician-1', 'technician'], ['technician-2', 'technician'],
        ['administrator-1', 'administrator'],
      ].map(([id, role]) => setDoc(doc(database, 'users', id), {
        fullName: id, email: `${id}@campusfix.test`, role,
      })),
      ...[
        ['own', 'reporter-1', null],
        ['assigned', 'reporter-2', 'technician-1'],
        ['foreign', 'reporter-2', 'technician-2'],
      ].flatMap(([id, author, technician], index) => [
        setDoc(doc(database, 'incidents', id), {
          sequenceNumber: index + 1, title: id, description: 'Reported issue',
          categoryId: 'lighting', location: 'Building A', priority: null,
          status: technician ? 'EN_ATENCION' : 'REPORTADA',
          createdAt, updatedAt: createdAt, createdByUserId: author,
          assignedTechnicianId: technician, resolutionDescription: null,
        }),
        setDoc(doc(database, 'incidents', id, 'history/created'), {
          actorUserId: author, createdAt, action: 'created', fromStatus: null,
          toStatus: 'REPORTADA', fromTechnicianId: null, toTechnicianId: null, reason: null,
        }),
        setDoc(doc(database, 'incidents', id, 'progress/comment'), {
          authorUserId: technician ?? 'technician-1', createdAt, description: 'Inspection comment',
        }),
      ]),
    ]);
  });
});

after(async () => {
  if (environment) {
    await environment.clearFirestore();
    await environment.cleanup();
  }
});

test('A reporter query retrieves only its own incidents with the configured ordering', async () => {
  const database = databaseFor();
  const snapshot = await assertSucceeds(getDocs(ownQuery(database)));
  assert.deepEqual(snapshot.docs.map((record) => record.id), ['own']);
  const other = databaseFor('reporter-2');
  const others = await assertSucceeds(getDocs(ownQuery(other, 'reporter-2')));
  assert.deepEqual(others.docs.map((record) => record.id).sort(), ['assigned', 'foreign']);
});

test('Unfiltered and foreign-owner queries are rejected rather than filtered by rules', async () => {
  const database = databaseFor();
  await assertFails(getDocs(collection(database, 'incidents')));
  await assertFails(getDocs(ownQuery(database, 'reporter-2')));
  await inspect(async (admin) => {
    await deleteDoc(doc(admin, 'incidents/assigned'));
    await deleteDoc(doc(admin, 'incidents/foreign'));
  });
  await assertFails(getDocs(collection(database, 'incidents')));
});

test('Technicians administrators and missing profiles cannot use reporter collection queries', async () => {
  for (const userId of ['technician-1', 'administrator-1', 'missing-profile']) {
    const database = databaseFor(userId);
    await assertFails(getDocs(ownQuery(database, userId)));
  }
});

test('The author can read its detail while an unrelated reporter cannot read it directly', async () => {
  await assertSucceeds(getDocFromServer(doc(databaseFor(), 'incidents/own')));
  await assertSucceeds(getDocFromServer(doc(databaseFor('reporter-2'), 'incidents/assigned')));
  await assertFails(getDocFromServer(doc(databaseFor(), 'incidents/assigned')));
});

test('Only the currently assigned stored technician role authorizes technician detail access', async () => {
  const database = databaseFor('technician-1');
  await assertSucceeds(getDocFromServer(doc(database, 'incidents/assigned')));
  await assertFails(getDocFromServer(doc(database, 'incidents/own')));
  await assertFails(getDocFromServer(doc(database, 'incidents/foreign')));
  await assertFails(getDocFromServer(doc(databaseFor('reporter-1', { role: 'administrator' }), 'incidents/assigned')));
  await inspect((admin) => updateDoc(doc(admin, 'users/technician-1'), { role: 'reporter' }));
  await assertFails(getDocFromServer(doc(database, 'incidents/assigned')));
});

test('Administrators may read incident details history and progress without granting collection listing', async () => {
  const database = databaseFor('administrator-1');
  for (const id of ['own', 'assigned', 'foreign']) {
    await assertSucceeds(getDocFromServer(doc(database, 'incidents', id)));
    await assertSucceeds(getDocs(collection(database, 'incidents', id, 'history')));
    await assertSucceeds(getDocs(collection(database, 'incidents', id, 'progress')));
  }
  await assertFails(getDocs(collection(database, 'incidents')));
});

test('History and progress direct reads and ordered queries share parent detail permissions', async () => {
  for (const name of ['history', 'progress']) {
    for (const userId of ['reporter-2', 'technician-1', 'administrator-1']) {
      const database = databaseFor(userId);
      const records = await assertSucceeds(getDocs(query(collection(database, 'incidents/assigned', name), orderBy('createdAt'))));
      assert.equal(records.size, 1);
      await assertSucceeds(getDocFromServer(doc(database, 'incidents/assigned', name, records.docs[0].id)));
    }
    for (const userId of ['reporter-1', 'technician-2']) {
      const database = databaseFor(userId);
      await assertFails(getDocs(collection(database, 'incidents/assigned', name)));
      await assertFails(getDocFromServer(doc(database, 'incidents/assigned', name, name === 'history' ? 'created' : 'comment')));
    }
  }
});

test('Unauthenticated callers cannot read details comments history or own report queries', async () => {
  const database = environment.unauthenticatedContext().firestore();
  await assertFails(getDocFromServer(doc(database, 'incidents/own')));
  await assertFails(getDocs(ownQuery(database)));
  await assertFails(getDocs(collection(database, 'incidents/own/history')));
  await assertFails(getDocs(collection(database, 'incidents/own/progress')));
});

test('Valid stored profiles can distinguish a missing incident from a denied existing incident', async () => {
  for (const userId of ['reporter-1', 'technician-1', 'administrator-1']) {
    const record = await assertSucceeds(getDocFromServer(doc(databaseFor(userId), 'incidents/missing')));
    assert.equal(record.exists(), false);
  }
  await assertFails(getDocFromServer(doc(databaseFor('missing-profile'), 'incidents/missing')));
});

test('Orphan subcollections do not grant read access even to administrators', async () => {
  await inspect(async (admin) => {
    await setDoc(doc(admin, 'incidents/missing/history/orphan'), { action: 'created', createdAt });
    await setDoc(doc(admin, 'incidents/missing/progress/orphan'), { description: 'Orphan', createdAt });
  });
  for (const name of ['history', 'progress']) {
    await assertFails(getDocFromServer(doc(databaseFor('administrator-1'), 'incidents/missing', name, 'orphan')));
    await assertFails(getDocs(collection(databaseFor('administrator-1'), 'incidents/missing', name)));
  }
});

test('Reassignment revokes existing technician access to both the parent and its children', async () => {
  const database = databaseFor('technician-1');
  await assertSucceeds(getDocFromServer(doc(database, 'incidents/assigned')));
  await inspect((admin) => updateDoc(doc(admin, 'incidents/assigned'), { assignedTechnicianId: 'technician-2' }));
  await assertFails(getDocFromServer(doc(database, 'incidents/assigned')));
  await assertFails(getDocs(collection(database, 'incidents/assigned/history')));
  await assertFails(getDocs(collection(database, 'incidents/assigned/progress')));
  await assertSucceeds(getDocFromServer(doc(databaseFor('technician-2'), 'incidents/assigned')));
});

test('An active detail listener receives a permission error when its assignment is removed', async () => {
  const database = databaseFor('technician-1');
  let unsubscribe;
  let timer;
  let changed = false;
  try {
    const failure = await new Promise((resolve, reject) => {
      timer = setTimeout(() => reject(new Error('The detail listener did not revoke access.')), 10_000);
      unsubscribe = onSnapshot(doc(database, 'incidents/assigned'), () => {
        if (changed) return;
        changed = true;
        inspect((admin) => updateDoc(doc(admin, 'incidents/assigned'), { assignedTechnicianId: null })).catch(reject);
      }, resolve);
    });
    assert.equal(failure.code, 'permission-denied');
  } finally {
    clearTimeout(timer);
    unsubscribe?.();
  }
});

test('Own report listeners receive new matching cases without including other authors', async () => {
  const database = databaseFor();
  let unsubscribe;
  let timer;
  let changed = false;
  try {
    const ids = await new Promise((resolve, reject) => {
      timer = setTimeout(() => reject(new Error('The own-report listener did not update.')), 10_000);
      unsubscribe = onSnapshot(ownQuery(database), (snapshot) => {
        if (snapshot.docs.some((record) => record.id === 'new-own')) {
          resolve(snapshot.docs.map((record) => record.id));
          return;
        }
        if (changed) return;
        changed = true;
        inspect((admin) => setDoc(doc(admin, 'incidents/new-own'), {
          createdByUserId: 'reporter-1', createdAt: Timestamp.fromMillis(2_000_000),
        })).catch(reject);
      }, reject);
    });
    assert.deepEqual(ids, ['new-own', 'own']);
  } finally {
    clearTimeout(timer);
    unsubscribe?.();
  }
});

test('Read permissions do not grant progress writes or evidence access', async () => {
  for (const userId of ['reporter-2', 'technician-1', 'administrator-1']) {
    const database = databaseFor(userId);
    await assertFails(setDoc(doc(database, 'incidents/assigned/progress/new'), {
      authorUserId: userId, createdAt, description: 'Unauthorized write',
    }));
    await assertFails(updateDoc(doc(database, 'incidents/assigned/progress/comment'), { description: 'Changed' }));
    await assertFails(deleteDoc(doc(database, 'incidents/assigned/progress/comment')));
    await assertFails(getDocs(collection(database, 'incidents/assigned/evidence')));
  }
});
