# CampusFix: contratos entre módulos

The [Incident model reference](part_2_incidents.md) describes incident, progress,
history and evidence serialization. [Runtime configuration](toolchain.md)
documents the executable versions and verification commands.

## Alcance y estado de este acuerdo

This reference defines shared field names, stored values and module boundaries.
Operations marked as proposed are interface contracts rather than implemented
services.

| Elemento | Estado actual | Integration area |
|---|---|---|
| Acceso, sesión, perfiles y roles | Implementados; pruebas reales registradas en `autenticacion.md` | Identity and access |
| `UserProfile`, `UserRole`, `Category` | Modelos con conversión de datos | Shared models |
| `Incident`, `IncidentStatus`, `IncidentPriority` | Model conversion and copy operations implemented | Incident data |
| Incident creation and sequences | Transactional service, repository and related-write security rules implemented | Incident persistence |
| Incident observation | Own reports and authorized detail, history and progress readers implemented | Incident queries |
| Photographs and progress persistence | Not implemented | Evidence and progress |
| Clasificación, asignaciones, transiciones y auditoría | Pendientes | Operational workflow |
| Active category reader | Service, repository and read rules implemented | Incident report selection |
| Category administration, queries and indicators | Proposed interfaces | Catalogs and reporting |

La arquitectura acordada es `screen → controller → repository → service`. La pantalla no accede directamente a Firebase. Los controladores usan `ChangeNotifier`; las dependencias se reciben por constructor.

Firebase Authentication and Firestore provide account and metadata services.
Real-time updates use Firestore listeners.

The evidence contract defines a maximum file size of 3 000 000 bytes. File-provider
configuration is separate from the incident metadata schema.

## Diccionario de datos

Los nombres siguientes respetan los modelos existentes. El identificador `id` se obtiene del ID del documento y no se duplica dentro de sus campos.

### `users/{userId}`: implementado

`userId` coincide con el UID de Firebase Authentication.

| Campo | Tipo almacenado | Regla |
|---|---|---|
| `fullName` | string | Nombre no vacío |
| `email` | string | Correo de la cuenta; no se modifica desde el perfil |
| `role` | string | `reporter`, `technician` o `administrator`, mediante `UserRole.name` |

Un registro normal crea un reportante. La preparación del primer administrador se realiza administrativamente y está documentada en `autenticacion.md`.

### `categories/{categoryId}`: active reader implemented

| Campo | Tipo almacenado | Regla |
|---|---|---|
| `name` | string | Nombre de la categoría |
| `isActive` | boolean | Controla si puede seleccionarse en reportes nuevos |

`Category.toMap()` and `Category.fromMap()` provide model conversion. Category
administration is a separate interface. Deactivation preserves `categoryId`
references in existing incidents without requiring deletion.

`CategoryService` queries only active documents. `CategoryRepository` parses
them into immutable lists sorted by case-insensitive name and then ID.
[Active category reader](categories.md) documents errors, subscriptions and
local permission verification.

### `incidents/{incidentId}`: transactional creation API

| Campo | Tipo almacenado | Correspondencia con `Incident` |
|---|---|---|
| `sequenceNumber` | integer | Consecutivo único mostrado al usuario |
| `title` | string | Título del reporte |
| `description` | string | Descripción del problema |
| `categoryId` | string | ID de categoría |
| `location` | string | Ubicación dentro del campus |
| `priority` | string o null | `IncidentPriority.value`: `BAJA`, `MEDIA`, `ALTA` |
| `status` | string | `IncidentStatus.value`; inicialmente `REPORTADA` |
| `createdAt` | Timestamp | Fecha de creación; `DateTime` en Dart |
| `updatedAt` | Timestamp | Fecha de última modificación; `DateTime` en Dart |
| `createdByUserId` | string | UID del reportante autenticado |
| `assignedTechnicianId` | string o null | UID del técnico asignado |
| `resolutionDescription` | string o null | Solución obligatoria al resolver |

