# CampusFix: Part 2 - Incidents, Evidence and Progress

## Scope and current status

Jose Daniel owns HU-05, HU-06, HU-07, HU-08 and HU-12. This document records
the agreed scope, acceptance criteria and delivery plan. It does not describe
completed incident functionality.

The baseline was inspected on October 21, 2026, at commit
`34739c64c6a4b23d086e3885696f2e329c8d762a`. The working tree was clean. A remote
fetch confirmed that local `main` matched `origin/main` before creating
`JDSM/parte-2`.

| Area | Baseline status | Part 2 responsibility |
| --- | --- | --- |
| Authentication, sessions, profiles and roles | Implemented in Part 1 | Reuse the existing behavior. |
| Profile editing and administrator user management | Implemented in Part 1 | Preserve existing behavior and tests. |
| Shared navigation and responsive components | Implemented in Part 1 | Connect the incident screens. |
| `Incident` | Fields and constructor exist; serialization is missing | Add conversion and copy operations. |
| `IncidentStatus` and `IncidentPriority` | Stored-value conversion exists | Preserve the existing stored values. |
| `Category` | Model conversion exists; persistence is pending | Add only the reads required by the reporting form. |
| Reports, sequences, personal queries and detail | Not implemented | Implement HU-05, HU-07 and HU-08. |
| Photographs and technician progress | Not implemented | Implement HU-06 and HU-12. |
| Firestore authorization | User rules exist; other collections are denied | Add module-specific rules and indexes. |

Classification, assignment, starting attention, resolution, closure and other
status transitions belong to Christian in Part 3. Category administration,
search, filters, indicators and final publication belong to Daniel in Part 4.
Part 2 will not implement those operations to make demonstrations work.

The existing [module contracts](contratos_modulos.md) remain the source of shared
field names, status values and responsibilities. The local evidence decision
below supersedes their earlier cloud-file-provider and no-custom-server
assumptions only for Part 2 evidence storage.

## Architecture and shared interfaces

Keep `screen -> controller -> repository -> service`, constructor-injected
dependencies and Provider. Controllers use `ChangeNotifier`. Screens must not
access Firestore or the local file API directly. Public classes, methods and new
documentation use English; visible interface text remains Spanish.

| Interface | Planned operations | Boundary |
| --- | --- | --- |
| `IncidentRepository` | `create`, `watchOwn`, `watchById`, `watchHistory`, `watchProgress`, `addProgress` | Only the operations owned by Part 2. |
| `EvidenceRepository` | `upload`, `attachToIncident`, `watchByIncident`, authenticated image loading | File transfer is separate from Firestore metadata. |
| Category reader | `watchActive` | No category administration. |
| Incident detail route | `/incidents/:id` | Require authentication and enforce data authorization. |

Preserve the agreed incident fields, `UserRole.name`, `IncidentStatus.value` and
`IncidentPriority.value`. Document IDs remain separate from stored fields.
Convert Firestore timestamps at the service/repository boundary. Do not replace
pending server timestamps with fabricated dates.

Create the incident, increment `counters/incidents` by exactly one, and record
the initial `created` event in one transaction. Prepare stable operation IDs
before retryable work and reuse them when reconciling an uncertain result.
Keep file uploads outside the transaction.

Personal queries filter by the authenticated UID in Firestore. Restrict detail,
history, progress and evidence reads to the owner, assigned technician or
administrator. Display only authorized profile information; retain stable actor
IDs when another person's profile cannot be read under the existing user rules.

Only the assigned technician may add progress while the incident is
`EN_ATENCION`. Save the progress, its evidence references and the `progressAdded`
event atomically in Firestore. HU-08 comments are the progress descriptions, as
defined in the module contracts. History records are immutable from the client.

Controllers own and cancel their subscriptions. Leaving a module, signing out
or changing accounts must clear private state and ignore stale callbacks.
Distinguish loading, empty, read-error, save-error and confirmed-success states.
Preserve drafts and pending attachment references on recoverable failures and
prevent overlapping submissions.

## Local evidence storage decision

