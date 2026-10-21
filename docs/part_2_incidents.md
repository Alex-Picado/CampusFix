# CampusFix: Incident Model

## Overview

`Incident` is an immutable representation of a campus service report. It stores
the report's identity, description, category, location, state, dates and user
references. Serialization preserves the data contract and keeps the document
identifier separate from its stored fields.

## Data structure

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

## Serialization and validation

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

## Immutable updates

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

## Verification

Verified on October 21, 2026, with Flutter `3.47.5` and Dart `3.13.4`:

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found. |
| `flutter test --no-pub` | 50 tests passed, including 19 incident-model tests. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

Model tests cover the field contract, initial and nullable values, date
precision, unknown fields, invalid types, unsupported enum values, unresolved
timestamps, identity preservation and explicit field clearing. These are model
checks; they do not exercise Firestore writes or security rules.

## References

- [Incident implementation](../lib/features/incidents/models/incident.dart).
- [Incident model tests](../test/features/incidents/models/incident_test.dart).
- [Shared data contracts](contratos_modulos.md).
- [Runtime configuration and verification](toolchain.md).
