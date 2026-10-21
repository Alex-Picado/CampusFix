# CampusFix: Report Draft and Submission Controller

## Overview

`IncidentReportController` manages one authenticated reporter's draft, active
category observation and confirmed creation result. It extends `ChangeNotifier`
and receives `IncidentRepository`, `CategoryRepository`, `SessionController` and
the reporter's UID through its constructor. It does not access Firebase
directly or derive authorship from editable form fields.

`IncidentDraft` is an immutable in-memory value containing `title`,
`description`, `categoryId` and `location`. It contains no author, sequence,
timestamps or persistence methods. Text remains untrimmed while editing;
`normalized()` creates the trimmed payload used for submission and preserves
internal line breaks and category identity. `copyWith(clearCategory: true)`
explicitly removes the category selection.

## State and actions

| API | Behavior |
| --- | --- |
| `draft`, `categories`, `selectedCategoryName` | Expose input, the current active category list and the selected category's last known label. |
| `fieldErrors` | Unmodifiable Spanish messages keyed by `title`, `description`, `location` and `categoryId`. |
| `isLoadingCategories`, `loadErrorMessage` | Distinguish initial loading, an empty successful result and a category observation failure. |
| `isSubmitting`, `isReviewing`, `isBusy` | Identify a pending creation/retry or a server check of an uncertain submission. |
| `canEditDraft`, `canSubmit`, `canResumeEditing` | Determine which actions the current session and submission state permit. |
| `createdIncident`, `successMessage` | Expose the confirmed report and its server-assigned consecutive number. |
| `submitErrorMessage` | Submission or reconciliation feedback, independent from category loading errors. |
| `startCategories()` | Cancel the previous category observation and retry without discarding draft text or submission feedback. |
| `updateDraft(...)` | Update editable fields and clear the corresponding field errors. |
| `validate()` | Check required trimmed text and membership in the active category list without allocating an ID or writing data. |
| `submit()` | Return the confirmed `Incident`, or null for invalid, busy, failed or obsolete operations. |
| `resumeEditing()` | Return true only after confirming that the reserved report ID is absent and unlocking its draft. |
| `resetDraft()` | Clear an editable or confirmed draft; return false while busy, inactive or unresolved. |
| `dispose()` | Cancel observations and clear private form state. |

New submissions require a successfully loaded, nonempty category list and
valid required fields. Draft text can be edited during category loading, but
submission remains disabled. Lists and error maps cannot be mutated by a view.
Renaming a selected category updates its label. Removing or deactivating an
editable selection clears the selected ID and adds a field error without
discarding the text fields. Invalid supplied category IDs also clear selection.

Submitting and reconciliation lock all draft actions before notifying
listeners. This prevents overlapping writes, duplicate checks and edits to
the payload while an operation is pending. Success locks the confirmed draft
until it is reset for a new report.

## Creation and uncertain results

After local validation, `submit()` allocates one ID through
`IncidentRepository.newIncidentId()` and freezes a normalized payload. It calls
`IncidentRepository.create()` with that ID and the same fields on every retry.
The repository and service supply the authenticated author, initial state,
sequence and confirmed dates. [Incident creation](incident_creation.md)
describes the atomic report, counter and initial history writes.

A failure retains the original raw draft, reserved ID and attempted payload.
It does not claim that the report was saved or that a rejected confirmation
means no write occurred. The draft remains read-only while its result is
uncertain. Retrying sends the same ID and payload, even if category observation
subsequently fails or the category disappears. The persistence layer can
recover an existing matching report before validating a new category write.

If ID allocation itself fails, no submission has been attempted. The draft
remains editable and the error is displayed separately from field validation.

`resumeEditing()` checks the reserved ID through
`IncidentRepository.watchById()` and consumes its first confirmed response:

