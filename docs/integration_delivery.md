# Integrated local and public clients

The application has two explicit photograph modes. Both use the same incident
schema, repositories, role checks, lifecycle transactions and live subscriptions.
All destinations open their implemented modules; the former placeholder page and
the obsolete pending-module notice have been removed.

## Public client

Photographs are disabled by default. The normal release does not construct an
`EvidenceRepository` or a local HTTP service, does not observe photograph metadata
and does not select, upload or download image bytes. Reports, text progress,
classification, assignments, resolution, closure, search and indicators remain
available. The report and detail explain the photograph limitation in Spanish.
Existing reports retain their photographs and references for the local client.

```powershell
flutter build web --release --target lib/main.dart --dart-define=ENABLE_LOCAL_PHOTOS=false
```

This is a deliberate delivery limitation, not compliance with the cloud photograph
storage requirement and not evidence of instructor approval. The published
walkthrough must use text-only progress and document that limitation.

## Local client with photographs

Select the pinned runtimes, install locked dependencies and use the existing
launcher. It explicitly enables local photographs:

```powershell
npm ci --prefix services/local_evidence
node tool/start_local.mjs
```

The independent Flutter command requires `--dart-define=ENABLE_LOCAL_PHOTOS=true`.
JPEG, PNG and WebP validation uses the cross-platform Flutter image codec sizing
callback. Direct `ImageDescriptor.width/height` access on encoded images is not
supported by Flutter Web. The file picker is attached to the document while open
and removes itself and its event listeners after completion or cancellation.
Server-side decoding, size limits and authorization remain unchanged.

## Isolated demonstration and verification

Phase 6 isolates emulator initialization in `tool/demo_main.dart`. Production
`lib/main.dart` contains no demo Firebase options or emulator connection branch;
both entry points share the same production dependency composition.

The existing development tooling remains outside the application runtime. Java 21
is required by the Firestore emulator, not by the deployed Flutter application.
No application feature starts Java or requires it from an end user. Test fixtures
target `demo-campusfix` only; real project rules, users and incident data are not
modified by the verification workflow.

```powershell
# Full local photographs, synthetic Auth and Firestore data.
node tool/start_local.mjs --demo --serve

# The public photograph behavior with the same isolated Firebase emulators.
# This does not start the photograph service.
node tool/start_local.mjs --demo --serve --no-photos
```

Use the accounts in [Local evidence](local_evidence.md). For a complete workflow:

1. Register a synthetic reporter and create a report with category and location.
2. In local photo mode, select an image and confirm its association.
3. Sign in as administrator, classify the report and assign the demo technician.
4. Sign in as that technician, start attention, save an advance and resolve with
   a nonblank solution. A progress photograph is optional in local mode.
5. Sign in as administrator and close the resolved case.
6. Review chronological history and global indicators; reload the protected route.
7. Review desktop and tablet layouts and sign out before changing accounts.

The launcher stops only its own processes when quit. Generated build output,
dependency caches and verification logs are ignored. One-off uploaded fixture
files must be removed after verification without deleting existing local images.
Permanent regression tests remain under `test/` and existing service test folders;
the application does not contain synthetic accounts or temporary diagnostic code.

Exact executed checks, real browser captures and remaining delivery limits are in
[Part 4 evidence](evidence/parte_4/README.md) and the phase 5 verification record.
