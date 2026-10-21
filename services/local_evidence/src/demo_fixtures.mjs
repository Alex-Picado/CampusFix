import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import sharp from 'sharp';
import { readConfig } from './config.mjs';
import { storeImage } from './storage.mjs';

/** Refuses all fixture operations unless both local emulators and a demo project are explicit. */
export function demoConfig() {
  const config = readConfig();
  if (!config.emulatorMode || config.projectId !== 'demo-campusfix') throw new Error('Demo fixtures require the local demo-campusfix emulators.');
  return config;
}

async function withDatabase(work) {
  const config = demoConfig();
  const app = initializeApp({ projectId: config.projectId }, `fixtures-${Date.now()}-${Math.random()}`);
  const db = getFirestore(app);
  try { return await work(db, getAuth(app), config); }
  finally { await db.terminate(); await deleteApp(app); }
}

/** Creates reproducible local accounts, categories, reports and an assigned attention case. */
export async function seedDemo(storageRoot) {
  return withDatabase(async (db, auth, config) => {
    const users = [['reporter-demo', 'reporter'], ['other-demo', 'reporter'], ['technician-demo', 'technician'],
      ['other-tech-demo', 'technician'], ['admin-demo', 'administrator']];
    for (const [uid, role] of users) {
      const email = `${uid}@campusfix.test`;
      try { await auth.getUser(uid); }
      catch (error) { if (error.code !== 'auth/user-not-found') throw error;
        await auth.createUser({ uid, email, password: 'CampusFixDemo123!', displayName: uid }); }
      await db.doc(`users/${uid}`).set({ fullName: uid, email, role });
    }
    await db.doc('categories/demo-lighting').set({ name: 'Iluminación', isActive: true });
    const timestamp = Timestamp.now();
    for (const [index, id] of ['demo-report', 'demo-assigned', 'demo-foreign'].entries()) {
      const author = id === 'demo-foreign' ? 'other-demo' : 'reporter-demo';
      await db.doc(`incidents/${id}`).set({ sequenceNumber: index + 1, title: `Caso de demostración ${index + 1}`,
        description: 'La iluminación del aula requiere una inspección.', categoryId: 'demo-lighting', location: 'Edificio A',
        priority: id === 'demo-assigned' ? 'MEDIA' : null, status: id === 'demo-assigned' ? 'EN_ATENCION' : 'REPORTADA',
        createdAt: timestamp, updatedAt: timestamp, createdByUserId: author,
        assignedTechnicianId: id === 'demo-assigned' ? 'technician-demo' : null, resolutionDescription: null });
      await db.doc(`incidents/${id}/history/created`).set({ actorUserId: author, createdAt: timestamp,
        action: 'created', fromStatus: null, toStatus: 'REPORTADA', fromTechnicianId: null, toTechnicianId: null, reason: null });
    }
    const counter = db.doc('counters/incidents');
    await db.runTransaction(async (tx) => {
      const previous = await tx.get(counter);
      if ((previous.data()?.lastSequenceNumber ?? 0) < 3) tx.set(counter, { lastSequenceNumber: 3, lastIncidentId: 'demo-foreign' });
    });
    const bytes = await sharp({ create: { width: 32, height: 24, channels: 3, background: '#28634f' } }).png().toBuffer();
    const reference = { id: 'demo-photo', assetId: 'demo-report/demo-photo', url: '/incidents/demo-report/evidence/demo-photo',
      fileName: 'demo.png', contentType: 'image/png', sizeBytes: bytes.length, progressId: null };
    await storeImage(storageRoot ?? config.storageDirectory, 'demo-report', 'demo-photo',
      { ...reference, uploadedByUserId: 'reporter-demo' }, bytes);
    const { id: _, ...fields } = reference;
    await db.doc('incidents/demo-report/evidence/demo-photo').set({ ...fields, provider: 'local',
      uploadedByUserId: 'reporter-demo', createdAt: timestamp });
    return bytes;
  });
}

/** Changes only prepared emulator state for permission-revocation checks. */
export async function changeDemoState(fields) {
  return withDatabase(async (db) => { await db.doc('incidents/demo-assigned').update(fields); });
}
