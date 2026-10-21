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

## Documentation

- [Incident models](docs/part_2_incidents.md).
- [Incident creation](docs/incident_creation.md).
- [Incident creation security](docs/incident_security.md).
- [Incident observation](docs/incident_observation.md).
- [Report draft and submission controller](docs/incident_reporting.md).
- [Local evidence service](docs/local_evidence.md).
- [Incident detail and follow-up](docs/incident_followup.md).
- [Active category reader](docs/categories.md).
- [Runtime configuration](docs/toolchain.md).
