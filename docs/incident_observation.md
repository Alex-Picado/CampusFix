# CampusFix: Incident Observation

## Interfaces

`IncidentRepository` exposes live models through the existing
`screen → controller → repository → service` boundary. `IncidentService`
constructs Firestore queries and converts confirmed timestamps to `DateTime`.

| Repository method | Result | Scope and ordering |
| --- | --- | --- |
| `watchOwn(userId: ...)` | `Stream<List<Incident>>` | Authenticated reporter's incidents, newest creation time first, then descending sequence and ascending ID. |
| `watchById(incidentId: ...)` | `Stream<Incident?>` | Authorized document updates; a confirmed absent document emits null. |
| `watchHistory(incidentId: ...)` | `Stream<List<IncidentHistoryEvent>>` | Authorized history in chronological order, using IDs to break date ties. |
| `watchProgress(incidentId: ...)` | `Stream<List<IncidentProgress>>` | Authorized technician progress and comments in chronological order, with ID tie breaks. |

Lists are unmodifiable. Empty confirmed query results produce empty lists.
Invalid document IDs are rejected before opening subscriptions. Malformed
models produce parsing errors instead of fallback records. A model parsing
error can be followed by a valid later snapshot.

`watchOwn()` requires the supplied UID to match the current authentication
session. Its Firestore query uses
`where('createdByUserId', isEqualTo: userId)` and descending `createdAt`
ordering. The repository additionally rejects unexpected foreign authors;
it does not fetch all incidents and hide foreign records locally.

## Confirmed snapshots

The service requests metadata changes and withholds snapshots marked as
cached or containing pending writes. A cached absence is not emitted as a
confirmed missing incident. Server acknowledgement can therefore produce a
new event even if only snapshot metadata changed.

Incident dates require confirmed `createdAt` and `updatedAt` timestamps.
History and progress require a confirmed `createdAt`. Missing, unresolved or
incorrectly typed dates raise `FormatException`; no local estimate is used.

The first confirmed snapshot has a 30-second deadline. If it does not arrive,
the stream reports a Firestore `unavailable` error and closes its subscriptions.
The `initialSnapshotTimeout` constructor argument configures this positive
duration. The deadline is cancelled after the first confirmed value, so an
unchanged authorized document does not produce an idle timeout.

## Session and subscription lifecycle

Each observation owns a Firestore subscription and an authentication
subscription. The service checks the current UID before opening the query,
before delivering values and when authentication changes. Signing out,
switching accounts, authentication observation failure or a terminal source
error closes the observation and cancels both subscriptions.

Pausing document delivery does not pause authentication checks. Cancelling the
consumer subscription also cancels both sources and its initial deadline.
Source errors retain their original exception rather than becoming empty
successful results. Service timestamp-normalization failures terminate the
source observation; downstream model parsing errors are reported separately.

Consumers own the returned subscription and cancel it when their view is
disposed. They must clear displayed private records after session or
authorization errors and discard results belonging to an obsolete view.

```dart
final subscription = repository.watchOwn(userId: profile.id).listen(
  onIncidents,
  onError: onIncidentError,
);

await subscription.cancel();
```

## Own-report list

`MyIncidentsScreen` opens from **Mis incidencias** and owns a
`MyIncidentsController` through Provider. The controller exposes immutable
`incidents`, `isLoading`, `errorMessage` and `isActive` state. `start()` restarts
the UID-filtered repository query. Loading, confirmed empty results and failed
queries have distinct presentations; errors clear previously displayed reports.

Each summary shows its consecutive number, title, Spanish status label,
location and creation time in the viewer's local timezone. The list preserves
the repository's newest-first order. Live snapshots replace changed or removed
records. Account changes, role loss and disposal cancel observation and clear
private state. An invalidated controller cannot be reused for another session.

**Crear incidencia** opens the independently owned report form and cancels the
list query. Returning starts a fresh confirmed query, including reports saved
through the form. Category observation runs only while the form is open.

## Read permissions

| Operation | Authorization |
| --- | --- |
| Own incident query | Stored reporter role and a `createdByUserId` filter equal to the authenticated UID. |
| Existing incident detail | Authenticated author, stored administrator role, or stored technician role currently assigned to that incident. |
| History and progress reads | The same detail authorization and an existing parent incident. |
| Absent incident probe | A stored reporter, technician or administrator profile. |

Unfiltered and foreign-owner reporter queries are rejected. Administrator and
technician detail permissions do not grant incident collection listing.
Reassignment removes the previous technician's access. Token role claims do
not replace stored roles. Orphan subcollections do not grant access, including
to administrators.

These read grants retain the creation invariants described in
[Creation security](incident_security.md). They do not authorize incident
updates, progress writes, evidence access or history mutation.

## Query index

`firestore.indexes.json` declares a collection index for `incidents`, using
ascending `createdByUserId` and descending `createdAt`. History and progress
queries order only by `createdAt` and use its default field index.

The local emulator does not enforce compound indexes, so emulator query
success does not verify a deployed index. This is an
[emulator limitation](https://firebase.google.com/docs/emulator-suite/connect_firestore#indexes).
The index definition is included in the repository; no index or rule deployment
is included in the recorded checks.

## Verification scope

Verified on October 21, 2026, with Flutter `3.47.5`, Dart `3.13.4` and Java `21.0.9`:

| Check | Result |
| --- | --- |
| `flutter test --no-pub` | 174 tests passed, including 19 observation tests and 6 own-list widget tests. |
| `npm test --prefix tool/firestore_tests` | 53 rule tests passed, including 14 read tests. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

Flutter tests exercise production service and repository behavior with
controlled authentication and snapshot sources. They cover query construction,
timestamp normalization, sorting, immutability, metadata acknowledgement,
empty and missing records, malformed data, error propagation, account changes,
paused consumers, cancellation and initial response deadlines.

The Firestore emulator suite separately verifies actual Firebase JavaScript SDK
queries and listeners. It covers role and parent permissions, direct requests,
filtered queries, reassignment, role changes, live own-report additions and
permission errors on an active reassigned detail listener. These checks do not
constitute a Flutter browser integration test.

## References

- [Incident repository](../lib/features/incidents/repositories/incident_repository.dart).
- [Own-list controller](../lib/features/incidents/controllers/my_incidents_controller.dart).
- [Own-list screen](../lib/features/incidents/screens/my_incidents_screen.dart).
- [Presentation tests](../test/incident_report_screen_test.dart).
- [Incident service](../lib/features/incidents/services/incident_service.dart).
- [Observation tests](../test/features/incidents/repositories/incident_observation_test.dart).
- [Controlled snapshot sources](../test/support/incident_observation.dart).
- [Read rule tests](../tool/firestore_tests/incident_reads.rules.test.mjs).
- [Firestore rules](../firestore.rules).
- [Query index definition](../firestore.indexes.json).
- [Runtime configuration](toolchain.md).
