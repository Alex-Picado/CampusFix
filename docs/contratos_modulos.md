# CampusFix: contratos entre módulos

> Part 2 implementation update: [Incidents, evidence and progress](part_2_incidents.md)
> records the requested local evidence service and versioned file storage. For
> Part 2 evidence only, it supersedes the cloud-file-provider and no-custom-server
> assumptions below. Authentication, Firestore and the other module contracts
> remain in effect. Implementation and verification are still pending.

## Alcance y estado de este acuerdo

Este documento fija nombres y responsabilidades para continuar la Parte 1 sin implementar las entregas de los compañeros. Las operaciones propuestas son contratos de diseño; no son interfaces ni servicios ya disponibles.

| Elemento | Estado actual | Responsable siguiente |
|---|---|---|
| Acceso, sesión, perfiles y roles | Implementados; pruebas reales registradas en `autenticacion.md` | Alex mantiene su base |
| `UserProfile`, `UserRole`, `Category` | Modelos con conversión de datos | Cada módulo los reutiliza |
| `Incident`, `IncidentStatus`, `IncidentPriority` | Campos y enumeraciones; falta serialización de `Incident` | José |
| Incidencias, consecutivos, fotografías y avances | Pendientes | José, Parte 2 |
| Clasificación, asignaciones, transiciones y auditoría | Pendientes | Christian, Parte 3 |
| Categorías, consultas, indicadores e integración final | Pendientes | Daniel, Parte 4 |

La arquitectura acordada es `screen → controller → repository → service`. La pantalla no accede directamente a Firebase. Los controladores usan `ChangeNotifier`; las dependencias se reciben por constructor.

Se mantiene Firebase Spark sin activar facturación. No se incorpora un servidor propio ni Cloud Functions. Las actualizaciones automáticas usarán escuchas de Firestore; la sugerencia de WebSockets no implica crear otro servidor.

El enunciado exige Firebase Storage para fotografías. Usar otro proveedor, como Cloudinary, continúa sujeto a aceptación del profesor; José debe resolverlo antes de integrar ese módulo. El límite de 3 MB es un acuerdo del equipo, no un requisito atribuido al enunciado.

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

### `categories/{categoryId}`: almacenamiento pendiente

| Campo | Tipo almacenado | Regla |
|---|---|---|
| `name` | string | Nombre de la categoría |
| `isActive` | boolean | Controla si puede seleccionarse en reportes nuevos |

`Category.toMap()` y `Category.fromMap()` ya existen. Daniel implementará el repositorio y la administración. Se desactivará una categoría usada en lugar de eliminarla y dejar referencias rotas; las incidencias anteriores conservan `categoryId`.

### `incidents/{incidentId}`: almacenamiento pendiente

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

La serialización de `Incident` está pendiente: no asumir que dispone de `toMap()`, `fromMap()` o `copyWith()`. José añadirá la conversión y sus pruebas sin cambiar silenciosamente estos nombres.

Los roles usan `.name`; estados y prioridades usan `.value`. No guardar `underReview`, `inProgress` o `high` como estados/prioridades. La interfaz puede mostrar tildes aunque el valor almacenado sea `EN_REVISION` o `EN_ATENCION`.

Las fechas de escritura se establecerán con hora del servidor. El límite entre repositorio y servicio convertirá `Timestamp` a `DateTime` y viceversa. Los valores locales aún pendientes de confirmación deben manejarse explícitamente; no sustituir fechas desconocidas por una fecha inventada.

### Consecutivo: `counters/incidents`, pendiente

Campos acordados: `lastSequenceNumber`, integer, y `lastIncidentId`, string con el ID de la incidencia creada por ese incremento. Si todavía no existe el contador, la primera transacción parte de cero y asigna el número uno.

La creación leerá el contador y escribirá contador actualizado, incidencia y evento inicial en una misma transacción. Generará los IDs necesarios antes del bloque que Firestore puede reintentar. La transacción no subirá fotografías ni mostrará mensajes de éxito.

La prueba mínima crea dos reportes simultáneos y comprueba IDs distintos, números distintos y exactamente un evento inicial por reporte. La operación puede fallar sin conexión; la pantalla conservará el formulario y permitirá reintentar sin anunciar una creación confirmada.

