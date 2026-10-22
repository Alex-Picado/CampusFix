# CampusFix

CampusFix is a Flutter Web application for campus service management. It uses
Firebase Authentication for account access and Cloud Firestore for user profiles
and roles. The incident models provide validated serialization and immutable
records independently of the persistence layer. An authenticated category
reader observes active categories for incident report selection.
The incident persistence API creates reports, sequence increments and initial
history events atomically, with stable IDs for retrying submissions.
Firestore rules validate the related writes and initial report fields.
Live incident readers provide own reports and authorized details, history and
technician progress with subscriptions tied to the authenticated session.
The reporting form manages validated drafts, stable submission retries and
server reconciliation, clearing its private state when the view or session ends.
The personal incident list observes the reporter's own records and updates their
status, location and creation date without reloading the application.
Protected detail routes show photographs, responsible accounts, comments and
history. Assigned technicians in attention can record progress with optional
photographs. Image bytes are stored in the versioned `local_storage/evidence/`
folder through a local authenticated Node.js service.

See [Local storage and startup](docs/local_evidence.md) for installation, portable
startup and the isolated emulator demonstration.

Administrators now classify reports, assign technicians, close resolutions and
manage rejection, cancellation and reopening through a live management queue.
Assigned technicians can start attention and resolve their cases. Lifecycle
updates and immutable audit events commit atomically, with independent Firestore
rules, stable retries and session-bound controllers.

Administrators can create, rename, activate and deactivate categories through a
live catalog. Existing incident details retain their category reference and show
its current name even after deactivation. Catalog writes are independently
protected by Firestore rules.

## Documentation

- [Incident management and Part 3 verification](docs/incident_management.md).
- [Authorized incident search](docs/incident_search.md).
- [Incident models](docs/part_2_incidents.md).
- [Incident creation](docs/incident_creation.md).
- [Incident creation security](docs/incident_security.md).
- [Incident observation](docs/incident_observation.md).
- [Report draft and submission controller](docs/incident_reporting.md).
- [Local evidence service](docs/local_evidence.md).
- [Incident detail and follow-up](docs/incident_followup.md).
- [Active category reader](docs/categories.md).
- [Part 4 delivery progress](docs/part_4_delivery.md).
- [Runtime configuration](docs/toolchain.md).
