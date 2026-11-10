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
    assignmentDeclined: { status: 'EN_REVISION', assignedTechnicianId: null },
    started: { status: 'EN_ATENCION' }, resolved: { status: 'RESUELTA', resolutionDescription: 'Replaced', technicianApproved: true, reporterApproved: false, adminApproved: false },
    reviewRequested: { status: 'REVISION_SOLICITADA', reporterApproved: false, adminApproved: false },
    reviewDismissed: { status: 'RESUELTA', reporterApproved: false, adminApproved: false },
    closed: { status: old.reporterApproved && old.technicianApproved ? 'CERRADA' : 'RESUELTA', adminApproved: true },
    solutionAccepted: { status: old.adminApproved && old.technicianApproved ? 'CERRADA' : 'RESUELTA', reporterApproved: true },
    rejected: { status: 'RECHAZADA' }, cancelled: { status: 'CANCELADA' },
    removedFromList: { status: ['CERRADA','CANCELADA','RECHAZADA'].includes(old.status) ? old.status : 'CANCELADA', reporterHidden: true },
    reopened: { status: 'EN_REVISION', assignedTechnicianId: null, priority: null, resolutionDescription: null, technicianApproved: false, reporterApproved: false, adminApproved: false },
  }[action] ?? {};
  const next = { ...old, ...changes, updatedAt: serverTimestamp(), lastWorkflowEventId: eventId, ...options.changeIncident };
  const reason = action === 'resolved' ? 'Replaced' : ['rejected','cancelled','removedFromList','reopened','reviewRequested','reviewDismissed','assignmentDeclined'].includes(action) ? 'Reason supplied' : null;
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

test('Only the stored reporter author cancels an open report with an atomic reasoned audit', async () => {
  for (const status of ['REPORTADA','EN_REVISION','ASIGNADA','EN_ATENCION','RESUELTA','REVISION_SOLICITADA','REABIERTA']) {
    await seed({status});
    for (const uid of ['other','tech','other-tech','missing']) await assertFails(attempt(uid,'cancelled'));
    await assertFails(attempt('owner','cancelled',{incidentOnly:true}));
    await assertFails(attempt('owner','cancelled',{eventOnly:true}));
    await assertSucceeds(attempt('owner','cancelled'));
  }
  for (const status of ['CERRADA','CANCELADA','RECHAZADA']) {
    await seed({status}); await assertFails(attempt('owner','cancelled'));
  }
});

test('Removal is author-only, cancels open work and retains the administrative report and immutable history', async () => {
  await attending();
  for (const uid of ['other','tech','other-tech','admin','missing']) await assertFails(attempt(uid,'removedFromList'));
  await assertFails(attempt('owner','removedFromList',{changeIncident:{createdByUserId:'other'}}));
  await assertFails(attempt('owner','removedFromList',{changeIncident:{resolutionDescription:'Forged solution'}}));
  await assertFails(attempt('owner','removedFromList',{changeIncident:{reporterHidden:false}}));
  for (const reason of [null,'','  ',' untrimmed ']) {
    await assertFails(attempt('owner','removedFromList',{changeEvent:{reason, details:{categoryId:null,priority:null,technicianId:null,reason}}}));
  }
  await assertSucceeds(attempt('owner','removedFromList',{eventId:'withdrawal'}));
  const admin = dbFor('admin');
  const data = (await assertSucceeds(getDoc(doc(admin,'incidents/case')))).data();
  assert.equal(data.status,'CANCELADA'); assert.equal(data.reporterHidden,true);
  assert.equal(data.assignedTechnicianId,'tech'); assert.equal(data.createdByUserId,'owner');
  const event = (await assertSucceeds(getDoc(doc(admin,'incidents/case/history/withdrawal')))).data();
  assert.equal(event.action,'removedFromList'); assert.equal(event.actorUserId,'owner');
  await assertFails(attempt('owner','removedFromList'));
  await assertFails(updateDoc(doc(dbFor('owner'),'incidents/case'),{reporterHidden:false}));
  const owner = dbFor('owner');
  const batch = writeBatch(owner);
  batch.delete(doc(owner,'incidents/case'));
  await assertFails(batch.commit());
});