José debe diseñar y probar las reglas que vinculen el incremento con la incidencia creada: incremento de exactamente uno y documento nuevo identificado por `lastIncidentId`, con número coincidente y creador autenticado, verificables en la misma operación con `getAfter()`. No se autoriza una escritura general al contador. La transacción del cliente, por sí sola, no impide que una petición modificada intente saltarse el contrato.

### Subcolecciones: diseño pendiente de implementación

El enunciado describe fotografías, comentarios e historial conceptualmente. El uso de subcolecciones es una decisión técnica del equipo para evitar que el documento de la incidencia crezca con cada actualización.

| Ruta | Campos propuestos | Responsable |
|---|---|---|
| `incidents/{incidentId}/progress/{progressId}` | `authorUserId`, `createdAt`, `description` | José |
| `incidents/{incidentId}/history/{eventId}` | `actorUserId`, `createdAt`, `action`, `fromStatus`, `toStatus`, `fromTechnicianId`, `toTechnicianId`, `reason` | Christian; José crea el evento inicial |
| `incidents/{incidentId}/evidence/{evidenceId}` | `uploadedByUserId`, `createdAt`, `provider`, `assetId`, `url`, `fileName`, `contentType`, `sizeBytes`, `progressId` | José |

Los modelos de avance, evento y evidencia todavía no existen. Sus IDs se obtendrán de los documentos y las fechas usarán `Timestamp`. Los estados dentro del historial siguen los mismos valores `.value` que la incidencia.

`action` usará códigos compartidos en inglés: `created`, `classified`, `assigned`, `started`, `progressAdded`, `resolved`, `closed`, `rejected`, `cancelled`, `reopened`. Los campos de antes/después no aplicables y `reason` opcional se guardarán como null; los motivos requeridos no estarán vacíos.

`progressId` será null para evidencia del reporte inicial y contendrá el ID del avance cuando corresponda. `assetId` identifica el archivo en el proveedor; `url` es su referencia de consulta. Firestore no almacenará los bytes ni imágenes en Base64.

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

### `IncidentRepository`: propuesta, Partes 2 y 3

Los nombres fijan la intención del contrato; las firmas Dart completas y tipos auxiliares se definirán al implementarlos. El actor se obtiene de la sesión autenticada y las reglas comprueban su UID y permisos.

| Operación | Entrada → resultado esperado | Permiso y responsable | Historias |
|---|---|---|---|
| `create` | Título, descripción, categoría y ubicación → `Future<Incident>` con ID y consecutivo confirmados | Reportante; José | HU-05 |
| `watchOwn` | UID propio → `Stream<List<Incident>>` | Reportante, solo sus casos; José | HU-07 |
| `watchById` | `incidentId` → `Stream<Incident?>` | Propietario, técnico asignado o administrador; José | HU-08 |
| `watchHistory` | `incidentId` → stream de eventos cronológicos | Mismo acceso al detalle; José consume, Christian completa eventos | HU-08, HU-19 |
| `watchProgress` | `incidentId` → stream de avances/comentarios | Mismo acceso al detalle; José | HU-08, HU-12 |
| `addProgress` | `incidentId`, descripción, referencias de evidencia opcionales → `Future<void>` | Técnico asignado durante atención; José | HU-12 |
| `watchAll` | Sin argumentos → `Stream<List<Incident>>` | Administrador; Christian | HU-09 |
| `classify` | `incidentId`, `categoryId`, prioridad → `Future<void>` | Administrador; Christian | HU-09 |
| `assignTechnician` | `incidentId`, UID técnico → `Future<void>` | Administrador; Christian | HU-10 |
| `watchAssigned` | UID propio → `Stream<List<Incident>>` | Técnico, solo casos asignados; Christian | HU-10, HU-11 |
| `startAttention` | `incidentId` → `Future<void>` | Técnico asignado; Christian | HU-11 |
| `resolve` | `incidentId`, solución no vacía → `Future<void>` | Técnico asignado; Christian | HU-13 |
| `close` | `incidentId` → `Future<void>` | Administrador; Christian | HU-14 |
| `reject`, `cancel`, `reopen` | `incidentId`, motivo no vacío → `Future<void>` | Administrador según matriz siguiente; Christian | Flujo acordado |

