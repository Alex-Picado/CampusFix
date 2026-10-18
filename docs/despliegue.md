# Preparación de Firebase Hosting

## Estado de la Parte 1

Alex inicializó Firebase Hosting para `campus-fix-ucr` el 18 de octubre de 2026.
Se verificó la configuración local generada. La publicación y comprobación de la
URL corresponden a Daniel en la Parte 4 y todavía están pendientes.

| Configuración | Valor |
| --- | --- |
| Proyecto predeterminado en `.firebaserc` | `campus-fix-ucr` |
| Directorio público | `build/web` |
| Reescritura para aplicación de una sola página | `**` hacia `/index.html` |
| Publicación automática desde GitHub | Desactivada |
| Reemplazo del `index.html` compilado | Rechazado; se conservó el archivo de Flutter |

`firebase.json` conserva las secciones de FlutterFire y Firestore, y añade la
sección `hosting`. El directorio `build/` ya está excluido de Git: se versiona la
configuración, y los archivos publicados se generan mediante Flutter.

## Publicación de la Parte 4

Desde la raíz de CampusFix, con la cuenta Firebase del equipo autenticada:

```cmd
flutter analyze
flutter test
flutter build web
firebase deploy --only hosting --project=campus-fix-ucr --account=campusfixucr@gmail.com
```

Daniel deberá comprobar la URL entregada por la herramienta, el acceso con los
tres roles, la recarga de la aplicación y el recorrido completo de incidencias.
La reescritura permite que las rutas del cliente reciban `index.html`.

La publicación de Hosting no publica las reglas de Firestore. Cada entrega debe
mantener y comprobar las reglas que correspondan a sus operaciones antes de
integrarlas. Los módulos futuros continúan sujetos al contrato documentado en
[Contratos entre módulos](contratos_modulos.md).

Los resultados del análisis, pruebas y compilación ya ejecutados están en
[Autenticación y sesión](autenticacion.md). Este documento registra preparación,
no una publicación exitosa ni una nueva ejecución de esas verificaciones.

[Guía oficial de Firebase Hosting](https://firebase.google.com/docs/hosting/quickstart).
