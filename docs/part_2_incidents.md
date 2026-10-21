# CampusFix: Incident Models

## Overview

The incident models represent service reports, technician progress, history
events and photograph metadata as immutable records. Serialization preserves
the field contract and keeps document identifiers separate from stored fields.
Dates are normalized `DateTime` values at the model boundary.

## Incident

`Incident` stores the report's identity, description, category, location, state,
dates and user references.

### Data structure

| Property | Model type | Description |
| --- | --- | --- |
| `id` | `String` | Document identifier supplied separately to `fromMap()`; excluded from `toMap()`. |
| `sequenceNumber` | `int` | Positive consecutive number displayed for the report. |
| `title` | `String` | Short description of the problem. |
| `description` | `String` | Detailed description of the problem. |
| `categoryId` | `String` | Referenced category identifier. |
| `location` | `String` | Location within the campus. |
| `priority` | `IncidentPriority?` | Optional priority, serialized as `BAJA`, `MEDIA` or `ALTA`. |
| `status` | `IncidentStatus` | Report state, serialized using its stored value. |
| `createdAt` | `DateTime` | Creation time. |
| `updatedAt` | `DateTime` | Last modification time. |
| `createdByUserId` | `String` | Identifier of the reporting account. |
| `assignedTechnicianId` | `String?` | Optional assigned technician identifier. |
| `resolutionDescription` | `String?` | Optional resolution description. |

The constructor defaults `status` to `IncidentStatus.reported` (`REPORTADA`).
Priority, assigned technician and resolution default to null.

### Serialization and validation

| API | Behavior |
| --- | --- |
| `toMap()` | Returns the stored fields, with enum values, `DateTime` dates and explicit null optional fields. Excludes `id`. |
| `Incident.fromMap(id: ..., data: ...)` | Constructs an incident from a document identifier and normalized fields. Missing optional fields become null; unrecognized fields are ignored. |
| `copyWith(...)` | Returns a separate instance with selected fields replaced, preserving the report's identity and creation metadata. |

`fromMap()` validates the input before constructing the model. Required text
and identifiers must be nonblank, the sequence must be a positive integer, and
status and priority must use supported stored values. An assigned technician
identifier must be nonblank when present. Invalid types, missing required
fields and unsupported enum values raise `FormatException`.

Valid text is preserved exactly, including surrounding whitespace and line
breaks. An `id` field inside the map does not override the document identifier
supplied to the factory.

Dates must be confirmed `DateTime` values. Raw Firestore `Timestamp` values
require conversion with `toDate()` before parsing. Null, missing or unconverted
dates are rejected. The parser does not substitute the current time or supply
an initial state when a stored state is missing.

`toMap()` retains dates as `DateTime`; it does not perform JSON encoding or set
server timestamps. Database conversion, writes and authorization are separate
from the model operations.

### Immutable updates

`copyWith()` preserves `id`, `sequenceNumber`, `createdByUserId` and `createdAt`.
Omitted or null arguments preserve their existing values. Explicit clearing is
available for nullable fields:

| Parameter | Effect when true |
| --- | --- |
| `clearPriority` | Sets `priority` to null. |
| `clearAssignedTechnician` | Sets `assignedTechnicianId` to null. |
| `clearResolution` | Sets `resolutionDescription` to null. |

A clear flag takes precedence over a simultaneous replacement for that field.
The original instance remains unchanged. Constructor and copy operations do not
enforce lifecycle transitions or authorize database writes.

```dart
final corrected = incident.copyWith(
  title: 'Broken classroom light',
  location: 'Building A, classroom 2',
);

final withoutPriority = corrected.copyWith(clearPriority: true);
```

## Technician progress

`IncidentProgress` contains an author's identifier, a confirmed date and the
progress description. Its document identifier is supplied separately to
`fromMap()` and excluded from `toMap()`.

| Field | Model type | Description |
| --- | --- | --- |
| `authorUserId` | `String` | Account that recorded the progress. |
| `createdAt` | `DateTime` | Confirmed recording time. |
| `description` | `String` | Follow-up comment text. |

