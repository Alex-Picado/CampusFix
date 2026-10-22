# CampusFix: Administrative Incident Filters

## User behavior (HU-16)

Administrators can combine the existing sequence/text and category search with:

- **Estado**: any supported lifecycle state, or **Todos los estados**.
- **Prioridad**: low, medium, high, **Sin prioridad**, or all priorities.
- **Técnico responsable**: one responsible UID displayed by name and email,
  **Sin asignar**, or all assignments.

All choices combine using AND. Results immediately reapply to the current live
snapshot and retain repository ordering. The count compares matching cases with
the full authorized source. **Limpiar filtros** clears text, category, state,
priority and assignment together. Choosing an individual all-option clears only
that criterion. No matches produce the existing explicit empty-search message.

Opening detail pauses list observations. Returning to the same list in the same
session restores all criteria. Leaving the module, signing out or changing
accounts/roles disposes or invalidates the original state. Reporters and
technicians retain their basic search without administrative controls.

## Architecture and authorization

`IncidentFilters` is an immutable value embedded in `IncidentSearch`. It matches
states and responsible UIDs exactly, distinguishes absent priorities and
assignments, and combines with the existing text/category matcher. The typed
priority choices avoid treating null priority as a specific urgency.

`IncidentSearchController` guards administrative setters by the original UID,
administrator role and available source snapshot. `setQuery` and category changes
preserve the operational choices; explicit reset clears them all. The
`IncidentAdministrativeFilters` widget only presents state and delegates input.

The administrative queue injects `UserRepository` for its existing protected
`watchAll()` reader. One profile subscription supplies current technician names
and emails, including names for previously assigned UIDs whose role has changed.
Available options include current technicians, UIDs referenced by loaded cases
and the selected UID. Missing profiles have an explicit unavailable label;
filtering still uses the stable UID.

Profile failures clear obsolete names and offer **Reintentar técnicos**, without
discarding filtered incident records. Retrying does not restart incident queries.
Profile and category subscriptions cancel on pause, invalidation and disposal;
version checks reject obsolete callbacks. Other roles never start the user-list
query. Firestore independently restricts user collection queries to administrators,
with direct SDK coverage for reporter, technician and unauthenticated denial.

No incident fields, indexes, dependencies, version pins or Firestore rules change.
Incident queries keep their existing role scope; filters run on authorized data
already loaded by the repository.

## Verification and evidence

Behavioral coverage is in the filter-model, search-controller and search-screen
tests. It includes all nine states, priorities including null, assignment
choices, all-five-criteria matching, resets, live changes, profile errors,
navigation and role/account cleanup. The independent Firestore test for profile
enumeration accompanies the existing role-authorization suite.

Generate pointer-free desktop/tablet captures with:

```powershell
& .\.fvm\sdk-3.47.5\bin\flutter.bat test --no-pub `
  test/incident_search_screen_test.dart `
  --dart-define=CAPTURE_FILTER_EVIDENCE=true --reporter expanded
```

This renders real application widgets with synthetic fixtures and SDK fonts.
Output goes to ignored `build/evidence/parte_4/`; reviewed copies and exact check
results are in [Daniel's evidence](evidence/parte_4/README.md). The images document
desktop/tablet layout rather than production or browser integration.

All team evidence is organized under `docs/evidence/parte_1` through `parte_4`.
Existing phase 1/2 records and images were relocated to Part 4 without changing
their contents. The original Part 3 record was moved to Part 3; indexes mark
missing images for other parts rather than inventing results.
