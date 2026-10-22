# User story traceability

The matrix follows the supplied statement's 20 stories. **Executed local** means
automated checks and/or an emulator browser walkthrough, not production testing.
**Limited** identifies the local-photo exception. **Pending** is not acceptance
of the published delivery.

| Story | Implementation | Evidence and current result |
| --- | --- | --- |
| HU-01 Registration/sign-in | Auth controller/repository and session gate | `test/widget_test.dart`; phase 5 browser registration and three-role sign-in. Executed local. |
| HU-02 Profile | Profile screen/controller and user repository | Profile save/validation/rollback/account-change tests in `test/widget_test.dart`. Executed local. |
| HU-03 Roles | Stored UserRole, role navigation, user administration and rules | `test/user_management_screen_test.dart`, role navigation and direct SDK denials. Executed local. |
| HU-04 Sign-out | AuthController and session-bound cleanup | Shared widget/session tests and phase 5 sign-outs. Executed local. |
| HU-05 Create report | Report controller and transactional incident service | Incident creation repository/rule tests; both phase 5 browser workflows. Executed local. |
| HU-06 Evidence | Evidence repository, browser picker and local byte service | Evidence/service tests, emulator integration and `phase_5_local_photo_desktop.jpg`. Limited: local storage only; cloud/public photographs not delivered. |
| HU-07 Own reports | MyIncidents controller and authorized own query | `test/incident_report_screen_test.dart`, read rules and phase 5 browser. Executed local. |
| HU-08 Detail/history | Protected route, referenced categories/people, comments and history | `test/incident_detail_screen_test.dart`; phase 5 flow and route reload. Executed local, photos limited as HU-06. |
| HU-09 Classify | Workflow controller and atomic classification | `test/incident_management_screen_test.dart`, workflow repository/rules and browser. Executed local. |
| HU-10 Assign | Validated administrator command and assigned queue | Management/workflow tests and both browser workflows. Executed local. |
| HU-11 Start attention | Assigned-technician command | Workflow tests and phase 5 ASIGNADA to EN_ATENCION. Executed local. |
| HU-12 Follow-up | Detail controller, text progress and optional local evidence | Detail tests, emulator integration and local/public tablet captures. Executed local; public photographs limited. |
| HU-13 Resolve | Assigned-technician command requiring solution | Workflow tests and both phase 5 browser solutions. Executed local. |
| HU-14 Close | Administrator-only transition from RESUELTA | Workflow tests, `phase_5_closed_tablet.jpg` and public text-only closure. Executed local. |
| HU-15 Search | Immutable IncidentSearch and shared authorized controller/panel | Phase 2 model/controller/screen tests and desktop/tablet PNGs. Executed local. |
| HU-16 Filters | IncidentFilters and administrative controls | Phase 3 tests, direct profile enumeration denials and desktop/tablet PNGs. Executed local. |
| HU-17 Dashboard | Independent global indicators model/controller/screen | Nine-state acceptance fixture, phase 4 tests/PNGs and phase 5 actual dashboard JPEG. Executed local. |
| HU-18 Category indicators | Stable-ID grouping and live complete catalog | Phase 4 inactive/rename/duplicate/missing-category tests; category counts sum to total. Executed local. |
| HU-19 Audit | Immutable transactional actor/date/lifecycle events | Direct rule tests reject forged/orphan events; phase 5 chronological browser history. Executed local. |
| HU-20 Publication | Public release preparation and Hosting config/fallback | Phase 6 checks and bundle. Prepared locally; Internet deploy, URL capture and published three-role verification pending user authorization. |

Test files reside under `test/`, `services/local_evidence/test/` and
`tool/firestore_tests/`. Screenshot names refer to `docs/evidence/parte_4/`.
[Daniel's evidence index](evidence/parte_4/README.md) links executed totals,
reviewed images and limits. No unexecuted production check is marked passed.

Local photographs do not fulfill the cloud-storage requirement or assert
instructor approval. Final acceptance remains open while HU-20 and production
verification remain pending.