`Incident.toMap()`, `Incident.fromMap(id: ..., data: ...)` and `Incident.copyWith()`
preserve the field names above and omit `id` from stored maps.
Dates are `DateTime` at the model boundary: services must normalize confirmed
Firestore timestamps before parsing and apply server timestamps when writing.
Pending or missing dates are rejected instead of replaced with local estimates.

`copyWith()` preserves the ID, sequence number, creator and creation time.
Its `clearPriority`, `clearAssignedTechnician` and `clearResolution` flags clear
nullable fields explicitly. These model methods do not authorize writes or
implement lifecycle transitions. Behavior and verification are documented in
[Incident model](part_2_incidents.md).

Los roles usan `.name`; estados y prioridades usan `.value`. No guardar `underReview`, `inProgress` o `high` como estados/prioridades. La interfaz puede mostrar tildes aunque el valor almacenado sea `EN_REVISION` o `EN_ATENCION`.

Las fechas de escritura se establecerán con hora del servidor. El límite entre repositorio y servicio convertirá `Timestamp` a `DateTime` y viceversa. Los valores locales aún pendientes de confirmación deben manejarse explícitamente; no sustituir fechas desconocidas por una fecha inventada.

### Sequence: `counters/incidents`

Campos acordados: `lastSequenceNumber`, integer, y `lastIncidentId`, string con el ID de la incidencia creada por ese incremento. Si todavía no existe el contador, la primera transacción parte de cero y asigna el número uno.

`IncidentService.create()` reads the counter and writes its increment, the
incident and `history/created` in one transaction. Document references are
fixed before the callback. `IncidentRepository.newIncidentId()` allocates the
stable ID retained for retries. No photographs or UI effects occur inside
the transaction.

Creation tests execute concurrent submissions against a controlled transaction
double and verify distinct sequences and a single initial event per report.
The independent JavaScript SDK rule suite exercises concurrent creation
against the local Firestore emulator. [Incident creation](incident_creation.md)
documents the API; [Creation security](incident_security.md) documents related
writes, minimum read permissions and bounded counter retries.

The counter rules require an increment of exactly one and a new incident
identified by `lastIncidentId`, with the same sequence and authenticated creator.
The rule source validates related writes with `getAfter()`. A client transaction
alone does not authorize unrestricted counter updates.

### Subcollection record formats

`IncidentProgress`, `IncidentHistoryEvent` and `IncidentEvidence` provide
`toMap()` and `fromMap()` conversions for their record fields. Document IDs
remain separate from those fields. Dates use `DateTime` in models and require
timestamp conversion at the persistence boundary.

| Ruta | Model fields | Model |
|---|---|---|
| `incidents/{incidentId}/progress/{progressId}` | `authorUserId`, `createdAt`, `description` | `IncidentProgress` |
| `incidents/{incidentId}/history/{eventId}` | `actorUserId`, `createdAt`, `action`, `fromStatus`, `toStatus`, `fromTechnicianId`, `toTechnicianId`, `reason` | `IncidentHistoryEvent` |
| `incidents/{incidentId}/evidence/{evidenceId}` | `uploadedByUserId`, `createdAt`, `provider`, `assetId`, `url`, `fileName`, `contentType`, `sizeBytes`, `progressId` | `IncidentEvidence` |

The history model uses the same `IncidentStatus.value` strings as the incident.
Unresolved dates and unsupported stored values raise `FormatException`.

`IncidentHistoryAction` defines the English codes `created`, `classified`,
`assigned`, `started`, `progressAdded`, `resolved`, `closed`, `rejected`,
`cancelled` and `reopened`. Optional fields are serialized as null. Present
technician identifiers and reasons must be nonblank.

`IncidentEvidence.provider` is `local`. Metadata accepts JPEG, PNG and WebP
content types and a positive size up to 3 000 000 bytes. `progressId` is null
for a report photograph or identifies its related progress entry. `assetId`
identifies the file and `url` contains its retrieval reference. Serialized
metadata contains neither image bytes nor Base64 data.

