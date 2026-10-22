# CampusFix: Part 4 Delivery Progress

## Working agreement

Daniel owns HU-15 through HU-18, HU-20, category administration and coordination
of the final integration and evidence. Work takes place on
`feat/queries-dashboard`, with one requested session per phase and at least one
meaningful commit per phase. Commit timestamps are real. Every push requires a
direct user request; completing a phase does not authorize a push or the next
phase. Alex reviews the final integration, retaining individual commits through
a merge commit. A later user instruction requests phases 5 and 6 together on local
branches `codex/phase-5-integration` and `codex/phase-6-delivery`. Phase 6 builds on
phase 5. `feat/queries-dashboard` stays at its phase 4 commit until integration is
requested; neither local branch is pushed automatically. Internet publication is
also deferred by this local-only instruction.

| Phase | Deliverable | Status |
| --- | --- | --- |
| 1 | Category creation, renaming, activation, historical names and permissions | Implemented; verification recorded below. |
| 2 | Authorized incident search (HU-15) | Implemented; verification recorded below. |
| 3 | Combined administrative filters (HU-16) | Implemented; verification recorded below. |
| 4 | Live global dashboard and category counts (HU-17, HU-18) | Implemented; verification recorded below. |
| 5 | Desktop/tablet integration and explicit public photo limitation | Implemented and verified locally on its separate branch. |
| 6 | Hosting publication, final documentation and 20-story evidence (HU-20) | Pending a later requested session. |

## Phase 1 implementation and evidence

The existing category model and incident schema are unchanged. The catalog now
supports administrator creation, renaming and activation/deactivation through
screen, controller, repository and service layers. Its controller handles draft
validation, pending writes, errors, confirmed success and session cleanup.

The incident detail resolves the current name of its referenced category, even
after deactivation, and observes later renames. Category errors have an explicit
retry and do not discard the rest of the authorized incident detail. New report
selection still uses the existing active-only query.

| Requirement | Implementation | Executable evidence |
| --- | --- | --- |
| Administrator category management | `CategoryManagementScreen`, `CategoryManagementController`, extended category repository/service | `test/category_management_screen_test.dart`, `test/features/catalogs/repositories/category_management_repository_test.dart` |
| Historical category references and names | Individual category reader and incident detail subscription | `test/incident_detail_screen_test.dart`, repository tests, category rule tests |
| Independent authorization and validation | Firestore category get/list/write/delete rules | `tool/firestore_tests/categories.rules.test.mjs` |
| Session cleanup and tablet layout | Session-bound controller, adaptive category rows | Category screen tests: navigation, role downgrade, pending acknowledgement, account change and tablet layout |

The exact verification results are recorded in `evidence/parte_4/part_4_phase_1_checks.txt`.
All database tests target the local `demo-campusfix` emulator. No production data
or security rules are changed by these tests.

## Phase 2 implementation and evidence

HU-15 is available in the reporter's own incidents, the technician's assignments
and the administrator's management queue. A shared immutable search model,
session-bound controller and presentation panel provide exact sequence lookup,
case/accent-insensitive text search and category selection using AND. Search
preserves repository ordering and reuses the existing authorized incident stream.

Referenced inactive categories remain selectable. Category failures have explicit
feedback and separate retries. Criteria survive a detail-route pause in the same
session and are cleared on sign-out, account changes or role changes. Technician
queues additionally reject any snapshot containing a foreign assignment before
forwarding records to search.

| Requirement | Implementation | Executable evidence |
| --- | --- | --- |
| HU-15: sequence, text and category | `IncidentSearch`, shared search controller/panel and existing list controllers | `test/features/incidents/models/incident_search_test.dart`, `test/incident_search_screen_test.dart` |
| Live updates, category names and session cleanup | Shared search controller with individual category subscriptions | `test/features/incidents/controllers/incident_search_controller_test.dart` and screen tests |
| Role isolation and detail navigation | Existing repository scopes plus list-controller checks | Search screen tests with three roles and foreign assignments; existing Firestore rule suite |
| Desktop and tablet presentation | Same application widgets at 1440x1100 and 768x1024 | `evidence/parte_4/phase_2_search_desktop.png`, `evidence/parte_4/phase_2_search_tablet.png` |

The PNGs are pointer-free captures of rendered application widgets under Flutter
tests, using synthetic incident fixtures and real fonts. They document the UI,
not production data or a browser walkthrough. The source test can regenerate
them with `--dart-define=CAPTURE_SEARCH_EVIDENCE=true`.

Exact executed checks and remaining limits are recorded in
`evidence/parte_4/part_4_phase_2_checks.txt`. Search requires no schema, index, dependency,
runtime-pin or Firestore-rule change. Administrative status/priority/technician
filters are recorded in phase 3 below.

## Phase 3 implementation and evidence

HU-16 adds administrator-only state, priority and responsible-technician choices,
including unclassified and unassigned cases. They combine with text and category
using AND, update with live snapshots and preserve the current repository order.
Clearing resets every choice; detail navigation preserves them within one session.

An administrator-authorized profile observation supplies current technician
names, while assigned historical UIDs remain available. Profile read failures
have a separate retry and do not discard filtered cases. Profile subscriptions
and criteria clear on pause, session change or disposal; other roles neither see
the administrative controls nor start this profile query.