Parsing requires nonblank identifiers and description text. Description text
retains whitespace and line breaks. Missing dates, unresolved timestamps and
invalid types raise `FormatException`.

## History events

`IncidentHistoryEvent` represents an audit record with its actor, date, action
and optional previous and resulting values. The event identifier is separate
from the serialized fields.

| Field | Model type | Description |
| --- | --- | --- |
| `actorUserId` | `String` | Account that performed the recorded action. |
| `createdAt` | `DateTime` | Confirmed recording time. |
| `action` | `IncidentHistoryAction` | Typed action, serialized as its English code. |
| `fromStatus` | `IncidentStatus?` | Previous status, serialized using `.value`. |
| `toStatus` | `IncidentStatus?` | Resulting status, serialized using `.value`. |
| `fromTechnicianId` | `String?` | Previous assigned technician. |
| `toTechnicianId` | `String?` | Resulting assigned technician. |
| `reason` | `String?` | Explanation associated with the action. |

The supported action codes are `created`, `classified`, `assigned`, `started`,
`progressAdded`, `resolved`, `closed`, `rejected`, `cancelled` and `reopened`.
`IncidentHistoryAction.fromValue()` rejects unsupported codes. Optional fields
are serialized as null when absent. Present technician IDs and reasons must
be nonblank; reason text is preserved without trimming.

The event model serializes audit data independently of transaction logic and
transition authorization.

## Photograph metadata

`IncidentEvidence` represents file metadata and its optional progress
association. Its `provider` property always returns `local`.

| Field | Model type | Description |
| --- | --- | --- |
| `uploadedByUserId` | `String` | Account that uploaded the file. |
| `createdAt` | `DateTime` | Confirmed metadata recording time. |
| `provider` | `String` | Local file-provider identifier. |
| `assetId` | `String` | Stored file identifier. |
| `url` | `String` | File retrieval reference. |
| `fileName` | `String` | Original display name. |
| `contentType` | `String` | Canonical image content type. |
| `sizeBytes` | `int` | Positive file size in bytes. |
| `progressId` | `String?` | Progress association, or null for a report photograph. |

`supportedContentTypes` contains `image/jpeg`, `image/png` and `image/webp`.
`maxFileSizeBytes` is 3 000 000 bytes, inclusive. Metadata parsing rejects other
providers, unsupported content types, missing references, invalid sizes and
blank progress identifiers. A missing `progressId` becomes null.

Model conversion handles metadata rather than image bytes. File operations,
content inspection and access authorization are separate from serialization.
`toMap()` excludes the document identifier and includes the optional association
explicitly, including null.

## Verification

Verified on October 21, 2026, with Flutter `3.47.5` and Dart `3.13.4`:

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found. |
| `flutter test --no-pub` | 84 tests passed, including 45 incident-record tests. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

Model tests cover the field contracts, initial and nullable values, date
precision, unknown fields, invalid types, supported action codes, unresolved
timestamps, identity preservation and explicit field clearing. Evidence tests
include the exact size limit, unsupported providers, content types and progress
associations. These checks do not exercise Firestore writes, security rules or
physical image files.

## References

- [Incident implementation](../lib/features/incidents/models/incident.dart).
- [Incident model tests](../test/features/incidents/models/incident_test.dart).
- [Progress implementation](../lib/features/incidents/models/incident_progress.dart).
- [Progress model tests](../test/features/incidents/models/incident_progress_test.dart).
- [History event implementation](../lib/features/incidents/models/incident_history_event.dart).
- [History action codes](../lib/features/incidents/models/incident_history_action.dart).
- [History model tests](../test/features/incidents/models/incident_history_event_test.dart).
- [Evidence implementation](../lib/features/incidents/models/incident_evidence.dart).
- [Evidence model tests](../test/features/incidents/models/incident_evidence_test.dart).
- [Shared data contracts](contratos_modulos.md).
- [Runtime configuration and verification](toolchain.md).
