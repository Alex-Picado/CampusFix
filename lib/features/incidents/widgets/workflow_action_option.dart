import 'package:flutter/material.dart';

import '../models/incident_history_action.dart';

/// Selects a workflow form without submitting its operation.
///
/// Displays a rectangular radio option. Color, marker and semantics identify
/// selection together; disabled choices cannot change a pending submission.
class WorkflowActionOption extends StatelessWidget {
  final IncidentHistoryAction action;
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  const WorkflowActionOption({
    super.key,
    required this.action,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = switch (action) {
      IncidentHistoryAction.assignmentDeclined ||
      IncidentHistoryAction.rejected ||
      IncidentHistoryAction.cancelled ||
      IncidentHistoryAction.reviewRequested => colors.error,
      IncidentHistoryAction.started ||
      IncidentHistoryAction.resolved ||
      IncidentHistoryAction.solutionAccepted ||
      IncidentHistoryAction.closed =>
        dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      _ => colors.primary,
    };
    final foreground = onSelected == null
        ? colors.onSurface.withValues(alpha: 0.55)
        : selected
        ? accent
        : colors.onSurface;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onSelected != null,
      label: label,
      onTap: onSelected,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: dark ? 0.16 : 0.08)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? accent : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: foreground,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected ? 'Opción seleccionada' : 'Seleccionar opción',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
