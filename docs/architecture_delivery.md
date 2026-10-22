# Delivery architecture, data and permissions

CampusFix uses **screen → ChangeNotifier controller → repository → service**.
Provider supplies constructor-injected dependencies and owns view/session
controllers. Screens render Spanish state and delegate actions; repositories
validate models; services perform Firebase or authenticated local HTTP operations.

## Services and deployment

- Firebase Authentication handles registration, sessions and sign-out.
- Cloud Firestore stores profiles, catalogs, reports and follow-up records.
  Authorized snapshot listeners deliver updates without a custom socket server.
- Firebase Hosting serves the static public Flutter client, with SPA fallback and
  revalidation headers. No Java or Node server is deployed alongside that client.
- The optional local Node photograph service verifies sessions and parent
  permissions, storing bytes under `local_storage/evidence/`. The public client
  does not construct its repository. Cloud photograph storage is not delivered;
  no billing activation or image-provider migration is included.

## Data

| Path | Purpose |
| --- | --- |
| `users/{uid}` | Full name, email and stored role; ID matches Auth UID. |
| `categories/{id}` | Name and active flag; historical references keep the ID. |
| `incidents/{id}` | Sequence, content, category/location, priority/state, author, technician, timestamps and solution. |
| `counters/incidents` | Transactional sequence allocation tied to the related report. |
| `incidents/{id}/history/{event}` | Immutable actor, date, action, prior/new state and assignment, reasons and previous solution. |
| `incidents/{id}/progress/{entry}` | Technician, timestamp, description and optional evidence references. |
| `incidents/{id}/evidence/{photo}` | Protected metadata and relative local byte reference. |

The schema and [module contracts](contratos_modulos.md) retain their existing
fields. Lifecycle operations atomically update the incident and its history.
Stable IDs reconcile uncertain retries. Category deactivation preserves references;
live name lookup avoids rewriting incidents on rename.

## Independent authorization

| Operation | Reporter | Technician | Administrator |
| --- | --- | --- | --- |
| Create / own report list | Own identity | No reporter operation | No reporter operation |
| Detail, history, progress reads | Own reports | Assigned reports | All reports |
| Global incident list / indicators | Denied | Denied | Allowed |
| Classify, assign, close | Denied | Denied | Valid state and references |
| Start, progress, resolve | Denied | Own assignment and permitted state | No technician operation |
| Active category list / historical category by ID | Authenticated | Authenticated | Authenticated |
| Complete catalog / category writes | Denied | Denied | Validated administrator operation |
| Enumerate profiles / manage roles | Denied | Denied | Stored-role authorization |
| Upload local photograph bytes | Own report | Assigned case in attention | No implicit owner/technician write |

Firestore rules validate permissions, schemas, related writes and transitions.
Local photo authorization checks again after receiving bytes. Client navigation
never replaces those checks. No administrative credential or role override exists
in Flutter. Signed-out sessions cannot read protected records or images.

Controllers bind to the original UID/role, cancel listeners on exit or session
loss, clear private records and reject obsolete callbacks. Search/filters consume
only authorized data. Dashboard observation is independent and category failures
have a separate retry without replacing valid incident metrics with zeros.

Emulators, synthetic fixtures and Java checks remain development tooling outside
the compiled runtime. Production preparation explicitly disables emulator
connections. Permanent tests are separate from application implementation.
