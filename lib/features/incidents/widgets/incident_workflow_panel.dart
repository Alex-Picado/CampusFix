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
import '../models/incident_status.dart';
import '../presentation/incident_action_labels.dart';
import '../presentation/incident_status_labels.dart';
import '../repositories/incident_repository.dart';

/// Owns an account-bound lifecycle form independently of progress and evidence.
class IncidentWorkflowPanel extends StatelessWidget {
  final String incidentId;
  const IncidentWorkflowPanel({super.key, required this.incidentId});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null) {
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
  _AdministratorStep? _submittedStep;

  void _selectAction(IncidentHistoryAction? action) => setState(() {
    _action = action;
    _reason.clear();
  });

  void _resetDraft() => setState(() {
    _reason.clear();
    _action = null;
    _categoryId = null;
    _priority = null;
    _technicianId = null;
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    if (!controller.active) return const SizedBox.shrink();
    final actions = controller.actions;
    if (controller.role == UserRole.reporter &&
        actions.isEmpty &&
        controller.loadingSources.isEmpty &&
        controller.readError == null &&
        controller.saveError == null &&
        controller.success == null &&
        controller.pending == null) {
      return const SizedBox.shrink();
    }
    final administrator = controller.role == UserRole.administrator;
    final incident = controller.incident;
    final status = controller.pending?.expectedStatus ?? incident?.status;
    final step = administrator
        ? (controller.pending == null ? null : _submittedStep) ??
              _AdministratorStep.forIncident(controller)
        : null;
    final preferredAction = switch (step) {
      _AdministratorStep.classification => IncidentHistoryAction.classified,
      _AdministratorStep.assignment => IncidentHistoryAction.assigned,
      _AdministratorStep.followUp => IncidentHistoryAction.closed,
      null => actions.firstOrNull,
    };
    final primary = actions.contains(preferredAction) ? preferredAction : null;
    final action = administrator && controller.pending != null
        ? controller.pending!.action
        : actions.contains(_action)
        ? _action
        : primary;
    final enabled =
        controller.ready &&
        !controller.saving &&
        controller.pending == null &&
        !(administrator && controller.awaitingUpdate);
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
      IncidentHistoryAction.reviewRequested,
      IncidentHistoryAction.reviewDismissed,
      IncidentHistoryAction.assignmentDeclined,
    ].contains(action);
    final buttons = <Widget>[
      if (controller.pending != null)
        FilledButton(
          key: const ValueKey('workflow-retry'),
          onPressed: controller.saving
              ? null
              : () async {
                  final wasDeclining =
                      controller.pending?.action ==
                      IncidentHistoryAction.assignmentDeclined;
                  final navigator = Navigator.of(context);
                  final route = ModalRoute.of(context);
                  final saved = await controller.retry();
                  if (saved && administrator && mounted) _resetDraft();
                  if (saved &&
                      wasDeclining &&
                      navigator.mounted &&
                      route?.isCurrent == true) {
                    navigator.pop();
                  }
                },
          child: Text(
            controller.saving ? 'Guardando...' : 'Reintentar el mismo cambio',
          ),
        )
      else if (action != null)
        FilledButton(
          key: const ValueKey('workflow-save'),
          onPressed: enabled
              ? () async {
                  _submittedStep = step;
                  final navigator = Navigator.of(context);
                  final route = ModalRoute.of(context);
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
                  if (saved && mounted) _resetDraft();
                  if (saved &&
                      action == IncidentHistoryAction.assignmentDeclined &&
                      navigator.mounted &&
                      route?.isCurrent == true) {
                    navigator.pop();
                  }
                }
              : null,
          child: Text(switch (action) {
            _ when controller.saving => 'Guardando...',
            IncidentHistoryAction.classified => 'Confirmar clasificación',
            IncidentHistoryAction.assigned => 'Confirmar asignación',
            _ => action.label,
          }),
        ),
      if (administrator && enabled) ...[
        if (action != primary)
          TextButton(
            onPressed: () => _selectAction(null),
            child: const Text('Volver a las opciones'),
          )
        else
          for (final alternative in actions.where((item) => item != primary))
            TextButton(
              key: ValueKey('workflow-option-${alternative.name}'),
              onPressed: () => _selectAction(alternative),
              child: Text(
                alternative == IncidentHistoryAction.classified
                    ? 'Editar clasificación'
                    : alternative.label,
              ),
            ),
      ],
    ];
    final form = Column(
      key: ValueKey(step),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null && status != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              step.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text(step.instructions(status)),
          const SizedBox(height: 12),
          if (controller.awaitingUpdate)
            const Text('Actualizando el estado de la incidencia…'),
        ],
        if (actions.isEmpty &&
            controller.ready &&
            controller.pending == null &&
            controller.role != UserRole.reporter)
          const Text('No hay acciones disponibles para este estado.'),
        if (action != null) ...[
          if (!administrator) ...[
            DropdownButtonFormField<IncidentHistoryAction>(
              key: ValueKey('workflow-action-${action.name}'),
              initialValue: action,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Acción'),
              items: [
                for (final value in actions)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: enabled ? _selectAction : null,
            ),
            const SizedBox(height: 12),
          ],
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
                    child: Text('${technician.fullName} · ${technician.email}'),
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
                    : action == IncidentHistoryAction.reviewRequested
                    ? '¿Qué problema continúa?'
                    : action == IncidentHistoryAction.reviewDismissed
                    ? 'Motivo para cerrar la solicitud'
                    : action == IncidentHistoryAction.assignmentDeclined
                    ? 'Motivo para rechazar la asignación'
                    : 'Motivo obligatorio',
              ),
            ),
            if (action == IncidentHistoryAction.reviewRequested)
              const Text(
                'Administración revisará tu solicitud y decidirá si el caso necesita otra atención.',
              ),
            if (action == IncidentHistoryAction.reviewDismissed)
              const Text(
                'La solicitud se cerrará sin una nueva atención. El motivo quedará visible en el historial.',
              ),
            if (action == IncidentHistoryAction.reopened)
              const Text(
                'La solución anterior quedará en el historial. Se quitarán el técnico y la prioridad para revisar y asignar nuevamente.',
              ),
            if (action == IncidentHistoryAction.assignmentDeclined)
              const Text(
                'La incidencia volverá a administración para asignarla nuevamente. Tu motivo quedará en el historial.',
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        if (administrator && buttons.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: 8, children: buttons),
          )
        else
          ...buttons,
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (controller.role) {
              UserRole.administrator => 'Flujo de atención',
              UserRole.reporter => 'Revisar la solución',
              UserRole.technician => 'Atención y gestión',
            }, style: Theme.of(context).textTheme.titleMedium),
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
            if (step != null) ...[
              _WorkflowSteps(
                current: status == null ? null : step,
                classified:
                    incident?.priority != null &&
                    step != _AdministratorStep.classification,
                assigned:
                    incident?.assignedTechnicianId != null &&
                    step == _AdministratorStep.followUp,
                finished:
                    status == IncidentStatus.closed ||
                    status == IncidentStatus.cancelled ||
                    status == IncidentStatus.rejected,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    for (final child in previous)
                      ExcludeFocus(
                        child: ExcludeSemantics(
                          child: IgnorePointer(child: child),
                        ),
                      ),
                    ?current,
                  ],
                ),
                child: form,
              ),
            ] else
              form,
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

