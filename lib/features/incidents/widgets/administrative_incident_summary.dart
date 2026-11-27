import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../controllers/incident_detail_controller.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';
import 'incident_detail_cards.dart';
import 'incident_queue_list.dart';

/// The incident record and its supporting details for administrators.
class AdministrativeIncidentSummary extends StatelessWidget {
  final IncidentDetailController controller;
  final String Function(String) person;
  final String Function(DateTime) formatDate;
  final Widget reportActions;

  const AdministrativeIncidentSummary({
    super.key,
    required this.controller,
    required this.person,
    required this.formatDate,
    required this.reportActions,
  });

  @override
  Widget build(BuildContext context) {
    final incident = controller.incident!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final solution = incident.resolutionDescription;
    final statusColor = switch (incident.status) {
      IncidentStatus.resolved || IncidentStatus.closed => _successColor(theme),
      IncidentStatus.rejected || IncidentStatus.cancelled => colors.error,
      IncidentStatus.inProgress => colors.tertiary,
      _ => colors.primary,
    };

    final description = IncidentNarrative(
      title: 'Descripción del problema',
      description: incident.description,
      icon: Icons.report_problem_outlined,
    );
    final solutionBlock = solution == null
        ? null
        : IncidentNarrative(
            key: const ValueKey('incident-resolution'),
            title: 'Solución del técnico',
            description: solution,
            icon: Icons.task_alt,
            accent: _successColor(theme),
          );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                label: Text(incident.status.label),
                labelStyle: TextStyle(color: statusColor),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                side: BorderSide(color: statusColor.withValues(alpha: 0.45)),
                shape: const StadiumBorder(),
              ),
              IncidentPriorityBadge(incident: incident),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              '#${incident.sequenceNumber} · ${incident.title}',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (incident.reporterHidden)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'El reportante eliminó este reporte de su lista. Se conserva su historial.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          if (solutionBlock == null)
            description
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 550) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      description,
                      const SizedBox(height: 12),
                      solutionBlock,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    Expanded(child: solutionBlock),
                  ],
                );
              },
            ),
          const Divider(height: 32),
          Text('Datos de la incidencia', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _Fact(
                  label: 'Ubicación',
                  value: incident.location,
                  icon: Icons.location_on_outlined,
                ),
                _categoryFact(),
                _Fact(
                  label: 'Prioridad',
                  value: incident.priority?.value ?? 'Sin clasificar',
                  icon: Icons.flag_outlined,
                ),
                _Fact(
                  label: 'Reportante',
                  value: person(incident.createdByUserId),
                  icon: Icons.person_outline,
                ),
                _Fact(
                  label: 'Técnico asignado',
                  value: switch (incident.assignedTechnicianId) {
                    final String id => person(id),
                    null => 'Sin asignar',
                  },
                  icon: Icons.engineering_outlined,
                ),
                _Fact(
                  label: 'Creada',
                  value: formatDate(incident.createdAt),
                  icon: Icons.event_outlined,
                ),
                _Fact(
                  label: 'Última actualización',
                  value: formatDate(incident.updatedAt),
                  icon: Icons.update,
                ),
              ];
              const gap = 16.0;
              final columns = constraints.maxWidth >= 570
                  ? 3
                  : constraints.maxWidth >= 280
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 14,
                children: [
                  for (final field in fields)
                    SizedBox(width: width, child: field),
                ],
              );
            },
          ),
          reportActions,
        ],
      ),
    );
  }

  Widget _categoryFact() {
    final category = controller.category;
    final error = controller.categoryError;
    final name = switch (category) {
      null => null,
      _ => '${category.name}${category.isActive ? '' : ' (inactiva)'}',
    };
    return _Fact(
      label: 'Categoría',
      value: controller.categoryLoading
          ? 'Cargando...'
          : error ?? name ?? 'La categoría ya no está disponible.',
      icon: Icons.category_outlined,
      action: error == null
          ? null
          : TextButton(
              key: const ValueKey('category-retry'),
              onPressed: controller.retryCategory,
              child: const Text('Reintentar categoría'),
            ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? action;

  const _Fact({
    required this.label,
    required this.value,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
        ?action,
      ],
    );
  }
}

/// Shows which participants have agreed to close the incident.
class IncidentClosureApprovals extends StatelessWidget {
  final Incident incident;

  const IncidentClosureApprovals({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approvals = [
      ('Técnico', incident.technicianApproved),
      ('Reportante', incident.reporterApproved),
      ('Administración', incident.adminApproved),
    ];
    final accepted = approvals.where((approval) => approval.$2).length;
    final pendingColor = theme.brightness == Brightness.dark
        ? const Color(0xFFFFC078)
        : const Color(0xFF865300);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              'Conformidad para el cierre',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '$accepted de ${approvals.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (role, approved) in approvals)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      approved ? Icons.task_alt : Icons.schedule,
                      size: 18,
                      color: approved ? _successColor(theme) : pendingColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(role)),
                  ],
                ),
                Text(
                  approved ? 'De acuerdo' : 'Pendiente',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: approved ? _successColor(theme) : pendingColor,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'El cierre requiere el acuerdo de las tres partes sobre esta solución.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

Color _successColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF81C784)
    : const Color(0xFF2E7D32);
