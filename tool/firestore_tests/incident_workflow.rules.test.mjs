import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, where, setDoc, updateDoc, writeBatch,
  serverTimestamp, Timestamp, setLogLevel, onSnapshot } from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8085') throw new Error('Local emulator required.');
setLogLevel('silent');
let environment;
let sequence = 0;
const dbFor = (uid) => environment.authenticatedContext(uid, { email: `${uid}@test.invalid` }).firestore();
const inspect = async (callback) => {
  let result;
  await environment.withSecurityRulesDisabled(async (context) => { result = await callback(context.firestore()); });
  return result;
};
const seed = (patch) => inspect((db) => updateDoc(doc(db, 'incidents/case'), patch));
before(async () => {
  environment = await initializeTestEnvironment({ projectId: 'demo-campusfix', firestore: {
    host: '127.0.0.1', port: 8085, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  } });
});
beforeEach(async () => {
  sequence = 0;
  await environment.clearFirestore();
  await inspect(async (db) => {
    await Promise.all([
      ...[['owner','reporter'], ['other','reporter'], ['tech','technician'], ['other-tech','technician'], ['admin','administrator']]
        .map(([uid, role]) => setDoc(doc(db, 'users', uid), { fullName: uid, email: `${uid}@test.invalid`, role })),
      setDoc(doc(db, 'categories/lighting'), { name: 'Lighting', isActive: true }),
      setDoc(doc(db, 'categories/inactive'), { name: 'Inactive', isActive: false }),
      setDoc(doc(db, 'incidents/case'), { createdByUserId: 'owner', assignedTechnicianId: null,
        status: 'REPORTADA', title: 'Light', description: 'Broken', categoryId: 'lighting', location: 'A',
        sequenceNumber: 1, priority: null, resolutionDescription: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now() }),
    ]);
  });
});
after(async () => { await environment.clearFirestore(); await environment.cleanup(); });

/** Builds direct SDK writes; deliberately does not rely on client-side guards. */
async function attempt(uid, action, options = {}) {
  const old = await inspect(async (db) => (await getDoc(doc(db, 'incidents/case'))).data());
  const eventId = options.eventId ?? `workflow-${++sequence}`;
  const changes = {
    classified: { status: 'EN_REVISION', categoryId: 'lighting', priority: 'ALTA' },
    assigned: { status: 'ASIGNADA', assignedTechnicianId: 'tech' },
    started: { status: 'EN_ATENCION' }, resolved: { status: 'RESUELTA', resolutionDescription: 'Replaced' },
    closed: { status: 'CERRADA' }, rejected: { status: 'RECHAZADA' }, cancelled: { status: 'CANCELADA' },
    reopened: { status: 'EN_REVISION', assignedTechnicianId: null, priority: null, resolutionDescription: null },
  }[action] ?? {};
  const next = { ...old, ...changes, updatedAt: serverTimestamp(), lastWorkflowEventId: eventId, ...options.changeIncident };
  const reason = action === 'resolved' ? 'Replaced' : ['rejected','cancelled','reopened'].includes(action) ? 'Reason supplied' : null;
  const event = { actorUserId: uid, createdAt: serverTimestamp(), action, fromStatus: old.status,
    toStatus: next.status, fromTechnicianId: old.assignedTechnicianId, toTechnicianId: next.assignedTechnicianId,
    reason, details: { categoryId: action === 'classified' ? next.categoryId : null,
      priority: action === 'classified' ? next.priority : null,
      technicianId: action === 'assigned' ? next.assignedTechnicianId : null, reason },
    previousResolutionDescription: action === 'reopened' ? old.resolutionDescription : null,
    ...options.changeEvent };
  const db = dbFor(uid);
  const batch = writeBatch(db);
  if (!options.eventOnly) batch.set(doc(db, 'incidents/case'), next);
  if (!options.incidentOnly) batch.set(doc(db, 'incidents/case/history', eventId), event);
  if (options.extraEvent) batch.set(doc(db, 'incidents/case/history/orphan'), event);
  return batch.commit();
}
async function classified() { await assertSucceeds(attempt('admin', 'classified')); }
async function assigned() { await classified(); await assertSucceeds(attempt('admin', 'assigned')); }
async function attending() { await assigned(); await assertSucceeds(attempt('tech', 'started')); }
async function resolved() { await attending(); await assertSucceeds(attempt('tech', 'resolved')); }

