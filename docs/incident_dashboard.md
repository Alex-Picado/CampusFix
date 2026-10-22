# Global incident indicators (HU-17 and HU-18)

The administrator's **Indicadores** page displays live global totals and category
counts. It uses the existing authorized `IncidentRepository.watchAll()` source,
with a separate controller from Management. Search, status, priority, category
and technician filters in Management never change the dashboard's population.
Reporters and technicians neither see this destination nor start its queries.
Firestore rules independently protect both administrative list operations.

## Count definitions

| Indicator | Included stored states |
| --- | --- |
| Total | Every authorized incident in all nine states |
| Open | `REPORTADA`, `EN_REVISION`, `ASIGNADA`, `EN_ATENCION` |
| In progress | `EN_ATENCION`; a subset of open |
| Resolved | `RESUELTA` |
| Closed | `CERRADA` |

`REABIERTA`, `RECHAZADA` and `CANCELADA` contribute to total and category counts
but not open. This follows the agreed HU-17 definition, rather than treating every
unfinished case as open. The interface explains that in-progress overlaps open
and that the five cards are not disjoint buckets.

`IncidentIndicators.fromIncidents` computes immutable counts from each complete
snapshot. It does not persist derived fields or change incident documents. An
empty successful snapshot produces five zero values and an explicit empty state.
Loading, failed or interrupted incident observation never produces invented zeros.

## Categories and lifecycle

Category counts group by stable `categoryId`, including inactive or unavailable
referenced categories. Categories with no incidents are omitted. Rows sort by
descending count and then ID; the counts always sum to total. Progress bars show
each category's fraction of total and expose accessible percentage semantics.

The existing administrator-only `CategoryRepository.watchAll()` supplies current
names and active flags. Renaming or deactivating a category updates its label
without rewriting reports or changing the group. Identical names remain separate
rows, identified by their IDs. Missing records show an explicit unavailable label
and their reference ID, preserving the count.

The session-bound `IncidentDashboardController` owns one incident and one catalog
subscription, without enumerating user profiles. Category loading or failure is
displayed separately; valid global counts remain visible. A category retry reads
only the catalog, and an incident retry reads only the incident source. Failed
subscriptions are cancelled and obsolete labels or incident counts are cleared.

Leaving the page disposes both subscriptions. Sign-out, account changes, role loss
and session failures clear private data and permanently invalidate the old
controller. Observation versions reject callbacks from previous subscriptions.
Reopening the module creates a fresh controller for the current authorized session.

## Verification and images

The acceptance fixture contains one incident per lifecycle state, across three
categories. Expected cards are **9 total, 4 open, 1 in progress, 1 resolved and
1 closed**; category counts are **4 + 3 + 2 = 9**.

- `test/features/incidents/models/incident_indicators_test.dart`: agreed counts,
  empty data, immutable snapshots and category conservation.
- `test/features/incidents/controllers/incident_dashboard_controller_test.dart`:
  live replacement, historical names, pending data, independent retry, malformed
  categories, synchronous query failures, interruption and session cancellation.
- `test/incident_dashboard_screen_test.dart`: global totals after Management
  search, live changes, duplicate names, missing categories, empty/loading/error
  states, navigation cleanup, role loss and responsive rendering.
- `test/widget_test.dart`: existing role navigation now opens the actual dashboard.

Regenerate desktop and tablet images with the pinned SDK:

```powershell
& .\.fvm\sdk-3.47.5\bin\flutter.bat test --no-pub `
  test/incident_dashboard_screen_test.dart `
  --dart-define=CAPTURE_DASHBOARD_EVIDENCE=true --reporter expanded
```

The test renders actual application widgets at 1440x1100 and 768x1024, with
synthetic fixtures and real SDK fonts. It writes pointer-free PNGs to ignored
`build/evidence/parte_4/`. Reviewed copies and the executed verification record
are in [Daniel's evidence](evidence/parte_4/README.md). They document automated
widget rendering rather than a production browser walkthrough.

No dependencies, runtime pins, Firestore rules, indexes or document schema change
in phase 4. The complete automated suite and web build are recorded in
[phase 4 checks](evidence/parte_4/part_4_phase_4_checks.txt). Production rule
deployment, full browser integration, public photograph handling and Hosting
publication remain pending in phases 5 and 6.
