import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../controllers/incident_search_controller.dart';
import 'incident_administrative_filters.dart';

/// Reusable Spanish search controls for authorized incident lists on any role.
class IncidentSearchPanel extends StatelessWidget {
  /// Controller owned by the enclosing list, never by this presentation widget.
  final IncidentSearchController controller;

  /// Presents sequence/text and category criteria without database or business logic.
  const IncidentSearchPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => !controller.hasSnapshot
      ? const SizedBox.shrink()
      : SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Buscar incidencias',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final query = TextFormField(
                    key: ValueKey(
                      'incident-search-query-${controller.editorVersion}',
                    ),
                    initialValue: controller.criteria.query,
                    onChanged: controller.setQuery,
                    decoration: const InputDecoration(
                      labelText: 'Consecutivo o texto',
                      hintText: 'Ej.: #12, iluminación o edificio A',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                  final category = DropdownButtonFormField<String>(
                    key: ValueKey(
                      'incident-search-category-${controller.criteria.categoryId ?? 'all'}',
                    ),
                    initialValue: controller.criteria.categoryId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todas las categorías'),
                      ),
                      for (final id in controller.categoryIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            controller.categoryLabel(id),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) =>
                        controller.selectCategory(id == '' ? null : id),
                  );
                  if (constraints.maxWidth < 650) {
                    return Column(
                      children: [query, const SizedBox(height: 16), category],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: query),
                      const SizedBox(width: 16),
                      SizedBox(width: 280, child: category),
                    ],
                  );
                },
              ),
              if (controller.administrative) ...[
                const SizedBox(height: 16),
                IncidentAdministrativeFilters(controller: controller),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Resultados: ${controller.results.length} de ${controller.total}',
                    key: const ValueKey('incident-search-count'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('incident-search-clear'),
                    onPressed: controller.criteria.hasCriteria
                        ? controller.reset
                        : null,
                    icon: const Icon(Icons.clear),
                    label: Text(
                      controller.administrative
                          ? 'Limpiar filtros'
                          : 'Limpiar búsqueda',
                    ),
                  ),
                ],
              ),
              if (controller.categoriesLoading)
                const Text('Cargando categorías...'),
              if (controller.hasCategoryErrors) ...[
                const Text('No se pudieron cargar algunas categorías.'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('incident-search-retry-categories'),
                    onPressed: controller.retryCategories,
                    child: const Text('Reintentar categorías'),
                  ),
                ),
              ],
            ],
          ),
        );
}
