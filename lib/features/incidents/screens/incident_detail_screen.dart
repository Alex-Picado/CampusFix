import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/incident_detail_controller.dart';
import '../models/incident_history_action.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';
import '../repositories/evidence_repository.dart';
import '../widgets/evidence_widgets.dart';
import '../widgets/incident_workflow_panel.dart';
import '../widgets/reporter_report_actions.dart';

/// Protected detail, chronological comments/history and assigned-technician progress.
class IncidentDetailScreen extends StatelessWidget {
  final String incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey('${profile.id}:${profile.role.name}:$incidentId'),
      create: (context) => IncidentDetailController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        evidenceRepository: context.read<EvidenceRepository?>(),
        session: session,
        incidentId: incidentId,
        uid: profile.id,
        role: profile.role,
      ),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView();
  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  bool _reporting = false;
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentDetailController>();
    if (!controller.active) return const SizedBox.shrink();
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      final error = SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(controller.error!),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('detail-retry'),
              onPressed: controller.start,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
      if (controller.role != UserRole.technician) return error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          error,
          IncidentWorkflowPanel(
            key: const ValueKey('detail-workflow-panel'),
            incidentId: controller.incidentId,
          ),
        ],
      );
    }
    if (controller.notFound) {
      return const SectionCard(child: Text('No se encontró esta incidencia.'));
    }
    final incident = controller.incident!;
    final profile = controller.session.profile!;
    String person(String id) => id == profile.id
        ? profile.fullName
        : id == incident.assignedTechnicianId
        ? 'Técnico asignado'
        : id == incident.createdByUserId
        ? 'Reportante'
        : 'Equipo de atención';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          key: const ValueKey('incident-detail-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(
              title: 'Incidencia #${incident.sequenceNumber}',
              description: incident.title,
            ),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(incident.status.label)),
                  if (incident.reporterHidden) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'El reportante eliminó este reporte de su lista. Se conserva su historial.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  SelectableText(incident.description),
                  const SizedBox(height: 12),
                  Text('Ubicación: ${incident.location}'),
                  if (controller.categoryLoading)
                    const Text('Categoría: Cargando...')
                  else if (controller.categoryError != null) ...[
                    Text('Categoría: ${controller.categoryError}'),
                    TextButton(
                      key: const ValueKey('category-retry'),
                      onPressed: controller.retryCategory,
                      child: const Text('Reintentar categoría'),
                    ),
                  ] else
                    Text(
                      'Categoría: ${controller.category!.name}'
                      '${controller.category!.isActive ? '' : ' (inactiva)'}',
                    ),
                  Text(
                    'Prioridad: ${incident.priority?.value ?? 'Sin clasificar'}',
                  ),
                  Text('Reportante: ${person(incident.createdByUserId)}'),
                  Text(
                    'Técnico asignado: ${incident.assignedTechnicianId == null ? 'Sin asignar' : person(incident.assignedTechnicianId!)}',
                  ),
                  Text('Creada: ${_date(incident.createdAt)}'),
                  Text('Última actualización: ${_date(incident.updatedAt)}'),
                  if (incident.resolutionDescription != null)
                    Text('Solución: ${incident.resolutionDescription}'),
                  if (incident.status == IncidentStatus.resolved ||
                      incident.status == IncidentStatus.closed) ...[
                    const Divider(height: 28),
                    Text(
                      'Conformidad para el cierre',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final approval in [
                          ('Técnico', incident.technicianApproved),
                          ('Reportante', incident.reporterApproved),
                          ('Administración', incident.adminApproved),
                        ])
                          Chip(
                            avatar: Icon(
                              approval.$2 ? Icons.check_circle : Icons.schedule,
                              size: 18,
                              color: approval.$2
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            label: Text(
                              '${approval.$1}: ${approval.$2 ? 'de acuerdo' : 'pendiente'}',
                            ),
                          ),
                      ],
                    ),
                    const Text(
                      'El cierre requiere el acuerdo de las tres partes sobre esta solución.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ReporterReportActions(
          incident: incident,
          onRemoved: () => Navigator.of(context).maybePop(),
        ),
        if (!controller.canAddProgress && !controller.frozen)
          IncidentWorkflowPanel(
            key: const ValueKey('detail-workflow-panel'),
            incidentId: incident.id,
          ),
        _section(
          context,
          'Fotografías',
          controller.loadingSections.contains('evidence'),
          [
            if (controller.evidenceRepository == null)
              const PhotoAvailabilityNotice()
            else if (controller.evidence.isEmpty)
              const Text('No hay fotografías asociadas.')
            else
              EvidenceGallery(uid: profile.id, evidence: controller.evidence),
          ],
        ),
        if (profile.role.name == 'reporter' &&
            incident.createdByUserId == profile.id)
          ReportPhotoUpload(incidentId: incident.id),
        _section(
          context,
          'Avances y comentarios',
          controller.loadingSections.contains('progress'),
          [
            if (controller.progress.isEmpty)
              const Text('Todavía no hay avances registrados.'),
            for (final entry in controller.progress)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avance ${controller.progress.indexOf(entry) + 1} · Técnico: ${person(entry.authorUserId)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _date(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(entry.description),
                    if (controller.evidence.any(
                      (photo) => photo.progressId == entry.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: EvidenceGallery(
                          uid: profile.id,
                          evidence: controller.evidence
                              .where((photo) => photo.progressId == entry.id)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (controller.canAddProgress || controller.frozen) ...[
          FilledButton.icon(
            key: const ValueKey('report-progress'),
            onPressed: () => setState(() => _reporting = !_reporting),
            icon: Icon(_reporting ? Icons.expand_less : Icons.edit_note),
            label: Text(_reporting ? 'Ocultar formulario' : 'Reportar avance'),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: !_reporting && !controller.frozen
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final children = [
                        const _ProgressForm(),
                        IncidentWorkflowPanel(
                          incidentId: incident.id,
                          blocked:
                              controller.saving ||
                              controller.frozen ||
                              controller.selecting,
                        ),
                      ];
                      if (constraints.maxWidth < 850) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: children[0]),
                          const SizedBox(width: 20),
                          Expanded(child: children[1]),
                        ],
                      );
                    },
                  ),
          ),
        ],
        _section(context, 'Historial', controller.loadingSections.contains('history'), [
          if (controller.history.isEmpty)
            const Text('No hay eventos registrados.'),
          for (final event in controller.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_action(event.action)} · ${_date(event.createdAt)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text('Por: ${person(event.actorUserId)}'),
                  if (event.fromStatus != null || event.toStatus != null)
                    Text(
                      '${event.fromStatus?.label ?? 'Inicio'} → ${event.toStatus?.label ?? 'Sin cambio'}',
                    ),
                  if (event.toTechnicianId != null)
                    Text('Responsable: ${person(event.toTechnicianId!)}'),
                  if (event.details?['categoryId'] != null)
                    Text(
                      'Categoría: ${event.details!['categoryId']} · Prioridad: ${event.details!['priority']}',
                    ),
                  if (event.fromTechnicianId != null &&
                      event.fromTechnicianId != event.toTechnicianId)
                    Text(
                      'Responsable anterior: ${person(event.fromTechnicianId!)}',
                    ),
                  if (event.toTechnicianId == null &&
                      event.fromTechnicianId != null)
                    const Text('Responsable actual: sin asignar'),
                  if (event.previousResolutionDescription != null)
                    Text(
                      'Solución anterior: ${event.previousResolutionDescription}',
                    ),
                  if (event.reason != null) Text(event.reason!),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    bool loading,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator() else ...children,
        ],
      ),
    ),
  );

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _action(IncidentHistoryAction action) => switch (action) {
    IncidentHistoryAction.created => 'Incidencia reportada',
    IncidentHistoryAction.classified => 'Clasificación actualizada',
    IncidentHistoryAction.assigned => 'Técnico asignado',
    IncidentHistoryAction.assignmentDeclined => 'Asignación rechazada',
    IncidentHistoryAction.started => 'Atención iniciada',
    IncidentHistoryAction.progressAdded => 'Avance registrado',
    IncidentHistoryAction.resolved => 'Incidencia resuelta',
    IncidentHistoryAction.solutionAccepted =>
      'Solución aceptada por el reportante',
    IncidentHistoryAction.reviewRequested => 'Nueva revisión solicitada',
    IncidentHistoryAction.reviewDismissed => 'Solicitud de revisión cerrada',
    IncidentHistoryAction.closed => 'Administración aprobó el cierre',
    IncidentHistoryAction.rejected => 'Incidencia rechazada',
    IncidentHistoryAction.cancelled => 'Incidencia cancelada',
    IncidentHistoryAction.removedFromList =>
      'Reporte eliminado de la lista del reportante',
    IncidentHistoryAction.reopened => 'Incidencia reabierta',
  };
}