El detalle debe mostrar fotografías, comentarios e historial (HU-08). La propuesta representa los comentarios de seguimiento mediante `progress.description`, con autor y fecha; esos textos deben verse en el detalle y no quedar ocultos en otra pantalla. Si el profesor requiere además comentarios libres distintos de los avances, se acordará ese alcance antes de crear otro contrato.

El historial será cronológico e inmutable desde el cliente: no se ofrecerán edición ni eliminación de eventos existentes. Conservará quién realizó cada cambio aunque después cambie su nombre o rol.

## Repositorios disponibles y propuestos

Todos los métodos pueden propagar errores de Firebase o datos inválidos. Los controladores presentan mensajes en español mediante `AppErrorMessages`; no muestran excepciones técnicas al usuario. Un resultado exitoso significa que la operación fue confirmada, no solamente que se pulsó el botón.

### `UserRepository`: disponible, Parte 1

| Operación | Entrada → resultado | Autorización |
|---|---|---|
| `getById` | `userId` → `Future<UserProfile?>` | Propietario o administrador |
| `watchById` | `userId` → `Stream<UserProfile?>` | Propietario o administrador |
| `saveProfile` | `UserProfile` → `Future<void>` | Creación propia como reportante; no es una vía para cambiar libremente el rol |
| `updateFullName` | `userId`, `fullName` → `Future<void>` | El propietario cambia únicamente su nombre |
| `watchAll` | Sin argumentos → `Stream<List<UserProfile>>` | Solo administrador; lista inmutable ordenada por nombre |
| `updateRole` | `userId`, `UserRole` → `Future<void>` | Solo administrador; cambia únicamente `role` |

La pantalla y el controlador impiden que el administrador se quite accidentalmente su propio rol. Las reglas actuales no garantizan que siempre quede un administrador; no presentar ese bloqueo visual como una garantía del servidor.

`saveProfile` reemplaza un documento completo. Los módulos posteriores deben usar operaciones específicas para cambios parciales y no reconstruir perfiles con campos o roles supuestos.

### Incident repository interfaces

`newIncidentId()`, `create()`, `watchOwn()`, `watchById()`, `watchHistory()` and
`watchProgress()` are implemented. Other operations in this table are proposed
interfaces. [Incident observation](incident_observation.md) documents live
reader signatures, metadata and session behavior. The creation service derives
its actor from
the authenticated session; database authorization is enforced independently.

| Operación | Entrada → resultado esperado | Authorization | Historias |
|---|---|---|---|
| `newIncidentId` | No arguments → stable document ID; no writes | Local allocation | HU-05 |
| `create` | Stable incident ID, title, description, category and location → `Future<Incident>` with confirmed dates and sequence | Reporter profile and authenticated author | HU-05 |
| `watchOwn` | `userId` → `Stream<List<Incident>>`, newest first | Authenticated reporter, own UID only | HU-07 |
| `watchById` | `incidentId` → `Stream<Incident?>` | Author, assigned technician or administrator | HU-08 |
| `watchHistory` | `incidentId` → `Stream<List<IncidentHistoryEvent>>`, chronological | Same parent detail authorization | HU-08, HU-19 |
| `watchProgress` | `incidentId` → `Stream<List<IncidentProgress>>`, chronological | Same parent detail authorization | HU-08, HU-12 |
| `addProgress` | `incidentId`, descripción, referencias de evidencia opcionales → `Future<void>` | Técnico asignado durante atención | HU-12 |
| `watchAll` | Sin argumentos → `Stream<List<Incident>>` | Administrador | HU-09 |
| `classify` | `incidentId`, `categoryId`, prioridad → `Future<void>` | Administrador | HU-09 |
| `assignTechnician` | `incidentId`, UID técnico → `Future<void>` | Administrador | HU-10 |
| `watchAssigned` | UID propio → `Stream<List<Incident>>` | Técnico, solo casos asignados | HU-10, HU-11 |
| `startAttention` | `incidentId` → `Future<void>` | Técnico asignado | HU-11 |
| `resolve` | `incidentId`, solución no vacía → `Future<void>` | Técnico asignado | HU-13 |
| `close` | `incidentId` → `Future<void>` | Administrador | HU-14 |
| `reject`, `cancel`, `reopen` | `incidentId`, motivo no vacío → `Future<void>` | Administrador según matriz siguiente | Flujo acordado |

