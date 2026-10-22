import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/incident_dashboard_controller.dart';
import '../models/incident_indicators.dart';
import '../repositories/incident_repository.dart';

/// Displays global administrative indicators with independently recoverable reads.
class IncidentDashboardScreen extends StatelessWidget {
  const IncidentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null || profile.role != UserRole.administrator) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey('dashboard:${profile.id}'),
      create: (_) => IncidentDashboardController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        session: session,
        uid: profile.id,
      ),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentDashboardController>();
    if (!controller.active) return const SizedBox.shrink();
    final indicators = controller.indicators;
    return Column(
      key: const ValueKey('dashboard-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Indicadores del campus',
          description: 'Resumen global actualizado en vivo. Los filtros de Gestión no afectan estos indicadores.',
        ),
        const SizedBox(height: 20),
        if (controller.loading)
          const Center(child: CircularProgressIndicator())
        else if (controller.error != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No se pudieron actualizar los indicadores.'),
                Text(controller.error!),
                TextButton(
                  key: const ValueKey('dashboard-retry'),
                  onPressed: controller.retryIncidents,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (indicators != null) ...[
          _Metrics(indicators: indicators),
          const SizedBox(height: 16),
          const Text(
            'Abiertas: reportadas, en revisión, asignadas y en atención. '
            'En atención forma parte de abiertas. El total también incluye rechazadas, canceladas y reabiertas.',
          ),
          const SizedBox(height: 24),
          if (indicators.total == 0)
            const SectionCard(
              child: Text('Todavía no hay incidencias registradas.'),
            )
          else
            _CategoryCounts(controller: controller, indicators: indicators),
        ],
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  final IncidentIndicators indicators;
  const _Metrics({required this.indicators});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'total',
        'Total de incidencias',
        indicators.total,
        Icons.description_outlined,
      ),
      ('open', 'Abiertas', indicators.open, Icons.folder_open_outlined),
      (
        'in-progress',
        'En atención',
        indicators.inProgress,
        Icons.handyman_outlined,
      ),
      ('resolved', 'Resueltas', indicators.resolved, Icons.task_alt_outlined),
      ('closed', 'Cerradas', indicators.closed, Icons.inventory_2_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 600
            ? 3
            : constraints.maxWidth >= 380
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (id, label, count, icon) in metrics)
              SizedBox(
                width: width,
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        '$count',
                        key: ValueKey('dashboard-$id'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(label),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryCounts extends StatelessWidget {
  final IncidentDashboardController controller;
  final IncidentIndicators indicators;
  const _CategoryCounts({required this.controller, required this.indicators});

  @override
  Widget build(BuildContext context) {
    final rows = indicators.byCategory.entries.toList()
      ..sort((first, second) {
        final byCount = second.value.compareTo(first.value);
        return byCount != 0 ? byCount : first.key.compareTo(second.key);
      });
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incidencias por categoría',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${indicators.total} incidencias · incluye categorías inactivas',
          ),
          const SizedBox(height: 20),
          if (controller.categoriesLoading)
            const Center(child: CircularProgressIndicator())
          else if (controller.categoryError != null) ...[
            const Text(
              'No se pudieron consultar los nombres de las categorías.',
            ),
            Text(controller.categoryError!),
            TextButton(
              key: const ValueKey('dashboard-categories-retry'),
              onPressed: controller.retryCategories,
              child: const Text('Reintentar categorías'),
            ),
          ] else
            for (final row in rows)
              Padding(
                key: ValueKey('dashboard-category-${row.key}'),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            controller.categories[row.key]?.name ??
                                'Categoría no disponible',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${row.value}',
                          key: ValueKey('dashboard-category-count-${row.key}'),
                        ),
                      ],
                    ),
                    Text(
                      'ID: ${row.key}${controller.categories[row.key]?.isActive == false ? ' · Inactiva' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: row.value / indicators.total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      semanticsLabel:
                          '${controller.categories[row.key]?.name ?? row.key}: '
                          '${row.value} de ${indicators.total} incidencias',
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
