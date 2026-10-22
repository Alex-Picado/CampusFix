# CampusFix: Categories and Administration

## Overview

The active category reader supplies the categories available for incident report
selection. The administrator catalog supports creation, renaming and activation
or deactivation. Firestore access is isolated in `CategoryService`; validation,
parsing and ordering belong to `CategoryRepository`. The screen delegates to a
session-bound `CategoryManagementController`. Dependencies use constructors.

## Interfaces

| API | Result | Behavior |
| --- | --- | --- |
| `CategoryService(firestore: ...)` | Service instance | Uses the supplied Firestore connection. |
| `CategoryService.watchActive()` | `Stream<Map<String, Map<String, dynamic>>>` | Observes `categories` with `where('isActive', isEqualTo: true)`, indexing document fields by document ID. |
| `CategoryRepository(categoryService: ...)` | Repository instance | Uses the supplied category service. |
| `CategoryRepository.watchActive()` | `Stream<List<Category>>` | Parses documents and emits an unmodifiable list ordered by case-insensitive name, then document ID. |
| `CategoryRepository.watchAll()` | `Stream<List<Category>>` | Administrator-only complete catalog, including inactive records, in the same immutable order. |
| `CategoryRepository.watchById(categoryId)` | `Stream<Category?>` | Authenticated individual lookup, including inactive records; null when missing. |
| `CategoryRepository.create(name: ...)` | `Future<Category>` | Creates an active category and returns its acknowledged ID, name and flag. |
| `CategoryRepository.update(categoryId: ..., name: ..., isActive: ...)` | `Future<void>` | Renames or changes availability without changing identity or incident documents. |

`Category.fromMap()` reads `name` and `isActive` using the existing field
contract. The repository additionally rejects blank identifiers, blank names
and inactive records with `FormatException`. Valid names retain their original
spelling and whitespace. One invalid record rejects that snapshot; valid later
snapshots can still be emitted.

An empty query produces an empty list. The reader does not insert demonstration
categories. Service and parsing errors reach the subscriber instead of becoming
empty successful results. Cancelling the repository subscription cancels the
underlying Firestore observation.

The query filters active records in Firestore. Name ordering occurs in the
repository, without adding an `orderBy` clause to the database query.

New write names are trimmed and must be nonblank. Individual lookups and updates
reject empty, untrimmed, path-like and reserved document IDs before contacting
Firestore. Full-catalog and individual readers validate the two stored fields;
malformed snapshots fail explicitly instead of supplying placeholder categories.

```dart
final categoryService = CategoryService(firestore: firestore);
final categoryRepository = CategoryRepository(categoryService: categoryService);
final subscription = categoryRepository.watchActive().listen(
  onCategories,
  onError: onCategoryError,
);

// Cancel when the owning controller is disposed or its session ends.
await subscription.cancel();
```

## Permissions and historical references

The category rules in `firestore.rules` enforce the following independently of
menu visibility:

- Authenticated sessions may read one category, including an inactive one.
- Reporters and technicians must filter collection queries by `isActive == true`.
- Administrators may query the full catalog, create categories and update them.
- Writes require exactly `name` and boolean `isActive`, with a nonblank trimmed
  name and a valid category ID. Extra fields are rejected.
- No client, including an administrator, may delete categories.

Deactivation removes a category from new-report and classification selections.
Existing reports retain `categoryId` and resolve its name through `watchById`.
The detail displays the current catalog name and an inactive label, observes
renames live and offers a separate retry for category failures. A rename updates
the displayed name of existing reports; this does not introduce historical name
snapshots or change incident serialization. Missing categories remain visible as
an explicit error rather than a successful name lookup.

The administrative controller cancels its query when its screen closes and
permanently invalidates itself after a session, account or role change. It clears
rows, drafts and feedback and ignores late acknowledgements. Writes already sent
under an authorized session may still finish. Pending writes disable duplicate
submissions and editing; success is shown only after acknowledgement. List
failures and write failures have separate feedback and retry behavior.

These checks use local emulators and do not deploy rules to the Firebase project.
Production catalog writes require the reviewed rules to be deployed separately.

## Local rule verification

Use the runtimes described in [Runtime configuration](toolchain.md) and Java 21
on `PATH`. The verified Java runtime is `21.0.9`. The pretest check rejects a
missing or different Java major version before starting the emulator.

When several JDK versions are installed, select Java 21 for the terminal
session. For example, in PowerShell, replacing the path with the installed JDK:

```powershell
$env:JAVA_HOME = 'C:\path\to\jdk-21'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
java -version
```

These assignments apply to the current terminal session.

From the repository root:

```text
npm ci --prefix tool/firestore_tests
npm test --prefix tool/firestore_tests
```

The package pins Firebase SDK, rules-testing library and Firebase CLI versions;
`package-lock.json` records their dependency resolution. Installation can
require network access. The CLI also downloads the Firestore emulator on first
use when it is not cached.

The test command starts Firestore on `127.0.0.1:8085`, uses the explicit
`demo-campusfix` project, runs the tests and shuts down the emulator. The test
file rejects execution unless `FIRESTORE_EMULATOR_HOST` matches that local
address. Fixtures are created only inside that test environment, with separate
reporter, technician and administrator identities.

The suite verifies authenticated filtered queries, direct reads, rejected
inactive and unfiltered queries, malformed active flags, denied catalog writes
and existing profile permissions. The same test command also runs the
[incident creation rule suite](incident_security.md). Repository tests cover
ordering, live changes, empty results, immutability, malformed snapshots, error
recovery and subscription cancellation.

Historical verification before Part 4, on October 21, 2026:

| Check | Result |
| --- | --- |
| `npm ci --prefix tool/firestore_tests` | Dependencies restored from the lockfile. |
| `npm test --prefix tool/firestore_tests` | 61 rule tests passed with Java `21.0.9`, including 10 category/profile checks. |
| Category repository tests | 8 tests passed as part of the 190-test Flutter suite. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

Current Part 4 verification and remaining phases are recorded in
[Part 4 delivery progress](part_4_delivery.md). Historical results above are not
a claim that the previous deny-all catalog policy remains in effect.

## References

- [Category model](../lib/features/catalogs/models/category.dart).
- [Category service](../lib/features/catalogs/services/category_service.dart).
- [Category repository](../lib/features/catalogs/repositories/category_repository.dart).
- [Repository tests](../test/features/catalogs/repositories/category_repository_test.dart).
- [Firestore rule tests](../tool/firestore_tests/categories.rules.test.mjs).
- [Firestore rules](../firestore.rules).
