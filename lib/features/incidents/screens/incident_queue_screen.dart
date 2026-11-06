import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../controllers/incident_queue_controller.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../models/technician_work_stage.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
import '../widgets/incident_search_panel.dart';

/// Displays the administrator's reports or the technician's own assignments.
class IncidentQueueScreen extends StatelessWidget {
  const IncidentQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null ||
        ![UserRole.administrator, UserRole.technician].contains(profile.role)) {
      return const SizedBox.shrink();
    }
    // The technician keeps the same feed in Inicio and Mi trabajo.
    if (profile.role == UserRole.technician) return const _QueueView();
    return ChangeNotifierProvider(
      key: ValueKey('queue:${profile.id}:${profile.role.name}'),
      create: (_) => IncidentQueueController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        userRepository: context.read<UserRepository>(),
        session: session,
        uid: profile.id,
        role: profile.role,
      ),
      child: const _QueueView(),
    );
  }
}

class _QueueView extends StatelessWidget {
  const _QueueView();
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentQueueController>();
    if (!controller.active) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('incident-queue'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: controller.role == UserRole.administrator
              ? 'Gestión de incidencias'
              : 'Mi trabajo',
          description: controller.role == UserRole.administrator
              ? 'Clasificá, asigná y supervisá los reportes del campus.'
              : 'Consultá y atendé tus incidencias asignadas.',
        ),
        const SizedBox(height: 20),
        if (!controller.loading && controller.error == null) ...[
          IncidentSearchPanel(controller: controller.search),
          const SizedBox(height: 20),
          if (controller.role == UserRole.technician) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: DropdownButtonFormField<bool>(
                key: ValueKey('technician-order-${controller.urgentFirst}'),
                initialValue: controller.urgentFirst,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: const [
                  DropdownMenuItem(
                    value: true,
                    child: Text('Más urgentes primero'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Más recientes primero'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) controller.setUrgentFirst(value);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
        if (controller.loading)
          const Center(child: CircularProgressIndicator())
        else if (controller.error != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.error!),
                TextButton(
                  onPressed: controller.start,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (controller.search.results.isEmpty)
          SectionCard(
            child: Text(
              controller.search.criteria.hasCriteria
                  ? 'No hay incidencias que coincidan con la búsqueda.'
                  : 'No hay incidencias disponibles.',
            ),
          )
        else if (controller.role == UserRole.technician)
          ..._technicianSections(controller)
        else
          for (final incident in controller.search.results)
            _QueueCard(incident: incident, controller: controller),
      ],
    );
  }

  Iterable<Widget> _technicianSections(
    IncidentQueueController controller,
  ) sync* {
    final groups = {
      for (final section in TechnicianWorkStage.values) section: <Incident>[],
    };
    for (final incident in controller.search.results) {
      groups[TechnicianWorkStage.forStatus(incident.status)]!.add(incident);
    }
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      entry.value.sort((a, b) {
        if (controller.urgentFirst) {
          final priority = (b.priority?.index ?? -1).compareTo(
            a.priority?.index ?? -1,
          );
          if (priority != 0) return priority;
        }
        final updated = b.updatedAt.compareTo(a.updatedAt);
        return updated != 0
            ? updated
            : b.sequenceNumber.compareTo(a.sequenceNumber);
      });
      final label = switch (entry.key) {
        TechnicianWorkStage.newAssignments => 'Sin empezar',
        TechnicianWorkStage.inProgress => 'Ya avanzadas',
        TechnicianWorkStage.history => 'Historial',
      };
      yield Column(
        key: ValueKey('technician-queue-${entry.key.name}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('$label (${entry.value.length})'),
          ),
          const SizedBox(height: 8),
          for (final incident in entry.value)
            _QueueCard(incident: incident, controller: controller),
        ],
      );
      yield const SizedBox(height: 8);
    }
  }
}

class _QueueCard extends StatelessWidget {
  final Incident incident;
  final IncidentQueueController controller;

  const _QueueCard({required this.incident, required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(incident.status.label)),
              Chip(label: Text(incident.priority?.value ?? 'Sin prioridad')),
            ],
          ),
          if (controller.role == UserRole.technician &&
              incident.status == IncidentStatus.resolved)
            const Text('Pendiente de cierre por un administrador.'),
          Text(incident.location),
          const SizedBox(height: 8),
          OutlinedButton(
            key: ValueKey('detail-${incident.id}'),
            onPressed: () async {
              final pauseForDetail = controller.role == UserRole.administrator;
              if (pauseForDetail) controller.pause();
              await Navigator.of(context)
                  .pushNamed('/incidents/${Uri.encodeComponent(incident.id)}');
              if (pauseForDetail && controller.active) controller.start();
            },
            child: const Text('Abrir incidencia'),
          ),
        ],
      ),
    ),
  );
}
