import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../controllers/incident_queue_controller.dart';
import '../controllers/my_incidents_controller.dart';
import '../models/incident_status.dart';
import '../models/technician_work_stage.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';

/// Gives a reporter a direct path to submit a case and track their own reports.
class ReporterIncidentDashboard extends StatelessWidget {
  final String userId;
  final VoidCallback onReport;
  final VoidCallback onViewReports;

  const ReporterIncidentDashboard({
    super.key,
    required this.userId,
    required this.onReport,
    required this.onViewReports,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    key: ValueKey('reporter-home:$userId'),
    create: (context) => MyIncidentsController(
      incidentRepository: context.read<IncidentRepository>(),
      categoryRepository: context.read<CategoryRepository>(),
      sessionController: context.read<SessionController>(),
      userId: userId,
    ),
    child: Builder(
      builder: (context) {
        final controller = context.watch<MyIncidentsController>();
        final rows = controller.incidents;
        final tracking = rows
            .where(
              (row) => switch (row.status) {
                IncidentStatus.closed ||
                IncidentStatus.cancelled ||
                IncidentStatus.rejected => false,
                _ => true,
              },
            )
            .length;
        final closed = rows
            .where((row) => row.status == IncidentStatus.closed)
            .length;
        return Column(
          key: const ValueKey('overview-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeading(
              title: 'Panel del reportante',
              description:
                  'Reportá un problema del campus y seguí su atención.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('reporter-dashboard-report'),
                  onPressed: onReport,
                  icon: const Icon(Icons.add),
                  label: const Text('Reportar incidencia'),
                ),
                OutlinedButton(
                  onPressed: onViewReports,
                  child: const Text('Ver mis incidencias'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (controller.isLoading)
              const LinearProgressIndicator()
            else if (controller.errorMessage case final String error)
              _DashboardError(error: error, onRetry: controller.start)
            else ...[
              _SummaryCards(
                items: [
                  ('Mis reportes', rows.length, 'Todas tus solicitudes'),
                  ('En seguimiento', tracking, 'Pendientes de un cierre'),
                  ('Cerradas', closed, 'Atención completada'),
                ],
              ),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes recientes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Todavía no tenés reportes. Usá «Reportar incidencia» para empezar.',
                        ),
                      ),
                    for (final row in rows.take(3))
                      Material(
                        key: ValueKey('recent-report-${row.id}'),
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('#${row.sequenceNumber} · ${row.title}'),
                          subtitle: Text(
                            '${row.status.reporterLabel}\n${row.status.reporterExplanation}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pushNamed(
                            '/incidents/${Uri.encodeComponent(row.id)}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// Summarizes only the current technician's confirmed assignments.
class TechnicianIncidentDashboard extends StatelessWidget {
  final VoidCallback onViewWork;

  const TechnicianIncidentDashboard({super.key, required this.onViewWork});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentQueueController>();
    final waiting = controller.incidents
        .where(
          (row) =>
              TechnicianWorkStage.forStatus(row.status) ==
              TechnicianWorkStage.newAssignments,
        )
        .length;
    final started = controller.incidents
        .where(
          (row) =>
              TechnicianWorkStage.forStatus(row.status) ==
              TechnicianWorkStage.inProgress,
        )
        .length;
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Panel del técnico',
          description:
              'Revisá tu carga de trabajo y qué casos requieren atención.',
        ),
        const SizedBox(height: 20),
        if (controller.loading)
          const LinearProgressIndicator()
        else if (controller.error case final String error)
          _DashboardError(error: error, onRetry: controller.start)
        else
          _SummaryCards(
            items: [
              (
                'Incidencias pendientes',
                waiting + started,
                'Asignadas que aún requieren atención',
              ),
              ('Sin empezar', waiting, 'Aún no iniciaste la atención'),
              ('Ya avanzadas', started, 'Con atención iniciada, sin resolver'),
            ],
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onViewWork,
          icon: const Icon(Icons.handyman_outlined),
          label: const Text('Ver mi trabajo'),
        ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final List<(String, int, String)> items;
  const _SummaryCards({required this.items});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 640
          ? (constraints.maxWidth - 24) / 3
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (label, count, description) in items)
            SizedBox(
              width: width,
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(description),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _DashboardError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _DashboardError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
