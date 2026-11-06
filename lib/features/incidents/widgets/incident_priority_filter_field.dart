import 'package:flutter/material.dart';

import '../models/incident_filters.dart';

/// Selects a priority without changing incident data or query permissions.
class IncidentPriorityFilterField extends StatelessWidget {
  final IncidentPriorityFilter value;
  final ValueChanged<IncidentPriorityFilter> onChanged;

  const IncidentPriorityFilterField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<IncidentPriorityFilter>(
        key: ValueKey('incident-filter-priority-${value.name}'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Prioridad'),
        items: [
          for (final filter in IncidentPriorityFilter.values)
            DropdownMenuItem(value: filter, child: Text(_label(filter))),
        ],
        onChanged: (filter) {
          if (filter != null) onChanged(filter);
        },
      );

  String _label(IncidentPriorityFilter filter) => switch (filter) {
    IncidentPriorityFilter.all => 'Todas las prioridades',
    IncidentPriorityFilter.withoutPriority => 'Sin prioridad',
    IncidentPriorityFilter.low => 'Baja',
    IncidentPriorityFilter.medium => 'Media',
    IncidentPriorityFilter.high => 'Alta',
  };
}
