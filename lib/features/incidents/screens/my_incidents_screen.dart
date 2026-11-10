import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/my_incidents_controller.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_search_panel.dart';
import 'incident_report_screen.dart';

/// Switches between the reporter's live reports and an independently owned form.
class MyIncidentsScreen extends StatefulWidget {
  final String userId;
  final bool initiallyCreating;
  final int initialStage;

  const MyIncidentsScreen({
    super.key,
    required this.userId,
    this.initiallyCreating = false,
    this.initialStage = 0,
  });

  @override
  State<MyIncidentsScreen> createState() => _MyIncidentsScreenState();
}

class _MyIncidentsScreenState extends State<MyIncidentsScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _creating = widget.initiallyCreating;
  }

  @override
  void didUpdateWidget(covariant MyIncidentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _creating = false;
    } else if (!oldWidget.initiallyCreating && widget.initiallyCreating) {
      _creating = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != SessionStatus.authenticated ||
        session.profile?.id != widget.userId ||
        session.profile?.role != UserRole.reporter) {
      return const SizedBox.shrink();
    }
    if (_creating) {
      return IncidentReportScreen(
        userId: widget.userId,
        onBack: () => setState(() => _creating = false),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(widget.userId),
      create: (context) => MyIncidentsController(
        incidentRepository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        sessionController: session,
        userId: widget.userId,
      ),
      child: _IncidentList(
        initialStage: widget.initialStage,
        onCreate: () => setState(() => _creating = true),
      ),
    );
  }
}

/// Groups a reporter's live reports into one navigable stage at a time.
class _IncidentList extends StatefulWidget {
  final VoidCallback onCreate;
  final int initialStage;

  const _IncidentList({required this.onCreate, required this.initialStage});

  @override
  State<_IncidentList> createState() => _IncidentListState();
}

class _IncidentListState extends State<_IncidentList> {
  int _selectedStage = 0;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MyIncidentsController>();
    if (!controller.isActive) return const SizedBox.shrink();
    final error = controller.errorMessage;
    final results = controller.search.results;
    final stages = _stages(results);
    final selected = stages[_selectedStage];
    return DefaultTabController(
      length: stages.length,
      initialIndex: _selectedStage,
      child: Column(
        key: const ValueKey('my-incidents-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Mis incidencias',
            description:
                'Consultá tus reportes según la etapa en que se encuentran.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('incidents-create'),
            onPressed: widget.onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Crear incidencia'),
          ),
          const SizedBox(height: 20),
          if (!controller.isLoading && error == null) ...[
            IncidentSearchPanel(controller: controller.search),
            const SizedBox(height: 20),
          ],
          if (controller.isLoading)
            const SectionCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Cargando incidencias...')),
                ],
              ),
            )
          else if (error != null)
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('incidents-retry'),
                    onPressed: controller.start,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else ...[
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (index) => setState(() => _selectedStage = index),
              tabs: [
                for (var index = 0; index < stages.length; index++)
                  Tab(
                    key: ValueKey('incidents-tab-$index'),
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
                      : 'Todavía no tenés incidencias reportadas.',
                ),
              )
            else if (selected.$3.isEmpty)
              const SectionCard(
                child: Text('No hay incidencias en esta etapa.'),
              )
            else
              _stageList(context, controller, _selectedStage, selected.$3),
          ],
        ],
      ),
    );
  }

  List<(String, String, List<Incident>)> _stages(List<Incident> results) => [
    (
      'Pendientes',
      'Reportes que esperan revisión o una nueva atención.',
      results
          .where(
            (item) => [
              IncidentStatus.reported,
              IncidentStatus.underReview,
              IncidentStatus.reopened,
              IncidentStatus.reviewRequested,
            ].contains(item.status),
          )
          .toList(),
    ),
    (
      'Asignadas',
      'Reportes que ya tienen un técnico asignado.',
      results.where((item) => item.status == IncidentStatus.assigned).toList(),
    ),
    (
      'En atención',
      'Reportes en los que está trabajando un técnico.',
      results
          .where((item) => item.status == IncidentStatus.inProgress)
          .toList(),
    ),
    (
      'Solucionada',
      'El técnico registró una solución. Podés revisarla y solicitar otra atención si el problema continúa.',
      results.where((item) => item.status == IncidentStatus.resolved).toList(),
    ),
    (
      'Finalizadas',
      'Reportes cerrados, rechazados o cancelados.',
      results
          .where(
            (item) => [
              IncidentStatus.closed,
              IncidentStatus.rejected,
              IncidentStatus.cancelled,
            ].contains(item.status),
          )
          .toList(),
    ),
  ];

  Widget _stageList(
    BuildContext context,
    MyIncidentsController controller,
    int index,
    List<Incident> incidents,
  ) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(),
      child: Column(
        key: ValueKey('incidents-stage-$index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final incident in incidents)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _incidentCard(context, controller, incident),
            ),
        ],
      ),
    ),
  );

  Widget _incidentCard(
    BuildContext context,
    MyIncidentsController controller,
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
        Text(incident.status.reporterGuidance),
        const Divider(height: 24),
        Text(
          'Categoría: ${controller.search.categoryLabel(incident.categoryId)}',
        ),
        const SizedBox(height: 4),
        Text('Ubicación: ${incident.location}'),
        const SizedBox(height: 4),
        Text(
          incident.updatedAt == incident.createdAt
              ? 'Reportada: ${_date(incident.createdAt)}'
              : 'Último cambio: ${_date(incident.updatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: ValueKey('detail-${incident.id}'),
          onPressed: () async {
            controller.pause();
            await Navigator.of(context)
                .pushNamed('/incidents/${Uri.encodeComponent(incident.id)}');
            if (controller.isActive) controller.start();
          },
          child: const Text('Ver detalle'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.topRight, child: status),
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
            status,
          ],
        );
      },
    );
  }

  /// Presents server timestamps in the viewer's local time without dependencies.
  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
