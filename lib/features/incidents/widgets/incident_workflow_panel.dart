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

/// Keeps pending workflow commands alive when the case itself loses access.
class IncidentWorkflowScope extends StatelessWidget {
  final String incidentId;
  final Widget child;
  const IncidentWorkflowScope({
    super.key,
    required this.incidentId,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null || profile.role == UserRole.reporter) {
      return child;
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
      child: child,
    );
  }
}

/// Displays actions available to the current administrator or technician.
class IncidentWorkflowPanel extends StatefulWidget {
  const IncidentWorkflowPanel({super.key});

  @override
  State<IncidentWorkflowPanel> createState() => _WorkflowFormState();
}

class _WorkflowFormState extends State<IncidentWorkflowPanel> {
  final _reason = TextEditingController();
  IncidentHistoryAction? _action;
  String? _categoryId;
  String? _technicianId;
  IncidentPriority? _priority;
  bool _declineDialogOpen = false;

  Future<void> _decline(IncidentWorkflowController controller) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    setState(() => _declineDialogOpen = true);
    final declined = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const _DeclineAssignmentDialog(),
      ),
    );
    if (mounted) setState(() => _declineDialogOpen = false);
    if (declined != true ||
        !controller.active ||
        !navigator.mounted ||
        route?.isCurrent != true) {
      return;
    }
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/');
    }
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La asignación volvió a Gestión para que se asigne a otro técnico.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    if (!controller.active) return const SizedBox.shrink();
    final availableActions = controller.actions;
    final canDecline = availableActions.contains(
      IncidentHistoryAction.assignmentDeclined,
    );
    final actions = availableActions
        .where((action) => action != IncidentHistoryAction.assignmentDeclined)
        .toList();
    final action = actions.contains(_action) ? _action : actions.firstOrNull;
    final enabled =
        controller.ready && !controller.saving && controller.pending == null;
    final categoryId = _categoryId ?? controller.incident?.categoryId;
    final selectedCategory =
        controller.categories.any((row) => row.id == categoryId)
        ? categoryId
        : null;
    final reassigning = action == IncidentHistoryAction.reassigned;
    final eligibleTechnicians = controller.technicians
        .where(
          (row) =>
              !reassigning ||
              row.id != controller.incident?.assignedTechnicianId,
        )
        .toList();
    final selectedTechnician =
        eligibleTechnicians.any((row) => row.id == _technicianId)
        ? _technicianId
        : null;
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
            if (action != null && actions.length > 1) ...[
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
                        _technicianId = null;
                        _reason.clear();
                      })
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            if (action != null) ...[
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
              if (action.selectsTechnician) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('workflow-technician-$selectedTechnician'),
                  initialValue: selectedTechnician,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: reassigning ? 'Nuevo técnico' : 'Técnico',
                  ),
                  items: [
                    for (final technician in eligibleTechnicians)
                      DropdownMenuItem(
                        value: technician.id,
                        child: Text(
                          '${technician.fullName} · ${technician.email}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => _technicianId = value)
                      : null,
                ),
                if (eligibleTechnicians.isEmpty && controller.ready)
                  Text(
                    reassigning
                        ? 'No hay otro técnico disponible para reasignar.'
                        : 'No hay usuarios con rol Técnico disponibles.',
                  ),
              ],
              if (action.requiresWorkflowReason) ...[
                TextField(
                  key: const ValueKey('workflow-reason'),
                  controller: _reason,
                  enabled: enabled,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: switch (action) {
                      IncidentHistoryAction.resolved => 'Solución realizada',
                      IncidentHistoryAction.reassigned =>
                        'Motivo de la reasignación',
                      _ => 'Motivo obligatorio',
                    },
                  ),
                ),
                if (reassigning)
                  const Text('Se conservan el estado y los avances del caso.'),
                if (action == IncidentHistoryAction.reopened)
                  const Text(
                    'La solución anterior quedará en el historial. Se quitarán el técnico y la prioridad para revisar y asignar nuevamente.',
                  ),
              ],
            ],
            if (controller.saveError != null && !_declineDialogOpen)
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
                onPressed: controller.saving
                    ? null
                    : controller.pending?.action ==
                          IncidentHistoryAction.assignmentDeclined
                    ? () => _decline(controller)
                    : controller.retry,
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
                          technicianId: action.selectsTechnician
                              ? selectedTechnician
                              : null,
                          reason: action.requiresWorkflowReason
                              ? _reason.text
                              : null,
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
            if (canDecline && controller.pending == null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('workflow-decline-assignment'),
                onPressed: enabled ? () => _decline(controller) : null,
                child: const Text('Rechazar asignación'),
              ),
            ],
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

class _DeclineAssignmentDialog extends StatefulWidget {
  const _DeclineAssignmentDialog();

  @override
  State<_DeclineAssignmentDialog> createState() =>
      _DeclineAssignmentDialogState();
}

class _DeclineAssignmentDialogState extends State<_DeclineAssignmentDialog> {
  final _reason = TextEditingController();

  Future<void> _submit(IncidentWorkflowController controller) async {
    final saved =
        controller.pending?.action == IncidentHistoryAction.assignmentDeclined
        ? await controller.retry()
        : await controller.submit(
            IncidentHistoryAction.assignmentDeclined,
            reason: _reason.text,
          );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    final retry =
        controller.pending?.action == IncidentHistoryAction.assignmentDeclined;
    final canSubmit =
        controller.ready &&
        controller.actions.contains(IncidentHistoryAction.assignmentDeclined);
    final error =
        controller.saveError ??
        (retry ? null : controller.readError) ??
        (controller.ready && !canSubmit && !retry
            ? 'La asignación ya no puede rechazarse.'
            : null);
    return PopScope(
      canPop: !controller.saving,
      child: AlertDialog(
        title: const Text('Rechazar asignación'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El administrador podrá asignar el caso a otro técnico. Los avances se conservan.',
              ),
              const SizedBox(height: 12),
              if (!retry)
                TextField(
                  key: const ValueKey('decline-reason'),
                  controller: _reason,
                  enabled: canSubmit && !controller.saving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    hintText: 'Ej.: No estaré disponible esta semana',
                  ),
                ),
              if (!controller.active)
                const Text(
                  'Tu sesión cambió. Cerrá este cuadro para continuar.',
                )
              else if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.saving
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('decline-confirm'),
            onPressed:
                !controller.active ||
                    controller.saving ||
                    (!retry && !canSubmit)
                ? null
                : () => _submit(controller),
            child: Text(
              controller.saving
                  ? 'Guardando...'
                  : retry
                  ? 'Reintentar'
                  : 'Confirmar rechazo',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }
}
