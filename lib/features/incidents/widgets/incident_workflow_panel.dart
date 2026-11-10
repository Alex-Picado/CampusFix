import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/session_confirmation_dialog.dart';
import '../../auth/controllers/session_controller.dart';
import '../../users/models/user_role.dart';
import '../controllers/incident_workflow_controller.dart';
import '../models/incident_history_action.dart';
import '../models/incident_priority.dart';
import '../models/incident_status.dart';
import '../models/incident_workflow.dart';
import '../presentation/incident_action_labels.dart';
import '../presentation/incident_status_labels.dart';
import 'workflow_action_option.dart';

/// Displays a lifecycle form using the detail page's shared workflow controller.
class IncidentWorkflowPanel extends StatelessWidget {
  final String incidentId;
  final bool blocked;
  final bool administrativeActions;
  const IncidentWorkflowPanel({
    super.key,
    required this.incidentId,
    this.blocked = false,
    this.administrativeActions = false,
  });
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    return _WorkflowForm(
      blocked: blocked,
      administrativeActions: administrativeActions,
    );
  }
}

class _WorkflowForm extends StatefulWidget {
  final bool blocked;
  final bool administrativeActions;
  const _WorkflowForm({
    required this.blocked,
    required this.administrativeActions,
  });
  @override
  State<_WorkflowForm> createState() => _WorkflowFormState();
}

class _WorkflowFormState extends State<_WorkflowForm> {
  final _reason = TextEditingController();
  IncidentHistoryAction? _action;
  IncidentStatus? _selectionStatus;
  String? _categoryId;
  String? _technicianId;
  final _technicianQueue = <String>[];
  bool _editingClassification = false;
  IncidentPriority? _priority;
  _AdministratorStep? _submittedStep;
  bool _confirmingResolution = false;
  bool _awaitingDraftReset = false;

  void _selectAction(IncidentHistoryAction action) {
    final status = context.read<IncidentWorkflowController>().incident?.status;
    if (_action == action &&
        _selectionStatus == status &&
        context.read<IncidentWorkflowController>().selectedAction == action) {
      return;
    }
    setState(() {
      _action = action;
      _selectionStatus = status;
      _reason.clear();
    });
    context.read<IncidentWorkflowController>().selectAction(action);
  }