Las consultas del propietario y del técnico incluirán el filtro de UID en Firestore. No consultar todos los casos para luego ocultar los ajenos en Flutter: las reglas autorizan consultas completas, no filtran sus resultados.

Una categoría válida y una prioridad asignada serán condiciones previas de la asignación. El destino debe corresponder a un usuario técnico; el cliente no puede asignar arbitrariamente un UID como si tuviera ese rol.

Cada clasificación, asignación o cambio de estado actualizará la incidencia y creará su evento en la misma transacción. Los cambios basados en el estado anterior volverán a leerlo dentro de esa transacción. Christian definirá el vínculo verificable con el evento al implementar las reglas y probará escrituras incompletas o alteradas.

`addProgress` guardará el avance, las referencias de evidencia relacionadas y el evento `progressAdded` de forma atómica en Firestore. La subida externa del archivo ocurre fuera de esa transacción; no se promete atomicidad entre dos proveedores.

### `CategoryRepository` y consultas: propuesta, Parte 4

| Operación | Entrada → resultado esperado | Permiso y responsable | Historias |
|---|---|---|---|
| `watchActive` | Sin argumentos → `Stream<List<Category>>` | Sesión autenticada; Daniel | Selección en HU-05 |
| `watchAll` | Sin argumentos → `Stream<List<Category>>` | Administrador; Daniel | Módulo de catálogos |
| `create` | Nombre → categoría persistida | Administrador; Daniel | Módulo de catálogos |
| `update` | `categoryId`, nombre, `isActive` → `Future<void>` | Administrador; Daniel | Módulo de catálogos |
| Consultas e indicadores | Incidencias autorizadas y criterios → resultados/conteos | Según el rol; Daniel | HU-15 a HU-18 |

Para el volumen previsto, Daniel puede buscar texto y combinar filtros sobre las incidencias autorizadas ya cargadas. No se contrata otro buscador. Las categorías inactivas deben seguir pudiendo identificarse en el detalle histórico; Daniel resolverá esa lectura con permisos explícitos.

Para probar la Parte 2 antes de completar la administración de catálogos, se prepararán categorías de prueba desde la consola. José incorporará la lectura de categorías activas y sus permisos mínimos, coordinando el contrato con Daniel; la administración completa del catálogo permanece en la Parte 4.

## Fotografías: contrato independiente del proveedor

José implementará `EvidenceRepository`; las pantallas dependerán de ese contrato y no de APIs concretas de Cloudinary o Storage.

- `upload`: recibe bytes, nombre, tipo de contenido y contexto de incidencia/avance; devuelve una referencia con `provider`, `assetId`, `url`, `fileName`, `contentType` y `sizeBytes` después de una carga confirmada.
- `attachToIncident`: recibe `incidentId`, un `evidenceId` estable y la referencia devuelta por la carga; devuelve `Future<void>` al persistir los metadatos de una fotografía inicial con `progressId: null`. Autoriza al reportante propietario y comprueba la incidencia existente. El ID estable permite reintentar la misma asociación sin duplicarla. Las evidencias de avances se asocian mediante `addProgress`.
- `watchByIncident`: recibe `incidentId`; emite metadatos de evidencias para quienes pueden consultar ese caso.
- La asociación persistente añade UID del autor y hora del servidor; no acepta un autor inventado desde el formulario.
- Se validará que sea una imagen y que no supere 3 MB. El equipo fija aquí 3 MB como 3 000 000 bytes para evitar umbrales distintos entre pantallas y proveedor.
- La validación del cliente mejora el mensaje; José también configurará las restricciones disponibles en el proveedor. No se incluirán claves administrativas ni secretos de firma dentro de Flutter.
- Una carga fallida conserva los datos del formulario y permite reintento. Si el archivo sube pero falla su asociación, se conserva una referencia para reintentar o se elimina mediante una operación autorizada si el proveedor lo permite.
- No se incorporan tarjeta, facturación ni servicios pagos. La selección del proveedor y la aceptación académica siguen pendientes; no se garantiza una cuota gratuita específica en este contrato.
- Las reglas de Firestore protegen metadatos, no una URL pública externa. José documentará quién puede abrir el archivo y qué protección ofrece realmente el proveedor elegido.

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

