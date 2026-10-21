# CampusFix: Local Evidence Storage

## Installation and startup

Use Flutter `3.47.5`, Dart `3.13.4` and Node.js `24.19.0`. From the checkout root:

```text
flutter pub get --enforce-lockfile
npm ci --prefix services/local_evidence
npm run start:app --prefix services/local_evidence
```

The launcher checks runtime pins and starts the local service plus Flutter on
`http://127.0.0.1:8080`. It leaves existing listeners untouched and closes only
its own processes when stopped. Authentication and metadata use the configured
Firebase project; image bytes use this checkout's `local_storage/evidence/`.
Reviewed Firestore rules and indexes must be deployed separately for real Firebase.
No administrative credential file is required or included.

The service can also run independently with `npm start --prefix services/local_evidence`.
Flutter then runs with `flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080`.
`GET http://127.0.0.1:8787/health` checks service availability.

## Local demonstration

Install the emulator tooling and put Java 21 on the terminal's `PATH`:

```text
npm ci --prefix tool/firestore_tests
npm run demo --prefix services/local_evidence
```

The launcher starts Auth on `127.0.0.1:9099`, Firestore on `127.0.0.1:8085`,
photographs on `127.0.0.1:8787` and Flutter on `127.0.0.1:8080`. It seeds only
`demo-campusfix`. Fixture execution refuses real projects or non-local hosts.
For a server without opening Chrome, use `node tool/start_local.mjs --demo --serve`.

| Demo account | Role |
| --- | --- |
| `reporter-demo@campusfix.test` | Reporter with two reports. |
| `technician-demo@campusfix.test` | Technician assigned to `demo-assigned` in attention. |
| `other-demo@campusfix.test` | Reporter without access to those reports. |
| `admin-demo@campusfix.test` | Administrator detail access. |

All demo accounts use `CampusFixDemo123!`. The assigned case opens at
`http://127.0.0.1:8080/#/incidents/demo-assigned` after signing in. **Mi trabajo**
also accepts an existing incident ID. Fixtures prepare assignments and states;
the application does not implement assignment or lifecycle management.
The included `demo-report/demo-photo` image is a synthetic fixture.

## Configuration

| Setting | Default | Behavior |
| --- | --- | --- |
| `LOCAL_EVIDENCE_HOST` | `127.0.0.1` | Loopback only: `127.0.0.1`, `localhost` or `::1`. |
| `LOCAL_EVIDENCE_PORT` | `8787` | Integer from 1 to 65535. |
| `LOCAL_EVIDENCE_ALLOWED_ORIGINS` | `http://127.0.0.1:8080,http://localhost:8080` | Explicit local HTTP/HTTPS browser origins. |
| `LOCAL_EVIDENCE_PROJECT_ID` | `campus-fix-ucr` | Firebase project used to verify sessions and permissions. |
| `LOCAL_EVIDENCE_EMULATORS` | Disabled | Requires a demo project and both loopback emulator host variables. |
| Flutter `LOCAL_EVIDENCE_URL` | `http://127.0.0.1:8787` | Local origin supplied with `--dart-define` for independent Flutter startup. |

## Authorization, files and retries

`PUT /incidents/{incidentId}/evidence/{evidenceId}` accepts a Firebase bearer ID
token, an image content type and the URL-encoded `X-File-Name` header. Technician
uploads also supply `X-Progress-Id`. Firebase Admin verifies tokens; Firestore
REST reads use the caller's token, preserving database rules and stored roles.
A report owner uploads initial photographs. Only the assigned technician in
`EN_ATENCION` uploads progress evidence. Permissions are checked again after
receiving and decoding bytes. `GET` on the same route requires incident access;
unassociated uploads remain visible only to their uploader. Tokens are never
placed in URLs, files or logs. CORS does not replace token authorization.

Client and server accept single-frame JPEG, PNG and WebP, from 1 through
3 000 000 bytes and up to 40 million pixels. Both decode content; extensions and
MIME declarations alone do not validate a photograph. Files use stable IDs,
relative references and a digest. Atomic directory renames publish bytes with
their metadata; symlinks and path traversal are rejected. Repeating identical
uploads returns the same reference; conflicting occupied IDs return 409.

Browser journals retain pending IDs, descriptions and acknowledged references
for association retries. They contain no tokens or image bytes, are scoped to
the account and clear on sign-out. After a reload before upload acknowledgement,
the original photograph must be selected again. Success clears the journal.
Closing the application or restarting the service does not delete image files.

## Portability and verification

`local_storage/evidence/` is versioned. A clone receives the files present in its
revision. Later photographs require a commit, push and update of the
other clone. Committed photos and metadata share the repository's visibility.
The application and service never run Git commands automatically.

```text
npm test --prefix services/local_evidence
npm run test:integration --prefix tool/firestore_tests
```

Ten service tests verify decoding, limits, CORS, token forwarding, retries and
persistence. The emulator integration verifies real Firebase sessions, protected
uploads/downloads, atomic progress/history/evidence, live updates, permission
revocation and storage copied to a second directory. [Runtime configuration](toolchain.md)
records the full application checks. [Follow-up](incident_followup.md) documents
metadata association and the protected detail route.

- [HTTP service](../services/local_evidence/src/server.mjs).
- [Authorization](../services/local_evidence/src/authorization.mjs).
- [Storage](../services/local_evidence/src/storage.mjs).
- [Portable launcher](../tool/start_local.mjs).
