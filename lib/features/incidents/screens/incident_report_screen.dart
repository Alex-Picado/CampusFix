import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../controllers/incident_report_controller.dart';
import '../repositories/incident_repository.dart';

/// Owns a report controller while the original reporter's form is mounted.
class IncidentReportScreen extends StatelessWidget {
  final String userId;
  final VoidCallback onBack;

  const IncidentReportScreen({
    super.key,
    required this.userId,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != SessionStatus.authenticated ||
        session.profile?.id != userId ||
        session.profile?.role != UserRole.reporter) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey(userId),
      create: (context) => IncidentReportController(
        incidentRepository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        sessionController: session,
        userId: userId,
      ),
      child: _ReportForm(onBack: onBack),
    );
  }
}

/// Presents controller state without retaining a separate submission payload.
class _ReportForm extends StatefulWidget {
  final VoidCallback onBack;

  const _ReportForm({required this.onBack});

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  late final IncidentReportController _controller;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    _controller = context.read<IncidentReportController>();
    _title = TextEditingController(text: _controller.draft.title);
    _description = TextEditingController(text: _controller.draft.description);
    _location = TextEditingController(text: _controller.draft.location);
    _controller.addListener(_syncDraft);
  }

  /// Applies confirmation, reset and session cleanup without replacing typing.
  void _syncDraft() {
    for (final (field, text) in [
      (_title, _controller.draft.title),
      (_description, _controller.draft.description),
      (_location, _controller.draft.location),
    ]) {
      if (field.text != text) {
        field.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  /// Delegates submission; success feedback comes only from confirmed state.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await _controller.submit();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentReportController>();
    if (!controller.isActive) return const SizedBox.shrink();
    final loadError = controller.loadErrorMessage;
    final submitError = controller.submitErrorMessage;
    final success = controller.successMessage;

    return ConstrainedBox(
      key: const ValueKey('report-page'),
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Crear incidencia',
            description: 'Describí el problema e indicá dónde ocurre.',
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField('title', 'Título', _title),
                const SizedBox(height: 20),
                _textField(
                  'description',
                  'Descripción',
                  _description,
                  lines: 4,
                ),
                const SizedBox(height: 20),
                _categoryField(controller),
                const SizedBox(height: 20),
                _textField('location', 'Ubicación', _location),
                if (controller.isLoadingCategories) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    key: ValueKey('report-categories-loading'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Cargando categorías...'),
                ] else if (loadError != null ||
                    controller.categories.isEmpty) ...[
                  const SizedBox(height: 16),
                  _feedback(
                    loadError ?? 'No hay categorías activas. Intentá nuevamente más tarde.',
                    error: loadError != null,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('report-retry-categories'),
                      onPressed: controller.isBusy
                          ? null
                          : controller.startCategories,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar categorías'),
                    ),
                  ),
                ],
                if (submitError != null) ...[
                  const SizedBox(height: 16),
                  _feedback(submitError, error: true),
                ],
                if (success != null) ...[
                  const SizedBox(height: 16),
                  _feedback(success),
                ] else if (controller.hasUnconfirmedSubmission &&
                    !controller.isSubmitting) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo confirmar el guardado. Podés reintentarlo. '
                    'Antes de editar, comprobaremos si la incidencia ya se guardó.',
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (success != null)
                      FilledButton.icon(
                        key: const ValueKey('report-new'),
                        onPressed: controller.resetDraft,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear otra incidencia'),
                      )
                    else
                      FilledButton.icon(
                        key: const ValueKey('report-submit'),
                        onPressed: controller.canSubmit ? _submit : null,
                        icon: controller.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          controller.isSubmitting
                              ? 'Guardando...'
                              : controller.hasUnconfirmedSubmission
                              ? 'Reintentar guardado'
                              : 'Guardar incidencia',
                        ),
                      ),
                    if (controller.hasUnconfirmedSubmission &&
                        !controller.isSubmitting)
                      OutlinedButton(
                        key: const ValueKey('report-edit'),
                        onPressed: controller.canResumeEditing
                            ? controller.resumeEditing
                            : null,
                        child: Text(
                          controller.isReviewing
                              ? 'Comprobando...'
                              : 'Editar datos',
                        ),
                      ),
                    TextButton(
                      key: const ValueKey('report-back'),
                      onPressed: widget.onBack,
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows errors from controller validation while retaining raw text input.
  Widget _textField(
    String name,
    String label,
    TextEditingController field, {
    int lines = 1,
  }) {
    return TextField(
      key: ValueKey('report-$name'),
      controller: field,
      readOnly: !_controller.canEditDraft,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        errorText: _controller.fieldErrors[name],
      ),
      onChanged: (value) {
        switch (name) {
          case 'title':
            _controller.updateDraft(title: value);
          case 'description':
            _controller.updateDraft(description: value);
          case 'location':
            _controller.updateDraft(location: value);
        }
      },
    );
  }

  /// Preserves the category label while a submission is locked or loading.
  Widget _categoryField(IncidentReportController controller) {
    final selectable =
        controller.canEditDraft &&
        !controller.isLoadingCategories &&
        controller.loadErrorMessage == null &&
        controller.categories.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Categoría',
        errorText: controller.fieldErrors['categoryId'],
      ),
      child: selectable
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('report-category'),
                isExpanded: true,
                isDense: true,
                value: controller.draft.categoryId,
                hint: const Text('Seleccioná una categoría'),
                items: [
                  for (final category in controller.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (id) => controller.updateDraft(categoryId: id),
              ),
            )
          : Text(
              controller.selectedCategoryName ?? 'Sin categoría seleccionada',
            ),
    );
  }

  /// Announces operation feedback without displaying technical exceptions.
  Widget _feedback(String message, {bool error = false}) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: error
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    ),
  );

  @override
  void dispose() {
    _controller.removeListener(_syncDraft);
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }
}
