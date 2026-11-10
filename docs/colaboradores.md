# Arranque para colaboradores

La rama `main` contiene la implementación publicada en
[CampusFix](https://campus-fix-ucr.web.app), el archivo de versiones exactas de
dependencias y la configuración de herramientas usada para compilarla.

## Herramientas

Instalar Flutter **3.47.9 estable**, que incluye Dart **3.13.7**, y agregar
Flutter al PATH. Para los servicios locales, instalar Node.js **24.19.0**.
`.fvmrc` y `.node-version` registran estas versiones; un `git pull` no instala
ni cambia las herramientas del equipo. Si se usa FVM, ejecutar los comandos
de Flutter con `fvm flutter` y los de Node con `fvm exec node` cuando deban
encontrar el SDK del proyecto.

## Descargar o actualizar

Para una copia nueva:

```text
git clone https://github.com/Alex-Picado/CampusFix.git
cd CampusFix
```

En una copia existente, desde la carpeta del proyecto:

```text
git switch main
git pull --ff-only origin main
```

## Ejecutar la aplicación web

```text
flutter --version
flutter pub get --enforce-lockfile
flutter run -d chrome
```

La primera instrucción debe mostrar Flutter 3.47.9 y Dart 3.13.7.
La segunda restaura las versiones compartidas en `pubspec.lock`, y Flutter
regenera sus archivos locales. Esta modalidad corresponde al cliente publicado:
incluye las funciones de incidencias y avances de texto; las fotografías de
evidencia requieren el servicio local.

La configuración de Firebase ya está en el repositorio y apunta a
`campus-fix-ucr`. Cada colaborador ingresa con su propia cuenta de CampusFix;
administración asigna los roles de técnico y administrador. El arranque normal
utiliza la base de datos real compartida con la aplicación publicada.

## Servicio local de fotografías

Con Flutter y Node en las versiones indicadas:

```text
node tool/verify_toolchain.mjs
flutter pub get --enforce-lockfile
npm ci --prefix services/local_evidence
npm run start:app --prefix services/local_evidence
```

El lanzador abre la aplicación en `http://127.0.0.1:8080` y sirve las fotos desde
`local_storage/evidence/` de esa computadora. Las fotos guardadas allí se
transfieren entre equipos por separado; un `git pull` del código no sincroniza
las nuevas fotografías locales.

Para una demostración con datos de prueba independientes, seguir el apartado
de emuladores de [almacenamiento local](local_evidence.md). Esa modalidad requiere
Java 21 y las dependencias de `tool/firestore_tests`.

## Comprobar cambios propios

```text
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

La documentación histórica conserva las versiones con las que se realizaron
verificaciones anteriores. Para la instalación actual, usar las versiones
de esta guía y los archivos de configuración de `main`.
