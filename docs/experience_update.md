# Mejoras de experiencia y conformidad de cierre

- Campanita disponible en los tres roles, tanto en el menú principal como en el detalle. Observa el historial autorizado, incluidos los avances. El punto rojo identifica novedades de otras personas. Permite abrir la incidencia y marcar novedades como leídas. La lectura se conserva en este dispositivo y se separa por cuenta y rol; no es un servicio de notificaciones push.
- Tarjetas del inicio abren la etapa exacta en Mis incidencias, Mi trabajo o Gestión. La actividad reciente abre el detalle.
- Administración dispone de totales semanales y mensuales, pendientes de conformidad, casos sin técnico y actividad diaria de siete días. Los períodos se calculan en hora de Costa Rica, con semanas de lunes a domingo. Cada indicador abre los casos que cuenta.
- Menú lateral con transición animada y modo compacto con ayudas al pasar el cursor. En pantallas pequeñas se presenta como menú desplegable. Listados, formularios y tarjetas ocupan el ancho disponible.
- El técnico inicia o rechaza asignaciones con botones separados. Una vez iniciada la atención, Reportar avance despliega el formulario de avance a la izquierda y la resolución a la derecha; en pantallas pequeñas se apilan. Los avances muestran número, autor, fecha, descripción y fotografías asociadas.
- Recuperar contraseña está disponible desde el ingreso, valida el correo y envía el enlace de Firebase Authentication. La confirmación no revela si existe una cuenta. En un emulador, los enlaces se consultan en el emulador de autenticación; en producción se utiliza la plantilla y configuración de correo del proyecto Firebase.

## Cierre por conformidad

Resolver registra el acuerdo del técnico sobre la solución actual. El reportante acepta la solución y administración aprueba el cierre, en cualquier orden. La incidencia permanece en RESUELTA hasta que existen las tres conformidades; la última aprobación la pasa a CERRADA en una transacción que incluye su evento de historial.

Solicitar otra revisión elimina las conformidades del reportante y administración. Responder una revisión devuelve el caso a RESUELTA y exige nuevamente las aprobaciones. Reabrir elimina todas las conformidades y la solución vigente, conservando el historial. Las reglas de Firestore impiden inventar aprobaciones de otro rol o saltarse el proceso mediante escrituras directas.

Las incidencias históricas ya cerradas se conservan. Una resolución antigua sin confirmación del técnico requiere reabrirse y resolverse con el nuevo flujo; se explica en el detalle. No se asignan aprobaciones retroactivas.

## Activación y recursos visuales

El cliente y las reglas de `firestore.rules` se publicaron el 9 de noviembre de 2026 en [CampusFix](https://campus-fix-ucr.web.app). Las nuevas aprobaciones no requieren índices adicionales. La versión publicada y sus recursos se verificaron contra la compilación local; las incidencias existentes se conservaron.

La identidad usa azul `#02477B`, celeste `#00C0F3` y blanco de la [paleta accesible de la UCR](https://ci.ucr.ac.cr/sites/default/files/2025-10/Analisis%20de%20color%20paleta%20UCR%20accesible.pdf). Se incluye una fotografía del mural del girasol desde el [sitio oficial de la UCR](https://www.ucr.ac.cr/medios/fotos/large/2025/1-6891382bc6223.jpg), almacenada en `assets/images/campus-ucr.jpg` para evitar depender de cargas externas al abrir la aplicación.
