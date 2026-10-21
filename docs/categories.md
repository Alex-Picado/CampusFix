# CampusFix: Active Category Reader

## Overview

The active category reader supplies the categories available for incident report
selection. Firestore access is isolated in `CategoryService`; parsing and list
ordering belong to `CategoryRepository`. Both dependencies are provided through
their constructors.

## Interfaces

| API | Result | Behavior |
| --- | --- | --- |
| `CategoryService(firestore: ...)` | Service instance | Uses the supplied Firestore connection. |
| `CategoryService.watchActive()` | `Stream<Map<String, Map<String, dynamic>>>` | Observes `categories` with `where('isActive', isEqualTo: true)`, indexing document fields by document ID. |
| `CategoryRepository(categoryService: ...)` | Repository instance | Uses the supplied category service. |
| `CategoryRepository.watchActive()` | `Stream<List<Category>>` | Parses documents and emits an unmodifiable list ordered by case-insensitive name, then document ID. |

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

## Read permissions

The category rules in `firestore.rules` permit authenticated reads only when
the stored `isActive` field is the boolean value `true`. Direct reads of
inactive categories and collection queries without the active filter are
rejected. Category creation, modification and deletion remain denied by these
rules.

The reader exposes no catalog administration methods. Existing user-profile
rules retain their authorization conditions. Rule verification uses a local
emulator; it does not deploy the rules to a Firebase project.

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

Verified on October 21, 2026:

| Check | Result |
| --- | --- |
| `npm ci --prefix tool/firestore_tests` | Dependencies restored from the lockfile. |
| `npm test --prefix tool/firestore_tests` | 53 rule tests passed with Java `21.0.9`, including 10 category/profile checks. |
| Category repository tests | 8 tests passed as part of the 129-test Flutter suite. |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build web --no-pub` | Web build completed; preliminary WebAssembly check passed. |

## References

- [Category model](../lib/features/catalogs/models/category.dart).
- [Category service](../lib/features/catalogs/services/category_service.dart).
- [Category repository](../lib/features/catalogs/repositories/category_repository.dart).
- [Repository tests](../test/features/catalogs/repositories/category_repository_test.dart).
- [Firestore rule tests](../tool/firestore_tests/categories.rules.test.mjs).
- [Firestore rules](../firestore.rules).
