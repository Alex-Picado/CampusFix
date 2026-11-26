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
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_administrative_filters.dart';
import '../widgets/incident_management_list.dart';
import '../widgets/incident_search_panel.dart';

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
  int _selectedStage = 0;
  late Set<IncidentStatus> _selectedStatuses;
  IncidentManagementOrder _order = IncidentManagementOrder.recent;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage.clamp(0, 4);
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
        if (isTechnician &&
            !controller.loading &&
            controller.error == null) ...[
          IncidentSearchPanel(controller: controller.search),
          const SizedBox(height: 20),
        ],
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
          _technicianStages(context, controller, results)
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
          ..sort(_order.compare);
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
          order: _order,
          onOrder: (order) => setState(() => _order = order),
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
          IncidentManagementList(
            incidents: matching,
            search: search,
            onOpen: (incident) => _openDetail(context, controller, incident),
          ),
      ],
    );
  }

  Widget _technicianStages(
    BuildContext context,
    IncidentQueueController controller,
    List<Incident> results,
  ) {
    final stages = _stages(results);
    final selected = stages[_selectedStage];
    return DefaultTabController(
      length: stages.length,
      initialIndex: _selectedStage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => setState(() => _selectedStage = index),
            tabs: [
              for (var index = 0; index < stages.length; index++)
                Tab(
                  key: ValueKey('workspace-tab-$index'),
                  text: '${stages[index].$1} (${stages[index].$3.length})',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(selected.$2, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (results.isEmpty)
            SectionCard(
              child: Text(
                controller.search.criteria.hasCriteria
                    ? 'No hay incidencias que coincidan con la búsqueda.'
                    : 'No hay incidencias disponibles.',
              ),
            )
          else if (selected.$3.isEmpty)
            const SectionCard(child: Text('No hay incidencias en esta etapa.'))
          else
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(),
                child: Column(
                  key: ValueKey('workspace-stage-$_selectedStage'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final incident in selected.$3)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _technicianCard(context, controller, incident),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<(String, String, List<Incident>)> _stages(List<Incident> results) => [
    (
      'Asignadas',
      'Incidencias que podés comenzar a atender.',
      results.where((item) => item.status == IncidentStatus.assigned).toList(),
    ),
    (
      'En atención',
      'Incidencias en las que estás trabajando.',
      results
          .where((item) => item.status == IncidentStatus.inProgress)
          .toList(),
    ),
    (
      'Solucionadas',
      'Registraste una solución y administración revisará el cierre.',
      results.where((item) => item.status == IncidentStatus.resolved).toList(),
    ),
    (
      'En revisión',
      'Incidencias que esperan una decisión de administración.',
      results
          .where(
            (item) => {
              IncidentStatus.reported,
              IncidentStatus.underReview,
              IncidentStatus.reviewRequested,
              IncidentStatus.reopened,
            }.contains(item.status),
          )
          .toList(),
    ),
    (
      'Finalizadas',
      'Incidencias cerradas, rechazadas o canceladas.',
      results
          .where(
            (item) => {
              IncidentStatus.closed,
              IncidentStatus.rejected,
              IncidentStatus.cancelled,
            }.contains(item.status),
          )
          .toList(),
    ),
  ];

  Widget _technicianCard(
    BuildContext context,
    IncidentQueueController controller,
    Incident incident,
  ) => SectionCard(
    key: ValueKey('incident-${incident.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader(context, incident),
        const SizedBox(height: 8),
        Text(
          incident.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(incident.status.technicianGuidance),
        const Divider(height: 24),
        Text(
          'Categoría: ${controller.search.categoryLabel(incident.categoryId)}',
        ),
        const SizedBox(height: 4),
        Text('Ubicación: ${incident.location}'),
        const SizedBox(height: 4),
        Text(
          'Último cambio: ${formatIncidentQueueDate(incident.updatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: ValueKey('detail-${incident.id}'),
          onPressed: () => _openDetail(context, controller, incident),
          child: const Text('Abrir incidencia'),
        ),
      ],
    ),
  );

  Widget _cardHeader(BuildContext context, Incident incident) {
    final title = Text(
      '#${incident.sequenceNumber} · ${incident.title}',
      style: Theme.of(context).textTheme.titleMedium,
    );
    final status = Chip(label: Text(incident.status.label));
    final badges = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        status,
        IncidentPriorityBadge(incident: incident),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.topRight, child: badges),
              const SizedBox(height: 4),
              title,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: title,
              ),
            ),
            const SizedBox(width: 12),
            badges,
          ],
        );
      },
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