test('Removal of a finalized report preserves its outcome, solution, assignment and all approvals', async () => {
  for (const status of ['CERRADA','RECHAZADA','CANCELADA']) {
    await seed({status,reporterHidden:false,resolutionDescription:'Original solution',
      technicianApproved:true,reporterApproved:true,adminApproved:true});
    await assertFails(attempt('owner','removedFromList',{changeIncident:{status:'CANCELADA' === status ? 'CERRADA' : 'CANCELADA'}}));
    await assertFails(attempt('owner','removedFromList',{changeIncident:{adminApproved:false}}));
    await assertSucceeds(attempt('owner','removedFromList'));
    const data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
    assert.equal(data.status,status); assert.equal(data.resolutionDescription,'Original solution');
    assert.equal(data.technicianApproved,true); assert.equal(data.reporterApproved,true); assert.equal(data.adminApproved,true);
    await assertFails(attempt('admin','reopened'));
  }
});

test('The full lifecycle commits changes and immutable audit events with actors and dates', async () => {
  await resolved(); await assertSucceeds(attempt('owner', 'solutionAccepted')); await assertSucceeds(attempt('admin', 'closed'));
  const db = dbFor('admin');
  const incident = (await getDoc(doc(db, 'incidents/case'))).data();
  assert.equal(incident.status, 'CERRADA'); assert.equal(incident.resolutionDescription, 'Replaced');
  const events = (await getDocs(collection(db, 'incidents/case/history'))).docs.map((record) => record.data());
  assert.equal(events.length, 6);
  assert.deepEqual(events.map((event) => event.actorUserId), ['admin','admin','tech','tech','owner','admin']);
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
test('Only the owner can request another review and administration must decide before closure', async () => {
  await resolved();
  for (const uid of ['other','admin','tech','other-tech']) await assertFails(attempt(uid,'reviewRequested'));
  await assertSucceeds(attempt('owner','reviewRequested'));
  await assertFails(attempt('admin','closed'));
  await assertFails(attempt('owner','reopened'));
  await assertSucceeds(attempt('admin','reopened'));
  const data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
  assert.equal(data.status,'EN_REVISION');
  assert.equal(data.resolutionDescription,null);
});
test('A closed case may be challenged and administrator can decline with a recorded reason', async () => {
  await resolved(); await assertSucceeds(attempt('admin','closed'));
  await assertSucceeds(attempt('owner','reviewRequested'));
  for (const reason of [null,'','  ',' untrimmed ']) await assertFails(attempt('admin','reviewDismissed',{changeEvent:{reason,details:{categoryId:null,priority:null,technicianId:null,reason}}}));
  await assertSucceeds(attempt('admin','reviewDismissed'));
  const data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
  assert.equal(data.status,'RESUELTA'); assert.equal(data.resolutionDescription,'Replaced');
  assert.equal(data.reporterApproved, false); assert.equal(data.adminApproved, false);
});
test('Only administrators classify and assign and only assigned technicians start attention', async () => {
  for (const uid of ['owner','other','tech','other-tech','missing']) await assertFails(attempt(uid, 'classified'));
  await classified();
  for (const uid of ['owner','tech','other-tech']) await assertFails(attempt(uid, 'assigned'));
  await assertSucceeds(attempt('admin', 'assigned'));
  for (const uid of ['admin','owner','other-tech']) await assertFails(attempt(uid, 'started'));
  await assertSucceeds(attempt('tech', 'started'));
});
test('An assigned technician declines with a reason and administration can reassign the case', async () => {
  await assigned();
  for (const uid of ['owner','admin','other-tech']) await assertFails(attempt(uid,'assignmentDeclined'));
  for (const reason of [null,'','  ',' untrimmed ']) {
    await assertFails(attempt('tech','assignmentDeclined',{
      changeEvent:{reason,details:{categoryId:null,priority:null,technicianId:null,reason}},
    }));
  }
  await assertFails(attempt('tech','assignmentDeclined',{changeIncident:{priority:null}}));
  await assertFails(attempt('tech','assignmentDeclined',{changeIncident:{resolutionDescription:'Forged'}}));
  await assertFails(attempt('tech','assignmentDeclined',{changeIncident:{assignedTechnicianId:'other-tech'}}));
  await assertSucceeds(attempt('tech','assignmentDeclined',{
    eventId:'declined',
    changeEvent:{reason:'Medical leave',details:{categoryId:null,priority:null,technicianId:null,reason:'Medical leave'}},
  }));
  const admin = dbFor('admin'); const tech = dbFor('tech');
  const data = (await getDoc(doc(admin,'incidents/case'))).data();
  assert.equal(data.status,'EN_REVISION'); assert.equal(data.assignedTechnicianId,null);
  assert.equal(data.priority,'ALTA'); assert.equal(data.resolutionDescription,null);
  await assertFails(getDoc(doc(tech,'incidents/case')));
  const event = (await assertSucceeds(getDoc(doc(tech,'incidents/case/history/declined')))).data();
  assert.equal(event.actorUserId,'tech'); assert.equal(event.fromTechnicianId,'tech');
  assert.equal(event.toTechnicianId,null); assert.equal(event.reason,'Medical leave');
  await assertFails(getDocs(collection(tech,'incidents/case/history')));
  await assertSucceeds(attempt('admin','assigned',{changeIncident:{assignedTechnicianId:'other-tech'}}));
  assert.equal((await getDoc(doc(admin,'incidents/case'))).data().assignedTechnicianId,'other-tech');
});
test('An attending technician can decline without deleting progress or granting access to other actors', async () => {
  await attending();
  await assertSucceeds(attempt('tech','assignmentDeclined'));
  const data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
  assert.equal(data.status,'EN_REVISION'); assert.equal(data.assignedTechnicianId,null);
  for (const uid of ['owner','admin','other-tech']) await assertFails(attempt(uid,'assignmentDeclined'));
  await assertFails(attempt('tech','assignmentDeclined'));
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
    await assertSucceeds(attempt('owner','solutionAccepted'));
    for(let i=0;i<80 && !Object.values(seen).every((states)=>states.includes('CERRADA'));i++) await new Promise((resolve)=>setTimeout(resolve,25));
    assert.deepEqual(errors,[]);
    for(const states of Object.values(seen)) for(const status of ['EN_ATENCION','RESUELTA','CERRADA']) assert.ok(states.includes(status),`${status} missing from ${states}`);
  } finally { stops.forEach((stop)=>stop()); }
});

test('Closure requires all three approvals in either order and rejects forged consent', async () => {
  await resolved();
  await assertFails(attempt('admin', 'closed', {changeIncident: {status:'CERRADA'}}));
  await assertFails(attempt('owner', 'solutionAccepted', {changeIncident: {adminApproved:true,status:'CERRADA'}}));
  for (const uid of ['admin','tech','other','other-tech']) await assertFails(attempt(uid, 'solutionAccepted'));
  await assertSucceeds(attempt('admin','closed'));
  let data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
  assert.equal(data.status,'RESUELTA');
  await assertFails(attempt('admin','closed'));
  await assertSucceeds(attempt('owner','solutionAccepted'));
  data = (await getDoc(doc(dbFor('admin'),'incidents/case'))).data();
  assert.equal(data.status,'CERRADA');
  assert.equal(data.reporterApproved,true); assert.equal(data.adminApproved,true); assert.equal(data.technicianApproved,true);
  await assertSucceeds(attempt('owner','reviewRequested'));
  await assertSucceeds(attempt('admin','reviewDismissed'));
  await assertFails(attempt('admin','closed',{changeIncident:{status:'CERRADA'}}));
  await assertSucceeds(attempt('owner','solutionAccepted'));
  await assertSucceeds(attempt('admin','closed'));
});

test('Unapproved legacy resolutions cannot be closed without a new technician resolution', async () => {
  await seed({status:'RESUELTA', assignedTechnicianId:'tech', resolutionDescription:'Legacy'});
  await assertFails(attempt('admin','closed'));
  await assertFails(attempt('owner','solutionAccepted'));
  await assertSucceeds(attempt('admin','reopened'));
});
