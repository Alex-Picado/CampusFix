import 'package:flutter/material.dart';

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

/// Separates each immutable audit event with its own heading and surface.
///
/// Receives authorized display names and a formatted timestamp from the detail.
/// Stored events, state transitions and their chronological order are preserved.
class IncidentHistoryCard extends StatelessWidget {
  final IncidentHistoryEvent event;
  final String title;
  final String timestamp;
  final String Function(String) person;
  final String? categoryName;

  const IncidentHistoryCard({
    super.key,
    required this.event,
    required this.title,
    required this.timestamp,
    required this.person,
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (event.action) {
      IncidentHistoryAction.resolved ||
      IncidentHistoryAction.solutionAccepted ||
      IncidentHistoryAction.closed => (
        Icons.task_alt,
        theme.brightness == Brightness.dark
            ? const Color(0xFF81C784)
            : const Color(0xFF2E7D32),
      ),
      IncidentHistoryAction.assignmentDeclined ||
      IncidentHistoryAction.rejected ||
      IncidentHistoryAction.cancelled => (
        Icons.info_outline,
        theme.colorScheme.error,
      ),
      IncidentHistoryAction.progressAdded || IncidentHistoryAction.started => (
        Icons.handyman_outlined,
        theme.colorScheme.tertiary,
      ),
      _ => (Icons.history, theme.colorScheme.primary),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(timestamp, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
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
                  value:
                      categoryName ?? event.details!['categoryId'].toString(),
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
              if (event.toTechnicianId == null &&
                  event.fromTechnicianId != null)
                const IncidentInfoField(
                  label: 'Responsable actual',
                  value: 'Sin asignar',
                  icon: Icons.person_outline,
                ),
            ],
          ),
          if (event.fromStatus != null || event.toStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              'Cambio de estado',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
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
          ],
          if (event.previousResolutionDescription != null) ...[
            const SizedBox(height: 16),
            IncidentNarrative(
              title: 'Solución anterior',
              description: event.previousResolutionDescription!,
            ),
          ],
          if (event.reason != null) ...[
            const SizedBox(height: 16),
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
      ),
    );
  }
}