class _ProgressForm extends StatefulWidget {
  const _ProgressForm();
  @override
  State<_ProgressForm> createState() => _ProgressFormState();
}

class _ProgressFormState extends State<_ProgressForm> {
  late final TextEditingController _description;
  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: context.read<IncidentDetailController>().description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentDetailController>();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registrar avance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('progress-description'),
            controller: _description,
            minLines: 3,
            maxLines: 8,
            readOnly: controller.saving || controller.frozen,
            onChanged: controller.setDescription,
            decoration: const InputDecoration(
              labelText: 'Descripción del avance',
            ),
          ),
          const SizedBox(height: 12),
          if (controller.photo != null)
            Image.memory(
              controller.photo!.bytes,
              height: 140,
              fit: BoxFit.contain,
            ),
          if (controller.evidenceId != null && controller.photo == null)
            Text(
              controller.uploaded == null
                  ? 'Volvé a seleccionar la fotografía original.'
                  : 'Fotografía cargada, pendiente de asociación.',
            ),
          if (controller.progressError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                controller.progressError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (controller.progressSuccess != null)
            Semantics(
              liveRegion: true,
              child: Text(controller.progressSuccess!),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (controller.evidenceRepository != null)
                OutlinedButton.icon(
                  key: const ValueKey('progress-photo'),
                  onPressed: controller.canSelect
                      ? controller.selectPhoto
                      : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    controller.selecting ? 'Leyendo foto...' : 'Foto opcional',
                  ),
                ),
              FilledButton(
                key: const ValueKey('progress-save'),
                onPressed: controller.saving || controller.selecting
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        if (await controller.saveProgress() && mounted) {
                          _description.clear();
                        }
                      },
                child: Text(
                  controller.saving
                      ? 'Guardando...'
                      : controller.frozen
                      ? 'Reintentar avance'
                      : 'Guardar avance',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }
}
