# CampusFix user manual

## Access and navigation

Register with your name, email and password, or use **Iniciar sesión**. New accounts
start as **Reportante**. An existing administrator assigns other roles through
**Usuarios**. **Mi perfil** lets you update your name. Use **Salir** before another
person uses the device.

Use **¿Olvidaste tu contraseña?** to request a password recovery email. The bell
shows updates to authorized cases, including progress, with a red unread dot.
Read status is remembered on the current device. Desktop users can collapse or
expand the animated sidebar. Click a home stage card to open that stage directly.

Desktop navigation is on the left; on tablets use **Abrir menú**. Incident links
use `/#/incidents/<incident-id>`. Sign in with an authorized account to open them.
Reload recovers the session and confirmed records. An unrelated reporter or an
unassigned technician cannot open your report.

## Reporter

**Inicio** shows the count of your reports in each stage and the three most
recently changed reports. Use **Crear incidencia** in the lower-right corner to
open the form directly, or **Ver mis incidencias** to browse the full list. If
the summary cannot load, select **Reintentar**.

1. Open **Mis incidencias**, then **Crear incidencia**.
2. Enter title, description and location, and select an active category.
3. Select **Guardar incidencia** and wait for the confirmed consecutive number.
   If confirmation fails, use the offered retry instead of creating another case.
4. In the local client, select and save a photograph after saving the incident.
   Use a single-frame JPEG, PNG or WebP up to 3 MB and 40 million pixels.
5. In **Mis incidencias**, switch between **Pendientes**, **Asignadas**,
   **En atención**, **Solucionada** and **Finalizadas**. On a phone, swipe the
   tab row horizontally to reach the later stages. Each card shows a short
   description, its current state, what that state means, category, location and
   latest change. **Finalizadas** contains closed, rejected or cancelled reports.
   **Solución registrada** means the technician recorded a solution. Open the
   detail and use **Aceptar solución** if it works. Closure requires the reporter,
   technician and administrator to agree. If the problem continues, use
   **Solicitar nueva revisión**, explaining what remains wrong. Administration
   will review the request and either reopen the case for another assignment or
   answer with a reason and request fresh agreement. Use **Ver detalle** in either view for responsible
   references, solution, progress comments and chronological history.

Search your own reports by exact consecutive number (with or without `#`), text
or category. The same search applies to every tab. Use **Limpiar
búsqueda** to reset the criteria.

The public client explains that photographs are available in the local version.
Reports and text progress remain available. Existing local photographs are
retained; their absence from the public client does not mean they were deleted.

## Technician

**Inicio** summarizes your assigned cases by status and shows the three most
recently changed assignments. Use **Ver mi trabajo** to open the full queue. If
the summary cannot load, select **Reintentar**.

**Mi trabajo** groups assignments into **Asignadas**, **En atención**,
**Solucionadas**, **En revisión** and **Finalizadas**. The search applies to
every tab. Cards show the current state, a short explanation, category,
location and latest change. The priority badge beside the state uses green for
**BAJA**, amber for **MEDIA**, red for **ALTA** and gray for **Sin prioridad**.
Open an assigned case and select
**Iniciar atención**. If you cannot take or continue the case, select
**Rechazar asignación** and explain why. The case returns to administration for
reassignment; the incident remains open and the reason stays in its history.
During attention, select **Reportar avance** to open the advance form on the left
and the resolution form on the right (stacked on smaller screens). Enter a nonblank **Descripción del avance**
and use **Guardar avance**. A local photograph is optional. To finish, enter
**Solución realizada** and select **Resolver incidencia**. This records the technician's
agreement; the case closes only after the reporter accepts and administration approves.
Follow retry instructions if a write cannot be confirmed; the
application preserves the pending operation ID.

## Administrator

**Inicio** shows the campus-wide count in each stage and the three most recently
changed reports. Use the shortcuts to open **Gestión**, **Indicadores**,
**Categorías** or **Usuarios**. If the summary cannot load, select **Reintentar**.

**Gestión** provides the global queue in **Todas**, **Pendientes**,
**Asignadas**, **En atención**, **Solucionadas**, **Revisión solicitada** and
**Finalizadas**. The stage counts follow the current filters. On a phone, swipe
the tab row horizontally to reach later stages. Each card explains its current
state and shows category, location and latest change. The priority badge sits
beside the state: green for **BAJA**, amber for **MEDIA**, red for **ALTA** and
gray for **Sin prioridad**. Open the case to see three steps. In **Clasificar**,
confirm an active category and priority. The form advances to **Asignar**,
where you select and confirm a technician. **Seguimiento** shows the current
state and available actions. Use **Aprobar cierre** after reviewing the registered
solution. The case remains resolved until the reporter also accepts it.
If the reporter requests another
review, reopen it for a new classification and assignment or answer the request
with a reason and obtain fresh agreement. Rejection, cancellation and reopening require a reason and a
permitted state. Reopening preserves the prior solution in history and clears
priority and the assigned technician.

Combine text/consecutive/category search with state, priority and technician
filters. **Sin prioridad** and **Sin asignar** are explicit choices. The result
count refers to all combined criteria across tabs; clear them to restore the global queue.

**Indicadores** uses the global population independently of Management filters.
It includes weekly and monthly reports, pending closure agreement, unassigned cases
and daily activity. Click a metric to see its cases. Calendar periods use Costa Rica time.
**En atención** and **Revisión solicitada** are included in **Abiertas**.
Rejected and cancelled cases count in total and categories but remain outside
open under the agreement.

**Categorías** allows creation, renaming and activation/deactivation. Deactivate
used categories instead of deleting them; earlier reports retain their reference
and current consultable name. **Usuarios** manages registered profiles and roles.

## Recoverable failures

Wait for loading and use the retry next to a failed section. Category errors do
not imply zero incidents, and unconfirmed writes do not prove rejection. If
authorization changes, leave the old view and sign in with the appropriate account.
Local photograph failures can require restarting the local launcher or selecting
the original file. Setup and limitations are in [Integrated clients](integration_delivery.md).
