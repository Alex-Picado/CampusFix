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

test('Inactive categories are denied to every role', async () => {
  for (const role of ['reporter', 'technician', 'administrator']) {
    await assertFails(getDoc(doc(contextFor(role).firestore(), 'categories/inactive')));
  }
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

test('Category creation modification and deletion remain denied for every role', async () => {
  for (const role of ['reporter', 'technician', 'administrator']) {
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

test('Only an explicit boolean active flag permits a category read', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'categories/invalid-flag'), {
      name: 'Invalid flag', isActive: 'true',
    });
    await setDoc(doc(context.firestore(), 'categories/missing-flag'), {
      name: 'Missing flag',
    });
  });
  const database = contextFor('reporter').firestore();
  await assertFails(getDoc(doc(database, 'categories/invalid-flag')));
  await assertFails(getDoc(doc(database, 'categories/missing-flag')));
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
