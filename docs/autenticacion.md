# Autenticación y sesión

## Alcance

Esta integración conecta los controladores existentes con los formularios de
inicio de sesión, registro y recuperación del perfil pendiente. También permite
consultar el perfil autenticado, actualizar el nombre, cerrar sesión y administrar
los roles de las cuentas desde Usuarios.

La preparación del primer administrador y la comprobación con Firebase real se
completarán en el siguiente bloque. Las vistas de los módulos de incidencias,
indicadores y categorías todavía muestran su condición de pendientes.

## Configuración necesaria

1. Usar el proyecto Firebase `campus-fix-ucr` con la configuración web generada
   en `lib/firebase_options.dart`.
2. Habilitar el proveedor Correo electrónico/Contraseña en Authentication.
3. Tener creada la base Firestore `(default)` y publicadas las reglas del proyecto.
4. Conservar las dependencias instaladas, incluido `provider`.
5. Abrir la aplicación con `flutter run -d chrome`.

Esta integración no utiliza Storage, Cloud Functions ni facturación adicional.

## Responsabilidades y recorrido

`main` inicializa Firebase, crea los servicios y repositorios y entrega sus
instancias a `AppProviders`. Este último crea una instancia compartida de
`AuthController` y otra de `SessionController`, y administra su eliminación.

El formulario le pide una acción a `AuthController`; este le pide la operación a
`AuthRepository`, que utiliza los servicios de autenticación y perfiles.
`SessionController` escucha los cambios de identidad y el perfil de esa cuenta.
`SessionGate` elige la pantalla con esos resultados, sin navegación manual después
de cada formulario.

| Estado de sesión | Pantalla |
| --- | --- |
| `loading` | Indicador de carga; no se muestra el contenido privado. |
| `signedOut` | Inicio de sesión o registro. |
| `profileRequired` | Nombre completo para recuperar el perfil que falta. |
| `authenticated` | Inicio y módulos visibles para el rol observado. |
| `failure` | Mensaje de error, reintento y cierre de sesión. |

Cuando cambia la cuenta, se reemplaza el estado del menú. Cuando termina la
sesión, se retiran las pantallas privadas y se liberan los campos de acceso.
Al desaparecer `AppProviders`, se eliminan los controladores y se cancelan las
suscripciones de la sesión.

## Formularios y errores

- Correo con formato básico válido y contraseña obligatoria para ingresar.
- Nombre obligatorio, contraseña de al menos seis caracteres y confirmación
  idéntica para registrarse. Firebase aplica su política definitiva de contraseñas.
- La contraseña se envía tal como se escribió; no se eliminan sus espacios.
- Las solicitudes en curso deshabilitan los controles para evitar envíos repetidos.
- Los mensajes de Firebase se traducen mediante `AppErrorMessages`; no se muestran
  excepciones internas ni se imprimen contraseñas.
- El cambio entre ingreso y registro limpia contraseñas, validaciones y errores.
- `PasswordField` ofrece mostrar u ocultar la contraseña y conserva su valor.
- Si falla el cierre de sesión, se muestra el error y se permite reintentarlo.

### Cuenta creada con perfil pendiente

La creación de una cuenta y el guardado del perfil son operaciones separadas.
Si Firebase crea la cuenta y después falla Firestore, la cuenta permanece activa.
La pantalla «Completá tu perfil» permite llamar a `completeProfile`, que recupera
un perfil existente o crea el que falta con rol `reporter`. No vuelve a registrar
la cuenta. También se ofrece cerrar sesión.

### Error al observar el perfil

Se oculta el contenido privado y se ofrece «Reintentar», que reinicia las escuchas
con `SessionController.start`. El usuario también puede cerrar sesión. Una
actualización de rol cambia el menú y abandona una vista que ya no corresponda.

## Actualización del perfil

`SessionGate` proporciona un `ProfileController` asociado al identificador de la
cuenta autenticada. El alcance se mantiene durante los cambios del mismo perfil
y se elimina al abandonar la sesión o cambiar de cuenta.

El recorrido de guardado es `ProfileScreen → ProfileController → UserRepository
→ UserService → Firestore`. El repositorio valida el identificador y el nombre,
elimina espacios exteriores del nombre y el servicio actualiza únicamente
`fullName` del documento existente. El correo, identificador y rol se conservan.
La escucha existente de `SessionController` recibe el perfil actualizado.

- El nombre es obligatorio. El formulario no envía un valor vacío ni un nombre
  que, después de eliminar espacios exteriores, sea igual al observado.
- Mientras se guarda, se deshabilitan el campo y el botón para evitar duplicados.
- La confirmación «Nombre actualizado» se muestra cuando la operación termina
  correctamente y el formulario continúa montado.
- Si falla el guardado, el borrador permanece disponible para corregirlo o reintentar.
  Las actualizaciones observadas y las reversiones de escrituras rechazadas no
  sustituyen ese borrador.
