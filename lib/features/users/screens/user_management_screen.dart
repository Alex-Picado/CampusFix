import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/user_management_controller.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../presentation/user_role_labels.dart';
import '../repositories/user_repository.dart';

/// Owns the administrative user query for the lifetime of this screen.
///
/// CampusShell mounts this screen only for an administrator. Leaving the screen,
/// losing that role or changing accounts disposes its controller and observation.
class UserManagementScreen extends StatelessWidget {
  final String currentUserId;

  const UserManagementScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserManagementController>(
      key: ValueKey(currentUserId),
      create: (context) => UserManagementController(
        userRepository: context.read<UserRepository>(),
        currentUserId: currentUserId,
      ),
      child: _UserManagementView(currentUserId: currentUserId),
    );
  }
}

/// Presents controller state and delegates selected roles without copying users.
class _UserManagementView extends StatefulWidget {
  final String currentUserId;

  const _UserManagementView({required this.currentUserId});

  @override
  State<_UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<_UserManagementView> {
  String? _successMessage;

  /// Confirms an acknowledged write only while the same view is still mounted.
  Future<void> _updateRole(UserProfile profile, UserRole? role) async {
    if (!mounted || role == null || role == profile.role) {
      return;
    }

    final controller = context.read<UserManagementController>();
    setState(() => _successMessage = null);
    final success = await controller.updateRole(userId: profile.id, role: role);
    if (!mounted || !success) {
      return;
    }

    setState(() {
      _successMessage = 'Rol de ${profile.fullName} actualizado.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UserManagementController>();
    final loadError = controller.loadErrorMessage;
    final saveError = controller.saveErrorMessage;
    final successMessage = _successMessage;

    return Column(
      key: const ValueKey('users-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Usuarios',
          description:
              'Consultá las cuentas registradas y administrá sus roles.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Elegí un rol para guardar el cambio. Tu cuenta conserva el rol '
          'de administrador.',
        ),
        const SizedBox(height: 24),
        if (controller.isSaving) ...[
          const LinearProgressIndicator(key: ValueKey('users-saving')),
          const SizedBox(height: 8),
          const Text('Guardando rol...'),
          const SizedBox(height: 16),
        ],
        if (saveError != null) ...[
          _UserError(
            key: const ValueKey('users-save-error'),
            message: saveError,
          ),
          const SizedBox(height: 16),
        ],
        if (successMessage != null) ...[
          Semantics(liveRegion: true, child: Text(successMessage)),
          const SizedBox(height: 16),
        ],
        SectionCard(child: _content(context, controller, loadError)),
      ],
    );
  }

  /// Keeps query failures separate from write failures and offers query retry.
  Widget _content(
    BuildContext context,
    UserManagementController controller,
    String? loadError,
  ) {
    if (controller.isLoading) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando usuarios...'),
        ],
      );
    }

    if (loadError != null) {
      VoidCallback? retry;
      if (!controller.isSaving) {
        retry = controller.start;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserError(
            key: const ValueKey('users-load-error'),
            message: loadError,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('users-retry'),
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (controller.users.isEmpty) {
      return const Text('No hay cuentas registradas.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cuentas registradas: ${controller.users.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final profile in controller.users) ...[
          const Divider(height: 24),
          _UserRoleRow(
            key: ValueKey('user-${profile.id}'),
            profile: profile,
            isCurrentUser: profile.id == widget.currentUserId,
            isSaving: controller.isSaving,
            onRoleSelected: (role) => _updateRole(profile, role),
          ),
        ],
      ],
    );
  }
}

/// Arranges identity and a controlled role selector for desktop and tablet.
class _UserRoleRow extends StatelessWidget {
  final UserProfile profile;
  final bool isCurrentUser;
  final bool isSaving;
  final ValueChanged<UserRole?> onRoleSelected;

  const _UserRoleRow({
    super.key,
    required this.profile,
    required this.isCurrentUser,
    required this.isSaving,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    ValueChanged<UserRole?>? selectRole;
    if (!isCurrentUser && !isSaving) {
      selectRole = onRoleSelected;
    }

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(profile.fullName, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(profile.email),
        if (isCurrentUser) ...[
          const SizedBox(height: 4),
          const Text('Tu cuenta'),
        ],
      ],
    );
    final roleSelector = InputDecorator(
      decoration: InputDecoration(
        labelText: 'Rol',
        enabled: selectRole != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          key: ValueKey('user-role-${profile.id}'),
          value: profile.role,
          isExpanded: true,
          isDense: true,
          onChanged: selectRole,
          items: [
            for (final role in UserRole.values)
              DropdownMenuItem(value: role, child: Text(role.label)),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [identity, const SizedBox(height: 16), roleSelector],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 24),
            SizedBox(width: 220, child: roleSelector),
          ],
        );
      },
    );
  }
}

/// Announces translated query or write errors without exposing raw exceptions.
class _UserError extends StatelessWidget {
  final String message;

  const _UserError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