Las consultas del propietario y del técnico incluirán el filtro de UID en Firestore. No consultar todos los casos para luego ocultar los ajenos en Flutter: las reglas autorizan consultas completas, no filtran sus resultados.

Una categoría válida y una prioridad asignada serán condiciones previas de la asignación. El destino debe corresponder a un usuario técnico; el cliente no puede asignar arbitrariamente un UID como si tuviera ese rol.

Classification, assignment and status-change contracts require the incident
update and history event in the same transaction. State-dependent operations
must reread the current incident and validate the related event atomically.

`addProgress` guardará el avance, las referencias de evidencia relacionadas y el evento `progressAdded` de forma atómica en Firestore. La subida externa del archivo ocurre fuera de esa transacción; no se promete atomicidad entre dos proveedores.

### Category repository and query interfaces

| Operación | Entrada → resultado esperado | Permiso y responsable | Historias |
|---|---|---|---|
| `watchActive` (implemented) | No arguments → `Stream<List<Category>>` | Authenticated session | Selection in HU-05 |
| `watchAll` (proposed) | Sin argumentos → `Stream<List<Category>>` | Administrador | Módulo de catálogos |
| `create` (proposed) | Nombre → categoría persistida | Administrador | Módulo de catálogos |
| `update` (proposed) | `categoryId`, nombre, `isActive` → `Future<void>` | Administrador | Módulo de catálogos |
| Consultas e indicadores | Incidencias autorizadas y criterios → resultados/conteos | Según el rol | HU-15 a HU-18 |

Search and combined filters operate on authorized incident data. Historical
details retain category identifiers, including inactive categories; category
reads require explicit authorization.

The category-reading contract is separate from catalog administration. Selecting
a category for a report requires an authenticated read of active categories.

## Fotografías: contrato independiente del proveedor

`EvidenceRepository` defines the evidence interface independently of the file
provider. Presentation code depends on that interface.

- `upload`: recibe bytes, nombre, tipo de contenido y contexto de incidencia/avance; devuelve una referencia con `provider`, `assetId`, `url`, `fileName`, `contentType` y `sizeBytes` después de una carga confirmada.
- `attachToIncident`: recibe `incidentId`, un `evidenceId` estable y la referencia devuelta por la carga; devuelve `Future<void>` al persistir los metadatos de una fotografía inicial con `progressId: null`. Autoriza al reportante propietario y comprueba la incidencia existente. El ID estable permite reintentar la misma asociación sin duplicarla. Las evidencias de avances se asocian mediante `addProgress`.
- `watchByIncident`: recibe `incidentId`; emite metadatos de evidencias para quienes pueden consultar ese caso.
- La asociación persistente añade UID del autor y hora del servidor; no acepta un autor inventado desde el formulario.
- Se validará que sea una imagen y que no supere 3 MB. El equipo fija aquí 3 MB como 3 000 000 bytes para evitar umbrales distintos entre pantallas y proveedor.
- Client validation supplies user-facing feedback; provider-side restrictions enforce file constraints independently. Flutter configuration must not contain administrative keys or signing secrets.
- Una carga fallida conserva los datos del formulario y permite reintento. Si el archivo sube pero falla su asociación, se conserva una referencia para reintentar o se elimina mediante una operación autorizada si el proveedor lo permite.
- No se incorporan tarjeta, facturación ni servicios pagos. La selección del proveedor y la aceptación académica siguen pendientes; no se garantiza una cuota gratuita específica en este contrato.
- Firestore rules protect metadata. File access depends on the provider's authorization mechanism; metadata permissions alone do not protect an external public URL.

## Estados, actores y auditoría

El flujo principal conserva los valores existentes:

