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
  getDocs,
  query,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
} from 'firebase/firestore';

const configuration = JSON.parse(
  readFileSync(new URL('../../firebase.json', import.meta.url), 'utf8'),
);
const { host, port } = configuration.emulators.firestore;

if (
  host !== '127.0.0.1' ||
  process.env.FIRESTORE_EMULATOR_HOST !== `${host}:${port}`
) {
  throw new Error('Run these tests with npm test and the configured local emulator.');
}

setLogLevel('silent');
let environment;

/** Returns a test account with the same identity fields used in user rules. */
function contextFor(role) {
  return environment.authenticatedContext(`${role}-1`, {
    email: `${role}@campusfix.test`,
  });
}

/** Builds the filtered query used by the active category service. */
function activeCategories(database) {
  return query(collection(database, 'categories'), where('isActive', '==', true));
}

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
      setDoc(doc(database, 'categories/lighting'), { name: 'Lighting', isActive: true }),
      setDoc(doc(database, 'categories/plumbing'), { name: 'Plumbing', isActive: true }),
      setDoc(doc(database, 'categories/inactive'), { name: 'Old category', isActive: false }),
      ...['reporter', 'technician', 'administrator'].map((role) =>
        setDoc(doc(database, `users/${role}-1`), {
          fullName: role,
          email: `${role}@campusfix.test`,
          role,
        }),
      ),
    ]);
  });
});

after(async () => {
  if (environment) {
    await environment.clearFirestore();
    await environment.cleanup();
  }
});

test('Unauthenticated sessions cannot query active categories', async () => {
  const database = environment.unauthenticatedContext().firestore();
  await assertFails(getDocs(activeCategories(database)));
});

test('Unauthenticated sessions cannot read an active category directly', async () => {
  const database = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(database, 'categories/lighting')));
});

test('Authenticated roles can query only active categories', async () => {
  for (const role of ['reporter', 'technician', 'administrator']) {
    const snapshot = await assertSucceeds(
      getDocs(activeCategories(contextFor(role).firestore())),
    );
    assert.deepEqual(snapshot.docs.map((document) => document.id).sort(), [
      'lighting', 'plumbing',
    ]);
  }
});

test('Authenticated sessions can read an active category directly', async () => {
  const database = contextFor('reporter').firestore();
  const snapshot = await assertSucceeds(getDoc(doc(database, 'categories/lighting')));
  assert.equal(snapshot.data().name, 'Lighting');
});

test('Authenticated roles can resolve inactive names without listing the catalog', async () => {
  for (const role of ['reporter', 'technician', 'administrator']) {
    const snapshot = await assertSucceeds(getDoc(doc(contextFor(role).firestore(), 'categories/inactive')));
    assert.equal(snapshot.data().name, 'Old category');
  }
  await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'categories/inactive')));
});

test('Queries for inactive categories are rejected', async () => {
  const database = contextFor('reporter').firestore();
  await assertFails(getDocs(
    query(collection(database, 'categories'), where('isActive', '==', false)),
  ));
});

test('Unfiltered queries remain denied even when all stored categories are active', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), 'categories/inactive'));
  });
  await assertFails(getDocs(collection(contextFor('reporter').firestore(), 'categories')));
});

test('Reporters and technicians cannot create modify or delete categories', async () => {
  for (const role of ['reporter', 'technician']) {
    const database = contextFor(role).firestore();
    await assertFails(setDoc(doc(database, 'categories/new-category'), {
      name: 'Unauthorized category', isActive: true,
    }));
    await assertFails(updateDoc(doc(database, 'categories/lighting'), {
      name: 'Unauthorized change',
    }));
    await assertFails(deleteDoc(doc(database, 'categories/lighting')));
  }
});

test('Administrators can list the complete catalog including inactive categories', async () => {
  const database = contextFor('administrator').firestore();
  const snapshot = await assertSucceeds(getDocs(collection(database, 'categories')));
  assert.deepEqual(snapshot.docs.map((record) => record.id).sort(), ['inactive', 'lighting', 'plumbing']);
  await assertSucceeds(getDocs(query(collection(database, 'categories'), where('isActive', '==', false))));
});

