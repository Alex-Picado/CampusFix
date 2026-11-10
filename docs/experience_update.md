# Mejoras de experiencia y conformidad de cierre

- Campanita disponible en los tres roles, tanto en el menú principal como en el detalle. El reportante recibe únicamente avisos cuando su incidencia pasa a Solucionada; los avances y demás cambios siguen disponibles en el detalle. Técnico y administración ven las novedades del historial autorizado. El punto rojo identifica novedades de otras personas. Permite abrir la incidencia y marcar novedades como leídas. La lectura se conserva en este dispositivo y se separa por cuenta y rol; no es un servicio de notificaciones push.
- Tarjetas del inicio abren la etapa exacta en Mis incidencias, Mi trabajo o Gestión. La actividad reciente abre el detalle.
- Administración dispone de totales semanales y mensuales, pendientes de conformidad, casos sin técnico y actividad diaria de siete días. Los períodos se calculan en hora de Costa Rica, con semanas de lunes a domingo. Cada indicador abre los casos que cuenta.
- Menú lateral con transición animada que se oculta por completo mediante Ocultar menú y reaparece con Mostrar menú. El contenido recupera ese espacio al ocultarlo. En pantallas pequeñas se presenta como menú desplegable. Listados, formularios y tarjetas ocupan el ancho disponible.
- Guardar incidencia muestra una ventana de confirmación únicamente cuando el guardado está confirmado. OK vuelve a Mis incidencias en Pendientes. El formulario no queda bloqueado después del envío. Las fotografías locales se agregan desde el detalle.
- En Mis incidencias y en el detalle, el autor puede Cancelar reporte con un motivo y una confirmación. Los reportes cancelados permanecen en Finalizadas. Eliminar de mi lista requiere confirmar y retira el reporte de los listados, indicadores y avisos del reportante en sus dispositivos. Si todavía no estaba finalizado, también cancela la atención en la misma transacción. Si estaba cerrado, rechazado o cancelado, conserva ese resultado. Administración mantiene el reporte, las fotografías, los avances y el historial, incluido quién lo retiró y cuándo. Solo el autor con rol Reportante puede usar estas acciones; no se borra ningún documento ni se reutiliza el consecutivo.
- El técnico inicia o rechaza asignaciones con botones separados. Una vez iniciada la atención, Reportar avance despliega el formulario de avance a la izquierda y la resolución a la derecha; en pantallas pequeñas se apilan. Los avances muestran número, autor, fecha, descripción y fotografías asociadas.
- Resolver incidencia requiere confirmar el aviso de que no se podrá continuar la atención hasta que administración reabra y reasigne el caso. Seguir atendiendo cancela sin guardar y conserva el texto de la solución. Las ventanas de confirmación se cierran si cambia la cuenta o el rol.
- Recuperar contraseña está disponible desde el ingreso, valida el correo y envía el enlace de Firebase Authentication. La confirmación no revela si existe una cuenta. En un emulador, los enlaces se consultan en el emulador de autenticación; en producción se utiliza la plantilla y configuración de correo del proyecto Firebase.

## Recordarme y recuperación de sesión

Recordarme está desmarcado inicialmente. Al ingresar o registrarse se elige cuánto se conserva la sesión después de cerrar la página: 30 minutos sin marcarlo y 30 días al marcarlo. Una página abierta mantiene la sesión. Salir finaliza la sesión inmediatamente y elimina su registro de conservación.

El cliente web registra la última actividad en el navegador y actualiza el momento de cierre con pagehide. Un latido cada minuto sirve de respaldo si el navegador termina abruptamente sin emitir ese evento. Al volver a cargar o recuperar una página desde el historial, valida el plazo y la identidad antes de consultar el perfil y mostrar vistas privadas. Las sesiones anteriores sin estos datos requieren un nuevo ingreso una sola vez.

Esta es una política de restauración del cliente en este navegador; no modifica la duración de los tokens ni revoca sesiones de otros dispositivos en Firebase. La persistencia de Firebase conserva las credenciales, mientras el registro propio almacena únicamente identidad, preferencia y fecha; no contiene contraseñas ni tokens.

## Cierre por conformidad

Resolver registra el acuerdo del técnico sobre la solución actual. El reportante acepta la solución y administración aprueba el cierre, en cualquier orden. La incidencia permanece en RESUELTA hasta que existen las tres conformidades; la última aprobación la pasa a CERRADA en una transacción que incluye su evento de historial.

Un reporte eliminado de la lista del autor queda disponible para consulta y auditoría; no puede reactivarse ni recibir nuevas acciones del flujo.

Solicitar otra revisión elimina las conformidades del reportante y administración. Responder una revisión devuelve el caso a RESUELTA y exige nuevamente las aprobaciones. Reabrir elimina todas las conformidades y la solución vigente, conservando el historial. Las reglas de Firestore impiden inventar aprobaciones de otro rol o saltarse el proceso mediante escrituras directas.

Las incidencias históricas ya cerradas se conservan. Una resolución antigua sin confirmación del técnico requiere reabrirse y resolverse con el nuevo flujo; se explica en el detalle. No se asignan aprobaciones retroactivas.

## Activación y recursos visuales

El cliente y las reglas de `firestore.rules` se publicaron el 9 de noviembre de 2026 en [CampusFix](https://campus-fix-ucr.web.app). Las nuevas aprobaciones no requieren índices adicionales. La versión publicada y sus recursos se verificaron contra la compilación local; las incidencias existentes se conservaron.

La identidad usa azul `#02477B`, celeste `#00C0F3` y blanco de la [paleta accesible de la UCR](https://ci.ucr.ac.cr/sites/default/files/2025-10/Analisis%20de%20color%20paleta%20UCR%20accesible.pdf). Se incluye una fotografía del mural del girasol desde el [sitio oficial de la UCR](https://www.ucr.ac.cr/medios/fotos/large/2025/1-6891382bc6223.jpg), almacenada en `assets/images/campus-ucr.jpg` para evitar depender de cargas externas al abrir la aplicación.
