# CampusFix: Runtime Configuration

## Runtime versions

The project specifies exact Flutter and Node.js versions for reproducible
execution. Version files identify the required tools; they do not install or
switch the active runtimes automatically.

| Runtime | Version | Configuration |
| --- | --- | --- |
| Flutter | `3.47.5` stable | `.fvmrc` |
| Dart | `3.13.4`, bundled with Flutter | Included in the selected Flutter SDK. |
| Node.js | `24.19.0` | `.node-version` |
| npm | `11.17.0` in the verified environment | Informational; not independently pinned. |

The Dart constraint in `pubspec.yaml` is `^3.13.0`. The bundled Dart version
satisfies this constraint. `flutter --version --machine` reports the active SDK
and its bundled Dart version.

## Runtime verification

With the required Flutter and Node.js executables on `PATH`, run:

```text
node tool/verify_toolchain.mjs
```

The verifier uses Node.js built-in modules and requires no third-party packages.
It reads `.fvmrc` and `.node-version`, compares them with the active runtimes,
and prints the bundled Dart version. A successful check returns exit code 0;
a mismatch, invalid configuration or Flutter launch failure returns exit code 1
with a diagnostic message.

Configuration paths are resolved relative to the script, so invocation from
another working directory uses the same project settings. On Windows, the
Flutter version command runs through `cmd.exe` because the executable is a
batch file. The subprocess is hidden and has a 60-second timeout.

Flutter requires write access to its SDK cache for normal lock files. If the
version query cannot access that cache, the verifier reports the launch failure
rather than accepting an unverified version.

## Optional FVM configuration

FVM reads the Flutter version from `.fvmrc` and provides project-scoped commands:

```text
fvm install --skip-pub-get
fvm exec node tool/verify_toolchain.mjs
fvm flutter pub get --enforce-lockfile
```

The `.fvm/` SDK link and local metadata are excluded from Git. Node.js version
selection is handled by the local installation or version manager; the verifier
checks the selected version against `.node-version`.

## Dependency restoration and project checks

From the repository root:

```text
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

`pubspec.lock` records package versions and hashes. Lockfile enforcement restores
those dependencies and rejects an inconsistent resolution. Subsequent checks
use `--no-pub` so dependency resolution is not repeated during each command.
The generated `.dart_tool/`, `.fvm/` and `build/` directories are excluded from
version control.

## Verification results

Verified on Windows on October 21, 2026:

| Check | Result |
| --- | --- |
| `flutter --version --machine` | Flutter `3.47.5` stable; bundled Dart `3.13.4`. |
| `node --version` | `v24.19.0`. |
| `npm --version` | `11.17.0`. |
| `node --check tool/verify_toolchain.mjs` | Passed. |
| `node tool/verify_toolchain.mjs` | Passed; both runtimes match their version files. |
| Incompatible runtime versions | Node.js and Flutter mismatches each return exit code 1. |
| Invocation from another directory | Passed; configuration is resolved relative to the script. |
| `flutter pub get --enforce-lockfile` | Passed; dependency declarations and lockfile unchanged. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter test --no-pub` | 50 tests passed. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

The Flutter tests exercise model conversion and presentation/controller behavior
with local repositories. They do not verify deployed Firestore security rules.
The FVM commands above describe the optional setup; the recorded checks used
the matching Flutter SDK directly.

## References

- [Version verifier](../tool/verify_toolchain.mjs).
- [FVM project configuration](https://fvm.app/documentation/getting-started/configuration).
- [FVM commands](https://fvm.app/documentation/guides/basic-commands).
- [Dart dependency restoration](https://dart.dev/tools/pub/cmd/pub-get).
- [Node.js child processes](https://nodejs.org/api/child_process.html).
