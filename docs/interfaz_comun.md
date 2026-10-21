# Interfaz común de CampusFix

Esta entrega incorpora una interfaz sencilla con controles estándar de Material,
colores discretos y navegación consistente. Utiliza controles Material sin
fuentes o imágenes externas. Provider conecta las pantallas con los controladores.

## Alcance actual

- Inicio con accesos rápidos y una explicación breve del recorrido.
- Menú con vistas de incidencias, gestión, trabajo del técnico, indicadores,
  categorías, usuarios y perfil.
- Cada módulo pendiente muestra «Próximamente». No se simulan registros,
  fotografías, indicadores ni operaciones exitosas.
- Acceso mediante correo y contraseña, registro y recuperación del perfil pendiente.
- Consulta del nombre, correo y rol del perfil autenticado, y actualización del nombre.
- Listado de cuentas y cambios de rol desde Usuarios, exclusivo del administrador.
- Incident reporting form with active categories, validation, stable retries and confirmed sequence feedback.
- Personal incident list with live status updates, owner-filtered queries and separate loading, empty and error states.
- Cierre de sesión y recuperación de errores de observación.
- El menú y los accesos rápidos muestran únicamente las opciones del rol actual.
  La visibilidad del menú no sustituye las reglas de seguridad de Firestore.

## Adaptación a pantalla

- Desde 900 píxeles lógicos: menú lateral fijo.
- Por debajo de 900 píxeles lógicos: menú desplegable con el botón «Abrir menú».
- El contenido permite desplazamiento vertical y los accesos rápidos se ajustan
  al ancho disponible mediante `Wrap`.

## Responsabilidades

| Archivo o componente | Responsabilidad |
| --- | --- |
| `CampusTheme` | Colores y estilos compartidos. |
| `CampusDestination` | Etiquetas, descripciones y visibilidad por rol. |
| `CampusNavigation` | Opciones del menú lateral y desplegable. |
| `CampusShell` | Distribución responsiva, selección de vista y cierre de sesión. |
| `OverviewScreen` | Pantalla inicial y accesos rápidos. |
| `ModulePreviewScreen` | Identificación explícita de funciones pendientes. |
| `PageHeading`, `SectionCard` | Componentes visuales reutilizables. |
| `AppProviders` | Instancias compartidas de repositorios y controladores. |
| `SessionGate` | Pantalla de sesión y alcance del controlador de perfil por cuenta. |
| `AuthScreen` | Formularios de acceso y registro. |
| `CompleteProfileScreen` | Recuperación de una cuenta cuyo perfil falta. |
| `SessionFailureScreen` | Reintento de observación y salida ante un error. |
| `ProfileScreen` | Consulta del perfil y formulario para actualizar el nombre. |
| `UserManagementScreen` | Consulta de cuentas y selección de roles; administra el alcance de su controlador. |
| `UserManagementController` | Escucha de usuarios, estados de carga y cambios de rol. |
| `IncidentReportScreen` | Reporter form and ownership of its account-bound submission controller. |
| `MyIncidentsScreen` | Live personal report list and navigation to the reporting form. |

`main.dart` conserva la inicialización de Firebase antes de abrir la aplicación.
La conexión utiliza los servicios, repositorios y controladores existentes.

## Módulos y permisos de presentación

| Rol | Opciones visibles |
| --- | --- |
| Reportante | Inicio, Mis incidencias y Mi perfil. |
| Técnico | Inicio, Mi trabajo y Mi perfil. |
| Administrador | Inicio, Gestión, Indicadores, Categorías, Usuarios y Mi perfil. |

El cambio de rol observado actualiza el menú. Si la vista seleccionada deja de
estar disponible, se vuelve a Inicio. El cambio de cuenta reinicia la selección.

Usuarios solo escucha la colección mientras esa vista administrativa está abierta.
Al salir de ella, perder el rol o cerrar sesión se elimina su controlador y se
cancela la escucha. Los cambios de rol se guardan al elegir una opción del selector;
durante la escritura se deshabilitan los selectores. El rol de la cuenta actual
permanece bloqueado en la interfaz para evitar una pérdida accidental de acceso.
Las confirmaciones y errores aparecen dentro de la vista y desaparecen al salir.

## Funciones pendientes

Reporting, personal lists, protected detail, local photographs, chronological
comments/history and assigned-technician progress are connected. Assignment,
classification, lifecycle actions, indicators and category administration retain
their pending views. [Follow-up](incident_followup.md) documents the implemented
detail and progress interface; [Local storage](local_evidence.md) documents startup.

La configuración, el recorrido de autenticación y sus pruebas se documentan en
[Autenticación y sesión](autenticacion.md).

## Cómo revisar la interfaz

Abrir con `flutter run -d chrome`, recorrer el menú y reducir la ventana hasta
que aparezca «Abrir menú».
