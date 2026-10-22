import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../users/models/user_role.dart';
import '../controllers/incident_queue_controller.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';

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
    return ChangeNotifierProvider(
      key: ValueKey('queue:${profile.id}:${profile.role.name}'),
      create: (_) => IncidentQueueController(
        repository: context.read<IncidentRepository>(),
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
        else if (controller.incidents.isEmpty)
          const SectionCard(child: Text('No hay incidencias disponibles.'))
        else
          for (final incident in controller.incidents)
            Padding(
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
                        Chip(
                          label: Text(
                            incident.priority?.value ?? 'Sin prioridad',
                          ),
                        ),
                      ],
                    ),
                    Text(incident.location),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        controller.pause();
                        await Navigator.of(context).pushNamed(
                          '/incidents/${Uri.encodeComponent(incident.id)}',
                        );
                        if (controller.active) controller.start();
                      },
                      child: const Text('Abrir incidencia'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
