# CampusFix

CampusFix is a Flutter Web application for campus service management. It uses
Firebase Authentication for account access and Cloud Firestore for user profiles
and roles. The incident models provide validated serialization and immutable
records independently of the persistence layer. An authenticated category
reader observes active categories for incident report selection.
The incident persistence API creates reports, sequence increments and initial
history events atomically, with stable IDs for retrying submissions.

## Documentation

- [Incident models](docs/part_2_incidents.md).
- [Incident creation](docs/incident_creation.md).
- [Active category reader](docs/categories.md).
- [Runtime configuration](docs/toolchain.md).