Keep Firebase Authentication and Cloud Firestore. Replace only the photograph
storage provider: neither Firebase Storage nor Cloudinary will be used for
Part 2 files.

The assignment describes cloud evidence storage. This records the requested
local substitution; academic acceptance has not been verified. It does not
claim compliance with the original cloud-file-storage requirement.

Flutter Web cannot write directly into the repository's filesystem. Include a
local Node.js service and the versioned `local_storage/evidence/` folder so a
clone contains the service and photographs committed with that revision.

| Decision | Planned behavior |
| --- | --- |
| Service address | Default to `127.0.0.1:8787`; allow client and service configuration. |
| Authentication | Send a Firebase ID token; verify it using Firebase Admin. |
| Authorization | Read relevant Firestore documents through REST with the caller's token, preserving Firestore rules. |
| Credentials | Do not require or commit administrative service-account keys. |
| API | Upload and download by incident ID and stable evidence ID; no public directory listing. |
| Validation | Accept JPEG, PNG and WebP; validate content and size in the client and service. |
| Size limit | At most 3 000 000 bytes per file, inclusive. |
| Paths | Use generated IDs as physical names and portable relative references. |
| Metadata | Preserve the evidence fields with `provider: local`; do not store image bytes or Base64 in Firestore. |
| Retries | Retain uploaded-file references when association fails; avoid duplicate files and attachments. |
| Persistence | Preserve files across browser refreshes and local-service restarts. |

Photographs included in a delivery will be versioned after approval. Newly
uploaded files reach another computer only after an approved commit and push,
followed by updating that clone. GitHub is not a live upload or synchronization
service. Missing files must produce a recoverable message.

Authentication protects service endpoints. A photograph committed to Git also
has the visibility of the repository and its history; endpoint access controls
do not protect the raw versioned copy.

Provide portable startup instructions and emulator-only demonstration data,
including categories and an assigned incident already in attention. Fixtures
must not create production assignments or bypass production rules. Final
Internet publication is outside this delivery; a local-only service is not a
remotely hosted evidence endpoint.

## Acceptance criteria and required evidence

Implementation and functional verification below are pending in this first
documentation block. Existing Part 1 results are historical evidence, not
results from a new execution.

| Story or concern | Acceptance criteria | Required verification |
| --- | --- | --- |
| HU-05: create an incident | Validated fields, ID, unique sequence, authenticated creator, server dates and `REPORTADA` status. | Concurrent reports receive distinct IDs and numbers, with one initial event each. Retry an uncertain result without duplication. |
| HU-06: attach evidence | Valid photographs remain associated after reload and service restart. Failed operations allow retry. | JPEG/PNG/WebP, exact size limit, oversized/invalid content, stopped service, upload retry and association retry. |
| HU-07: personal reports | The reporter sees only their own reports. | Two reporters, an unauthorized collection query and direct access to another reporter's case. |
| HU-08: detail and history | Authorized users see state, responsible actors, photographs, progress comments and chronological history. | Live updates, missing/inaccessible cases, immutable history and denied reads by unrelated accounts. |
| HU-12: technician progress | Each advance records author, server date, description and optional evidence. | Allow the assigned technician in attention; reject unrelated actors and incompatible states. Verify atomic records and retries. |
| Sessions and errors | Clear loading/success/error messages; account changes remove private data. | Sign out or switch accounts during reads and writes; verify cancellation and late-response isolation. |
| Security | Firestore and the service independently enforce permissions. | Alter UID, role, sequence, dates, events, evidence IDs and paths in direct requests; verify rejection. |
| Portability and layout | A fresh clone runs the service and uses its committed photographs. | Second checkout, refresh, service restart, desktop and tablet layouts. |
| Regression | Part 1 functionality remains operational. | Analysis, Flutter tests, web build, local-service tests and Firestore emulator tests. |

Use emulator tests for concurrency and authorization. UI visibility and mocked
repositories do not prove effective security. Record runtime versions, commands
and actual outcomes. Distinguish automated results, confirmed manual checks and
pending verification.

## Runtime compatibility and verification status

