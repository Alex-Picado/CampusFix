import 'package:material_ui/material_ui.dart';

import '../../../app/theme/campus_palette.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/incident_search_controller.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/incident_list_order.dart';
import 'incident_queue_list.dart';
import 'incident_search_panel.dart';

/// The stages in the technician queue, in the same order as the home shortcuts.
enum TechnicianWorkStage {
  assigned('Asignadas', 'Incidencias que podés comenzar a atender.', {
    IncidentStatus.assigned,
  }),
  working('En atención', 'Incidencias en las que estás trabajando.', {
    IncidentStatus.inProgress,
  }),
  solved(
    'Solucionadas',
    'Registraste una solución y administración revisará el cierre.',
    {IncidentStatus.resolved},
  ),
  review(
    'En revisión',
    'Incidencias que esperan una decisión de administración.',
    {
      IncidentStatus.reported,
      IncidentStatus.underReview,
      IncidentStatus.reviewRequested,
      IncidentStatus.reopened,
    },
  ),
  finished('Finalizadas', 'Incidencias cerradas, rechazadas o canceladas.', {
    IncidentStatus.closed,
    IncidentStatus.rejected,
    IncidentStatus.cancelled,
  });

  final String label;
  final String description;
  final Set<IncidentStatus> statuses;

  const TechnicianWorkStage(this.label, this.description, this.statuses);

  Color accent(Brightness brightness) => switch (this) {
    assigned => CampusPalette.statusAssigned(brightness),
    working => CampusPalette.statusInProgress(brightness),
    solved => CampusPalette.statusResolved(brightness),
    review => CampusPalette.statusReview(brightness),
    finished => CampusPalette.statusNeutral(brightness),
  };
}

/// Presents the technician's authorized assignments without issuing queries.
class TechnicianWorkQueue extends StatelessWidget {
  final IncidentSearchController search;
  final TechnicianWorkStage selected;
  final IncidentListOrder order;
  final ValueChanged<TechnicianWorkStage> onStage;
  final ValueChanged<IncidentListOrder> onOrder;
  final ValueChanged<Incident> onOpen;

