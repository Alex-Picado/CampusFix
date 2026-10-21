# CampusFix: Incident Creation Security

## Authorization

The rules in `firestore.rules` validate report creation independently of the
Flutter client. The reporter role comes from `users/{request.auth.uid}`.
Client-supplied roles and token role claims do not replace the stored profile.

| Path | Permitted operations | Conditions |
| --- | --- | --- |
| `incidents/{incidentId}` | Create | Stored reporter profile, valid initial fields, matching counter increment and initial history in the same atomic operation. |
| `incidents/{incidentId}` | Get | Authenticated author, stored administrator, or currently assigned stored technician. Valid stored profiles may probe absent IDs. |
| `incidents/{incidentId}` | List | Stored reporter role with a query constrained to its own `createdByUserId`. |
| `counters/incidents` | Get | Stored reporter profile, including the absent-counter case. |
| `counters/incidents` | Create or update | Exact counter schema and a matching new report in the same atomic operation. |
| `incidents/{incidentId}/history/created` | Create | Valid initial event accompanying the creation of its parent report. |
| `incidents/{incidentId}/history/{eventId}` and `progress/{progressId}` | Get or list | Existing parent incident and the same detail authorization. |

Unfiltered or foreign-owner incident queries, incident updates/deletion,
history updates/deletion and counter listing/deletion are denied by these rules.
Other counter documents, progress entries and evidence records have no write
grant. Existing profile and active-category authorization conditions are unchanged.

[Incident observation](incident_observation.md) documents reader interfaces,
session cleanup, parent authorization and the own-query index.

## Initial report validation

A report must contain exactly the fields documented in
[Incident models](part_2_incidents.md). Required title, description and location
values must be nonblank strings. Category references must be valid document
IDs, and the referenced category must be active with a nonblank name.

The author must match `request.auth.uid`. The initial status is `REPORTADA`;
priority, assigned technician and resolution are explicitly null.
`createdAt` and `updatedAt` must be timestamps equal to `request.time`.
Unknown fields and missing required fields are rejected.

Incident IDs and referenced document IDs are single path segments without
surrounding whitespace, dot segments or reserved `__...__` names. The sequence
is an integer from 1 through 9 007 199 254 740 991.

## Related writes

The rules inspect the [post-write document state](https://firebase.google.com/docs/firestore/security/rules-conditions#access_other_documents)
with `getAfter()` to validate all three records before an atomic operation can
commit. Both transactions and complete validated write batches satisfy this
boundary.

The incident requires an incremented `counters/incidents` document that points
to its ID and sequence. An absent counter starts at one; an existing valid
counter advances by exactly one. The counter has exactly two fields:
`lastSequenceNumber` and `lastIncidentId`. Malformed existing counters cannot
be reset or repaired through a creation request.

The counter requires a report that was absent before the operation and exists
after it, with the same sequence and authenticated creator. Referencing an
existing report cannot authorize an increment. A single increment cannot be
shared by multiple new reports.

The incident also requires a new `history/created` document. Its fields must
match the initial event contract: authenticated actor, request timestamp,
`created` action, null previous status, `REPORTADA` resulting status and null
technician references and reason. The event requires a new parent report in
the same operation. An orphan event cannot be overwritten, and initial history
cannot be added later to an existing parent.

Incomplete or inconsistent sets of writes are rejected as a whole. A failure
does not leave a partial counter increment, incident or initial event.

## Counter contention

`IncidentService.create()` preserves the same incident and initial history IDs
through retries. Firestore SDK retries handle ordinary transaction conflicts.
The service also handles a rejected stale counter proposal with a bounded
verification step:

1. The failed callback must have proposed a sequence for a new report, and the
   error must be `permission-denied` or `aborted`.
2. A `Source.server` counter read must confirm an integer at least as large as
   the proposed sequence, within the supported numeric range and accompanied
   by a nonblank incident ID.
3. Cached or pending snapshots cannot authorize a retry. A failed probe
   preserves the original transaction error.
4. The service rechecks the session and repeats the complete transaction,
   including profile, category and counter validation.

The service makes at most three transaction invocations. The SDK can rerun a
callback within an invocation. No retry weakens server authorization. An ID
already confirmed for the same submission is recovered without new writes.

## Verification

The rule suite uses Java `21.0.9`, the pinned Node.js runtime and the local
Firestore emulator at `127.0.0.1:8085`, under the explicit `demo-campusfix`
project. Run it from the repository root:

```text
npm ci --prefix tool/firestore_tests
npm test --prefix tool/firestore_tests
```

Verified on October 21, 2026:

| Check | Result |
| --- | --- |
| Local rule suite | 53 tests passed: 29 creation, 14 read and 10 category/profile tests. |
| Concurrent reporters | Different consecutive numbers and one initial event per report. |
| Concurrent retries of one ID | One incident, one counter increment and one initial event. |
| Flutter suite | 159 tests passed, including 26 creation and 19 observation tests. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

The creation rule tests cover complete and incomplete atomic writes, real
client transactions, concurrent reporters, concurrent repeated IDs, forged
authors and actors, stored roles, invalid categories, field schemas, initial
state, timestamps, counter increments and limits, immutable history, orphan
events, direct read permissions, profile escalation and unrelated writes.

The Node.js rule tests submit raw requests through the Firebase JavaScript SDK.
The Flutter suite separately executes the production repository and service
using controlled transaction doubles, including bounded retry checks. These
suites do not constitute a Flutter browser integration test or a production
deployment.

## References

- [Rule source](../firestore.rules).
- [Creation rule tests](../tool/firestore_tests/incident_creation.rules.test.mjs).
- [Category and profile rule tests](../tool/firestore_tests/categories.rules.test.mjs).
- [Incident service](../lib/features/incidents/services/incident_service.dart).
- [Creation service tests](../test/features/incidents/repositories/incident_creation_test.dart).
- [Incident creation API](incident_creation.md).
- [Runtime configuration](toolchain.md).
- [Firestore string validation](https://firebase.google.com/docs/reference/rules/rules.String).