  void _resetDraft() => setState(() {
    _reason.clear();
    _action = null;
    _selectionStatus = null;
    _categoryId = null;
    _priority = null;
    _technicianId = null;
    _technicianQueue.clear();
    _editingClassification = false;
    _awaitingDraftReset = false;
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    if (!controller.active) return const SizedBox.shrink();
    if (_awaitingDraftReset && !controller.awaitingUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _awaitingDraftReset &&
            controller.active &&
            !controller.awaitingUpdate) {
          _resetDraft();
        }
      });
    }
    final allActions = controller.actions
        .where(
          (action) =>
              controller.role != UserRole.reporter ||
              (action != IncidentHistoryAction.cancelled &&
                  action != IncidentHistoryAction.removedFromList),
        )
        .toList();
    const destructive = [
      IncidentHistoryAction.rejected,
      IncidentHistoryAction.cancelled,
    ];
    final actions = allActions
        .where(
          (action) =>
              controller.role != UserRole.administrator ||
              widget.administrativeActions == destructive.contains(action),
        )
        .toList();
    if (widget.administrativeActions &&
        actions.isEmpty &&
        controller.pending == null) {
      return const SizedBox.shrink();
    }
    if (controller.role == UserRole.reporter &&
        actions.isEmpty &&
        controller.loadingSources.isEmpty &&
        controller.readError == null &&
        controller.saveError == null &&
        controller.success == null &&
        controller.pending == null) {
      return const SizedBox.shrink();
    }
    final administrator =
        controller.role == UserRole.administrator &&
        !widget.administrativeActions;
    final incident = controller.incident;
    final status = controller.pending?.expectedStatus ?? incident?.status;
    final step = administrator
        ? (controller.pending == null ? null : _submittedStep) ??
              (_editingClassification &&
                      allActions.contains(IncidentHistoryAction.classified)
                  ? _AdministratorStep.classification
                  : _AdministratorStep.forIncident(controller))
        : null;
    final preferredAction = switch (step) {
      _AdministratorStep.classification => IncidentHistoryAction.classified,
      _AdministratorStep.assignment => IncidentHistoryAction.assigned,
      _AdministratorStep.followUp => IncidentHistoryAction.closed,
      null => actions.firstOrNull,
    };
    final primary = actions.contains(preferredAction) ? preferredAction : null;
    final ownsPending =
        controller.pending != null &&
        (controller.role != UserRole.administrator ||
            widget.administrativeActions ==
                destructive.contains(controller.pending!.action));
    final ownsFeedback =
        controller.role != UserRole.administrator ||
        widget.administrativeActions ==
            destructive.contains(controller.selectedAction);
    final action = ownsPending
        ? controller.pending!.action
        : actions.contains(_action) &&
              _selectionStatus == status &&
              controller.selectedAction == _action
        ? _action
        : null;
    final enabled =
        !_confirmingResolution &&
        !widget.blocked &&
        controller.ready &&
        !controller.saving &&
        controller.pending == null &&
        !controller.awaitingUpdate;
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
      if (ownsPending)
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
                  if (saved && mounted) {
                    if (controller.awaitingUpdate) {
                      setState(() => _awaitingDraftReset = true);
                    } else {
                      _resetDraft();
                    }
                  }
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
                  if (action == IncidentHistoryAction.resolved &&
                      _reason.text.trim().isNotEmpty) {
                    final before = controller.incident!;
                    FocusScope.of(context).unfocus();
                    setState(() => _confirmingResolution = true);
                    final confirmed = await showSessionConfirmationDialog(
                      context: context,
                      title: '¿Resolver esta incidencia?',
                      message: 'Al resolverla ya no podrás registrar avances ni continuar la atención. Solo podrás retomarla si administración la reabre y te la vuelve a asignar.\n\nVerificá que terminaste el trabajo y que la solución está completa.',
                      confirmLabel: 'Sí, resolver incidencia',
                      confirmKey: const ValueKey('resolution-confirm'),
                      cancelLabel: 'Seguir atendiendo',
                      cancelKey: const ValueKey('resolution-cancel'),
                      icon: Icons.fact_check_outlined,
                    );
                    if (!mounted || !context.mounted) return;
                    setState(() => _confirmingResolution = false);
                    if (!confirmed || !controller.active) return;
                    if (widget.blocked ||
                        controller.incident?.updatedAt != before.updatedAt ||
                        !controller.actions.contains(action)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La incidencia cambió. Revisá su estado antes de resolverla.',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  if (!context.mounted) return;
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
                    technicianQueue: action == IncidentHistoryAction.assigned
                        ? _technicianQueue
                        : const [],
                    reason: needsReason ? _reason.text : null,
                  );
                  if (saved && mounted) {
                    if (controller.awaitingUpdate) {
                      setState(() => _awaitingDraftReset = true);
                    } else {
                      _resetDraft();
                    }
                  }
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
            IncidentHistoryAction.resolved => 'Confirmar resolución',
            IncidentHistoryAction.assignmentDeclined => 'Confirmar rechazo',
            _ => 'Confirmar: ${action.label}',
          }),
        ),
    ];
    final form = Column(
      key: ValueKey(step),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step == _AdministratorStep.assignment &&
            allActions.contains(IncidentHistoryAction.classified)) ...[
          TextButton.icon(
            key: const ValueKey('workflow-back-classification'),
            onPressed: enabled
                ? () {
                    setState(() => _editingClassification = true);
                    _selectAction(IncidentHistoryAction.classified);
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a clasificación'),
          ),
          const SizedBox(height: 8),
        ],
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
        if (actions.isNotEmpty) ...[
          Text(
            'Elegí una opción',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Después completá los datos y confirmá con el botón de abajo.',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final value in [
                    ?primary,
                    ...actions.where(
                      (value) =>
                          value != primary &&
                          !(administrator &&
                              step == _AdministratorStep.assignment &&
                              value == IncidentHistoryAction.classified) &&
                          !(administrator &&
                              step == _AdministratorStep.classification &&
                              value == IncidentHistoryAction.assigned),
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: WorkflowActionOption(
                        key: ValueKey('workflow-option-${value.name}'),
                        action: value,
                        label: value.label,
                        selected: action == value,
                        onSelected: enabled ? () => _selectAction(value) : null,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (action == null)
            const Text('Seleccioná una opción para continuar.'),
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
          if (action == IncidentHistoryAction.assigned) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('workflow-technician-$selectedTechnician'),
              initialValue: selectedTechnician,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Técnico principal'),
              items: [
                for (final technician in controller.technicians)
                  DropdownMenuItem(
                    value: technician.id,
                    child: Text('${technician.fullName} · ${technician.email}'),
                  ),
              ],
              onChanged: enabled
                  ? (value) => setState(() {
                      _technicianId = value;
                      _technicianQueue.remove(value);
                    })
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Suplentes en orden de atención',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Si el técnico rechaza, se asignará al siguiente activo. Podés añadir hasta cuatro suplentes.',
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _technicianQueue.length; index++)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 2}')),
                  title: Text(
                    controller.technicians
                            .where((user) => user.id == _technicianQueue[index])
                            .firstOrNull
                            ?.fullName ??
                        'Técnico no disponible',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Subir en la cola',
                        onPressed: enabled && index > 0
                            ? () => setState(() {
                                final id = _technicianQueue.removeAt(index);
                                _technicianQueue.insert(index - 1, id);
                              })
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Quitar suplente',
                        onPressed: enabled
                            ? () => setState(
                                () => _technicianQueue.removeAt(index),
                              )
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'workflow-add-backup-${_technicianQueue.join(',')}-$selectedTechnician',
              ),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Añadir técnico suplente',
              ),
              items: [
                for (final user in controller.technicians.where(
                  (user) =>
                      user.id != selectedTechnician &&
                      !_technicianQueue.contains(user.id),
                ))
                  DropdownMenuItem(
                    value: user.id,
                    child: Text('${user.fullName} · ${user.email}'),
                  ),
              ],
              onChanged:
                  enabled &&
                      selectedTechnician != null &&
                      _technicianQueue.length <
                          IncidentWorkflow.maxBackupTechnicians
                  ? (id) {
                      if (id != null) setState(() => _technicianQueue.add(id));
                    }
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
                'La respuesta quedará en el historial. El reportante deberá aceptar la solución antes del cierre.',
              ),
            if (action == IncidentHistoryAction.reopened)
              const Text(
                'La solución anterior quedará en el historial. Se quitarán el técnico y la prioridad para revisar y asignar nuevamente.',
              ),
            if (action == IncidentHistoryAction.assignmentDeclined)
              const Text(
                'Se asignará al siguiente suplente activo. Si no quedan suplentes, volverá a revisión administrativa. Tu motivo quedará en el historial.',
              ),
          ],
        ],
        if (ownsFeedback && controller.saveError != null)
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
        if (ownsFeedback && controller.success != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(controller.success!),
            ),
          ),
        const SizedBox(height: 12),
        if (buttons.isNotEmpty)
          Wrap(spacing: 12, runSpacing: 12, children: buttons),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.administrativeActions
                  ? 'Acciones del reporte'
                  : switch (controller.role) {
                      UserRole.administrator => 'Flujo de atención',
                      UserRole.reporter => 'Revisar la solución',
                      UserRole.technician =>
                        status == IncidentStatus.inProgress
                            ? 'Atención y resolución'
                            : 'Atención y gestión',
                    },
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (widget.blocked)
              const Text(
                'Terminá de guardar el avance pendiente antes de resolver la incidencia.',
              ),
            if (status == IncidentStatus.resolved &&
                incident?.technicianApproved == false)
              const Text(
                'Esta solución anterior todavía no tiene confirmación del técnico. Administración debe reabrirla para registrar una solución con el nuevo flujo de conformidad.',
              ),
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
      IncidentStatus.resolved => 'Revisá la solución y aprobá el cierre. Solo se cerrará cuando también la acepte el reportante.',
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
