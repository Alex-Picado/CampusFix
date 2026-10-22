import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../../users/models/user_role.dart';
import '../controllers/category_management_controller.dart';
import '../repositories/category_repository.dart';

/// Presents catalog administration and owns its session-bound controller.
class CategoryManagementScreen extends StatelessWidget {
  /// Creates the administrative screen; access also requires Firestore rules.
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    if (profile == null || profile.role != UserRole.administrator) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey('categories:${profile.id}'),
      create: (_) => CategoryManagementController(
        repository: context.read<CategoryRepository>(),
        session: session,
        uid: profile.id,
      ),
      child: const _CategoryManagementView(),
    );
  }
}

class _CategoryManagementView extends StatelessWidget {
  const _CategoryManagementView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CategoryManagementController>();
    if (!controller.active) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('categories-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          title: 'Categorías',
          description:
              'Organizá las categorías disponibles para reportar incidencias.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Desactivar una categoría conserva las incidencias anteriores '
          'y evita seleccionarla en nuevos reportes.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.editingId == null
                    ? 'Nueva categoría'
                    : 'Editar categoría',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey('category-name-${controller.editorVersion}'),
                initialValue: controller.draftName,
                enabled: controller.canEdit,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                ),
                onChanged: controller.setName,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('category-save'),
                    onPressed: controller.canEdit ? controller.save : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      controller.editingId == null
                          ? 'Crear categoría'
                          : 'Guardar cambios',
                    ),
                  ),
                  if (controller.editingId != null)
                    OutlinedButton(
                      key: const ValueKey('category-cancel'),
                      onPressed: controller.canEdit
                          ? controller.cancelEdit
                          : null,
                      child: const Text('Cancelar edición'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (controller.isSaving) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const Text('Guardando categoría...'),
        ],
        if (controller.saveError != null) ...[
          const SizedBox(height: 16),
          _Notice(message: controller.saveError!, isError: true),
        ],
        if (controller.success != null) ...[
          const SizedBox(height: 16),
          _Notice(message: controller.success!),
        ],
        const SizedBox(height: 24),
        if (controller.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (controller.loadError != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Notice(message: controller.loadError!, isError: true),
                TextButton(
                  key: const ValueKey('categories-retry'),
                  onPressed: controller.isSaving ? null : controller.start,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (controller.categories.isEmpty)
          const SectionCard(child: Text('No hay categorías registradas.'))
        else
          for (final category in controller.categories)
            Padding(
              key: ValueKey('category-${category.id}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            category.isActive ? 'Activa' : 'Inactiva',
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('category-edit-${category.id}'),
                          onPressed: controller.canEdit
                              ? () => controller.edit(category)
                              : null,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        Semantics(
                          label:
                              '${category.isActive ? 'Desactivar' : 'Activar'} ${category.name}',
                          child: Switch(
                            key: ValueKey('category-active-${category.id}'),
                            value: category.isActive,
                            onChanged: controller.canEdit
                                ? (value) =>
                                      controller.setActive(category, value)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final String message;
  final bool isError;
  const _Notice({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: isError
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    ),
  );
}
