# Interfaz común de CampusFix

Esta entrega incorpora una interfaz sencilla con controles estándar de Material,
colores discretos y navegación consistente. No requiere fuentes, imágenes ni
dependencias nuevas.

## Alcance actual

- Inicio con accesos rápidos y una explicación breve del recorrido.
- Menú con vistas de incidencias, gestión, trabajo del técnico, indicadores,
  categorías, usuarios y perfil.
- Cada módulo pendiente muestra «Próximamente». No se simulan registros,
  fotografías, indicadores ni operaciones exitosas.
- La interfaz es actualmente un prototipo navegable. Todavía no conecta las
  pantallas con `AuthController` y `SessionController`, ni consulta datos privados.
  Por eso las opciones del menú se muestran para revisar la estructura completa;
  no representan accesos autorizados de una sesión real.

## Adaptación a pantalla

- Desde 900 píxeles lógicos: menú lateral fijo.
- Por debajo de 900 píxeles lógicos: menú desplegable con el botón «Abrir menú».
- El contenido permite desplazamiento vertical y los accesos rápidos se ajustan
  al ancho disponible mediante `Wrap`.

## Responsabilidades

| Archivo o componente | Responsabilidad |
| --- | --- |
| `CampusTheme` | Colores y estilos compartidos. |
| `CampusDestination` | Etiquetas y descripciones de las vistas del prototipo. |
| `CampusNavigation` | Opciones del menú lateral y desplegable. |
| `CampusShell` | Distribución responsiva y selección de vista. |
| `OverviewScreen` | Pantalla inicial y accesos rápidos. |
| `ModulePreviewScreen` | Identificación explícita de funciones pendientes. |
| `PageHeading`, `SectionCard` | Componentes visuales reutilizables. |

`main.dart` conserva la inicialización de Firebase antes de abrir la aplicación.
La capa visual no modifica servicios, repositorios, controladores o reglas.

## Siguiente integración

Conectar los estados de sesión a las pantallas de acceso y perfil pendiente.
El menú deberá mostrar las opciones correspondientes al rol autenticado;
Firestore seguirá siendo responsable de proteger los datos.

## Verificaciones de esta entrega

- Análisis de Dart: sin problemas.
- Pruebas de Flutter: nueve aprobadas, incluidas la navegación de los módulos
  y la apertura y cierre del menú en una tablet de 768 × 1024 píxeles lógicos.
- Compilación web: completada correctamente.
- Revisión visual en navegador: inicio comprobado a 1280 × 720 píxeles.

Estas verificaciones cubren el prototipo visual. La integración de acceso,
perfiles y permisos todavía requiere sus propias pruebas.

## Cómo revisar la interfaz

Abrir con `flutter run -d chrome`, recorrer el menú y reducir la ventana hasta
que aparezca «Abrir menú».