test('Administrators create rename deactivate and reactivate without deleting', async () => {
  const database = contextFor('administrator').firestore();
  const reference = doc(database, 'categories/accessibility');
  await assertSucceeds(setDoc(reference, { name: 'Accessibility', isActive: true }));
  await assertSucceeds(updateDoc(reference, { name: 'Access', isActive: false }));
  assert.equal((await getDoc(reference)).data().name, 'Access');
  await assertSucceeds(updateDoc(reference, { isActive: true }));
  await assertFails(deleteDoc(reference));
  await assertFails(deleteDoc(doc(database, 'categories/inactive')));
});

test('Catalog writes reject blank untrimmed missing mistyped and unexpected fields', async () => {
  const database = contextFor('administrator').firestore();
  for (const data of [
    { name: '', isActive: true }, { name: ' \t ', isActive: true },
    { name: ' Lighting ', isActive: true }, { name: 123, isActive: true },
    { name: 'Lighting', isActive: 'true' }, { name: 'Lighting' },
    { isActive: true }, { name: 'Lighting', isActive: true, extra: 'unexpected' },
  ]) {
    await assertFails(setDoc(doc(database, 'categories/invalid'), data));
    await assertFails(setDoc(doc(database, 'categories/lighting'), data));
  }
});

test('Unauthenticated catalog writes and a revoked administrator are denied', async () => {
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anonymous, 'categories/new'), { name: 'New', isActive: true }));
  await assertFails(updateDoc(doc(anonymous, 'categories/lighting'), { isActive: false }));
  await assertFails(deleteDoc(doc(anonymous, 'categories/lighting')));
  const database = contextFor('administrator').firestore();
  await environment.withSecurityRulesDisabled((context) =>
    updateDoc(doc(context.firestore(), 'users/administrator-1'), { role: 'reporter' }));
  await assertFails(updateDoc(doc(database, 'categories/lighting'), { isActive: false }));
  await assertFails(getDocs(collection(database, 'categories')));
});

test('Deactivation preserves existing incident references and historical names', async () => {
  await environment.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), 'incidents/historical'), {
      categoryId: 'lighting', createdByUserId: 'reporter-1', assignedTechnicianId: null,
    }));
  const database = contextFor('administrator').firestore();
  await assertSucceeds(updateDoc(doc(database, 'categories/lighting'), { isActive: false }));
  const reporter = contextFor('reporter').firestore();
  assert.equal((await getDoc(doc(reporter, 'incidents/historical'))).data().categoryId, 'lighting');
  assert.equal((await getDoc(doc(reporter, 'categories/lighting'))).data().name, 'Lighting');
  const active = await getDocs(activeCategories(reporter));
  assert.deepEqual(active.docs.map((record) => record.id), ['plumbing']);
});

test('Existing profile permissions still protect user data', async () => {
  const reporter = contextFor('reporter').firestore();
  await assertSucceeds(getDoc(doc(reporter, 'users/reporter-1')));
  await assertFails(getDoc(doc(reporter, 'users/technician-1')));
  await assertFails(updateDoc(doc(reporter, 'users/reporter-1'), {
    role: 'administrator',
  }));
  await assertSucceeds(getDocs(collection(contextFor('administrator').firestore(), 'users')));
});

test('Only administrators can list profiles for technician filter labels', async () => {
  const administrator = contextFor('administrator').firestore();
  const profiles = await assertSucceeds(getDocs(collection(administrator, 'users')));
  assert.equal(profiles.size, 3);
  for (const role of ['reporter', 'technician']) {
    await assertFails(getDocs(collection(contextFor(role).firestore(), 'users')));
  }
  await assertFails(getDocs(collection(environment.unauthenticatedContext().firestore(), 'users')));
});
