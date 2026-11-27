import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../controllers/incident_search_controller.dart';
import '../models/incident_filters.dart';
import '../models/incident_status.dart';
import '../presentation/administrative_incident_stages.dart';
import '../presentation/incident_list_order.dart';
import '../presentation/incident_status_labels.dart';
import 'incident_search_panel.dart';

/// Quick views and filters for the administrator's live incident list.
class IncidentAdministrativeFilters extends StatelessWidget {
  final IncidentSearchController controller;
  final Map<IncidentStatus, int> counts;
  final Set<IncidentStatus> selectedStatuses;
  final ValueChanged<Set<IncidentStatus>> onSelectStatuses;
  final IncidentListOrder order;
  final ValueChanged<IncidentListOrder> onOrder;

  const IncidentAdministrativeFilters({
    super.key,
    required this.controller,
    required this.counts,
    required this.selectedStatuses,
    required this.onSelectStatuses,
    required this.order,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final filters = controller.criteria.filters;
    final technicianValue = filters.technicianId != null
        ? 'uid:${filters.technicianId}'
        : filters.unassignedOnly
        ? 'none'
        : '';
    final sort = IncidentSortField(
      key: const ValueKey('management-sort'),
      order: order,
      onChanged: onOrder,
    );
    final quickViews = _quickViews();
    final dropdownTextStyle = Theme.of(context).textTheme.bodyMedium;
    final fields = [
      _statusField(context),
      IncidentCategoryFilter(controller: controller, compact: true),
      DropdownButtonFormField<IncidentPriorityFilter>(
        key: ValueKey('incident-filter-priority-${filters.priority.name}'),
        initialValue: filters.priority,
        isExpanded: true,
        style: dropdownTextStyle,
        decoration: const InputDecoration(
          labelText: 'Prioridad',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: [
          for (final value in IncidentPriorityFilter.values)
            DropdownMenuItem(
              value: value,
              child: Text(
                _priorityLabel(value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) controller.selectPriority(value);
        },
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('incident-filter-technician-$technicianValue'),
        initialValue: technicianValue,
        isExpanded: true,
        style: dropdownTextStyle,
        decoration: const InputDecoration(
          labelText: 'Técnico responsable',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
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
      ),
    ];
    final query = IncidentQueryField(controller: controller);
    const gap = 12.0;
    return SectionCard(
      key: const ValueKey('incident-administrative-filters'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 780
              ? 4
              : width >= 360
              ? 2
              : 1;
          final fieldWidth = (width - (columns - 1) * gap) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (width >= 970)
                Row(
                  children: [
                    Expanded(child: quickViews),
                    const SizedBox(width: gap),
                    SizedBox(width: 280, child: sort),
                  ],
                )
              else ...[
                quickViews,
                const SizedBox(height: gap),
                SizedBox(width: width < 550 ? width : 280, child: sort),
              ],
              const SizedBox(height: gap),
              if (width >= 1100)
                Row(
                  children: [
                    Expanded(flex: 3, child: query),
                    for (final field in fields) ...[
                      const SizedBox(width: gap),
                      Expanded(flex: 2, child: field),
                    ],
                  ],
                )
              else ...[
                query,
                const SizedBox(height: gap),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final field in fields)
                      SizedBox(width: fieldWidth, child: field),
                  ],
                ),
              ],
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
                TextButton(
                  key: const ValueKey('incident-filter-retry-technicians'),
                  onPressed: controller.retryTechnicians,
                  child: const Text('Reintentar técnicos'),
                ),
              ],
              IncidentCategoryFeedback(controller: controller),
            ],
          );
        },
      ),
    );
  }

  Widget _quickViews() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final view in IncidentManagementView.values)
        ChoiceChip(
          key: ValueKey('management-view-${view.id}'),
          label: Text('${view.label} (${_viewCount(view)})'),
          selected:
              view.statuses.length == selectedStatuses.length &&
              selectedStatuses.containsAll(view.statuses),
          onSelected: (_) => onSelectStatuses(view.statuses),
        ),
    ],
  );

  int _viewCount(IncidentManagementView view) => counts.entries
      .where(
        (entry) => view.statuses.isEmpty || view.statuses.contains(entry.key),
      )
      .fold(0, (sum, entry) => sum + entry.value);

  Widget _statusField(BuildContext context) {
    final label = switch (selectedStatuses.length) {
      0 => 'Todos los estados',
      1 => selectedStatuses.single.label,
      _ => '${selectedStatuses.length} estados seleccionados',
    };
    return OutlinedButton(
      key: const ValueKey('incident-filter-status'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _chooseStatuses(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado', style: Theme.of(context).textTheme.labelSmall),
                Text(label, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Future<void> _chooseStatuses(BuildContext context) async {
    final draft = selectedStatuses.toSet();
    final selected = await showDialog<Set<IncidentStatus>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filtrar por estado'),
          scrollable: true,
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final status in IncidentStatus.values)
                  CheckboxListTile(
                    key: ValueKey('management-status-${status.value}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    value: draft.contains(status),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        draft.add(status);
                      } else {
                        draft.remove(status);
                      }
                    }),
                    title: Text(status.label),
                    secondary: Text('${counts[status] ?? 0}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('management-status-clear'),
              onPressed: draft.isEmpty ? null : () => setState(draft.clear),
              child: const Text('Quitar selección'),
            ),
            FilledButton(
              key: const ValueKey('management-status-apply'),
              onPressed: () => Navigator.of(context).pop(Set.of(draft)),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (context.mounted && controller.administrative && selected != null) {
      onSelectStatuses(selected);
    }
  }

  String _priorityLabel(IncidentPriorityFilter value) => switch (value) {
    IncidentPriorityFilter.all => 'Todas las prioridades',
    IncidentPriorityFilter.withoutPriority => 'Sin prioridad',
    IncidentPriorityFilter.low => 'Baja',
    IncidentPriorityFilter.medium => 'Media',
    IncidentPriorityFilter.high => 'Alta',
  };
}
