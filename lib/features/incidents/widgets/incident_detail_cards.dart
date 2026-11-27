import 'package:material_ui/material_ui.dart';

import '../../../app/theme/campus_palette.dart';
import '../models/incident_history_action.dart';
import '../models/incident_history_event.dart';
import '../presentation/incident_status_labels.dart';

/// Shows an incident field with a bold label, icon and wrapping value.
class IncidentInfoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const IncidentInfoField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Highlights a complete description without truncating technician notes.
class IncidentNarrative extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? accent;

  const IncidentNarrative({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.notes_outlined,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }
}

/// Presents an immutable audit event as a card or as part of a timeline.
class IncidentHistoryCard extends StatelessWidget {
  final IncidentHistoryEvent event;
  final String title;
  final String timestamp;
  final String Function(String) person;
  final String? categoryName;
  final bool inTimeline;
  final bool showTimelineConnector;

  const IncidentHistoryCard({
    super.key,
    required this.event,
    required this.title,
    required this.timestamp,
    required this.person,
    this.categoryName,
    this.inTimeline = false,
    this.showTimelineConnector = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (event.action) {
      IncidentHistoryAction.resolved ||
      IncidentHistoryAction.solutionAccepted ||
      IncidentHistoryAction.closed => (
        Icons.task_alt,
        CampusPalette.statusResolved(theme.brightness),
      ),
      IncidentHistoryAction.assignmentDeclined ||
      IncidentHistoryAction.rejected ||
      IncidentHistoryAction.cancelled => (
        Icons.info_outline,
        CampusPalette.statusCritical(theme.brightness),
      ),
      IncidentHistoryAction.progressAdded || IncidentHistoryAction.started => (
        Icons.handyman_outlined,
        CampusPalette.statusInProgress(theme.brightness),
      ),
      _ => (Icons.history, theme.colorScheme.primary),
    };
    final marker = CircleAvatar(
      radius: inTimeline ? 16 : null,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: inTimeline ? 18 : null),
    );
    final heading = Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    final date = Text(
      timestamp,
      style: inTimeline
          ? theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )
          : theme.textTheme.bodySmall,
    );
    final fields = [
      IncidentInfoField(
        label: 'Por',
        value: person(event.actorUserId),
        icon: Icons.person_outline,
      ),
      if (event.toTechnicianId != null)
        IncidentInfoField(
          label: 'Responsable',
          value: person(event.toTechnicianId!),
          icon: Icons.engineering_outlined,
        ),
      if (event.details?['categoryId'] != null)
        IncidentInfoField(
          label: 'Categoría',
          value: categoryName ?? event.details!['categoryId'].toString(),
          icon: Icons.category_outlined,
        ),
      if (event.details?['priority'] != null)
        IncidentInfoField(
          label: 'Prioridad',
          value: event.details!['priority'].toString(),
          icon: Icons.flag_outlined,
        ),
      if (event.fromTechnicianId != null &&
          event.fromTechnicianId != event.toTechnicianId)
        IncidentInfoField(
          label: 'Responsable anterior',
          value: person(event.fromTechnicianId!),
          icon: Icons.person_outline,
        ),
      if (event.toTechnicianId == null && event.fromTechnicianId != null)
        const IncidentInfoField(
          label: 'Responsable actual',
          value: 'Sin asignar',
          icon: Icons.person_outline,
        ),
    ];
    final content = Column(
      crossAxisAlignment: inTimeline
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        if (inTimeline) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 2,
            children: [heading, date],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final width = constraints.maxWidth >= 390
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                children: [
                  for (final field in fields)
                    SizedBox(width: width, child: field),
                ],
              );
            },
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              marker,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 6), date],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(spacing: 20, runSpacing: 4, children: fields),
        ],
        if (event.fromStatus != null || event.toStatus != null) ...[
          SizedBox(height: inTimeline ? 4 : 12),
          if (!inTimeline) ...[
            Text(
              'Cambio de estado',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Semantics(
            label: inTimeline ? 'Cambio de estado' : null,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(event.fromStatus?.label ?? 'Inicio')),
                const Icon(Icons.arrow_forward, size: 18),
                Chip(
                  backgroundColor: color.withValues(alpha: 0.12),
                  label: Text(event.toStatus?.label ?? 'Sin cambio'),
                ),
              ],
            ),
          ),
        ],
        if (event.previousResolutionDescription != null) ...[
          const SizedBox(height: 16),
          IncidentNarrative(
            title: 'Solución anterior',
            description: event.previousResolutionDescription!,
          ),
        ],
        if (event.reason != null) ...[
          SizedBox(height: inTimeline ? 8 : 16),
          IncidentNarrative(
            title: switch (event.action) {
              IncidentHistoryAction.resolved => 'Solución del técnico',
              IncidentHistoryAction.progressAdded => 'Descripción del avance',
              _ => 'Detalle del evento',
            },
            description: event.reason!,
            icon: icon,
            accent: color,
          ),
        ],
      ],
    );
    if (inTimeline) {
      return Stack(
        children: [
          if (showTimelineConnector)
            PositionedDirectional(
              start: 15,
              top: 32,
              bottom: 0,
              width: 2,
              child: ColoredBox(color: theme.colorScheme.outlineVariant),
            ),
          PositionedDirectional(start: 0, top: 0, child: marker),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: 44,
              top: 3,
              bottom: showTimelineConnector ? 22 : 3,
            ),
            child: content,
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}