| Requirement | Implementation | Executable evidence |
| --- | --- | --- |
| HU-16: combined state, priority and technician | `IncidentFilters`, shared search controller and administrative filter panel | Filter-model, search-controller and search-screen tests |
| Independent user-catalog authorization | Existing Firestore user-list rule | Direct SDK rule test covering all roles and unauthenticated sessions |
| Desktop/tablet and session cleanup | Responsive controls and session-bound profile observation | Filter-screen tests and `evidence/parte_4/phase_3_filters_desktop.png`, `phase_3_filters_tablet.png` |
| Evidence organization | `docs/evidence/parte_1` through `parte_4` | Versioned indexes, original Part 3 record and all Daniel records/images under Part 4 |

Executed checks are in `evidence/parte_4/part_4_phase_3_checks.txt`.
Existing verification records were moved without modifying their original
results; historical screenshot captures were preserved. Versions, incident schema,
indexes, dependencies and production Firebase state remain unchanged.

## Phase 4 implementation and evidence

HU-17 and HU-18 replace the administrator's dashboard placeholder with live global
state and category counts. A separate session-bound dashboard controller reuses
the existing administrative incident source, independently of Management filters.
The immutable indicators model follows the agreed four-state open definition;
in-progress is an explicitly labelled subset. Reopened cases count only in total
and their category, alongside rejected and cancelled cases.

The complete administrative category reader supplies historical and inactive
names. Aggregates use stable IDs, so renames or identical names do not merge
groups; unavailable references remain counted. Catalog errors retain global
metrics and have an independent retry. Loading and incident errors never appear
as zero incidents. Navigation and session invalidation release both observations
and reject callbacks from obsolete subscriptions.

| Requirement | Implementation | Executable evidence |
| --- | --- | --- |
| HU-17: global state counts | `IncidentIndicators`, independent dashboard controller/screen | Indicator-model tests, controller tests and screen tests |
| HU-18: counts by stable category ID | Complete catalog subscription; live names, inactive and unavailable references | Rename/deactivation, identical-name and missing-reference tests |
| Global scope and authorization | Existing `IncidentRepository.watchAll()` and admin-only page/controller | Dashboard after restrictive Management search; role/session tests; existing direct-SDK rule suite |
| Desktop/tablet layout | Responsive cards and category bars | `evidence/parte_4/phase_4_dashboard_desktop.png`, `phase_4_dashboard_tablet.png` |

The nine-state acceptance fixture produces 9 total, 4 open, 1 in progress,
1 resolved and 1 closed, with category counts 4 + 3 + 2 = 9. The screenshots
capture actual application widgets with synthetic data and real fonts, without
mouse pointers. They are automated UI evidence, not a production walkthrough.
Executed checks and explicit remaining limits are recorded in
`evidence/parte_4/part_4_phase_4_checks.txt`. See `incident_dashboard.md` for the
definitions, lifecycle behavior and screenshot regeneration command.

## Phase 5 implementation and evidence

The public client explicitly disables local photograph operations and explains
the limitation, preserving reports and text progress. The local launcher opts
into photographs; `--no-photos` previews the public behavior against demo
emulators. The actual browser walkthrough exposed and fixed unsupported encoded
image dimension access in Flutter Web and a detached file-picker lifecycle issue.
Obsolete placeholder navigation and pending-module interface text were removed.

Both local-photo and public text-only workflows completed report creation,
classification, assignment, attention, progress, resolution and administrator
closure with synthetic accounts. The photograph run also covered registration,
live history, protected-route reload and resulting global indicators. Desktop
and tablet captures document the actual browser. Exact checks and the limited
extra Chrome test attempt are in `evidence/parte_4/part_4_phase_5_checks.txt`.
See `integration_delivery.md` for modes, setup and reproducible walkthroughs.

Java was used only by existing verification emulators. The runtime application
contains no Java dependency or temporary diagnostic instrumentation. One-off
uploaded files were removed, existing images preserved and demo processes stopped.

## Runtime setup

The global Flutter installation is not changed. A local checkout of the official
Flutter `3.47.5` release is available under ignored `.fvm/sdk-3.47.5`, with Dart
`3.13.4`. Node is `24.19.0`; the tests select Java `21.0.9` explicitly.

On this Windows checkout, use:

```powershell
& .\.fvm\sdk-3.47.5\bin\flutter.bat pub get --enforce-lockfile
& .\.fvm\sdk-3.47.5\bin\flutter.bat analyze --no-pub
& .\.fvm\sdk-3.47.5\bin\flutter.bat test --no-pub
& .\.fvm\sdk-3.47.5\bin\flutter.bat build web --no-pub
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm.cmd test --prefix tool/firestore_tests
```

The SDK checkout is local and not committed. Other contributors can select the
same release using their existing SDK or FVM as documented in `toolchain.md`.

## Explicit delivery limitations

- Photographs retain the team's local authenticated service and local storage.
  This was selected by the user; it is not recorded as instructor approval of
  the difference from the cloud-storage requirement.
- The full demonstration with photographs remains local. Phase 5 implements
  an explicit public-client mode without local photograph operations.
- Hosting publication and real-project rule deployment have not been performed
  in phase 1. New catalog operations need the reviewed rules deployed before
  they can be verified against the real project.
- Evidence for all 20 stories and the published three-role walkthrough belong
  to the final integration. They are not claimed complete by this phase.
