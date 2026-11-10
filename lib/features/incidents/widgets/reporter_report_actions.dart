import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/session_confirmation_dialog.dart';
import '../../auth/controllers/session_controller.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../controllers/incident_workflow_controller.dart';
import '../models/incident.dart';
import '../models/incident_history_action.dart';
import '../models/incident_workflow.dart';
import '../repositories/incident_repository.dart';

/// Reporter-only withdrawal controls shared by the list and protected detail.
class ReporterReportActions extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onRemoved;

  const ReporterReportActions({
    super.key,
    required this.incident,
    this.onRemoved,
  });

  Future<void> _open(BuildContext context, IncidentHistoryAction action) async {
    final session = context.read<SessionController>();
    final profile = session.profile;
    if (profile == null) return;
    final saved = await showSessionDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => IncidentWorkflowController(
          repository: context.read<IncidentRepository>(),
          categoryRepository: context.read<CategoryRepository>(),
          userRepository: context.read<UserRepository>(),
          session: session,
          uid: profile.id,
          role: profile.role,
          incidentId: incident.id,
        ),
        child: _ReporterActionForm(
          action: action,
          number: incident.sequenceNumber,
        ),
      ),
    );
    if (saved == true &&
        context.mounted &&
        action == IncidentHistoryAction.removedFromList) {
      onRemoved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SessionController>().profile;
    if (profile == null || profile.role != UserRole.reporter) {
      return const SizedBox.shrink();
    }
    final actions = IncidentWorkflow.actions(
      incident,
      profile.role,
      profile.id,
    );
    if (!actions.contains(IncidentHistoryAction.removedFromList)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (actions.contains(IncidentHistoryAction.cancelled))
            OutlinedButton.icon(
              key: ValueKey('report-cancel-${incident.id}'),
              onPressed: () => _open(context, IncidentHistoryAction.cancelled),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar reporte'),
            ),
          TextButton.icon(
            key: ValueKey('report-remove-${incident.id}'),
            onPressed: () =>
                _open(context, IncidentHistoryAction.removedFromList),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar de mi lista'),
          ),
        ],
      ),
    );
  }
}

class _ReporterActionForm extends StatefulWidget {
  final IncidentHistoryAction action;
  final int number;
  const _ReporterActionForm({required this.action, required this.number});
  @override
  State<_ReporterActionForm> createState() => _ReporterActionFormState();
}

class _ReporterActionFormState extends State<_ReporterActionForm> {
  final _reason = TextEditingController();
  bool get removing => widget.action == IncidentHistoryAction.removedFromList;

  Future<void> _submit() async {
    final controller = context.read<IncidentWorkflowController>();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    FocusScope.of(context).unfocus();
    final saved = controller.pending != null
        ? await controller.retry()
        : await controller.submit(
            widget.action,
            reason: removing
                ? 'Reporte eliminado de mi lista por el reportante.'
                : _reason.text,
          );
    if (!mounted || !controller.active || !saved || route?.isCurrent != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removing
              ? 'Reporte eliminado de tu lista. Su historial se conserva.'
              : 'Reporte cancelado. Podés consultarlo en Finalizadas.',
        ),
      ),
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentWorkflowController>();
    final hasPending = controller.pending != null;
    final canSubmit =
        controller.active &&
        !controller.saving &&
        (hasPending ||
            (controller.ready && controller.actions.contains(widget.action)));
    final active =
        controller.incident != null &&
        !IncidentWorkflow.isFinal(controller.incident!.status);
    return AlertDialog(
      scrollable: true,
      icon: Icon(
        removing ? Icons.delete_outline : Icons.cancel_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(
        '${removing ? 'Eliminar' : 'Cancelar'} reporte #${widget.number}',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.loadingSources.isNotEmpty)
              const LinearProgressIndicator(),
            Text(
              removing
                  ? '${active ? 'Se cancelará el reporte y se detendrá su atención. ' : ''}'
                        'Se quitará de Mis incidencias y de tus indicadores. '
                        'Administración conservará el reporte y su historial.'
                  : 'Se detendrá la atención de este reporte. '
                        'Podrás consultarlo en Finalizadas y su historial se conservará.',
            ),
            if (!removing) ...[
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('report-withdraw-reason'),
                controller: _reason,
                enabled: !controller.saving && !hasPending,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación',
                ),
              ),
            ],
            if (controller.readError != null) ...[
              Text(controller.readError!),
              TextButton(
                onPressed: controller.start,
                child: const Text('Reintentar lectura'),
              ),
            ],
            if (controller.saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (controller.ready &&
                !hasPending &&
                !controller.actions.contains(widget.action))
              const Text(
                'El reporte cambió. Volvé a la lista para revisar su estado.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('report-withdraw-back'),
          onPressed: controller.saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const ValueKey('report-withdraw-confirm'),
          onPressed: canSubmit ? _submit : null,
          child: Text(
            controller.saving
                ? 'Guardando…'
                : hasPending
                ? 'Reintentar el mismo cambio'
                : removing
                ? 'Eliminar de mi lista'
                : 'Cancelar reporte',
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }
}