  const TechnicianWorkQueue({
    super.key,
    required this.search,
    required this.selected,
    required this.order,
    required this.onStage,
    required this.onOrder,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final stage in TechnicianWorkStage.values)
        search.results
            .where((incident) => stage.statuses.contains(incident.status))
            .toList(),
    ];
    final incidents = groups[selected.index]..sort(order.compare);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchControls(context),
        const SizedBox(height: 16),
        _stageControls(context, groups),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(
              selected.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IncidentSearchSummary(
              count: search.results.length,
              total: search.total,
              clearLabel: 'Limpiar búsqueda',
              onClear: search.criteria.hasCriteria ? search.reset : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (incidents.isEmpty)
          SectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  search.total == 0
                      ? 'No hay incidencias disponibles.'
                      : search.results.isEmpty
                      ? 'No hay incidencias que coincidan con la búsqueda.'
                      : 'No hay incidencias en esta etapa.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (search.total > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    search.criteria.hasCriteria
                        ? 'Probá con otra búsqueda o categoría.'
                        : 'Las asignaciones de esta etapa aparecerán acá.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          )
        else
          IncidentQueueList.technician(
            key: ValueKey('workspace-stage-${selected.index}'),
            incidents: incidents,
            search: search,
            onOpen: onOpen,
          ),
      ],
    );
  }

  Widget _searchControls(BuildContext context) => SectionCard(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 500 ? 12 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final query = IncidentQueryField(controller: search);
            final compact = constraints.maxWidth < 430;
            final sideBySide =
                constraints.maxWidth >=
                MediaQuery.textScalerOf(context).scale(304);
            final category = IncidentCategoryFilter(
              controller: search,
              compact: compact && sideBySide,
            );
            final sort = IncidentSortField(
              key: const ValueKey('workspace-sort'),
              order: order,
              compact: compact && sideBySide,
              options: const [
                IncidentListOrder.priority,
                IncidentListOrder.recent,
                IncidentListOrder.oldest,
                IncidentListOrder.descendingNumber,
              ],
              onChanged: onOrder,
            );
            if (constraints.maxWidth >= 820) {
              return Row(
                children: [
                  Expanded(child: query),
                  const SizedBox(width: gap),
                  SizedBox(width: 235, child: category),
                  const SizedBox(width: gap),
                  SizedBox(width: 270, child: sort),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                query,
                const SizedBox(height: gap),
                if (sideBySide)
                  Row(
                    children: [
                      Expanded(child: category),
                      const SizedBox(width: gap),
                      Expanded(child: sort),
                    ],
                  )
                else ...[
                  category,
                  const SizedBox(height: gap),
                  sort,
                ],
              ],
            );
          },
        ),
        IncidentCategoryFeedback(controller: search),
      ],
    ),
  );

  Widget _stageControls(BuildContext context, List<List<Incident>> groups) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = BorderSide(color: theme.dividerColor);
    final enlarged = (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(
      0.0,
      32.0,
    );
    final tabWidth = 136 + enlarged * 3;
    final tabHeight = 98 + enlarged * 4;
    return DefaultTabController(
      length: TechnicianWorkStage.values.length,
      initialIndex: selected.index,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? colors.surfaceContainerLow
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 470) {
                  return _stageGrid(context, groups, border, enlarged);
                }
                final scrollable =
                    constraints.maxWidth <
                    tabWidth * TechnicianWorkStage.values.length;
                return TabBar(
                  isScrollable: scrollable,
                  tabAlignment: scrollable
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  padding: EdgeInsets.zero,
                  labelPadding: EdgeInsets.zero,
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  onTap: (index) => onStage(TechnicianWorkStage.values[index]),
                  tabs: [
                    for (final stage in TechnicianWorkStage.values)
                      Tab(
                        key: ValueKey('workspace-tab-${stage.index}'),
                        height: tabHeight,
                        child: _stageCard(
                          context,
                          stage,
                          groups[stage.index].length,
                          width: scrollable ? tabWidth : double.infinity,
                          border: border,
                          lastInRow: stage == TechnicianWorkStage.finished,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageGrid(
    BuildContext context,
    List<List<Incident>> groups,
    BorderSide border,
    double enlarged,
  ) {
    final stages = TechnicianWorkStage.values;
    Widget row(List<TechnicianWorkStage> stages) => SizedBox(
      height: 82 + enlarged * 4,
      child: Row(
        children: [
          for (final (index, stage) in stages.indexed)
            Expanded(
              child: Semantics(
                selected: stage == selected,
                child: InkWell(
                  key: ValueKey('workspace-tab-${stage.index}'),
                  onTap: () => onStage(stage),
                  child: _stageCard(
                    context,
                    stage,
                    groups[stage.index].length,
                    width: double.infinity,
                    border: border,
                    lastInRow: index == stages.length - 1,
                    compact: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          row(stages.take(3).toList()),
          const Divider(height: 1),
          row(stages.skip(3).toList()),
        ],
      ),
    );
  }

  Widget _stageCard(
    BuildContext context,
    TechnicianWorkStage stage,
    int count, {
    required double width,
    required BorderSide border,
    required bool lastInRow,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final active = stage == selected;
    final accent = stage.accent(theme.brightness);
    final foreground = theme.colorScheme.onSurface;
    return Semantics(
      label: '${stage.label}, $count incidencias',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 9),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.12) : null,
          border: BorderDirectional(
            end: lastInRow ? BorderSide.none : border,
            bottom: BorderSide(
              color: active ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style:
                  (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.16,
                        color: foreground,
                      ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stage.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact
                                ? theme.textTheme.labelMedium
                                : theme.textTheme.labelLarge)
                            ?.copyWith(
                              fontWeight: active ? FontWeight.w700 : null,
                              height: 1.20,
                              color: active
                                  ? foreground
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
