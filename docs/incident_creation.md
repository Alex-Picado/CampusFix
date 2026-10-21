# CampusFix: Incident Creation

## Overview

`IncidentRepository` validates report submissions and converts the confirmed
result to `Incident`. `IncidentService` obtains the authenticated account and
performs the database transaction. The caller supplies the database and
authentication dependencies through the service constructor.

## Interfaces

| API | Result | Behavior |
| --- | --- | --- |
| `IncidentService(firestore: ..., authService: ...)` | Service instance | Uses the supplied Firestore connection and existing authentication service. |
| `IncidentRepository(incidentService: ...)` | Repository instance | Uses the supplied persistence service. |
| `newIncidentId()` | `String` | Allocates a Firestore document ID locally without writing documents. |
| `create(incidentId: ..., title: ..., description: ..., categoryId: ..., location: ...)` | `Future<Incident>` on the repository | Creates or recovers a matching report and returns its confirmed fields. |

The repository trims the title, description and location. Required text must
remain nonblank. Incident and category IDs must be nonblank single document
segments without surrounding whitespace, dot segments or reserved `__...__`
names. IDs are validated without changing their identity.

The author, initial status, consecutive number and dates are derived inside
the service rather than accepted as submission parameters.

## Transaction

Each submission uses fixed document references before entering the callback:

| Document | Data written |
| --- | --- |
| `counters/incidents` | Incremented `lastSequenceNumber` and matching `lastIncidentId`. |
| `incidents/{incidentId}` | Report fields, authenticated author, `REPORTADA` status and creation/update timestamps. |
| `incidents/{incidentId}/history/created` | The single initial `created` event, its actor, timestamp and resulting `REPORTADA` status. |

The callback first reads the requested incident. For a new report it then reads
the current user's profile, the selected category and the sequence counter.
All reads precede writes. A new submission requires an existing `reporter`
profile and an active category with a nonblank name.

An absent counter starts the sequence at one. An existing counter requires a
positive integer `lastSequenceNumber` and a nonblank `lastIncidentId`; malformed
records are rejected instead of reset. Sequence values cannot exceed
9 007 199 254 740 991, the maximum exactly representable integer in Flutter Web.

The report initially has null priority, technician assignment and resolution.
`createdAt`, `updatedAt` and the history event date use server timestamp
sentinels in the same transaction. The initial event's previous status,
technician references and reason are null. The initial history ID is exposed
as `IncidentService.initialHistoryEventId`.

Firestore can rerun the callback after a read conflict. Its callback contains
only database work: ID allocation, file uploads and presentation effects do
not occur inside it.

## Confirmation and retries

Retain the allocated ID and normalized submission fields until the result is
confirmed. A retry with the same ID and matching stored fields performs no
writes. It preserves the original sequence, dates, history and any subsequent
operational changes to the incident.

The existing document must belong to the authenticated account. Its title,
description, category and location must match the submission. An ID belonging
to another account produces `permission-denied`; an occupied ID with different
submission fields produces `already-exists`. Reusing an ID does not overwrite
an existing report.

After the transaction, the service requests the incident with
`Source.server`. Cached snapshots, snapshots with pending writes and missing
or unresolved timestamps cannot produce a successful return. Confirmed
`Timestamp` values are converted to `DateTime` before model parsing.

A confirmation-read failure can occur after a successful commit. Retrying
with the retained ID recovers the stored report without incrementing the
counter again. A rejected transaction leaves its report, counter update and
initial event uncommitted. No local time estimate substitutes for server
confirmation.

If a failed proposal reports `permission-denied` or `aborted`, the service
checks the server counter before considering another transaction. A confirmed
advance permits a bounded retry with the same IDs. Cached or pending counter
values do not permit retries, and a failed probe preserves the original error.
The limit is three transaction invocations; the SDK can rerun callbacks within
each invocation. [Creation security](incident_security.md) describes the
conditions and verification.

The service checks the authenticated UID before the transaction, before
writes and around confirmation. A changed account cannot become the author
of an earlier submission or receive its returned record. A transaction already
committed before an account change remains attributed to its original author.

## Authorization boundary

Client validation does not grant database access. The committed rule source
authorizes reporter creation only with a valid counter increment and initial
history in the same atomic operation. Owner reads support confirmation and
retry recovery. [Authorized readers](incident_observation.md) provide own
queries and detail, history and progress reads. Other incident mutations remain
denied.
[The report controller](incident_reporting.md) supplies validated drafts,
stable retries and reconciliation through this API. A report form is not yet
connected in the current application.

The creation tests use a controlled database double to execute the production
repository and transaction callback. The double models read conflicts, atomic
commit application and timestamp resolution. It does not run a Firestore
server, enforce security rules or verify network behavior.

## Verification

The creation test suite covers ID allocation, normalized fields, initial data,
existing counters, concurrent distinct submissions, concurrent repeated IDs,
lost confirmations, rejected commits, conflicting payloads, ownership, roles,
categories, malformed counters, numeric limits, category/role changes during
transactions, account changes and confirmed snapshot requirements.

Run the focused suite from the repository root:

```text
flutter test --no-pub test/features/incidents/repositories/incident_creation_test.dart
```

Verified on October 21, 2026, with Flutter `3.47.5` and Dart `3.13.4`:

| Check | Result |
| --- | --- |
| Creation tests | 26 tests passed as part of the full suite. |
| `flutter test --no-pub` | 159 tests passed. |
| Local Firestore rule suite | 53 tests passed, including 29 incident creation tests. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

Creation concurrency and write authorization are verified separately against
the local Firestore emulator using Firebase JavaScript SDK requests. The
suite covers concurrent reporters, repeated IDs and direct requests that
violate the rule conditions. It also retains category and profile regression
checks. No production deployment or Flutter browser integration test is
included in these results.

## References

- [Incident repository](../lib/features/incidents/repositories/incident_repository.dart).
- [Incident service](../lib/features/incidents/services/incident_service.dart).
- [Creation tests](../test/features/incidents/repositories/incident_creation_test.dart).
- [Controlled database and session doubles](../test/support/incident_firestore.dart).
- [Incident model reference](part_2_incidents.md).
- [Shared data contracts](contratos_modulos.md).
- [Creation security and rule verification](incident_security.md).
- [Runtime configuration](toolchain.md).
