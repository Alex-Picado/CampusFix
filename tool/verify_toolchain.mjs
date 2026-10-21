import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const projectRoot = new URL('../', import.meta.url);

/** Reads an exact runtime version from the checked-in project configuration. */
function readPinnedVersion(fileName, property) {
  const content = readFileSync(new URL(fileName, projectRoot), 'utf8');
  const version = property ? JSON.parse(content)[property] : content.trim();

  if (typeof version !== 'string' || !/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error(`${fileName} must specify an exact runtime version.`);
  }

  return version;
}

/** Rejects a runtime mismatch without installing or upgrading any tools. */
function requireVersion(name, actual, expected, configuration) {
  if (actual !== expected) {
    throw new Error(
      `${name} ${actual ?? 'unknown'} does not match ${expected} in ` +
        `${configuration}. Select the pinned version and run this check again.`,
    );
  }
}

/** Reads Flutter's machine-readable version using the current executable PATH. */
function readFlutterVersion() {
  const windows = process.platform === 'win32';
  const command = windows ? (process.env.ComSpec || 'cmd.exe') : 'flutter';
  const args = windows
    ? ['/d', '/s', '/c', 'flutter --version --machine']
    : ['--version', '--machine'];
  const result = spawnSync(command, args, {
    cwd: fileURLToPath(projectRoot),
    encoding: 'utf8',
    timeout: 60_000,
    windowsHide: true,
  });

  if (result.error?.code === 'ETIMEDOUT') {
    throw new Error(
      'Flutter did not report its version within 60 seconds. Check SDK cache ' +
        'write access and whether another Flutter command holds its lock.',
    );
  }

  if (result.error || result.status !== 0) {
    const details = result.error?.message || result.stderr?.trim();
    throw new Error(
      'Flutter could not report its version. Check that Flutter is on PATH ' +
        'and its SDK cache is writable.' +
        (details ? `\n${details}` : ''),
    );
  }

  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error('Flutter did not return valid version information.');
  }
}

/** Checks the active Node.js and Flutter runtimes against their project pins. */
function main() {
  const expectedNode = readPinnedVersion('.node-version');
  const expectedFlutter = readPinnedVersion('.fvmrc', 'flutter');

  requireVersion('Node.js', process.versions.node, expectedNode, '.node-version');
  console.log(`Node.js ${process.versions.node}: matches .node-version`);

  const flutter = readFlutterVersion();
  requireVersion('Flutter', flutter.frameworkVersion, expectedFlutter, '.fvmrc');
  console.log(`Flutter ${flutter.frameworkVersion}: matches .fvmrc`);
  console.log(`Bundled Dart: ${flutter.dartSdkVersion}`);
  console.log('Toolchain verification passed.');
}

try {
  main();
} catch (error) {
  console.error(`Toolchain verification failed: ${error.message}`);
  process.exitCode = 1;
}
