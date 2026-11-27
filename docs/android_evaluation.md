# CampusFix Android evaluation

The Project 2 implementation starts from commit `71092e1`. The team still needs
to attach the instructor's original feedback and link each observation to its
implementation and verification. Android uses the same incident repositories,
transactions and role rules as the web application.

| Change included in the starting version | Commit | Mobile verification |
| --- | --- | --- |
| Administrative queue and filters | `7ff7fd4` | M02, M09 |
| Administrative incident detail | `31fbdd0` | M02, M09 |
| Technician assignment queue | `976572e` | M03, M09 |
| UCR identity and reporter incident list | `71092e1` | M01, M09 |

## Shared Firebase backend

Android (`cr.ac.ucr.campusfix`) and the web app both use Firebase project
`campus-fix-ucr`. The Android registration is part of the shared project, and
`lib/firebase_options.dart` contains the client configuration for both targets.
Collaborators sign in with their existing CampusFix credentials. Firebase Auth
uses the same UID and Firestore supplies the same role and incident records on
both clients.

Use existing test accounts for the reporter, administrator and active technician
roles. For demonstrations, create a fictional report with a title prefixed with
`TEST -` and use that report throughout. Updates are visible in both clients and
can trigger the existing status email worker. The Firebase emulators remain
available for isolated development.

## Build, install and update

Use the repository Flutter pin, Android SDK and the Android Studio JDK. Build a
single APK from a clean, identified commit and increment the build number for
each distributed version.

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
flutter test
flutter build apk --release --build-name=1.1.0 --build-number=1
git rev-parse HEAD
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
```

The candidate uses development signing for academic distribution. Designate one
build machine and signing identity for all distributed candidates. Retain the
APK, SHA-256, build number and commit together. On the Galaxy S24 Ultra and a
second physical device, transfer the APK using an approved channel, install it,
then open CampusFix and sign in with the assigned CampusFix test account. A clean install
should be recorded on a phone distinct from the usual development phone. Test
the shared Firebase backend over mobile data or an independent network.

Install an update over the previous build signed by the same identity. To recover
while keeping app data, rebuild the previous stable source and configuration with
the same signing identity and a higher build number. A clean reinstall of the
archived APK is an alternative if the user agrees to discard local app data.
Confirmed incidents remain in Firestore, while uninstalling clears local drafts.

For emulator development, start the existing demo backend and load its fixtures
using [Local evidence storage](local_evidence.md). Then run
`flutter run -d <android-emulator-id> --target tool/demo_main.dart`. The Android
emulator uses `10.0.2.2` to reach the host Firebase emulators. The distributed
APK uses `lib/main.dart` instead. The Android evaluation covers text incidents,
progress and resolution. Photo evidence remains available in the local web
client.

## Functional scope and acceptance cases

Record the device, Android and One UI versions, app version and commit, initial
conditions, steps, actual result and evidence for each execution. The entries
below are acceptance criteria. Actual results require device execution.

| ID | Case | Expected result |
| --- | --- | --- |
| M01 | As reporter, submit a fictional report and open its detail. | A server-confirmed sequence appears. The incident is visible in the reporter's list and detail. |
| M02 | As administrator, classify the incident and assign the test technician. | Category and priority persist. The technician's queue shows the assigned report and the history records the transition. |
| M03 | As technician, start attention, save a text progress entry and resolve the incident. | Progress and the solution persist. Authorized detail shows both and the new state. |
| M04 | Submit with missing title, category or location. | Required fields are marked and there is no confirmed report. |
| M05 | Open an incident belonging to another account or attempt an action outside the signed-in role. | Access is denied and the incident/history are unaffected. The existing Firestore rule tests cover authorization independently of the UI. |
| M06 | Save an Android draft, force-stop CampusFix, launch again and open the report form. | The same account can recover its fields. A different account receives its own draft. |
| M07 | Turn off Wi-Fi and mobile data before submitting, restore connectivity and retry. | The app preserves the original submission ID, shows an unconfirmed state and eventually shows one confirmed incident. |
| M08 | Clean-install the release APK on a physical Android device and sign in over an independent network. | The app opens and reaches the shared Firebase backend. An update preserves a draft with the same package and signing identity. |
| M09 | On the Galaxy S24 Ultra, repeat M01–M03 with the keyboard open where applicable, enlarged font/display settings and TalkBack. | Controls remain reachable by scrolling, input and focus order are clear, and actions or state changes can be understood without relying on color. |

Use logical viewport dimensions for layout checks. Record the actual settings on
the Galaxy S24 Ultra, as display zoom, text scaling, keyboard and system bars
affect the usable viewport. Run the three role tasks on one identified version
with three volunteers outside the team, at least one with relevant experience.
Capture outcome, time, errors, assistance, ease rating from 1 to 5 and comments.
Retest the highest-impact fix with at least one of those participants.

## Feedback and release evidence

Record each Project 1 observation with its action, priority, evidence and status.
For the 15-minute live demonstration and 10-minute feedback session, show the
three roles, installation, changes and test results. Collect feedback from the
instructor and another team. Record the decision and reasoning for each item,
implement at least two applicable improvements and retest them. If fewer than
two items are applicable, implement all applicable items and record why.

For final submission, tag the verified version and include the APK and evaluation
access, technical report, improvement matrix, technical and user test report,
presentation and feedback instrument, user guide, and each member's contributions.
