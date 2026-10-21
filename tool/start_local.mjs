import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createConnection } from 'node:net';
import { readConfig } from '../services/local_evidence/src/config.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const windows = process.platform === 'win32';
const demo = process.argv.includes('--demo');
const serve = process.argv.includes('--serve');
const children = [];
const env = { ...process.env, ...(demo ? {
  LOCAL_EVIDENCE_EMULATORS: 'true', LOCAL_EVIDENCE_PROJECT_ID: 'demo-campusfix',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085',
} : {}) };
let stopping = false;

/** Stops only processes created by this launcher, including their Windows child trees. */
function stop() {
  if (stopping) return;
  stopping = true;
  for (const child of [...children].reverse()) {
    if (child.exitCode !== null || child.killed) continue;
    if (windows) spawnSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
    else child.kill('SIGTERM');
  }
}
process.on('SIGINT', stop); process.on('SIGTERM', stop); process.on('exit', stop);

/** Starts a tracked foreground command with no separate visible shell window. */
function start(command, args) {
  const child = spawn(command, args, { cwd: root, env, stdio: 'inherit', windowsHide: true });
  children.push(child);
  child.on('error', (error) => { console.error(error.message); process.exitCode = 1; stop(); });
  return child;
}
function completed(child) { return new Promise((resolve, reject) => {
  child.once('error', reject); child.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`Command exited with ${code}.`)));
}); }
function portOpen(port, host = '127.0.0.1') { return new Promise((resolve) => {
  const socket = createConnection({ host, port });
  socket.setTimeout(500);
  socket.once('connect', () => { socket.destroy(); resolve(true); });
  socket.once('error', () => resolve(false)); socket.once('timeout', () => { socket.destroy(); resolve(false); });
}); }
async function waitPort(port, host) {
  for (let attempt = 0; attempt < 240 && !stopping; attempt++) {
    if (await portOpen(port, host)) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Local listener on port ${port} did not start.`);
}

try {
  const check = spawnSync(process.execPath, ['tool/verify_toolchain.mjs'], { cwd: root, env, stdio: 'inherit', windowsHide: true });
  if (check.status !== 0) throw new Error('Select the pinned runtimes before starting the application.');
  const config = readConfig(env);
  for (const port of [config.port, 8080, ...(demo ? [8085, 9099] : [])]) {
    if (await portOpen(port)) throw new Error(`Port ${port} is in use. Existing listeners were left unchanged.`);
  }
  if (demo) {
    const java = spawnSync(process.execPath, ['tool/firestore_tests/verify_java.mjs'], { cwd: root, env, stdio: 'inherit', windowsHide: true });
    if (java.status !== 0) throw new Error('Java 21 is required for the demo emulators.');
    start(process.execPath, ['tool/firestore_tests/node_modules/firebase-tools/lib/bin/firebase.js',
      'emulators:start', '--config', 'firebase.json', '--project', 'demo-campusfix', '--only', 'auth,firestore']);
    await waitPort(9099); await waitPort(8085);
    await completed(start(process.execPath, ['services/local_evidence/src/seed_demo.mjs']));
  }
  start(process.execPath, ['services/local_evidence/src/main.mjs']);
  await waitPort(config.port, config.host);
  const host = config.host === '::1' ? '[::1]' : config.host;
  const args = ['run', '--no-pub', '-d', serve ? 'web-server' : 'chrome', '--web-hostname', '127.0.0.1', '--web-port', '8080',
    `--dart-define=LOCAL_EVIDENCE_URL=http://${host}:${config.port}`, ...(demo ? ['--dart-define=USE_FIREBASE_EMULATORS=true'] : [])];
  const flutter = windows ? start(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', `flutter ${args.join(' ')}`]) : start('flutter', args);
  await completed(flutter); stop();
} catch (error) { console.error(`Local startup failed: ${error.message}`); process.exitCode = 1; stop(); }
