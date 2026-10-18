import 'package:flutter/material.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../models/user_profile.dart';
import '../presentation/user_role_labels.dart';

/// Displays the observed profile without exposing profile editing controls yet.
class ProfileScreen extends StatelessWidget {
  final UserProfile profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('profile-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Mi perfil',
          description: 'Información de tu cuenta.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileField(label: 'Nombre completo', value: profile.fullName),
              const SizedBox(height: 20),
              _ProfileField(label: 'Correo electrónico', value: profile.email),
              const SizedBox(height: 20),
              _ProfileField(label: 'Rol', value: profile.role.label),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('La actualización del nombre todavía está pendiente.'),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    );
  }
}
