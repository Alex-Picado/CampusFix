# CampusFix: Reproducible Toolchain

## Supported project versions

Use these versions when developing or reviewing Part 2. The pins establish a
shared verified environment; they do not install software or change the global
Flutter version automatically.

| Runtime | Pinned version | Configuration |
| --- | --- | --- |
| Flutter | `3.47.5` stable | `.fvmrc` |
| Dart | `3.13.4`, bundled with the pinned Flutter SDK | Do not select a separate Dart SDK for Flutter commands. |
| Node.js | `24.19.0` | `.node-version` |
| npm | `11.17.0` observed during baseline verification | Informational; no Node package dependencies exist in this block. |

The project continues to declare Dart `^3.13.0` in `pubspec.yaml`. The verified
bundled Dart version satisfies that constraint. Flutter directory names are not
version evidence: use `flutter --version --machine` to inspect the active SDK.

## Selecting and checking runtimes

Install or select Flutter `3.47.5` and Node.js `24.19.0` on the current computer.
Keep their executables on `PATH`, then run from the repository root:

```text
node tool/verify_toolchain.mjs
```

The dependency-free verifier reads the checked-in version pins and checks the
running Node.js executable and the Flutter executable on `PATH`. It prints the
bundled Dart version, exits with code 1 on a mismatch or launch failure, and
does not install tools or upgrade dependencies. Flutter's version query may
need write access to its own SDK cache. The check resolves the project files
relative to its script, so it can also be invoked from another directory.

On Windows, the verifier invokes the fixed Flutter version command through
`cmd.exe`, because Flutter is supplied as a batch file. No user-provided command
text is evaluated. The subprocess is hidden and has a 60-second timeout.

FVM is optional. If it is already installed, the checked-in `.fvmrc` supports
selecting this project's Flutter SDK independently of other projects:

```text
fvm install --skip-pub-get
fvm exec node tool/verify_toolchain.mjs
fvm flutter pub get --enforce-lockfile
```

The FVM-managed SDK link and local metadata in `.fvm/` are ignored by Git.
Developers using a manually selected SDK can run the plain `flutter` commands
below instead. Node version selection remains the responsibility of the local
Node installation or version manager; the verifier checks `.node-version`.

## Restoring dependencies and checking a clone

Run the following after verifying the runtime versions:

```text
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

Commit the application lockfile. Dependency restoration must use the checked-in
versions and package hashes. If lockfile enforcement fails, inspect the mismatch
instead of deleting the lockfile or running a general dependency upgrade.

New packages introduced by later blocks require a deliberate dependency change,
an updated lockfile and verification before that block's commit approval. Do not
commit SDK caches, `.dart_tool/`, `.fvm/` or `build/`.

Before integration, update the feature branch with the team's current base using
the agreed Git workflow, review dependency changes and repeat these checks with
the same pins. Passing this baseline does not guarantee compatibility with
changes made later on another branch. Preserve meaningful feature commits when
integrating the delivery.

## Baseline verification on October 21, 2026

The existing application was checked on Windows from branch `JDSM/parte-2`,
following documentation commit `9fe64b6`. No incident features or Dart application
code were changed for these checks.

| Check | Observed result |
| --- | --- |
| `flutter --version --machine` | Flutter `3.47.5`, stable; bundled Dart `3.13.4`. |
| `node --version` | `v24.19.0`. |
| `npm --version` | `11.17.0`. |
| `node --check tool/verify_toolchain.mjs` | Passed. |
| `node tool/verify_toolchain.mjs` | Passed; both active runtimes match their pins. |
| Verifier mismatch scenarios | Passed; incompatible Node.js and Flutter versions each return exit code 1. |
| Verifier invoked from another directory | Passed; project configuration is resolved relative to the script. |
| `flutter pub get --enforce-lockfile` | Passed; `pubspec.yaml` and `pubspec.lock` remain unchanged. |
| `flutter analyze --no-pub` | Passed; no issues found. |
| `flutter test --no-pub` | Passed; 31 tests. |
| `flutter build web --no-pub` | Passed; generated `build/web`. The preliminary WebAssembly check also passed. |

The earlier sandbox failure was caused by restricted access to Flutter's cache
outside the workspace. Rerunning with approved tool access allowed Flutter to
create its normal cache locks. No SDK upgrade or global permission change was
needed. The project's Flutter metadata file `.metadata` remains unchanged.

Dependency restoration reported newer available package versions. They were not
adopted; this block verifies the committed dependency set. The existing tests
cover models and Part 1 presentation/controllers with local repositories. They
do not demonstrate production Firebase authorization or the pending incident
workflows. Service tests, emulator/security tests and a second-computer startup
check remain scheduled for later blocks. The FVM alternative is documented from
its official reference; this baseline used the existing matching SDK, without
installing FVM.

## References

- [FVM project configuration](https://fvm.app/documentation/getting-started/configuration): `.fvmrc` and the ignored `.fvm/` directory.
- [FVM commands](https://fvm.app/documentation/guides/basic-commands): project-scoped installation and execution.
- [Dart dependency restoration](https://dart.dev/tools/pub/cmd/pub-get): application lockfiles and `--enforce-lockfile`.
- [Node child processes](https://nodejs.org/api/child_process.html): Windows batch execution and subprocess timeouts.
