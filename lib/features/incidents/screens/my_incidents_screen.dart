import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/my_incidents_controller.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_search_panel.dart';
import 'incident_report_screen.dart';

/// Switches between the reporter's live list and an independently owned form.
class MyIncidentsScreen extends StatefulWidget {
  final String userId;

  const MyIncidentsScreen({super.key, required this.userId});

  @override
  State<MyIncidentsScreen> createState() => _MyIncidentsScreenState();
}

class _MyIncidentsScreenState extends State<MyIncidentsScreen> {
  bool _creating = false;

  @override
  void didUpdateWidget(covariant MyIncidentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _creating = false;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != SessionStatus.authenticated ||
        session.profile?.id != widget.userId ||
        session.profile?.role != UserRole.reporter) {
      return const SizedBox.shrink();
    }
    if (_creating) {
      return IncidentReportScreen(
        userId: widget.userId,
        onBack: () => setState(() => _creating = false),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(widget.userId),
      create: (context) => MyIncidentsController(
        incidentRepository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        sessionController: session,
        userId: widget.userId,
      ),
      child: _IncidentList(onCreate: () => setState(() => _creating = true)),
    );
  }
}

/// Displays confirmed report summaries and explicit loading, empty and error states.
class _IncidentList extends StatelessWidget {
  final VoidCallback onCreate;

  const _IncidentList({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MyIncidentsController>();
    if (!controller.isActive) return const SizedBox.shrink();
    final error = controller.errorMessage;
    return Column(
      key: const ValueKey('my-incidents-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Mis incidencias',
          description: 'Consultá el estado de tus reportes.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('incidents-create'),
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Crear incidencia'),
        ),
        const SizedBox(height: 20),
        if (!controller.isLoading && error == null) ...[
          IncidentSearchPanel(controller: controller.search),
          const SizedBox(height: 20),
        ],
        if (controller.isLoading)
          const SectionCard(
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Cargando incidencias...')),
              ],
            ),
          )
        else if (error != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('incidents-retry'),
                  onPressed: controller.start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (controller.search.results.isEmpty)
          SectionCard(
            child: Text(
              controller.search.criteria.hasCriteria
                  ? 'No hay incidencias que coincidan con la búsqueda.'
                  : 'Todavía no tenés incidencias reportadas.',
            ),
          )
        else
          for (final incident in controller.search.results)
            Padding(
              key: ValueKey('incident-${incident.id}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${incident.sequenceNumber} · ${incident.title}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Chip(label: Text(incident.status.label)),
                    const SizedBox(height: 8),
                    Text('Ubicación: ${incident.location}'),
                    const SizedBox(height: 4),
                    Text('Reportada: ${_date(incident.createdAt)}'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: ValueKey('detail-${incident.id}'),
                      onPressed: () async {
                        controller.pause();
                        await Navigator.of(context).pushNamed(
                          '/incidents/${Uri.encodeComponent(incident.id)}',
                        );
                        if (controller.isActive) controller.start();
                      },
                      child: const Text('Ver detalle'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// Presents server timestamps in the viewer's local time without dependencies.
  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