test('The full lifecycle commits changes and immutable audit events with actors and dates', async () => {
  await resolved(); await assertSucceeds(attempt('admin', 'closed'));
  const db = dbFor('admin');
  const incident = (await getDoc(doc(db, 'incidents/case'))).data();
  assert.equal(incident.status, 'CERRADA'); assert.equal(incident.resolutionDescription, 'Replaced');
  const events = (await getDocs(collection(db, 'incidents/case/history'))).docs.map((record) => record.data());
  assert.equal(events.length, 5);
  assert.deepEqual(events.map((event) => event.actorUserId), ['admin','admin','tech','tech','admin']);
  assert.ok(events.every((event) => event.createdAt instanceof Timestamp));
});
test('Reopening resolved and closed cases retains the prior solution and resets assignment and priority', async () => {
  await resolved(); await assertSucceeds(attempt('admin', 'closed'));
  await assertSucceeds(attempt('admin', 'reopened'));
  const db = dbFor('admin'); const data = (await getDoc(doc(db, 'incidents/case'))).data();
  assert.equal(data.status, 'EN_REVISION'); assert.equal(data.priority, null);
  assert.equal(data.resolutionDescription, null); assert.equal(data.assignedTechnicianId, null);
  const event = (await getDoc(doc(db, `incidents/case/history/${data.lastWorkflowEventId}`))).data();
  assert.equal(event.previousResolutionDescription, 'Replaced'); assert.equal(event.fromTechnicianId, 'tech');
  await assertFails(attempt('admin', 'assigned'));
  await classified(); await assertSucceeds(attempt('admin', 'assigned'));
});
test('Reopening directly from resolved is permitted', async () => {
  await resolved(); await assertSucceeds(attempt('admin', 'reopened'));
});
test('Only administrators classify and assign and only assigned technicians start attention', async () => {
  for (const uid of ['owner','other','tech','other-tech','missing']) await assertFails(attempt(uid, 'classified'));
  await classified();
  for (const uid of ['owner','tech','other-tech']) await assertFails(attempt(uid, 'assigned'));
  await assertSucceeds(attempt('admin', 'assigned'));
  for (const uid of ['admin','owner','other-tech']) await assertFails(attempt(uid, 'started'));
  await assertSucceeds(attempt('tech', 'started'));
});
test('Assignment requires classification, an active category, a valid priority and a stored technician', async () => {
  await assertFails(attempt('admin', 'assigned'));
  await classified();
  for (const id of ['owner','admin','missing']) await assertFails(attempt('admin','assigned',{changeIncident:{assignedTechnicianId:id}}));
  await seed({priority:null}); await assertFails(attempt('admin','assigned'));
  await seed({priority:'ALTA',categoryId:'inactive'}); await assertFails(attempt('admin','assigned'));
});
test('Classification rejects inactive or absent categories and unsupported priorities', async () => {
  for (const categoryId of ['inactive','absent']) await assertFails(attempt('admin','classified',{changeIncident:{categoryId}}));
  for (const priority of [null,'URGENTE',3]) await assertFails(attempt('admin','classified',{changeIncident:{priority}}));
  await classified(); await assertSucceeds(attempt('admin','classified',{changeIncident:{priority:'BAJA'}}));
});
test('Resolution requires attention, the current assigned role and a nonblank solution', async () => {
  await assigned(); await assertFails(attempt('tech','resolved'));
  await assertSucceeds(attempt('tech','started'));
  for (const uid of ['admin','owner','other-tech']) await assertFails(attempt(uid,'resolved'));
  for (const reason of ['', '  ']) await assertFails(attempt('tech','resolved',{changeIncident:{resolutionDescription:reason}, changeEvent:{reason,details:{categoryId:null,priority:null,technicianId:null,reason}}}));
  await inspect((db) => updateDoc(doc(db,'users/tech'),{role:'reporter'}));
  await assertFails(attempt('tech','resolved'));
});
test('Only administrators close resolved cases and cannot skip attention or resolution', async () => {
  await assertFails(attempt('admin','closed')); await attending();
  await assertFails(attempt('admin','closed')); await assertSucceeds(attempt('tech','resolved'));
  for (const uid of ['owner','tech','other-tech']) await assertFails(attempt(uid,'closed'));
  await assertSucceeds(attempt('admin','closed'));
});
test('Rejection is confined to review and cancellation to the four active states', async () => {
  await assertFails(attempt('admin','rejected')); await classified();
  await assertSucceeds(attempt('admin','rejected'));
  await assertFails(attempt('admin','reopened')); await assertFails(attempt('admin','cancelled'));
  for (const status of ['REPORTADA','EN_REVISION','ASIGNADA','EN_ATENCION']) {
    await seed({status}); await assertSucceeds(attempt('admin','cancelled'));
  }
  for (const status of ['RESUELTA','CERRADA','CANCELADA','RECHAZADA','REABIERTA']) {
    await seed({status}); await assertFails(attempt('admin','cancelled'));
  }
});
test('Rejection cancellation and reopening require nonblank normalized reasons', async () => {
  for (const [action,status] of [['rejected','EN_REVISION'],['cancelled','REPORTADA'],['reopened','RESUELTA']]) {
    await seed({status});
    for (const reason of [null,'','  ',' untrimmed ']) await assertFails(attempt('admin',action,{changeEvent:{reason,details:{categoryId:null,priority:null,technicianId:null,reason}}}));
  }
});
test('Incident-only event-only and extra orphan events are rejected without partial writes', async () => {
  for (const options of [{incidentOnly:true},{eventOnly:true},{extraEvent:true}]) {
    await assertFails(attempt('admin','classified',options));
    assert.equal((await getDoc(doc(dbFor('admin'),'incidents/case'))).data().status,'REPORTADA');
    assert.equal((await getDocs(collection(dbFor('admin'),'incidents/case/history'))).size,0);
  }
});
test('Forged audit actors dates state assignments payloads and prior solutions are rejected', async () => {
  for (const changeEvent of [{actorUserId:'owner'},{createdAt:Timestamp.fromMillis(1)}, {fromStatus:'CERRADA'},
    {toStatus:'ASIGNADA'},{toTechnicianId:'tech'},{fromTechnicianId:'tech'},{arbitrary:true},
    {previousResolutionDescription:'Forged'},{details:{categoryId:'inactive',priority:'ALTA',technicianId:null,reason:null}}]) {
    await assertFails(attempt('admin','classified',{changeEvent}));
  }
});
test('Immutable incident fields and arbitrary schema extensions cannot change during workflow', async () => {
  for (const changeIncident of [{createdByUserId:'other'},{createdAt:serverTimestamp()}, {sequenceNumber:99},
    {title:'Replaced'},{description:'Replaced'},{location:'Elsewhere'},{arbitrary:true},
    {resolutionDescription:'Injected'},{assignedTechnicianId:'tech'}, {updatedAt:Timestamp.fromMillis(1)}]) {
    // createdAt == serverTimestamp is a genuine change because the fixture predates this request.
    await assertFails(attempt('admin','classified',{changeIncident}));
  }
});
test('History cannot be overwritten reused deleted or linked to the wrong incident update', async () => {
  await assertSucceeds(attempt('admin','classified',{eventId:'fixed'}));
  await assertFails(attempt('admin','classified',{eventId:'fixed'}));
  await assertFails(attempt('admin','classified',{changeIncident:{lastWorkflowEventId:'different'}}));
  await assertFails(attempt('admin','classified',{eventId:'created'}));
  await assertFails(updateDoc(doc(dbFor('admin'),'incidents/case/history/fixed'),{reason:'Changed'}));
});
test('Administrator queues and server-filtered own technician queues enforce stored roles', async () => {
  await assigned();
  const tech = dbFor('tech');
  const own = query(collection(tech,'incidents'),where('assignedTechnicianId','==','tech'));
  assert.equal((await assertSucceeds(getDocs(own))).size,1);
  await assertFails(getDocs(collection(tech,'incidents')));
  await assertFails(getDocs(query(collection(tech,'incidents'),where('assignedTechnicianId','==','other-tech'))));
  await assertSucceeds(getDocs(collection(dbFor('admin'),'incidents')));
  await assertFails(getDocs(collection(dbFor('owner'),'incidents')));
  await assertFails(getDocs(collection(environment.unauthenticatedContext().firestore(),'incidents')));
});
test('An owner session and an assigned technician session receive lifecycle changes live', async () => {
  await assigned();
  const seen = {owner:[],tech:[]}; const errors=[];
  const stops=Object.keys(seen).map((uid)=>onSnapshot(doc(dbFor(uid),'incidents/case'),(snapshot)=>seen[uid].push(snapshot.data().status),(error)=>errors.push(error)));
  try {
    await assertSucceeds(attempt('tech','started'));
    await assertSucceeds(attempt('tech','resolved'));
    await assertSucceeds(attempt('admin','closed'));
    for(let i=0;i<80 && !Object.values(seen).every((states)=>states.includes('CERRADA'));i++) await new Promise((resolve)=>setTimeout(resolve,25));
    assert.deepEqual(errors,[]);
    for(const states of Object.values(seen)) for(const status of ['EN_ATENCION','RESUELTA','CERRADA']) assert.ok(states.includes(status),`${status} missing from ${states}`);
  } finally { stops.forEach((stop)=>stop()); }
});