Las reglas de rechazo, cancelación y reapertura son acuerdos del equipo: el enunciado menciona esos estados sin detallar todas sus transiciones. Christian debe conservar esta distinción al documentarlos.

`IncidentStatus.reopened` ya existe con valor `REABIERTA`. El acuerdo actual registra `action: reopened` en el historial y devuelve el caso a `EN_REVISION`, sin dejarlo estacionado en `REABIERTA`. No eliminar ese enum ni producir un flujo distinto sin coordinarlo.

Para concretar la reapertura se propone limpiar `resolutionDescription` y conservar la solución anterior en un campo `previousResolutionDescription` del evento. Esta política adicional deberá acordarse al implementar la Parte 3; no es una condición impuesta por el enunciado.

La misma propuesta limpia `assignedTechnicianId` y requiere nueva clasificación/asignación, registrando esa eliminación en el evento. Si se permite reasignar durante atención, Christian debe acordar primero su transición y pruebas; no es una operación implícita.

Para los indicadores, abiertas son `REPORTADA`, `EN_REVISION`, `ASIGNADA` y `EN_ATENCION`. `RESUELTA` sigue pendiente de cierre administrativo, pero se cuenta separadamente; `CERRADA`, `RECHAZADA` y `CANCELADA` no se mezclan con abiertas.

## Escuchas, permisos y evidencias de entrega

Cada controlador es dueño de sus suscripciones: cancela al salir del módulo y al hacer `dispose()`. Al cerrar sesión o perder el rol, se desmonta el módulo y se limpian listas y datos privados. Una respuesta tardía no debe modificar la siguiente sesión.

Las pantallas distinguen carga, lista vacía, error de lectura y error al guardar. Un snapshot posterior no debe borrar un error de guardado pendiente. Tras perder conexión se indica el estado disponible y se comprueba recuperación; no se confunde una vista local con una escritura confirmada.

Las reglas actuales solo permiten operaciones autorizadas en `users`; `categories`, `incidents`, `counters` y sus subcolecciones continúan denegadas. Este documento no habilita esos accesos. Cada responsable entregará reglas y pruebas junto con su módulo, sin usar un permiso general para desbloquearlo.

Se comprobarán consultas y escrituras directas no autorizadas, transiciones inválidas y ausencia de eventos huérfanos. Las pruebas deben intentar modificar UID, rol, consecutivo, actor y fechas; esconder botones no constituye una prueba de seguridad.

Cada entrega documenta clases/métodos públicos, datos, errores, permisos y la relación `HU → implementación → evidencia de prueba`. Distinguir pruebas automatizadas ejecutadas, comprobaciones manuales confirmadas y verificaciones pendientes. Un formulario visible no acredita que el recorrido completo funcione.

Los cambios se guardan en commits pequeños y coherentes con `tipo(alcance): descripción`, usando `feat`, `fix`, `perf`, `build`, `ci`, `docs`, `refactor`, `style` o `test`. No dividir artificialmente una funcionalidad solo para aumentar el contador.

La integración de `feat/base` a `main` debe preservar los commits individuales mediante un merge normal. Evitar `Squash and merge`, que reemplazaría ese historial por un solo commit en `main`. Alex ejecuta sus commits y push; las siguientes entregas también conservan su historia significativa.

José implementa y documenta la Parte 2; Christian revisa esa entrega y realiza la Parte 3; Daniel revisa la Parte 3 y coordina la Parte 4. Cada integrante corrige los problemas de su módulo. Alex revisa el cierre de Daniel. La publicación final pertenece a la Parte 4.

## Referencias técnicas

- [Transacciones y escrituras atómicas de Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions): operaciones conjuntas y reintentos por concurrencia.
- [Condiciones y acceso a documentos en reglas](https://firebase.google.com/docs/firestore/security/rules-conditions): permisos por datos y validación de operaciones relacionadas con `getAfter()`.
- [Escritura de datos y hora del servidor](https://firebase.google.com/docs/firestore/manage-data/add-data): timestamps establecidos en Firestore.
