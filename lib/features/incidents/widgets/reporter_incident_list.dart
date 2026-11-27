import 'package:material_ui/material_ui.dart';

import '../../../app/theme/campus_palette.dart';
import '../../../core/widgets/section_card.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';
import 'incident_queue_list.dart' show formatIncidentQueueDate;
import 'reporter_report_actions.dart';

/// The reporter's stages, in the order used by the home shortcuts.
enum ReporterIncidentStage {
  pending('Pendientes', 'Reportes que esperan revisión o una nueva atención.'),
  assigned('Asignadas', 'Reportes que ya tienen un técnico asignado.'),
  working('En atención', 'Reportes en los que está trabajando un técnico.'),
  solved('Solucionada', 'Reportes con una solución registrada por el técnico.'),
  finished('Finalizadas', 'Reportes cerrados, rechazados o cancelados.');

  final String label;
  final String description;

  const ReporterIncidentStage(this.label, this.description);

  static ReporterIncidentStage fromStatus(IncidentStatus status) =>
      switch (status) {
        IncidentStatus.reported ||
        IncidentStatus.underReview ||
        IncidentStatus.reopened ||
        IncidentStatus.reviewRequested => pending,
        IncidentStatus.assigned => assigned,
        IncidentStatus.inProgress => working,
        IncidentStatus.resolved => solved,
        IncidentStatus.closed ||
        IncidentStatus.cancelled ||
        IncidentStatus.rejected => finished,
      };

  Color accent(Brightness brightness) => switch (this) {
    pending || finished => CampusPalette.statusNeutral(brightness),
    assigned => CampusPalette.statusAssigned(brightness),
    working => CampusPalette.statusInProgress(brightness),
    solved => CampusPalette.statusResolved(brightness),
  };
}

/// Counts stay visible in two rows on a phone and one row on wide screens.
class ReporterIncidentStages extends StatelessWidget {
  final ReporterIncidentStage selected;
  final Map<ReporterIncidentStage, List<Incident>> groups;
  final ValueChanged<ReporterIncidentStage> onSelected;

  const ReporterIncidentStages({
    super.key,
    required this.selected,
    required this.groups,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = ReporterIncidentStage.values;

    return SectionCard(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxWidth >= 630 * scale) {
            return _row(context, stages);
          }
          if (constraints.maxWidth >= 294 * scale) {
            return Column(
              children: [
                _row(context, stages.take(3).toList()),
                const SizedBox(height: 6),
                _row(context, stages.skip(3).toList()),
              ],
            );
          }
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final stage in stages) _button(theme, stage)],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, List<ReporterIncidentStage> stages) => Row(
    children: [
      for (final (index, stage) in stages.indexed) ...[
        if (index > 0) const SizedBox(width: 6),
        Expanded(child: _button(Theme.of(context), stage)),
      ],
    ],
  );

  Widget _button(ThemeData theme, ReporterIncidentStage stage) {
    final colors = theme.colorScheme;
    final active = stage == selected;
    final count = groups[stage]!.length;
    final label = '${stage.label} ($count)';
    final accent = stage.accent(theme.brightness);
    final textColor = active ? colors.onPrimaryContainer : colors.onSurface;
    return Semantics(
      selected: active,
      child: OutlinedButton(
        key: ValueKey('incidents-tab-${stage.index}'),
        onPressed: () => onSelected(stage),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          backgroundColor: active ? colors.primaryContainer : colors.surface,
          foregroundColor: textColor,
          side: BorderSide(
            color: active ? colors.primary : colors.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${stage.label} '),
              TextSpan(
                text: '($count)',
                style: TextStyle(
                  color: active ? textColor : accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          semanticsLabel: label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// One confirmed report and the current action available to its owner.
class ReporterIncidentCard extends StatelessWidget {
  final Incident incident;
  final String category;
  final ReporterIncidentStage stage;
  final bool needsSolutionReview;
  final VoidCallback onOpen;

  const ReporterIncidentCard({
    super.key,
    required this.incident,
    required this.category,
    required this.stage,
    required this.needsSolutionReview,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (incident.status) {
      IncidentStatus.reviewRequested => CampusPalette.statusReview(
        theme.brightness,
      ),
      IncidentStatus.cancelled ||
      IncidentStatus.rejected => CampusPalette.statusCritical(theme.brightness),
      _ => stage.accent(theme.brightness),
    };
    final sameDate = incident.createdAt == incident.updatedAt;
    final timestamp = sameDate ? incident.createdAt : incident.updatedAt;
    final metadataColor = colors.onSurfaceVariant;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${incident.sequenceNumber} · ${incident.title}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          incident.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                child: Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            _LabeledIcon(
              icon: Icons.location_on_outlined,
              label: 'Ubicación: ${incident.location}',
              color: metadataColor,
            ),
            _LabeledIcon(
              icon: Icons.schedule,
              label:
                  '${sameDate ? 'Reportada' : 'Último cambio'}: ${formatIncidentQueueDate(timestamp)}',
              color: metadataColor,
            ),
          ],
        ),
        if (stage != ReporterIncidentStage.finished) ...[
          const SizedBox(height: 10),
          _LabeledIcon(
            icon: Icons.info_outline,
            label: incident.status.reporterGuidance,
            color: accent,
          ),
        ],
      ],
    );
    final status = _status(theme, accent);
    final open = needsSolutionReview
        ? FilledButton.icon(
            key: ValueKey('detail-${incident.id}'),
            onPressed: onOpen,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Revisar solución'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          )
        : OutlinedButton(
            key: ValueKey('detail-${incident.id}'),
            onPressed: onOpen,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Ver detalle'),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SectionCard(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final narrow = constraints.maxWidth < 620 * textScale;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (narrow) ...[
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: status,
                      ),
                      const SizedBox(height: 10),
                      summary,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: summary),
                          const SizedBox(width: 16),
                          status,
                        ],
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: narrow ? double.infinity : null,
                      child: open,
                    ),
                    ReporterReportActions(incident: incident),
                  ],
                );
              },
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }

  Widget _status(ThemeData theme, Color accent) {
    final colors = theme.colorScheme;
    final step = stage.index + 1;
    final isInterrupted =
        incident.status == IncidentStatus.cancelled ||
        incident.status == IncidentStatus.rejected;
    final progress = 'Etapa $step de ${ReporterIncidentStage.values.length}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.52)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            incident.status.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!isInterrupted) ...[
          const SizedBox(height: 6),
          Semantics(
            label: progress,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  progress,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                for (
                  var index = 0;
                  index < ReporterIncidentStage.values.length;
                  index++
                )
                  Container(
                    width: 7,
                    height: 4,
                    margin: const EdgeInsetsDirectional.only(start: 3),
                    decoration: BoxDecoration(
                      color: index < step ? accent : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LabeledIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LabeledIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    ],
  );
}
