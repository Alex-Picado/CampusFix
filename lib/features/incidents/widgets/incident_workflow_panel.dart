import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../controllers/incident_workflow_controller.dart';
import '../models/incident_history_action.dart';
import '../models/incident_priority.dart';
import '../presentation/incident_action_labels.dart';
import '../repositories/incident_repository.dart';

/// Owns an account-bound lifecycle form independently of progress and evidence.
class IncidentWorkflowPanel extends StatelessWidget {
  final String incidentId;
  const IncidentWorkflowPanel({super.key, required this.incidentId});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null || profile.role == UserRole.reporter) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey('workflow:${profile.id}:${profile.role.name}:$incidentId'),
      create: (_) => IncidentWorkflowController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        userRepository: context.read<UserRepository>(),
        session: session,
        uid: profile.id,
        role: profile.role,
        incidentId: incidentId,
      ),
      child: const _WorkflowForm(),
    );
  }
}

class _WorkflowForm extends StatefulWidget {
  const _WorkflowForm();
  @override
  State<_WorkflowForm> createState() => _WorkflowFormState();
}

class _WorkflowFormState extends State<_WorkflowForm> {
  final _reason = TextEditingController();
  IncidentHistoryAction? _action;
  String? _categoryId;
  String? _technicianId;
  IncidentPriority? _priority;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    if (!controller.active) return const SizedBox.shrink();
    final actions = controller.actions;
    final action = actions.contains(_action) ? _action : actions.firstOrNull;
    final enabled =
        controller.ready && !controller.saving && controller.pending == null;
    final categoryId = _categoryId ?? controller.incident?.categoryId;
    final selectedCategory =
        controller.categories.any((row) => row.id == categoryId)
        ? categoryId
        : null;
    final selectedTechnician =
        controller.technicians.any((row) => row.id == _technicianId)
        ? _technicianId
        : null;
    final needsReason = [
      IncidentHistoryAction.resolved,
      IncidentHistoryAction.rejected,
      IncidentHistoryAction.cancelled,
      IncidentHistoryAction.reopened,
    ].contains(action);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atención y gestión',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (controller.loadingSources.isNotEmpty)
              const LinearProgressIndicator(),
            if (controller.readError != null) ...[
              Text(controller.readError!),
              TextButton(
                onPressed: controller.start,
                child: const Text('Reintentar lectura'),
              ),
            ],
            if (actions.isEmpty &&
                controller.ready &&
                controller.pending == null)
              const Text('No hay acciones disponibles para este estado.'),
            if (action != null) ...[
              DropdownButtonFormField<IncidentHistoryAction>(
                key: ValueKey('workflow-action-${action.name}'),
                initialValue: action,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Acción'),
                items: [
                  for (final value in actions)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: enabled
                    ? (value) => setState(() {
                        _action = value;
                        _reason.clear();
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              if (action == IncidentHistoryAction.classified) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('workflow-category-$selectedCategory'),
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final category in controller.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => _categoryId = value)
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IncidentPriority>(
                  key: ValueKey(
                    'workflow-priority-${_priority ?? controller.incident?.priority}',
                  ),
                  initialValue: _priority ?? controller.incident?.priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: [
                    for (final priority in IncidentPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priority.value),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => _priority = value)
                      : null,
                ),
                if (controller.categories.isEmpty && controller.ready)
                  const Text(
                    'No hay categorías activas. Contactá a quien administra el catálogo.',
                  ),
              ],
              if (action == IncidentHistoryAction.assigned) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('workflow-technician-$selectedTechnician'),
                  initialValue: selectedTechnician,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Técnico'),
                  items: [
                    for (final technician in controller.technicians)
                      DropdownMenuItem(
                        value: technician.id,
                        child: Text(
                          '${technician.fullName} · ${technician.email}',
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => _technicianId = value)
                      : null,
                ),
                if (controller.technicians.isEmpty && controller.ready)
                  const Text('No hay usuarios con rol Técnico disponibles.'),
              ],
              if (needsReason) ...[
                TextField(
                  key: const ValueKey('workflow-reason'),
                  controller: _reason,
                  enabled: enabled,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: action == IncidentHistoryAction.resolved
                        ? 'Solución realizada'
                        : 'Motivo obligatorio',
                  ),
                ),
                if (action == IncidentHistoryAction.reopened)
                  const Text(
                    'La solución anterior quedará en el historial. Se quitarán el técnico y la prioridad para revisar y asignar nuevamente.',
                  ),
              ],
            ],
            if (controller.saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (controller.success != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(controller.success!),
                ),
              ),
            const SizedBox(height: 12),
            if (controller.pending != null)
              FilledButton(
                key: const ValueKey('workflow-retry'),
                onPressed: controller.saving ? null : controller.retry,
                child: Text(
                  controller.saving
                      ? 'Guardando...'
                      : 'Reintentar el mismo cambio',
                ),
              )
            else if (action != null)
              FilledButton(
                key: const ValueKey('workflow-save'),
                onPressed: enabled
                    ? () async {
                        final saved = await controller.submit(
                          action,
                          categoryId: action == IncidentHistoryAction.classified
                              ? selectedCategory
                              : null,
                          priority: action == IncidentHistoryAction.classified
                              ? (_priority ?? controller.incident?.priority)
                              : null,
                          technicianId: action == IncidentHistoryAction.assigned
                              ? selectedTechnician
                              : null,
                          reason: needsReason ? _reason.text : null,
                        );
                        if (saved && mounted) {
                          setState(() {
                            _reason.clear();
                            _action = null;
                            _categoryId = null;
                            _priority = null;
                            _technicianId = null;
                          });
                        }
                      }
                    : null,
                child: Text(controller.saving ? 'Guardando...' : action.label),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }
}