The installed SDK cache inspected during planning identifies Flutter `3.47.5`
and Dart `3.13.4`, although its directory name contains `3.47.2`. The project's
Dart constraint, `^3.13.0`, accepts the inspected Dart version. Node.js reported
`24.19.0` during planning.

Flutter execution was blocked during planning because its lock file is in the
SDK cache outside the writable workspace. Runtime startup and full baseline
verification remain pending. Block 2 will address tool access and verify the
baseline before feature implementation.

Pin Flutter `3.47.5` and Node.js `24.19.0` during block 2. Preserve the existing
dependency lockfile and lock added dependencies. Do not perform a general
dependency upgrade or change the global Flutter installation for this module.
Review dependency changes and rerun verification before integration.

Required final checks are `flutter analyze`, `flutter test`, `flutter build web`,
local-service tests and Firestore emulator integration/security tests. Record
environment failures separately from application failures. Results documented
in [Authentication and sessions](autenticacion.md) have not been rerun by this
documentation change.

## Incremental delivery and Git approval workflow

Work on `JDSM/parte-2`, created from updated `main`. Git rejects the originally
requested `JDSM/parte 2` because it contains a space. Use the existing local
Jose Daniel Git identity for commits.

Prepare only the current block. Before each commit/push pair, present its exact
changes, verification results and commit message. Wait for explicit user
acceptance. One acceptance authorizes only that presented commit and its
immediate push to `origin/JDSM/parte-2`, not later commits. Confirm the push
before preparing the next block. If it fails, recover the same commit without
creating a duplicate or continuing to the next block.

The first push will explicitly set the feature branch upstream. Keep the
individual commits for Christian's review and eventual integration; do not
push feature work to `main` or squash the delivery into a single commit.

Each block must be coherent and include relevant verification. This table is
the planned order, not a claim that commits exist or have been pushed. At this
initial checkpoint, block 1 is prepared for approval; blocks 2-24 are planned.

| Block | Proposed commit message |
| --- | --- |
| 1 | `docs(incidents): document part two scope and acceptance criteria` |
| 2 | `build(toolchain): pin runtimes and verify the project baseline` |
| 3 | `feat(incidents): implement incident serialization` |
| 4 | `feat(incidents): add evidence progress and history models` |
| 5 | `feat(incidents): read active categories for incident reports` |
| 6 | `feat(incidents): create reports with transactional sequences` |
| 7 | `feat(incidents): secure report creation counters and initial history` |
| 8 | `feat(incidents): observe authorized reports and incident details` |
| 9 | `feat(incidents): manage report drafts and submission state` |
| 10 | `feat(incidents): add the incident reporting form` |
| 11 | `feat(incidents): connect the personal incident list` |
| 12 | `build(evidence): add the local service and versioned storage folder` |
| 13 | `feat(evidence): authorize local file access with Firebase sessions` |
| 14 | `feat(evidence): implement validated uploads and protected downloads` |
| 15 | `test(evidence): cover persistence validation and upload retries` |
| 16 | `feat(evidence): add photo selection and authenticated requests` |
| 17 | `feat(evidence): persist attachments with recoverable retries` |
| 18 | `feat(evidence): display incident photographs and loading states` |
| 19 | `feat(incidents): display live details comments and history` |
| 20 | `feat(incidents): save authorized technician progress atomically` |
| 21 | `feat(incidents): add the technician progress form` |
| 22 | `test(incidents): verify concurrency permissions and complete workflows` |
| 23 | `build(incidents): add portable startup and demonstration fixtures` |
| 24 | `docs(incidents): record verification evidence and integration guidance` |

## Technical references

- [Flutter Web filesystem limitations](https://docs.flutter.dev/platform-integration/web/faq): why uploads require a local service.
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions): atomic creation and concurrent sequences.
- [Firestore security conditions](https://firebase.google.com/docs/firestore/security/rules-conditions): related-document authorization.
- [Firebase ID token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens): local-service authentication.
- [Firestore REST authentication](https://firebase.google.com/docs/firestore/use-rest-api): caller-token access subject to rules.
- [Security Rules unit tests](https://firebase.google.com/docs/rules/unit-tests): emulator-based verification.
