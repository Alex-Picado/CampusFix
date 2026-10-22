import 'package:flutter/material.dart';

import '../controllers/incident_search_controller.dart';
import '../models/incident_filters.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';

/// Presents administrator-only state, priority and responsible-person criteria.
class IncidentAdministrativeFilters extends StatelessWidget {
  /// Session-bound search state; its owning queue manages all subscriptions.
  final IncidentSearchController controller;

  /// Creates presentation controls with no independent database or filter logic.
  const IncidentAdministrativeFilters({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.administrative) return const SizedBox.shrink();
    final filters = controller.criteria.filters;
    final technicianValue = filters.technicianId != null
        ? 'uid:${filters.technicianId}'
        : filters.unassignedOnly
        ? 'none'
        : '';
    final status = DropdownButtonFormField<IncidentStatus>(
      key: ValueKey('incident-filter-status-${filters.status?.value ?? 'all'}'),
      initialValue: filters.status,
      isExpanded: true,
      hint: const Text('Todos los estados'),
      decoration: const InputDecoration(labelText: 'Estado'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos los estados')),
        for (final value in IncidentStatus.values)
          DropdownMenuItem(value: value, child: Text(value.label)),
      ],
      onChanged: controller.selectStatus,
    );
    final priority = DropdownButtonFormField<IncidentPriorityFilter>(
      key: ValueKey('incident-filter-priority-${filters.priority.name}'),
      initialValue: filters.priority,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Prioridad'),
      items: [
        for (final value in IncidentPriorityFilter.values)
          DropdownMenuItem(value: value, child: Text(_priorityLabel(value))),
      ],
      onChanged: (value) {
        if (value != null) controller.selectPriority(value);
      },
    );
    final technician = DropdownButtonFormField<String>(
      key: ValueKey('incident-filter-technician-$technicianValue'),
      initialValue: technicianValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Técnico responsable'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos los técnicos')),
        const DropdownMenuItem(value: 'none', child: Text('Sin asignar')),
        for (final id in controller.technicianIds)
          DropdownMenuItem(
            value: 'uid:$id',
            child: Text(
              controller.technicianLabel(id),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        if (value == 'none') {
          controller.selectTechnician(null, unassignedOnly: true);
        } else {
          controller.selectTechnician(
            value.isEmpty ? null : value.substring(4),
          );
        }
      },
    );
    return Column(
      key: const ValueKey('incident-administrative-filters'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Filtros administrativos',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 16),
                  Expanded(child: priority),
                  const SizedBox(width: 16),
                  Expanded(child: technician),
                ],
              );
            }
            if (constraints.maxWidth >= 560) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 16),
                      Expanded(child: priority),
                    ],
                  ),
                  const SizedBox(height: 16),
                  technician,
                ],
              );
            }
            return Column(
              children: [
                status,
                const SizedBox(height: 16),
                priority,
                const SizedBox(height: 16),
                technician,
              ],
            );
          },
        ),
        if (controller.techniciansLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Cargando técnicos...'),
          ),
        if (controller.technicianError != null) ...[
          const SizedBox(height: 8),
          Text(
            'No se pudieron cargar los técnicos. ${controller.technicianError}',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('incident-filter-retry-technicians'),
              onPressed: controller.retryTechnicians,
              child: const Text('Reintentar técnicos'),
            ),
          ),
        ],
      ],
    );
  }

  String _priorityLabel(IncidentPriorityFilter value) => switch (value) {
    IncidentPriorityFilter.all => 'Todas las prioridades',
    IncidentPriorityFilter.withoutPriority => 'Sin prioridad',
    IncidentPriorityFilter.low => 'Baja',
    IncidentPriorityFilter.medium => 'Media',
    IncidentPriorityFilter.high => 'Alta',
  };
}
