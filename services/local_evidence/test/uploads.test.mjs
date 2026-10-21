import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import test from 'node:test';
import sharp from 'sharp';
import { readConfig } from '../src/config.mjs';
import { firebaseAuthorization, HttpError } from '../src/authorization.mjs';
import { startEvidenceService } from '../src/server.mjs';
import { validateImage } from '../src/storage.mjs';

const png = await sharp({ create: { width: 2, height: 2, channels: 3, background: 'white' } }).png().toBuffer();

async function fixture(t) {
  const parent = resolve(tmpdir());
  const root = await mkdtemp(join(parent, 'campusfix-uploads-'));
  let role = 'reporter';
  const authorize = async (request, incident, writing, progress) => {
    if (request.headers.authorization !== 'Bearer valid') throw new HttpError(401, 'unauthenticated');
    if (incident !== 'case-1' || (writing && role === 'denied') ||
      (writing && ((role === 'reporter' && progress != null) || (role === 'technician' && progress == null)))) {
      throw new HttpError(403, 'permission_denied');
    }
    return { uid: 'user-1', read: async () => null };
  };
  const config = { ...readConfig({}), port: 0, storageDirectory: join(root, 'evidence') };
  let server = await startEvidenceService(config, { authorize });
  const close = async () => {
    await new Promise((resolve) => { server.close(resolve); server.closeIdleConnections(); });
  };
  t.after(async () => {
    await close();
    assert.equal(dirname(resolve(root)), parent);
    assert.ok(basename(root).startsWith('campusfix-uploads-'));
    await rm(root, { recursive: true, force: true });
  });
  return { get url() { return `http://127.0.0.1:${server.address().port}`; },
    role(value) { role = value; }, async restart() { await close(); server = await startEvidenceService(config, { authorize }); } };
}

function put(url, bytes = png, headers = {}) {
  return fetch(`${url}/incidents/case-1/evidence/photo-1`, { method: 'PUT', body: bytes,
    headers: { Authorization: 'Bearer valid', 'Content-Type': 'image/png', 'X-File-Name': 'photo.png', ...headers } });
}

test('Fully decodes JPEG PNG and WebP and rejects corrupted, oversized or mismatched content', async () => {
  for (const [format, type] of [['jpeg', 'image/jpeg'], ['png', 'image/png'], ['webp', 'image/webp']]) {
    const bytes = await sharp(png).toFormat(format).toBuffer();
    await validateImage(bytes, type);
  }
  await assert.rejects(validateImage(Buffer.from('not an image'), 'image/png'), { status: 415 });
  await assert.rejects(validateImage(png, 'image/jpeg'), { status: 415 });
  await assert.rejects(validateImage(png.subarray(0, 35), 'image/png'), { status: 415 });
  await assert.rejects(validateImage(Buffer.alloc(3_000_001), 'image/png'), { status: 413 });
  const padded = Buffer.concat([await sharp(png).jpeg().toBuffer(), Buffer.alloc(3_000_000 - (await sharp(png).jpeg().toBuffer()).length)]);
  await validateImage(padded, 'image/jpeg');
});

test('Uploads and downloads protected bytes, preserves them on restart and retries without duplicates', async (t) => {
  const service = await fixture(t);
  const first = await put(service.url);
  assert.equal(first.status, 200);
  const reference = await first.json();
  const retries = await Promise.all([put(service.url), put(service.url)]);
  for (const response of retries) { assert.equal(response.status, 200); assert.deepEqual(await response.json(), reference); }
  await service.restart();
  const image = await fetch(`${service.url}${reference.url}`, { headers: { Authorization: 'Bearer valid' } });
  assert.equal(image.status, 200); assert.deepEqual(Buffer.from(await image.arrayBuffer()), png);
  assert.equal((await put(service.url, png, { 'X-File-Name': 'different.png' })).status, 409);
});

test('Rejects missing sessions, revoked upload permissions, invalid images and path injection', async (t) => {
  const service = await fixture(t);
  assert.equal((await put(service.url, png, { Authorization: '' })).status, 401);
  service.role('denied'); assert.equal((await put(service.url)).status, 403);
  service.role('reporter');
  assert.equal((await put(service.url, Buffer.from('invalid'))).status, 415);
  assert.equal((await put(service.url, Buffer.alloc(3_000_001))).status, 413);
  assert.equal((await put(service.url, png, { 'X-File-Name': '..%2Fsecret' })).status, 400);
  assert.equal((await fetch(`${service.url}/incidents/%2e%2e%5csecret/evidence/photo`, { headers: { Authorization: 'Bearer valid' } })).status, 400);
  assert.equal((await put(service.url, png, { 'X-Progress-Id': 'progress-1' })).status, 403);
  service.role('technician');
  assert.equal((await put(service.url, png, { 'X-Progress-Id': 'progress-1' })).status, 200);
});

test('Forwards the user token to Firestore REST and checks stored technician assignment and state', async () => {
  const config = readConfig({});
  const reads = [];
  let status = 'EN_ATENCION';
  const authorize = firebaseAuthorization(config, {
    verifyToken: async (token) => { assert.equal(token, 'verified'); return { uid: 'tech' }; },
    fetcher: async (url, options) => {
      assert.equal(options.headers.Authorization, 'Bearer verified'); reads.push(url);
      const fields = url.endsWith('/users/tech') ? { role: { stringValue: 'technician' } } : {
        assignedTechnicianId: { stringValue: 'tech' }, status: { stringValue: status },
      };
      return Response.json({ fields });
    },
  });
  const request = { headers: { authorization: 'Bearer verified' } };
  assert.equal((await authorize(request, 'case-1', true, 'p1')).uid, 'tech');
  assert.equal(reads.length, 2);
  status = 'RESUELTA'; await assert.rejects(authorize(request, 'case-1', true, 'p1'), { status: 403 });
  await assert.rejects(authorize({ headers: {} }, 'case-1', false), { status: 401 });
});