| Confirmed response | Result |
| --- | --- |
| Existing report with the reserved ID and original author | Adopt the stored fields and show success; do not unlock or submit another report. |
| Missing report | Unlock the draft and revalidate its category, retaining the reserved ID for subsequent edits or resets. |
| Error or stream closure without a result | Keep the submission locked and retryable; do not interpret failure as absence. |

Retaining an ID after an absent response prevents another ID from being
allocated if an earlier operation commits later. A conflicting payload for an
occupied ID is rejected by the creation service and can be reconciled again.
The controller accepts a result only when its ID and author match its scope.
Only resetting a confirmed report releases its ID for a new report.

## Session and view lifecycle

An instance is active only for its original authenticated reporter UID. A name
update within that session preserves the draft. Sign-out, another account,
a changed role or an unavailable profile permanently invalidates the instance.
Invalidation cancels category observation and an active reconciliation check,
clears the draft and all feedback, and ignores late write completions.
Restoring the same account does not reactivate an invalidated instance.

The view owns the controller and must dispose it when leaving the form.
Cancelling a reconciliation also cancels the repository observation and its
underlying subscriptions. A transaction already dispatched cannot be cancelled
by disposing the controller; its late result cannot repopulate the old view.
Server authorization remains independent of these presentation checks.

Draft fields and unresolved submission state exist only for this controller's
lifetime. They are not restored from disk or after a browser reload. Confirmed
incidents persist through Firestore.

## Reporting screen

`IncidentReportScreen` opens through **Mis incidencias → Crear incidencia**.
It reuses `PageHeading`, `SectionCard` and the shell's scrollable layout. The
screen owns its controller through Provider and cancels observation on exit.
`main.dart` constructs the incident and category repositories, and `AppProviders`
shares them without opening a query until the form is mounted.

The form accepts title, description, active category and location. It displays
field errors, category loading/empty/error states and confirmed creation with
its sequence. Pending fields remain read-only. **Reintentar guardado** resends
the same submission; **Editar datos** checks the server before unlocking fields.
**Crear otra incidencia** resets the confirmed form. Buttons wrap on narrow
screens, and tablet navigation uses the existing drawer.

The Firestore connection requires the incident rules and active categories
described in [Creation security](incident_security.md). The widget tests use
local repositories and do not verify a deployed Firebase configuration.

## Verification

Run the focused controller suite from the repository root:

```text
flutter test --no-pub test/features/incidents/controllers/incident_report_controller_test.dart
```

The 30 controller tests use controlled session and repository dependencies.
They cover loading, empty and error states, category retries and removal,
field validation, normalization, overlapping and reentrant submissions,
uncertain results, stable IDs and payloads, reconciliation, safe resets,
role/account changes, cancellation, disposal and late completions. They do not
initialize Firebase or verify browser interactions.

Verified on October 21, 2026, with Flutter `3.47.5` and Dart `3.13.4`:

| Check | Result |
| --- | --- |
| Focused controller suite | 30 tests passed. |
| Incident screen suite | 15 widget tests passed: 9 report-form tests and 6 own-list tests with controlled repositories. |
| `flutter test --no-pub` | 174 tests passed. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

The dependency declarations, lockfiles, rule source and query index definitions
are unchanged by the controller implementation. No Firebase deployment is
included in these checks.

The persistence and security suites are documented separately in
[Incident creation](incident_creation.md),
[Incident observation](incident_observation.md) and
[Creation security](incident_security.md).

## References

- [Report controller](../lib/features/incidents/controllers/incident_report_controller.dart).
- [Reporting screen](../lib/features/incidents/screens/incident_report_screen.dart).
- [Screen tests](../test/incident_report_screen_test.dart).
- [Draft model](../lib/features/incidents/models/incident_draft.dart).
- [Controller tests](../test/features/incidents/controllers/incident_report_controller_test.dart).
- [Active category reader](categories.md).
- [Shared data contracts](contratos_modulos.md).
- [Runtime configuration and verification results](toolchain.md).