`REPORTADA → EN_REVISION → ASIGNADA → EN_ATENCION → RESUELTA → CERRADA`

| Acción | Origen → destino | Actor y condición |
|---|---|---|
| Revisar/clasificar | `REPORTADA → EN_REVISION` | Administrador; registra categoría y prioridad |
| Actualizar clasificación | `EN_REVISION → EN_REVISION` | Administrador; permite reclasificar un caso reabierto |
| Asignar | `EN_REVISION → ASIGNADA` | Administrador; categoría, prioridad y técnico válidos |
| Iniciar atención | `ASIGNADA → EN_ATENCION` | Únicamente el técnico asignado |
| Resolver | `EN_ATENCION → RESUELTA` | Técnico asignado; solución obligatoria |
| Cerrar | `RESUELTA → CERRADA` | Únicamente administrador |
| Rechazar | `EN_REVISION → RECHAZADA` | Administrador; motivo obligatorio |
| Cancelar | Estado activo anterior a `RESUELTA` → `CANCELADA` | Administrador; motivo obligatorio |
| Reabrir | `RESUELTA` o `CERRADA` → `EN_REVISION` | Administrador; motivo obligatorio |

The rejection, cancellation and reopening transitions are application rules.
The state enumeration alone does not define their authorization or transitions.

`IncidentStatus.reopened` ya existe con valor `REABIERTA`. El acuerdo actual registra `action: reopened` en el historial y devuelve el caso a `EN_REVISION`, sin dejarlo estacionado en `REABIERTA`. No eliminar ese enum ni producir un flujo distinto sin coordinarlo.

Para concretar la reapertura se propone limpiar `resolutionDescription` y conservar la solución anterior en un campo `previousResolutionDescription` del evento. Esta política adicional deberá acordarse al implementar la Parte 3; no es una condición impuesta por el enunciado.

The proposed reopening contract clears `assignedTechnicianId`, records that
change in history and requires a new classification and assignment. Reassignment
during attention requires an explicit transition contract and validation.

Para los indicadores, abiertas son `REPORTADA`, `EN_REVISION`, `ASIGNADA` y `EN_ATENCION`. `RESUELTA` sigue pendiente de cierre administrativo, pero se cuenta separadamente; `CERRADA`, `RECHAZADA` y `CANCELADA` no se mezclan con abiertas.

## Escuchas y permisos

Cada controlador es dueño de sus suscripciones: cancela al salir del módulo y al hacer `dispose()`. Al cerrar sesión o perder el rol, se desmonta el módulo y se limpian listas y datos privados. Una respuesta tardía no debe modificar la siguiente sesión.

Las pantallas distinguen carga, lista vacía, error de lectura y error al guardar. Un snapshot posterior no debe borrar un error de guardado pendiente. Tras perder conexión se indica el estado disponible y se comprueba recuperación; no se confunde una vista local con una escritura confirmada.

The current rule source allows authorized operations on `users`, authenticated
reads of active `categories` and atomic reporter creation of incidents with
their counter increment and initial history. Authors, assigned technicians and
administrators can read authorized incident details, history and progress.
Reporters can query their own incidents and read the creation counter. Valid
stored profiles can probe absent incident IDs. Incident updates, history mutation,
category writes, progress and evidence writes remain denied. Each operation
requires explicit
authorization; a general read/write grant is not part of the contract.

Se comprobarán consultas y escrituras directas no autorizadas, transiciones inválidas y ausencia de eventos huérfanos. Las pruebas deben intentar modificar UID, rol, consecutivo, actor y fechas; esconder botones no constituye una prueba de seguridad.

## Referencias técnicas

- [Transacciones y escrituras atómicas de Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions): operaciones conjuntas y reintentos por concurrencia.
- [Condiciones y acceso a documentos en reglas](https://firebase.google.com/docs/firestore/security/rules-conditions): permisos por datos y validación de operaciones relacionadas con `getAfter()`.
- [Escritura de datos y hora del servidor](https://firebase.google.com/docs/firestore/manage-data/add-data): timestamps establecidos en Firestore.
