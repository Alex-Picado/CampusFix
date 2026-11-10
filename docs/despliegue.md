# Firebase Hosting delivery

## Current status

The user authorized production publication on November 9, 2026. The updated
application is live at https://campus-fix-ucr.web.app with the UCR sign-in design,
role notifications, interactive dashboards and three-party closure approvals.
The new Firestore rules were published and read back to verify their source.
This publication does not perform a Git push or merge. The authenticated
three-role production walkthrough remains separate from the verified public
sign-in page and automated application/emulator checks.

Executed checks: 329 Flutter tests, clean Flutter analysis, a release web build,
and the previously executed 88 Firestore permission tests for these rules. The
published index, JavaScript, manifest and campus photograph return HTTP 200 and
match the reviewed build byte for byte. A browser screenshot is saved locally at
`build/evidence/production/ingreso-ucr-publicado.jpg`.

Published Firestore ruleset: `aac15141-0df8-4eb9-9cd0-c057dad3591b`.
Previous ruleset: `bc33e7f0-b8d0-4477-8dc0-e25ad7f55ada`.
Rules SHA-256: `f2b7c67e24d72a6f7f6386fcd67930da3d0315761573726a0e79f2575125911e`.

The combined CLI deploy encountered a 403 on its Service Usage API precheck.
Rules were instead validated, published and verified through the Firebase Rules
service using the existing authorized account; Hosting was published through
the Firebase CLI. No IAM permissions, stored incidents or indexes were changed.

The public client disables local photographs while retaining reports, text
progress, authorized queries, management and live indicators. The local launcher
retains photographs. The cloud-storage requirement remains an explicit exception;
no instructor approval, paid plan or external image provider is assumed.

## Prepare locally

Use Flutter 3.47.9/Dart 3.13.7 and Node 24.19.0 on PATH. From the repository root:

```powershell
flutter analyze --no-pub
flutter test --no-pub
node tool/prepare_release.mjs
```

The tool verifies pinned runtimes and the project, then builds with
`ENABLE_LOCAL_PHOTOS=false`, the production-only `lib/main.dart` entry point and
local web renderer assets. Demo initialization lives separately in
`tool/demo_main.dart`. Ignored `build/release/campusfix-public/` contains:

- `web/`: compiled static client without source tests or local photographs.
- `firebase.json` and `.firebaserc`: standalone Hosting configuration for `web/`
  and project `campus-fix-ucr`, preserving rule/index paths.
- Reviewed `firestore.rules` and `firestore.indexes.json` copies.
- `release.json`: time, runtimes, disabled development capabilities and critical
  file SHA-256 hashes.

The tool performs no deployment or Git operation. Re-running replaces only its
own validated output folder. Do not add emulator builds, image bytes, tokens or
administrative keys. Firebase's public client configuration is not an admin key.

## Local Hosting check

The locked development tooling already supplies Firebase CLI:

```powershell
node tool/firestore_tests/node_modules/firebase-tools/lib/bin/firebase.js `
  emulators:start --config build/release/campusfix-public/firebase.json `
  --project demo-campusfix --only hosting
```

In another terminal run `node tool/check_hosting.mjs`, then review
`http://127.0.0.1:5000`. The check covers entry/fallback responses, assets, MIME
types, headers and manifest. Hosting alone starts no Java process. Quit afterward.
Three-role functional emulator walkthroughs are documented in phase 5.

Headers use a supported RE2 catch-all (`.*`) to avoid the native path-separator
issue observed with global header globs in the Windows emulator. See the
[Firebase Hosting header format](https://firebase.google.com/docs/hosting/full-config#headers).

## Production publication

After user authorization and team review, use the team's existing Firebase login.
From the repository root, after a fresh public build, deploy reviewed rules and
indexes separately from Hosting:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project campus-fix-ucr
firebase deploy --only hosting --project campus-fix-ucr
```

Alternatively specify the standalone bundle config explicitly. Hosting alone does
not install the phase 1 category rules. Wait for indexes to be ready. Preserve
Spark and email/password authentication; do not add administrative secrets to web.

Record the actual URL printed by the CLI. With authorized test accounts, repeat
registration/sign-in, each role's menus, profile, report, classification,
assignment, text progress, resolution, closure, audit, search/filters, indicators
and categories. Check photo notice, sign-out, protected hash-route reload,
desktop/tablet layout and unrelated-user denial. Omit private fields from evidence
and update HU-20 only after these checks pass.

If publication fails, retain its diagnostic and pending status. Hosting release
history can restore the preceding static release; that does not roll back database
writes. Preserve the tested incident schema and rules.

See [traceability](requirements_traceability.md), [architecture and permissions](architecture_delivery.md),
[user manual](user_manual.md), [demonstration](demo_script.md) and
[executed evidence](evidence/parte_4/README.md).
