# CampusFix: Incident Management (Part 3)

## Delivered scope

Administrators open **Gestión**, and technicians open **Mi trabajo**. Both queues
observe confirmed Firestore snapshots. Opening a case reuses the existing detail,
photographs, progress and chronological history. Every available lifecycle action
appears in **Atención y gestión**. Form validation, pending writes, success, read
errors, write errors and retry controls have distinct states.

| Story | Behavior | Implementation | Verification evidence |
| --- | --- | --- | --- |
| HU-09 | Administrative queue, active category and priority classification before assignment | `IncidentQueueScreen`, `IncidentWorkflowController`, `IncidentWorkflow.changes`, `watchAll` | Workflow service tests; screen classification validation; rule tests for inactive categories, invalid priorities and missing classification |
| HU-10 | Assignment exclusively to stored technicians; own technician queue | Administrator profile selection, transactional role validation, `watchAssigned` with a server UID filter | Queue observation tests; UI assignment; direct SDK tests for unauthorized assignees and foreign queries |
| HU-11 | Only the assigned stored technician starts an assigned case | `started` command, role/state checks in the service and rules | Full lifecycle UI test; unrelated technician and role-downgrade tests |
| HU-13 | Assigned technician resolves only during attention, with a nonblank solution | `resolved` command and validated solution form | UI required-solution validation; service tests; invalid resolution and actor rule tests |
| HU-14 | Administrator closes only resolved cases | `closed` command | UI lifecycle test; direct attempts to close reported/attention cases and technician closure |
| HU-19 | Immutable actor/date/state/assignment audit, atomically associated with every update | Linked history event, `lastWorkflowEventId`, server timestamps and `getAfter()` validation | Atomicity, forged actor/date/assignment, protected-field, orphan-event and event-reuse tests; two-session live listener test |
| Alternative states | Rejection during review; cancellation before resolution; reopening resolved or closed cases, always with a reason | Shared transition matrix, command forms and independent rule validation | Service and rule matrices; UI cancellation validation; UI reopening with previous solution visible |

## Architecture and API

`IncidentQueueScreen` and `IncidentWorkflowPanel` obtain their controllers through
Provider. Each ChangeNotifier owns its subscriptions and receives repositories
and session dependencies through its constructor. Screens render forms and invoke
controller methods; state transitions live in `IncidentWorkflow`, and persistence
lives in `IncidentService` behind `IncidentRepository`.

The repository exposes:

- `watchAll()`: administrator queue, ordered locally by last update then sequence.
- `watchAssigned(userId: uid)`: technician queue with `assignedTechnicianId == uid`
  applied in Firestore. Another authenticated UID is rejected before querying.
- `applyWorkflow(incidentId: ..., command: ...)`: validates identifiers and forwards
  one immutable `IncidentWorkflowCommand` containing the event ID, expected status,
  expected update date, action and applicable category/priority/technician/reason.

A command uses the existing English action codes: `classified`, `assigned`,
`started`, `resolved`, `closed`, `rejected`, `cancelled` and `reopened`.
`IncidentWorkflow.changes()` implements the matrix in
[Shared contracts](contratos_modulos.md#estados-actores-y-auditoría).

## Atomicity, concurrency and retries

The service fixes the incident and event references before its retryable
transaction. Inside the callback it rereads the incident, actor's stored role,
existing event and applicable category/assignee documents before writing. A stale
expected state or update date fails instead of overwriting a newer classification.
The incident's protected identity, author, title, description, location, sequence
and creation date are preserved.

Each successful operation writes a new history event and sets the optional
`lastWorkflowEventId` incident metadata to that event's ID. Rules validate the
incident-to-event and event-to-incident links in both directions. A standalone
incident update, standalone event, extra orphan event or reused ID fails. Existing
history remains immutable. The rule suite uses direct SDK batches to demonstrate
that these protections do not depend on hidden buttons or Flutter validation.

After a transaction, an explicit server read confirms the event and timestamp.
If acknowledgement is lost, the controller retains the same command in memory
and freezes the form. **Reintentar el mismo cambio** compares the existing event's
actor, action, original state and normalized payload instead of replaying it.
There are no file uploads, UI effects or new ID allocations inside the transaction.
Confirmed validation/permission failures unlock the form. Read updates do not
clear a write error. Pending workflow commands last for the lifetime of that view;
a new view reads confirmed incident/history state before another action.

## Reopening and audit extensions

Reopening returns `RESUELTA` or `CERRADA` to `EN_REVISION`. It clears the current
solution, technician and priority. A new classification is required before
assignment. The `REABIERTA` enum remains available for compatibility but is not
emitted by this flow. Rejection and cancellation are terminal in this matrix;
reassignment during attention is not exposed.

Lifecycle history retains the original eight fields and adds:

- `details`: category ID, stored priority, technician ID and normalized reason;
  inapplicable values are null. This preserves classification and retry payloads.
- `previousResolutionDescription`: the solution before reopening, otherwise null.

The detail view shows actor identity, date, before/after states, assignment
changes, category/priority, reason and previous solution. Existing creation and
progress events still parse without these optional extensions. No collection
migration or administrative client credentials are needed.

## Session lifecycle and access

Queue and workflow instances are bound to both UID and role. Sign-out, role loss
or account changes clear private records, pending commands, selections and
messages, cancel subscriptions and invalidate late callbacks. Opening detail
pauses the covered queue; returning restarts its confirmed observation. The
protected detail route retains its own session checks. Service observations also
terminate when authentication changes.

Administrators can list incidents. Technicians can list only queries constrained
to their own assignment. Reporter queries and detail access retain their previous
permissions. Category administration and indicators remain outside Part 3.

## Reproducing the demonstration

Use the pinned Flutter and Node versions and Java 21 from
[Runtime configuration](toolchain.md). Restore the locked dependencies and run:

```text
node tool/start_local.mjs --demo --serve
```

Open the local application at `http://127.0.0.1:8080` and use the emulator accounts
in [Local evidence storage](local_evidence.md). As `admin-demo@campusfix.test`, open
**Gestión**, choose an initially reported case, classify it and assign
`technician-demo`. In a separate browser session, use
`technician-demo@campusfix.test`, open **Mi trabajo**, start attention and write a
solution. The administrator can observe the updates, close the case and reopen it
with a reason. Check the previous solution and assignment change in history.
Demo accounts use `CampusFixDemo123!` and exist only in the local emulators.

Tests load the repository's rule source into the local `demo-campusfix` emulator;
production rules must be reviewed and deployed separately before using this
workflow against real Firebase. No production deployment is part of these checks.

## Verification on October 21, 2026

See [Recorded verification](evidence/part_3_checks.txt) for command results.
Flutter `3.47.5` / Dart `3.13.4`, Node `24.19.0` and Java `21.0.12.1` were used.
Node and Java were prepared in temporary folders; the system runtimes were left
unchanged. All checks use the existing lockfiles without dependency upgrades.

The workflow adds nine transaction tests, two observation tests and six screen
and session tests. Sixteen new emulator tests cover the independent security
boundary. The existing photo test now also covers ordinary filenames and invalid
control/path characters; its production validation already handled these inputs.

Verification sources:

- [Transaction and concurrency tests](../test/features/incidents/repositories/incident_workflow_test.dart).
- [Live observation tests](../test/features/incidents/repositories/incident_observation_test.dart).
- [Screen and session tests](../test/incident_management_screen_test.dart).
- [Direct SDK security tests](../tool/firestore_tests/incident_workflow.rules.test.mjs).
