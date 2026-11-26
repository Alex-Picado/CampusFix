# Correo de cambios de estado sin Firebase Blaze

Este servicio Node.js corre en Docker fuera de Firebase. Flutter guarda un
cambio de estado, su historial y una tarea `emailOutbox` en una sola transacción.
El contenedor consulta las tareas cada minuto y envía correos mediante SendGrid,
incluso si Flutter ya está cerrado. Firebase sigue en Spark; el equipo que
ejecute Docker debe permanecer encendido para que los correos salgan.

Cada cambio real de estado genera una tarea. Los destinatarios son el autor del
reporte, el técnico anterior, el actual, los técnicos de respaldo todavía
relacionados con el reporte y los usuarios con rol `administrator` o
`superAdministrator` y quien hizo el cambio. Se elimina cada UID duplicado.
La lista de destinatarios
se calcula en el servidor: Flutter no envía direcciones de correo ni la clave
de SendGrid.

## Preparación local

1. Instalar Docker Desktop con contenedores Linux.
2. Copiar `.env.example` a `.env` y poner en `SENDGRID_FROM_EMAIL` el remitente
   verificado en SendGrid. Ese archivo se ignora en Git.
3. Crear `secrets/sendgrid_api_key.txt` con **solo** la API Key de SendGrid.
   Crear `secrets/firebase_service_account.json` con la clave JSON de una
   cuenta de servicio dedicada con acceso de lectura/escritura a Firestore.
   Ambos archivos se ignoran en Git y en la imagen Docker.
4. Desde `backend/mailer`, ejecutar `docker compose up --build -d`.
5. Visitar `http://localhost:3000/health` para comprobar que el proceso inició.
   El puerto se publica solo en `127.0.0.1`; no hay un endpoint público para
   solicitar envíos arbitrarios.

La API Key y el JSON se montan como secretos de Docker Compose en
`/run/secrets`. **Nunca** los pegues en Flutter, `Dockerfile`, `compose.yaml`,
`.env`, Git ni en una captura. Si una clave se expone, revócala y crea otra.

## Firebase

Antes de usar la función de correo hay que publicar de forma coordinada el
cliente Flutter actualizado, `firestore.rules` y `firestore.indexes.json`.
Las reglas exigen una tarea `emailOutbox` en cada cambio de estado: durante
el intervalo entre publicar reglas y cliente, los cambios de estado pueden
fallar. Las pestañas antiguas de la app deben recargarse tras la publicación.
El contenedor accede con Firebase
Admin SDK y cuenta de servicio. Ese acceso de servidor usa IAM y no las reglas
de seguridad de los clientes.

## Entrega y reintentos

El Worker procesa hasta dos tareas por ciclo y hace hasta seis intentos.
Registra los UID procesados después de cada respuesta HTTP 202 de SendGrid;
al reintentar continúa con los pendientes. Un 202 significa que SendGrid aceptó
la solicitud, no que el correo llegó a la bandeja. Si el proceso se detiene
justo después de un 202 y antes de registrar el UID, esa persona podría recibir
un correo duplicado. Las tareas fallidas quedan en Firestore con `lastError`.

Docker no activa Firebase Cloud Functions ni Cloud Run. Una computadora local
sirve para la demostración académica; para uso continuo habría que alojar el
contenedor en un equipo o servidor siempre disponible.
