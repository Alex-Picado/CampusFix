import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const loopbackHosts = new Set(['localhost', '127.0.0.1', '::1']);
const storageDirectory = fileURLToPath(new URL('../../../local_storage/evidence/', import.meta.url));

/** Rejects a runtime mismatch without installing or changing Node.js. */
export function verifyRuntime(actual = process.versions.node) {
  const expected = readFileSync(new URL('../../../.node-version', import.meta.url), 'utf8').trim();
  if (actual !== expected) {
    throw new Error(`Node.js ${actual} does not match ${expected} in .node-version.`);
  }
}

/** Normalizes a configured HTTP origin and limits browser access to loopback. */
function localOrigin(value) {
  const origin = new URL(value);
  const hostname = origin.hostname === '[::1]' ? '::1' : origin.hostname;
  if (!['http:', 'https:'].includes(origin.protocol) || !loopbackHosts.has(hostname) ||
      origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash) {
    throw new Error('Allowed origins must be local HTTP origins without credentials, paths or queries.');
  }
  return origin.origin;
}

/** Reads validated service settings; storage is always relative to this checkout. */
export function readConfig(env = process.env) {
  const emulatorMode = env.LOCAL_EVIDENCE_EMULATORS === 'true';
  const projectId = env.LOCAL_EVIDENCE_PROJECT_ID ?? 'campus-fix-ucr';
  if (!/^[a-z][a-z0-9-]+$/.test(projectId)) throw new Error('Invalid Firebase project ID.');
  if (emulatorMode && (!projectId.startsWith('demo-') ||
      !/^127\.0\.0\.1:\d+$/.test(env.FIRESTORE_EMULATOR_HOST ?? '') ||
      !/^127\.0\.0\.1:\d+$/.test(env.FIREBASE_AUTH_EMULATOR_HOST ?? ''))) {
    throw new Error('Emulators require a demo project and explicit loopback Auth and Firestore hosts.');
  }
  if (!emulatorMode && (env.FIREBASE_AUTH_EMULATOR_HOST || env.FIRESTORE_EMULATOR_HOST)) {
    throw new Error('Emulator hosts require explicit LOCAL_EVIDENCE_EMULATORS mode.');
  }
  const host = env.LOCAL_EVIDENCE_HOST ?? '127.0.0.1';
  const portText = env.LOCAL_EVIDENCE_PORT ?? '8787';
  if (!loopbackHosts.has(host)) throw new Error('LOCAL_EVIDENCE_HOST must identify a loopback interface.');
  if (!/^\d+$/.test(portText) || Number(portText) < 1 || Number(portText) > 65535) {
    throw new Error('LOCAL_EVIDENCE_PORT must be an integer from 1 to 65535.');
  }
  const configuredOrigins = env.LOCAL_EVIDENCE_ALLOWED_ORIGINS ??
    'http://127.0.0.1:8080,http://localhost:8080';
  const origins = configuredOrigins.split(',').map((value) => value.trim());
  if (origins.some((value) => !value)) throw new Error('Allowed origins cannot be empty.');
  return Object.freeze({
    host,
    port: Number(portText),
    allowedOrigins: Object.freeze([...new Set(origins.map(localOrigin))]),
    storageDirectory,
    projectId,
    emulatorMode,
    firestoreOrigin: emulatorMode ? `http://${env.FIRESTORE_EMULATOR_HOST}` : 'https://firestore.googleapis.com',
  });
}
