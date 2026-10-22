import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

// This verification never contacts a real Firebase project or accepts a remote URL.
const origin = 'http://127.0.0.1:5000';
const bundle = new URL('../build/release/campusfix-public/', import.meta.url);
const release = JSON.parse(await readFile(new URL('release.json', bundle), 'utf8'));
assert.equal(release.project, 'campus-fix-ucr');
assert.equal(release.localPhotos, false);
assert.equal(release.firebaseEmulators, false);
for (const file of ['web/index.html', 'web/main.dart.js', 'web/flutter_bootstrap.js',
  'web/manifest.json', 'firebase.json', 'firestore.rules', 'firestore.indexes.json']) {
  const digest = createHash('sha256').update(await readFile(new URL(file, bundle))).digest('hex');
  assert.equal(digest, release.hashes[file], `Release integrity: ${file}`);
}
const compiled = await readFile(new URL('web/main.dart.js', bundle), 'utf8');
for (const marker of ['demo-campusfix', 'http://127.0.0.1:8787', 'CampusFixDemo123!']) {
  assert.equal(compiled.includes(marker), false, `Development marker: ${marker}`);
}
const expected = await readFile(new URL('../build/release/campusfix-public/web/index.html', import.meta.url), 'utf8');
for (const path of ['/', '/incidents/local-preview']) {
  const response = await fetch(`${origin}${path}`, { signal: AbortSignal.timeout(10000) });
  assert.equal(response.status, 200, path);
  assert.equal(await response.text(), expected, `${path} must serve the compiled client`);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.match(response.headers.get('cache-control') ?? '', /no-cache/);
}
for (const path of ['/index.html', '/flutter_bootstrap.js', '/main.dart.js', '/manifest.json']) {
  const response = await fetch(`${origin}${path}`, { signal: AbortSignal.timeout(10000) });
  assert.equal(response.status, 200, path);
  assert.match(response.headers.get('cache-control') ?? '', /no-cache/);
  assert.match(response.headers.get('content-type') ?? '', path.endsWith('.js') ? /javascript/ : path.endsWith('.json') ? /json/ : /html/);
  await response.arrayBuffer();
}
const manifest = await (await fetch(`${origin}/manifest.json`, { signal: AbortSignal.timeout(10000) })).json();
assert.equal(manifest.name, 'CampusFix');
assert.equal(manifest.orientation, 'any');
console.log('Verified local Firebase Hosting: release integrity, development isolation, compiled entry, SPA fallback, assets, MIME types, headers and manifest.');
