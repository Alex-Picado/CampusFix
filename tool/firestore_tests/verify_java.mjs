import { spawnSync } from 'node:child_process';

// Check the same PATH executable that Firebase CLI uses for the emulator.
const result = spawnSync('java', ['-version'], {
  encoding: 'utf8',
  windowsHide: true,
  timeout: 10_000,
});
const version = `${result.stdout ?? ''}\n${result.stderr ?? ''}`
  .match(/version\s+"(\d+)([^\"]*)"/);

if (result.error || result.status !== 0 || version?.[1] !== '21') {
  process.stderr.write(
    'Firestore rule tests require Java 21 on PATH. Select a Java 21 runtime and retry.\n',
  );
  process.exitCode = 1;
} else {
  process.stdout.write(`Java ${version[1]}${version[2]} verified.\n`);
}
