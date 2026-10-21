# CampusFix: Incident Detail and Follow-up

## Detail and navigation

`/incidents/{id}` passes through `SessionGate`. A direct link waits for sign-in
and profile observation before mounting `IncidentDetailScreen`. The author,
current assigned technician and administrator can read the case. Missing data,
loading and denied access are separate states. Role/account changes invalidate
old subscriptions; late responses cannot populate another account's view.

The screen observes the incident, chronological progress, history and photograph
metadata. It presents description, category identity, priority, location, state,
responsible accounts, confirmed dates and resolution when available. Own account
names come from the existing profile; other responsible accounts retain their
stored identifiers without expanding profile access permissions. Photos use
authenticated byte requests rather than public download URLs. Each progress
entry displays its related optional evidence. Failed image requests have their
own retry action.

**Mis incidencias → Ver detalle** pauses the list query while the route is open.
Returning observes current reports again. Initial photographs can be attached
after creation or from the owner's detail screen.

## Writes and recovery

| Operation | Confirmation and authorization |
| --- | --- |
| `EvidenceRepository.attach` | Owner reporter, existing incident, immutable metadata and server date. A matching existing ID is recovered without rewriting. |
| `IncidentRepository.addProgress` | Assigned stored technician role during `EN_ATENCION`; progress, matching history and optional evidence commit in one transaction. |

Progress uses a stable ID shared with its history document. History retains the
agreed fields, action `progressAdded`, actor, server date and matching description.
The initial event remains `history/created`. Progress does not change the incident
state, assignment, classification or resolution. Metadata and history are immutable.

Files upload outside the Firestore transaction. Failed metadata association
retains the uploaded reference and retries without uploading again. Uncertain
progress submissions freeze their ID, normalized description and optional photo
reference. Retrying recovers a matching saved entry without a second history
event. Conflicting submissions are rejected. [Local storage](local_evidence.md)
describes recovery journals, original-photo reselection and repository portability.

## Verification

The Flutter follow-up tests execute production transaction callbacks with
controlled Firestore responses, including lost confirmations, rejection, retries,
role/state/assignment checks and account changes. Screen tests exercise protected
routes, live comments, loading/errors, photographs, progress retries and tablet
layout. HTTP client tests verify bearer headers, relative paths, account isolation,
image decoding and journal cleanup.

The local Firestore suite has 61 permission tests, including 8 follow-up tests.
The separate integration uses real emulator Auth tokens and Firestore listeners
with the local file service. No rules, indexes or application hosting are deployed
by these checks. [Runtime results](toolchain.md) record executed commands.

- [Detail controller](../lib/features/incidents/controllers/incident_detail_controller.dart).
- [Detail screen](../lib/features/incidents/screens/incident_detail_screen.dart).
- [Follow-up rule tests](../tool/firestore_tests/incident_followup.rules.test.mjs).
- [Integrated workflow](../tool/firestore_tests/evidence.integration.mjs).