- Un formulario sin cambios pendientes sigue los nombres recibidos por la escucha.
- El cierre de sesión elimina el controlador y el formulario de esa cuenta. Una
  operación anterior que termine después no muestra una confirmación en otra cuenta.

## Administración de usuarios

`CampusShell` abre `UserManagementScreen` únicamente desde el menú del administrador.
La pantalla crea un `UserManagementController` asociado al identificador de la
cuenta actual. Ese controlador escucha `UserRepository.watchAll`, que convierte
los documentos en perfiles y los ordena por nombre sin distinguir mayúsculas.
`UserService` mantiene la consulta de la colección `users`.

El recorrido de escritura es `UserManagementScreen → UserManagementController →
UserRepository.updateRole → UserService.updateRole → Firestore`. Se actualiza
únicamente `role`, conservando nombre, correo e identificador. La lista muestra
los cambios recibidos por la escucha; no mantiene una segunda copia editable.

- Elegir un rol diferente inicia su guardado; una selección idéntica no escribe.
- Todos los selectores se deshabilitan durante una escritura para evitar duplicados.
- El selector de la cuenta actual está deshabilitado. El controlador también
  rechaza quitarle el rol de administrador a esa misma cuenta.
- Los errores de consulta y escritura se muestran por separado. Un error de
  consulta retira la lista y ofrece Reintentar; un snapshot posterior no borra
  un error de escritura. Otra selección permite reintentar el guardado.
- Las confirmaciones se muestran dentro de Usuarios. Se eliminan al salir,
  evitando trasladar nombres a una sesión o pantalla posterior.
- Salir de Usuarios, perder el rol administrativo, cerrar sesión o cambiar de
  cuenta elimina el controlador y cancela su suscripción. Una escritura iniciada
  puede terminar después; su respuesta no modifica una vista que ya se eliminó.
- El listado usa disposición horizontal en escritorio y apila los campos cuando
  el espacio disponible es menor de 600 píxeles lógicos.

La protección de la cuenta administrativa actual evita errores desde esta
interfaz. Las reglas actuales permiten a un administrador modificar su propio
rol; no garantizan conservar al último administrador. El primer acceso
administrativo requiere un procedimiento aparte en Firebase, pendiente de documentar.

## Permisos

Todos los registros normales reciben el rol `reporter` definido por el repositorio.
No existe un selector de rol en el registro. Los nombres españoles del menú se
resuelven en presentación; los identificadores almacenados no cambian.

La visibilidad por rol se documenta en [Interfaz común](interfaz_comun.md).
Las reglas de Firestore siguen siendo la autoridad para cada lectura y escritura.
Los módulos pendientes deberán añadir sus propias consultas y reglas cuando se
implementen; ocultar una opción del menú no protege datos por sí mismo.

## Validación y evidencias

Las pruebas de widgets usan los controladores reales con repositorios locales
controlables. No crean cuentas en Firebase ni prueban las reglas desplegadas.
Cubren formularios inválidos, errores de acceso, envíos repetidos, registro,
recuperación del perfil, cierre de sesión, fallos de observación, menú por rol,
cambio de rol y navegación en tablet. Las pruebas de edición de perfil también
cubren nombres vacíos, envíos repetidos, conservación del correo y rol, recuperación
tras escrituras rechazadas y aislamiento de una operación al cambiar de cuenta.
Las pruebas de Usuarios cubren selección de roles, bloqueo de envíos, conservación
de identidad, errores recuperables, cancelación de consultas al salir o perder
permisos, aislamiento entre cuentas y distribución en tablet.

Resultados de esta integración:

- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: 31 pruebas aprobadas, incluidas las de modelos existentes
  y nueve pruebas de integración de la pantalla de Usuarios.
- `flutter build web --no-pub`: compilación completada.
- Navegador a 1280 × 720: formularios de ingreso y registro revisados visualmente.
- Tablet de 768 × 1024: navegación, cierre del menú y distribución de Usuarios
  verificados por pruebas de widgets.

La comprobación con el proyecto Firebase real queda como prueba manual:

1. Crear una cuenta desde «Registrate» y verificar que abre Inicio.
2. Consultar Mi perfil y comprobar el rol Reportante.
3. Cambiar el nombre, guardar y comprobarlo después de recargar.
4. Comprobar la recuperación de la sesión al recargar.
5. Salir, entrar con la misma cuenta y verificar un intento con contraseña incorrecta.
6. Comprobar en Firestore el documento `users/{uid}`: cambia `fullName` y se
   mantienen el correo y el rol.

No se deben adjuntar contraseñas a capturas o documentación. La prueba de tres
roles y las pruebas de reglas siguen pendientes; las pruebas de interfaz con
repositorios locales no verifican la autorización efectiva de Firestore.
