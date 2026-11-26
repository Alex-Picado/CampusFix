import 'package:material_ui/material_ui.dart';

import '../controllers/incident_search_controller.dart';
import '../models/incident.dart';
import '../models/incident_priority.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';

/// Compact administrative results for reviewing and opening incidents.
class IncidentManagementList extends StatelessWidget {
  final List<Incident> incidents;
  final IncidentSearchController search;
  final ValueChanged<Incident> onOpen;

  const IncidentManagementList({
    super.key,
    required this.incidents,
    required this.search,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, incident) in incidents.indexed) ...[
                if (index > 0) const Divider(height: 1),
                _IncidentManagementRow(
                  key: ValueKey('incident-${incident.id}'),
                  incident: incident,
                  category: search.categoryLabel(incident.categoryId),
                  technician: switch (incident.assignedTechnicianId) {
                    final String id => search.technicianName(id),
                    null => 'Sin asignar',
                  },
                  onOpen: () => onOpen(incident),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentManagementRow extends StatelessWidget {
  final Incident incident;
  final String category;
  final String technician;
  final VoidCallback onOpen;

  const _IncidentManagementRow({
    super.key,
    required this.incident,
    required this.category,
    required this.technician,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;
    final status = incident.status;
    final accent = _statusColor(status, theme.brightness);
    final guidance = switch (status) {
      IncidentStatus.reported ||
      IncidentStatus.underReview ||
      IncidentStatus.resolved ||
      IncidentStatus.reviewRequested ||
      IncidentStatus.reopened => status.administratorGuidance,
      _ => null,
    };

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${incident.sequenceNumber} · ${incident.title}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          incident.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                child: Text(category, style: text.bodySmall),
              ),
            ),
            _IncidentRowDetail(
              icon: Icons.location_on_outlined,
              label: 'Ubicación',
              value: incident.location,
            ),
            _IncidentRowDetail(
              icon: Icons.person_outline,
              label: 'Técnico responsable',
              value: technician,
            ),
            _IncidentRowDetail(
              icon: Icons.schedule,
              label: 'Último cambio',
              value: formatIncidentQueueDate(incident.updatedAt),
            ),
          ],
        ),
        if (guidance != null) ...[
          const SizedBox(height: 8),
          _IncidentRowDetail(
            icon: Icons.outlined_flag,
            value: guidance,
            color: accent,
          ),
        ],
      ],
    );

    final statusBadge = Chip(
      side: BorderSide(color: accent.withValues(alpha: 0.52)),
      backgroundColor: accent.withValues(alpha: 0.12),
      labelStyle: text.labelMedium?.copyWith(color: accent),
      label: Text(status.label),
      shape: const StadiumBorder(),
    );

    return Stack(
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: 4,
          child: ColoredBox(color: accent),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final open = OutlinedButton(
                key: ValueKey('detail-${incident.id}'),
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, compact ? 48 : 40),
                  side: BorderSide(color: colors.primary),
                ),
                child: const Text('Abrir incidencia'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        statusBadge,
                        IncidentPriorityBadge(incident: incident),
                      ],
                    ),
                    const SizedBox(height: 6),
                    open,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.29,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        statusBadge,
                        IncidentPriorityBadge(incident: incident),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.30,
                    ),
                    child: open,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Color _statusColor(IncidentStatus status, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (status) {
      IncidentStatus.reported ||
      IncidentStatus.closed ||
      IncidentStatus.rejected ||
      IncidentStatus.cancelled =>
        dark ? const Color(0xFFAFB8C7) : const Color(0xFF586477),
      IncidentStatus.underReview ||
      IncidentStatus.reviewRequested ||
      IncidentStatus.reopened =>
        dark ? const Color(0xFFFFBA68) : const Color(0xFF8B5600),
      IncidentStatus.assigned =>
        dark ? const Color(0xFF96C3FF) : const Color(0xFF245DA8),
      IncidentStatus.inProgress =>
        dark ? const Color(0xFFC4ABFF) : const Color(0xFF6745A5),
      IncidentStatus.resolved =>
        dark ? const Color(0xFF70DCA9) : const Color(0xFF146843),
    };
  }
}

class _IncidentRowDetail extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String value;
  final Color? color;

  const _IncidentRowDetail({
    required this.icon,
    this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: label == null ? value : '$label, $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the common incident priority label and its color-coded dot.
class IncidentPriorityBadge extends StatelessWidget {
  final Incident incident;

  const IncidentPriorityBadge({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
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
}

/// Formats the local date and time shown in incident queues.
String formatIncidentQueueDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
