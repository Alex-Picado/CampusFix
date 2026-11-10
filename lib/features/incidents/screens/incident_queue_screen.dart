import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../controllers/incident_queue_controller.dart';
import '../models/incident.dart';
import '../models/incident_priority.dart';
import '../models/incident_status.dart';
import '../presentation/administrative_incident_stages.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
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
        ![UserRole.administrator, UserRole.technician].contains(profile.role)) {
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
  int _selectedAdminStage = 0;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage.clamp(0, 4);
    _selectedAdminStage = widget.initialStage.clamp(0, 6);
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
        if (!controller.loading && controller.error == null) ...[
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
    final stages = [
      ('Todas', 'Todos los reportes con los filtros actuales.', results),
      ...administrativeIncidentStages(results),
    ];
    final selected = stages[_selectedAdminStage];
    return DefaultTabController(
      length: stages.length,
      initialIndex: _selectedAdminStage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => setState(() => _selectedAdminStage = index),
            tabs: [
              for (var index = 0; index < stages.length; index++)
                Tab(
                  key: ValueKey('management-tab-$index'),
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
                  key: ValueKey('management-stage-$_selectedAdminStage'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final incident in selected.$3)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _administratorCard(
                          context,
                          controller,
                          incident,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
          'Último cambio: ${_date(incident.updatedAt)}',
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
      children: [status, _priorityBadge(context, incident)],
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

  Widget _priorityBadge(BuildContext context, Incident incident) {
    final priority = incident.priority;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch ((priority, dark)) {
      (IncidentPriority.low, true) => const Color(0xFF81C784),
      (IncidentPriority.medium, true) => const Color(0xFFFFCC80),
      (IncidentPriority.high, true) => const Color(0xFFEF9A9A),
      (null, true) => const Color(0xFFB3BAC5),
      (IncidentPriority.low, false) => const Color(0xFF2E7D32),
      (IncidentPriority.medium, false) => const Color(0xFF9A6700),
      (IncidentPriority.high, false) => const Color(0xFFC62828),
      (null, false) => const Color(0xFF667085),
    };
    return Chip(
      key: ValueKey('priority-${incident.id}'),
      avatar: CircleAvatar(radius: 5, backgroundColor: color),
      label: Text(
        priority == null ? 'Sin prioridad' : 'Prioridad ${priority.value}',
      ),
      backgroundColor: color.withValues(alpha: 0.10),
    );
  }

  Widget _administratorCard(
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
        Text(incident.status.administratorGuidance),
        const Divider(height: 24),
        Text(
          'Categoría: ${controller.search.categoryLabel(incident.categoryId)}',
        ),
        const SizedBox(height: 4),
        Text('Ubicación: ${incident.location}'),
        const SizedBox(height: 4),
        Text(
          'Último cambio: ${_date(incident.updatedAt)}',
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

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
