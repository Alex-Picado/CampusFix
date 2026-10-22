# CampusFix user manual

## Access and navigation

Register with your name, email and password, or use **Iniciar sesión**. New accounts
start as **Reportante**. An existing administrator assigns other roles through
**Usuarios**. **Mi perfil** lets you update your name. Use **Salir** before another
person uses the device.

Desktop navigation is on the left; on tablets use **Abrir menú**. Incident links
use `/#/incidents/<incident-id>`. Sign in with an authorized account to open them.
Reload recovers the session and confirmed records. An unrelated reporter or an
unassigned technician cannot open your report.

## Reporter

1. Open **Mis incidencias**, then **Crear incidencia**.
2. Enter title, description and location, and select an active category.
3. Select **Guardar incidencia** and wait for the confirmed consecutive number.
   If confirmation fails, use the offered retry instead of creating another case.
4. In the local client, select and save a photograph after saving the incident.
   Use a single-frame JPEG, PNG or WebP up to 3 MB and 40 million pixels.
5. Use **Ver detalle** for current state, responsible references, solution,
   progress comments and chronological history.

Search your own reports by exact consecutive number (with or without `#`), text
or category. Use **Limpiar búsqueda** to reset the criteria.

The public client explains that photographs are available in the local version.
Reports and text progress remain available. Existing local photographs are
retained; their absence from the public client does not mean they were deleted.

## Technician

**Mi trabajo** contains your assignments. Open an assigned case and select
**Iniciar atención**. During attention, enter a nonblank **Descripción del avance**
and use **Guardar avance**. A local photograph is optional. To finish, enter
**Solución realizada** and select **Resolver incidencia**. An administrator performs
formal closure. Follow retry instructions if a write cannot be confirmed; the
application preserves the pending operation ID.

## Administrator

**Gestión** provides the global queue. Classify a reported case with an active
category and priority before selecting **Asignar técnico**. Assign a current
technician. Close a case only after it is **Resuelta**. Rejection, cancellation
and reopening require a reason and a permitted state. Reopening preserves the
prior solution in history and clears priority and the assigned technician.

Combine text/consecutive/category search with state, priority and technician
filters. **Sin prioridad** and **Sin asignar** are explicit choices. The result
count refers to all combined criteria; clear them to restore the global queue.

**Indicadores** uses the global population independently of Management filters.
**En atención** is included in **Abiertas**. Reopened, rejected and cancelled
cases count in total and categories but remain outside open under the agreement.

**Categorías** allows creation, renaming and activation/deactivation. Deactivate
used categories instead of deleting them; earlier reports retain their reference
and current consultable name. **Usuarios** manages registered profiles and roles.

## Recoverable failures

Wait for loading and use the retry next to a failed section. Category errors do
not imply zero incidents, and unconfirmed writes do not prove rejection. If
authorization changes, leave the old view and sign in with the appropriate account.
Local photograph failures can require restarting the local launcher or selecting
the original file. Setup and limitations are in [Integrated clients](integration_delivery.md).
