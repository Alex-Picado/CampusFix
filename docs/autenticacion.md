# Autenticación y sesión

## Alcance

Esta integración conecta los controladores existentes con los formularios de
inicio de sesión, registro y recuperación del perfil pendiente. También permite
consultar el perfil autenticado y cerrar sesión.

La edición del nombre, la administración de roles y la preparación del primer
administrador se completarán en bloques posteriores. Ver un menú administrativo
no implica que sus funciones pendientes estén implementadas.

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
cambio de rol y navegación en tablet.

Resultados de esta integración:

- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: 18 pruebas aprobadas, incluidas las de modelos existentes.
- `flutter build web --no-pub`: compilación completada.
- Navegador a 1280 × 720: formularios de ingreso y registro revisados visualmente.
- Tablet de 768 × 1024: navegación y cierre del menú verificados por prueba de widgets.

La comprobación con el proyecto Firebase real queda como prueba manual:

1. Crear una cuenta desde «Registrate» y verificar que abre Inicio.
2. Consultar Mi perfil y comprobar el rol Reportante.
3. Recargar y comprobar la recuperación de la sesión.
4. Salir, entrar con la misma cuenta y verificar un intento con contraseña incorrecta.
5. Comprobar en Firestore el documento `users/{uid}` y sus campos.

No se deben adjuntar contraseñas a capturas o documentación. La prueba de tres
roles y las pruebas de reglas se completarán al implementar su administración.