enum _AdministratorStep {
  classification('Clasificar', 'Clasificá la prioridad'),
  assignment('Asignar', 'Asigná un técnico'),
  followUp('Seguimiento', 'Seguimiento y cierre');

  const _AdministratorStep(this.label, this.title);

  final String label;
  final String title;

  static _AdministratorStep forIncident(IncidentWorkflowController controller) {
    if (controller.actions.contains(IncidentHistoryAction.classified)) {
      final categoryId = controller.incident?.categoryId;
      if (controller.actions.contains(IncidentHistoryAction.assigned) &&
          (controller.loadingSources.contains('categories') ||
              controller.categories.any((row) => row.id == categoryId))) {
        return assignment;
      }
      return classification;
    }
    return controller.incident == null ? classification : followUp;
  }

  String instructions(IncidentStatus status) => switch (this) {
    classification =>
      'Confirmá la categoría y la prioridad para pasar a la asignación.',
    assignment => 'Seleccioná el técnico que se encargará de la incidencia.',
    followUp => switch (status) {
      IncidentStatus.assigned =>
        'El técnico asignado aún no inicia la atención.',
      IncidentStatus.inProgress => 'El técnico está atendiendo la incidencia. Podrás cerrarla cuando registre una solución.',
      IncidentStatus.resolved => 'El técnico registró una solución. Revisala antes de cerrar o reabrir la incidencia.',
      _ => status.administratorGuidance,
    },
  };
}

class _WorkflowSteps extends StatelessWidget {
  final _AdministratorStep? current;
  final bool classified;
  final bool assigned;
  final bool finished;

  const _WorkflowSteps({
    required this.current,
    required this.classified,
    required this.assigned,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              for (final step in _AdministratorStep.values)
                Expanded(child: _step(context, step, compact: compact)),
            ],
          );
        },
      ),
    );
  }

  Widget _step(
    BuildContext context,
    _AdministratorStep step, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final complete = switch (step) {
      _AdministratorStep.classification => classified,
      _AdministratorStep.assignment => assigned,
      _AdministratorStep.followUp => finished,
    };
    final active = step == current && !complete;
    final number = step.index + 1;
    final foreground = active
        ? colors.onPrimary
        : complete
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final marker = CircleAvatar(
      radius: 17,
      backgroundColor: active
          ? colors.primary
          : complete
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      foregroundColor: foreground,
      child: complete
          ? const Icon(Icons.check, size: 18)
          : Text('$number', style: TextStyle(color: foreground)),
    );
    final label = Text(
      step.label,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: active ? FontWeight.bold : null,
      ),
    );
    return Semantics(
      selected: active,
      label:
          'Paso $number de 3. ${step.label}${complete ? '. Completado' : ''}',
      excludeSemantics: true,
      child: compact
          ? Column(children: [marker, const SizedBox(height: 6), label])
          : Row(
              children: [
                marker,
                const SizedBox(width: 8),
                Flexible(child: label),
              ],
            ),
    );
  }
}
