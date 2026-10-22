import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const output = resolve(root, 'build/release/campusfix-public');

/** Executes a fixed local command, propagating failures without deploying. */
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', windowsHide: true });
  if (result.error || result.status !== 0) throw result.error ?? new Error(`${command} failed (${result.status}).`);
}

/** Builds an explicitly public, non-emulator bundle with no local image bytes. */
async function prepare() {
  run(process.execPath, ['tool/verify_toolchain.mjs']);
  const firebase = JSON.parse(await readFile(join(root, 'firebase.json'), 'utf8'));
  const project = JSON.parse(await readFile(join(root, '.firebaserc'), 'utf8')).projects.default;
  if (project !== 'campus-fix-ucr' || firebase.hosting.public !== 'build/web') {
    throw new Error('Review the Firebase project and web output configuration before packaging.');
  }
  const args = ['build', 'web', '--no-pub', '--release', '--no-web-resources-cdn',
    '--target', 'lib/main.dart', '--dart-define=ENABLE_LOCAL_PHOTOS=false'];
  if (process.platform === 'win32') run(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', `flutter ${args.join(' ')}`]);
  else run('flutter', args);

  // Replacing this tool's own output must never follow a link outside build/.
  await mkdir(dirname(output), { recursive: true });
  const parent = await realpath(dirname(output));
  if (parent !== resolve(root, 'build/release')) throw new Error('Release parent must not be redirected.');
  if (existsSync(output)) {
    if (await realpath(output) !== output || !output.startsWith(`${parent}${sep}`)) {
      throw new Error('Refusing to replace a redirected release directory.');
    }
    await rm(output, { recursive: true });
  }
  await cp(join(root, 'build/web'), join(output, 'web'), { recursive: true });
  const { hosting, firestore } = firebase;
  await writeFile(join(output, 'firebase.json'), `${JSON.stringify({
    hosting: { ...hosting, public: 'web' }, firestore,
    emulators: { hosting: { host: '127.0.0.1', port: 5000 }, ui: { enabled: false } },
  }, null, 2)}\n`);
  for (const file of ['.firebaserc', 'firestore.rules', 'firestore.indexes.json']) {
    await cp(join(root, file), join(output, file));
  }
  const files = ['web/index.html', 'web/main.dart.js', 'web/flutter_bootstrap.js',
    'web/manifest.json', 'firebase.json', 'firestore.rules', 'firestore.indexes.json'];
  const hashes = {};
  for (const file of files) {
    hashes[file] = createHash('sha256').update(await readFile(join(output, file))).digest('hex');
  }
  await writeFile(join(output, 'release.json'), `${JSON.stringify({
    project, localPhotos: false, firebaseEmulators: false,
    generatedAt: new Date().toISOString(),
    flutter: JSON.parse(await readFile(join(root, '.fvmrc'), 'utf8')).flutter,
    node: process.versions.node, hashes,
  }, null, 2)}\n`);
  console.log(`Prepared ${relative(root, output)}. No deployment or Git operation was performed.`);
}

prepare().catch((error) => { console.error(error.message); process.exitCode = 1; });
