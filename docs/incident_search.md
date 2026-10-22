# CampusFix: Authorized Incident Search

## User behavior (HU-15)

The same Spanish search panel appears in **Mis incidencias**, **Mi trabajo** and
**Gestión** after the current incident query loads successfully. Results remain
limited to own reports, assigned cases or the administrative queue respectively.

- Enter `12` or `#12` for an exact sequence number; it does not match `112`.
  Leading zeros and whitespace around the optional hash are accepted. Invalid
  hash-prefixed sequences and oversized numbers yield no matches.
- Other input matches any substring of the title, description or location.
  Matching ignores case, common Spanish accents and combining accent marks.
- Select a category to combine its exact ID with the text criterion using AND.
  Names are resolved by ID; referenced inactive categories show `(inactiva)`.
- **Limpiar búsqueda** clears both criteria. The result count compares matches
  with the current authorized source, preserving its existing sort order.

Criteria immediately reapply when a live snapshot arrives. An empty search
result is distinct from a source query failure. Opening a result releases the
list's observations; returning to that list in the same session restores its
criteria against a fresh snapshot. Leaving the module disposes the controller.

## Architecture and interfaces

`IncidentSearch` is an immutable local query value with `query` and optional
`categoryId`. Its `applyTo(Iterable<Incident>)` returns an immutable list in source
order. It is not an authorization layer: callers supply already authorized data.

`IncidentSearchController` owns criteria, results and the referenced category
names for one UID and role. Existing list controllers keep their current
repository/service query and call `replaceIncidents` for each authorized snapshot.
The shared `IncidentSearchPanel` presents state and delegates input; it performs
no database access or matching logic.

Typing does not restart incident observations or request additional incident
documents. Category lookups use at most one `watchById` subscription per distinct
referenced or selected category. Unused subscriptions are cancelled. Selecting a
category that disappears from the source preserves the criterion, allowing a
clear zero-result state until the user resets it or a matching case returns.

Category failures clear obsolete names, show explicit feedback and offer
**Reintentar categorías**, without dropping incident results. A missing category
can still be selected by its ID with an unavailable-name label. No inactive
catalog enumeration is added for reporters or technicians.

All records, names and criteria clear when the original authenticated account or
role changes. Version checks reject obsolete category callbacks. A technician
queue also rejects foreign-assignment snapshots before exposing them to search;
reporter lists retain their existing author check. Firestore independently
enforces the role-scoped incident queries.

## Verification and captures

The search-specific suite covers model semantics, live source changes, category
renames/deactivation, errors/retries, subscription cancellation, three-role
isolation, detail navigation, account changes and desktop/tablet layout:

```powershell
& .\.fvm\sdk-3.47.5\bin\flutter.bat test --no-pub `
  test/features/incidents/models/incident_search_test.dart `
  test/features/incidents/controllers/incident_search_controller_test.dart `
  test/incident_search_screen_test.dart --reporter expanded
```

For pointer-free PNG evidence, add
`--dart-define=CAPTURE_SEARCH_EVIDENCE=true`. This loads the local pinned SDK's
Roboto and Material fonts and captures the actual application widget tree with
synthetic fixtures. It writes to ignored `build/evidence/`; reviewed copies are
stored under `docs/evidence/phase_2_search_desktop.png` and
`docs/evidence/phase_2_search_tablet.png`. These are automated UI evidence, not a
production browser session. Normal test runs do not generate screenshots.

Results are recorded in `evidence/part_4_phase_2_checks.txt`.

## Compatibility and delivery boundary

No incident fields, dependencies, indexes or Firestore rules change for search.
Historical category names require the phase 1 individual-read rules; those rules
have been tested locally but are not claimed deployed to the real project.
The provided baseline rules reference lacks those phase 1 category changes and
must not replace the current repository rules without review.

Administrative status, priority and technician filters (HU-16), the dashboard
(HU-17/HU-18), browser-wide integration and Hosting publication remain in their
later phases. Photograph handling remains the existing local implementation.
