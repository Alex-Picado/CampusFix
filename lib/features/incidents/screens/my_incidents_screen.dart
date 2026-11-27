import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/my_incidents_controller.dart';
import '../models/incident.dart';
import '../models/incident_history_action.dart';
import '../models/incident_status.dart';
import '../models/incident_workflow.dart';
import '../presentation/incident_list_order.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_search_panel.dart';
import '../widgets/reporter_incident_list.dart';
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
  late int _initialListStage;

  @override
  void initState() {
    super.initState();
    _creating = widget.initiallyCreating;
    _initialListStage = widget.initialStage;
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
        onReported: () => setState(() {
          _creating = false;
          _initialListStage = 0;
        }),
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
        initialStage: _initialListStage,
        onCreate: () => setState(() => _creating = true),
      ),
    );
  }
}

/// Groups the reporter's confirmed incidents by their current stage.
class _IncidentList extends StatefulWidget {
  final VoidCallback onCreate;
  final int initialStage;

  const _IncidentList({required this.onCreate, required this.initialStage});

  @override
  State<_IncidentList> createState() => _IncidentListState();
}

class _IncidentListState extends State<_IncidentList> {
  late ReporterIncidentStage _selected;
  IncidentListOrder _order = IncidentListOrder.recent;

  @override
  void initState() {
    super.initState();
    final stages = ReporterIncidentStage.values;
    _selected = stages[widget.initialStage.clamp(0, stages.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MyIncidentsController>();
    if (!controller.isActive) return const SizedBox.shrink();

    final error = controller.errorMessage;
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(
          key: const ValueKey('my-incidents-page'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(),
            const SizedBox(height: 20),
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
              _error(context, controller, error)
            else
              _reports(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _heading() => LayoutBuilder(
    builder: (context, constraints) {
      const heading = PageHeading(
        title: 'Mis incidencias',
        description:
            'Consultá tus reportes según la etapa en que se encuentran.',
      );
      final create = FilledButton.icon(
        key: const ValueKey('incidents-create'),
        onPressed: widget.onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Crear incidencia'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      );
      if (constraints.maxWidth < 680) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [heading, const SizedBox(height: 12), create],
        );
      }
      return Row(
        children: [
          const Expanded(child: heading),
          const SizedBox(width: 20),
          create,
        ],
      );
    },
  );

  Widget _error(
    BuildContext context,
    MyIncidentsController controller,
    String message,
  ) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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
  );

  Widget _reports(BuildContext context, MyIncidentsController controller) {
    final search = controller.search;
    final results = search.results;
    final filtered = search.criteria.hasCriteria;
    final groups = {
      for (final stage in ReporterIncidentStage.values) stage: <Incident>[],
    };
    for (final incident in results) {
      groups[ReporterIncidentStage.fromStatus(incident.status)]!.add(incident);
    }
    final visible = groups[_selected]!;
    visible.sort(_order.compare);
    final uid = context.read<SessionController>().profile!.id;
    final pendingReview = {
      for (final incident in controller.incidents)
        if (incident.status == IncidentStatus.resolved &&
            IncidentWorkflow.actions(
              incident,
              UserRole.reporter,
              uid,
            ).contains(IncidentHistoryAction.solutionAccepted))
          incident.id,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingReview.isNotEmpty &&
            (_selected != ReporterIncidentStage.solved || filtered)) ...[
          _solutionsBanner(context, pendingReview.length, () {
            if (filtered) search.reset();
            setState(() => _selected = ReporterIncidentStage.solved);
          }),
          const SizedBox(height: 14),
        ],
        IncidentSearchPanel(
          controller: search,
          order: _order,
          onOrderChanged: (order) => setState(() => _order = order),
        ),
        const SizedBox(height: 14),
        ReporterIncidentStages(
          selected: _selected,
          groups: groups,
          onSelected: (stage) => setState(() => _selected = stage),
        ),
        const SizedBox(height: 12),
        Text(
          _selected.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text(
              visible.length == 1
                  ? '1 reporte en esta etapa'
                  : '${visible.length} reportes en esta etapa',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IncidentSearchSummary(
              count: results.length,
              total: search.total,
              clearLabel: 'Limpiar filtros',
              onClear: filtered ? search.reset : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          _empty(context, filtered: filtered, hasMatches: results.isNotEmpty)
        else
          Column(
            key: ValueKey('incidents-stage-${_selected.index}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final incident in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ReporterIncidentCard(
                    key: ValueKey('incident-${incident.id}'),
                    incident: incident,
                    category: search.categoryLabel(incident.categoryId),
                    stage: _selected,
                    needsSolutionReview: pendingReview.contains(incident.id),
                    onOpen: () => _open(context, controller, incident),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _solutionsBanner(
    BuildContext context,
    int count,
    VoidCallback onReview,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = count == 1
        ? 'Tenés una solución por revisar'
        : 'Tenés $count soluciones por revisar';
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.fact_check_outlined, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Revisá el trabajo y confirmá si resolvió el problema.',
              ),
            ],
          ),
        ),
      ],
    );
    final review = OutlinedButton(
      key: const ValueKey('reporter-review-solutions'),
      onPressed: onReview,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: colors.surface,
      ),
      child: const Text('Ver solucionadas'),
    );
    return Container(
      key: const ValueKey('reporter-solutions-banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border.all(color: colors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onPrimaryContainer),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onPrimaryContainer),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 540) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 10), review],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  review,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _empty(
    BuildContext context, {
    required bool filtered,
    required bool hasMatches,
  }) {
    final theme = Theme.of(context);
    final message = hasMatches
        ? 'No hay incidencias en esta etapa.'
        : filtered
        ? 'No hay incidencias que coincidan con la búsqueda.'
        : 'Todavía no tenés incidencias reportadas.';
    return SectionCard(
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (filtered) ...[
            const SizedBox(height: 4),
            const Text(
              'Probá con otra búsqueda o limpiá los filtros.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    MyIncidentsController controller,
    Incident incident,
  ) async {
    controller.pause();
    await Navigator.of(context)
        .pushNamed('/incidents/${Uri.encodeComponent(incident.id)}');
    if (controller.isActive) controller.start();
  }
}
