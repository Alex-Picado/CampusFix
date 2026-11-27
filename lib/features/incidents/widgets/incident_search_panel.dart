import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../controllers/incident_search_controller.dart';
import '../presentation/incident_list_order.dart';

/// Search and local ordering for the reporter's list.
class IncidentSearchPanel extends StatelessWidget {
  final IncidentSearchController controller;
  final IncidentListOrder order;
  final ValueChanged<IncidentListOrder> onOrderChanged;

  const IncidentSearchPanel({
    super.key,
    required this.controller,
    required this.order,
    required this.onOrderChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.hasSnapshot) return const SizedBox.shrink();
    final phone = MediaQuery.sizeOf(context).width < 500;
    return SectionCard(
      padding: EdgeInsets.all(phone ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final width = constraints.maxWidth;
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final fullRow = width >= 760 * textScale;
              final compact = width < 430;
              final pairFits = width >= 304 * textScale;
              final category = IncidentCategoryFilter(
                controller: controller,
                compact: compact && pairFits,
              );
              final sort = IncidentSortField(
                key: const ValueKey('reporter-sort'),
                order: order,
                options: const [
                  IncidentListOrder.recent,
                  IncidentListOrder.oldest,
                ],
                onChanged: onOrderChanged,
                compact: compact && pairFits,
              );
              final query = IncidentQueryField(controller: controller);
              if (fullRow) {
                return Row(
                  children: [
                    Expanded(child: query),
                    const SizedBox(width: gap),
                    SizedBox(width: 240 * textScale, child: category),
                    const SizedBox(width: gap),
                    SizedBox(width: 200 * textScale, child: sort),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  query,
                  const SizedBox(height: gap),
                  if (pairFits)
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
          IncidentCategoryFeedback(controller: controller),
        ],
      ),
    );
  }
}

class IncidentQueryField extends StatelessWidget {
  final IncidentSearchController controller;

  const IncidentQueryField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('incident-search-query-${controller.editorVersion}'),
    initialValue: controller.criteria.query,
    onChanged: controller.setQuery,
    decoration: const InputDecoration(
      labelText: 'Consecutivo o texto',
      hintText: 'Ej.: #12, iluminación o edificio A',
      prefixIcon: Icon(Icons.search),
    ),
  );
}

class IncidentCategoryFilter extends StatelessWidget {
  final IncidentSearchController controller;
  final bool compact;

  const IncidentCategoryFilter({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ids = controller.categoryIds;
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'incident-search-category-${controller.criteria.categoryId ?? 'all'}',
      ),
      initialValue: controller.criteria.categoryId ?? '',
      isExpanded: true,
      decoration: _queueFilterDecoration('Categoría', compact: compact),
      selectedItemBuilder: compact
          ? (context) => [
              const Text('Todas'),
              for (final id in ids)
                Text(
                  controller.categoryLabel(id),
                  overflow: TextOverflow.ellipsis,
                ),
            ]
          : null,
      items: [
        const DropdownMenuItem(value: '', child: Text('Todas las categorías')),
        for (final id in ids)
          DropdownMenuItem(
            value: id,
            child: Text(
              controller.categoryLabel(id),
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => controller.selectCategory(id == '' ? null : id),
    );
  }
}

/// Selects the presentation order of the incidents already loaded.
class IncidentSortField extends StatelessWidget {
  final IncidentListOrder order;
  final List<IncidentListOrder> options;
  final ValueChanged<IncidentListOrder> onChanged;
  final bool compact;

  const IncidentSortField({
    super.key,
    required this.order,
    this.options = IncidentListOrder.values,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<IncidentListOrder>(
        key: ValueKey(order),
        initialValue: order,
        isExpanded: true,
        decoration: _queueFilterDecoration(
          'Ordenar',
          compact: compact,
          icon: Icons.sort,
        ),
        items: [
          for (final value in options)
            DropdownMenuItem(
              value: value,
              child: Text(
                compact ? _shortLabel(value) : value.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );

  String _shortLabel(IncidentListOrder order) => switch (order) {
    IncidentListOrder.recent => 'Recientes',
    IncidentListOrder.oldest => 'Antiguas',
    IncidentListOrder.priority => 'Prioridad alta',
    IncidentListOrder.descendingNumber => 'Mayor consecutivo',
    IncidentListOrder.ascendingNumber => 'Menor consecutivo',
  };
}

InputDecoration _queueFilterDecoration(
  String label, {
  required bool compact,
  IconData? icon,
}) => InputDecoration(
  labelText: label,
  contentPadding: compact
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
      : null,
  prefixIcon: compact || icon == null ? null : Icon(icon),
);

class IncidentSearchSummary extends StatelessWidget {
  final int count;
  final int total;
  final String clearLabel;
  final VoidCallback? onClear;

  const IncidentSearchSummary({
    super.key,
    required this.count,
    required this.total,
    required this.clearLabel,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Resultados: $count de $total',
        key: const ValueKey('incident-search-count'),
      ),
      TextButton.icon(
        key: const ValueKey('incident-search-clear'),
        onPressed: onClear,
        icon: const Icon(Icons.clear),
        label: Text(clearLabel),
      ),
    ],
  );
}

class IncidentCategoryFeedback extends StatelessWidget {
  final IncidentSearchController controller;

  const IncidentCategoryFeedback({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (controller.categoriesLoading) const Text('Cargando categorías...'),
      if (controller.hasCategoryErrors) ...[
        const Text('No se pudieron cargar algunas categorías.'),
        TextButton(
          key: const ValueKey('incident-search-retry-categories'),
          onPressed: controller.retryCategories,
          child: const Text('Reintentar categorías'),
        ),
      ],
    ],
  );
}
