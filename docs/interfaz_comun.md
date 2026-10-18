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

## Funciones pendientes

La administración de roles y las funciones de incidencias, fotografías, gestión,
indicadores y categorías siguen pendientes.
Los módulos pendientes no muestran registros ficticios ni acciones exitosas.

La configuración, el recorrido de autenticación y sus pruebas se documentan en
[Autenticación y sesión](autenticacion.md).

## Cómo revisar la interfaz

Abrir con `flutter run -d chrome`, recorrer el menú y reducir la ventana hasta
que aparezca «Abrir menú».
