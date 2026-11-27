import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../controllers/incident_queue_controller.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/administrative_incident_stages.dart';
import '../presentation/incident_list_order.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_administrative_filters.dart';
import '../widgets/incident_queue_list.dart';
import '../widgets/incident_search_panel.dart';
import '../widgets/technician_work_queue.dart';

/// Displays the administrator's reports or the technician's own assignments.
class IncidentQueueScreen extends StatelessWidget {
  final int initialStage;
  const IncidentQueueScreen({super.key, this.initialStage = 0});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null ||
        (!profile.role.isAdministrative &&
            profile.role != UserRole.technician)) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey('queue:${profile.id}:${profile.role.name}'),
      create: (_) => IncidentQueueController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        userRepository: context.read<UserRepository>(),
        session: session,
        uid: profile.id,
        role: profile.role,
      ),
      child: _QueueView(initialStage: initialStage),
    );
  }
}

class _QueueView extends StatefulWidget {
  final int initialStage;
  const _QueueView({required this.initialStage});

  @override
  State<_QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<_QueueView> {
  late TechnicianWorkStage _selectedStage;
  late Set<IncidentStatus> _selectedStatuses;
  IncidentListOrder _managementOrder = IncidentListOrder.recent;
  IncidentListOrder _technicianOrder = IncidentListOrder.priority;

  @override
  void initState() {
    super.initState();
    _selectedStage =
        TechnicianWorkStage.values[widget.initialStage.clamp(
          0,
          TechnicianWorkStage.values.length - 1,
        )];
    _selectedStatuses = administrativeStageStatuses(widget.initialStage);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentQueueController>();
    if (!controller.active) return const SizedBox.shrink();
    final isTechnician = controller.role == UserRole.technician;
    final results = controller.search.results;
    return Column(
      key: const ValueKey('incident-queue'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: isTechnician ? 'Mi trabajo' : 'Gestión de incidencias',
          description: isTechnician
              ? 'Consultá tus asignaciones según la etapa en que se encuentran.'
              : 'Clasificá, asigná y supervisá los reportes del campus.',
        ),
        const SizedBox(height: 20),
        if (controller.loading)
          const Center(child: CircularProgressIndicator())
        else if (controller.error != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.error!),
                TextButton(
                  onPressed: controller.start,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (isTechnician)
          TechnicianWorkQueue(
            search: controller.search,
            selected: _selectedStage,
            order: _technicianOrder,
            onStage: (stage) => setState(() => _selectedStage = stage),
            onOrder: (order) => setState(() => _technicianOrder = order),
            onOpen: (incident) => _openDetail(context, controller, incident),
          )
        else
          _administratorStages(context, controller, results),
      ],
    );
  }

  Widget _administratorStages(
    BuildContext context,
    IncidentQueueController controller,
    List<Incident> results,
  ) {
    final search = controller.search;
    final counts = <IncidentStatus, int>{};
    for (final incident in results) {
      counts.update(incident.status, (count) => count + 1, ifAbsent: () => 1);
    }
    final matching =
        results
            .where(
              (incident) =>
                  _selectedStatuses.isEmpty ||
                  _selectedStatuses.contains(incident.status),
            )
            .toList()
          ..sort(_managementOrder.compare);
    final filtered =
        search.criteria.hasCriteria || _selectedStatuses.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IncidentAdministrativeFilters(
          controller: search,
          counts: counts,
          selectedStatuses: _selectedStatuses,
          onSelectStatuses: (statuses) =>
              setState(() => _selectedStatuses = statuses),
          order: _managementOrder,
          onOrder: (order) => setState(() => _managementOrder = order),
        ),
        const SizedBox(height: 8),
        IncidentSearchSummary(
          count: matching.length,
          total: search.total,
          clearLabel: 'Limpiar filtros',
          onClear: filtered
              ? () {
                  setState(() => _selectedStatuses = const {});
                  search.reset();
                }
              : null,
        ),
        const SizedBox(height: 8),
        if (matching.isEmpty)
          SectionCard(
            child: Column(
              children: [
                Icon(
                  Icons.search_off_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  search.total > 0
                      ? 'No hay incidencias que coincidan con la búsqueda.'
                      : 'No hay incidencias disponibles.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (search.total > 0) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Probá con otra búsqueda o cambiá los filtros.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          )
        else
          IncidentQueueList.administration(
            incidents: matching,
            search: search,
            onOpen: (incident) => _openDetail(context, controller, incident),
          ),
      ],
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    IncidentQueueController controller,
    Incident incident,
  ) async {
    controller.pause();
    await Navigator.of(context)
        .pushNamed('/incidents/${Uri.encodeComponent(incident.id)}');
    if (controller.active) controller.start();
  }
}
