import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import { readConfig, verifyRuntime } from '../src/config.mjs';
import { startEvidenceService } from '../src/server.mjs';

/** Creates an isolated fixture and validates its cleanup stays inside its temp parent. */
async function temporaryDirectory(t) {
  const parent = resolve(tmpdir());
  const directory = await mkdtemp(join(parent, 'campusfix-evidence-'));
  t.after(async () => {
    const target = resolve(directory);
    assert.equal(dirname(target), parent);
    assert.ok(basename(target).startsWith('campusfix-evidence-'));
    await rm(target, { recursive: true, force: true });
  });
  return directory;
}

/** Starts a real loopback listener on an ephemeral test port. */
async function service(t) {
  const directory = await temporaryDirectory(t);
  const config = { ...readConfig({}), port: 0, storageDirectory: join(directory, 'evidence') };
  const server = await startEvidenceService(config);
  t.after(() => stop(server));
  return { server, config, url: `http://127.0.0.1:${server.address().port}` };
}

/** Closes only the listener created by the current test. */
async function stop(server) {
  if (!server.listening) return;
  await new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
    server.closeIdleConnections();
  });
}

test('Resolves defaults from the checkout even when started from another directory', async (t) => {
  const directory = await temporaryDirectory(t);
  const configUrl = new URL('../src/config.mjs', import.meta.url).href;
  const child = spawnSync(process.execPath, ['--input-type=module', '--eval',
    `import { readConfig, verifyRuntime } from ${JSON.stringify(configUrl)};
     verifyRuntime(); console.log(JSON.stringify(readConfig({})));`],
  { cwd: directory, encoding: 'utf8', windowsHide: true, timeout: 10_000 });
  assert.equal(child.status, 0, child.stderr);
  const config = JSON.parse(child.stdout);
  assert.equal(config.host, '127.0.0.1');
  assert.equal(config.port, 8787);
  assert.equal(config.storageDirectory,
    fileURLToPath(new URL('../../../local_storage/evidence/', import.meta.url)));
});

test('Normalizes configured local origins and rejects invalid bindings and origins', () => {
  const config = readConfig({ LOCAL_EVIDENCE_HOST: '::1', LOCAL_EVIDENCE_PORT: '8790',
    LOCAL_EVIDENCE_ALLOWED_ORIGINS: 'http://localhost:8081/, http://localhost:8081, https://[::1]:8080' });
  assert.deepEqual(config.allowedOrigins, ['http://localhost:8081', 'https://[::1]:8080']);
  assert.equal(config.port, 8790);
  assert.ok(Object.isFrozen(config.allowedOrigins));
  for (const port of ['0', '65536', 'abc', '8787.5', '', '-1']) {
    assert.throws(() => readConfig({ LOCAL_EVIDENCE_PORT: port }));
  }
  assert.throws(() => readConfig({ LOCAL_EVIDENCE_HOST: '0.0.0.0' }));
  for (const origin of ['', 'null', 'http://example.com', 'http://localhost.evil.test',
    'http://user:password@localhost', 'http://localhost/path', 'http://localhost/?token=x']) {
    assert.throws(() => readConfig({ LOCAL_EVIDENCE_ALLOWED_ORIGINS: origin }));
  }
});

test('Rejects a Node.js version different from the project pin', () => {
  assert.doesNotThrow(() => verifyRuntime());
  assert.throws(() => verifyRuntime('0.0.0'), /does not match/);
});

test('Serves health and explicit local browser preflight without exposing storage paths', async (t) => {
  const { url } = await service(t);
  const health = await fetch(`${url}/health`, { headers: { Origin: 'http://127.0.0.1:8080' } });
  assert.equal(health.status, 200);
  assert.equal(health.headers.get('access-control-allow-origin'), 'http://127.0.0.1:8080');
  assert.equal(health.headers.get('cache-control'), 'no-store');
  assert.equal(health.headers.get('x-content-type-options'), 'nosniff');
  assert.deepEqual(await health.json(), { status: 'ok', service: 'campusfix-local-evidence' });
  const preflight = await fetch(`${url}/health`, { method: 'OPTIONS',
    headers: { Origin: 'http://localhost:8080', 'Access-Control-Request-Method': 'GET' } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-methods'), 'GET, PUT, OPTIONS');
});

test('Rejects unlisted, remote and opaque browser origins', async (t) => {
  const { url } = await service(t);
  for (const origin of ['http://localhost:8081', 'https://example.com', 'null']) {
    const response = await fetch(`${url}/health`, { headers: { Origin: origin } });
    assert.equal(response.status, 403);
    assert.equal(response.headers.get('access-control-allow-origin'), null);
    assert.deepEqual(await response.json(), { error: 'origin_not_allowed' });
  }
});

test('Keeps existing files across restarts and provides no public file or upload route', async (t) => {
  const { server, config, url } = await service(t);
  const file = join(config.storageDirectory, 'private.png');
  await writeFile(file, 'private fixture contents');
  for (const path of ['/local_storage/evidence/private.png', '/incidents/report-1/evidence/photo-1']) {
    for (const method of ['GET', 'PUT']) {
      const response = await fetch(`${url}${path}`, { method });
      assert.equal(response.status, path.startsWith('/incidents/') ? 401 : 404);
      assert.deepEqual(await response.json(), { error: path.startsWith('/incidents/') ? 'unauthenticated' : 'not_found' });
    }
  }
  await stop(server);
  const restarted = await startEvidenceService(config);
  t.after(() => stop(restarted));
  assert.equal(await readFile(file, 'utf8'), 'private fixture contents');
});
