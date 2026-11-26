import assert from 'node:assert/strict';
import { test } from 'node:test';
import { messageFor, recipientIds } from './message.mjs';

test('includes reporter, involved technicians, backups and administrators once, including the actor', () => {
  const incident = { createdByUserId: 'owner', technicianQueue: ['backup', 'tech'] };
  const event = { actorUserId: 'tech', fromTechnicianId: 'tech', toTechnicianId: 'next' };
  assert.deepEqual(recipientIds(incident, event, ['admin', 'owner']),
    ['owner', 'tech', 'next', 'backup', 'admin']);
});

test('the author also receives a status email when hiding their own report', () => {
  const incident = { createdByUserId: 'owner', reporterHidden: true };
  const event = { fromTechnicianId: 'tech', toTechnicianId: null };
  assert.deepEqual(recipientIds(incident, event, ['admin']), ['owner', 'tech', 'admin']);
});

test('includes the actor even when their profile is outside the other recipient groups', () => {
  const incident = { createdByUserId: 'owner', technicianQueue: [] };
  const event = { actorUserId: 'actor', fromTechnicianId: null, toTechnicianId: null };
  assert.deepEqual(recipientIds(incident, event, ['admin']),
    ['owner', 'actor', 'admin']);
});

test('message uses the event transition and report link', () => {
  const message = messageFor('a b', { sequenceNumber: 12 },
    { fromStatus: 'ASIGNADA', toStatus: 'RESUELTA' }, 'Ana', 'https://campus-fix-ucr.web.app/');
  assert.match(message.subject, /#12.*Resuelta/);
  assert.match(message.text, /Asignada a Resuelta/);
  assert.match(message.text, /#\/incidents\/a%20b/);
});
