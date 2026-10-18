import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/profile_controller.dart';
import '../models/user_profile.dart';
import '../presentation/user_role_labels.dart';

/// Displays the observed profile and delegates name updates to its controller.
class ProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
  }

  /// Refreshes an untouched form without replacing an unsaved or failed draft.
  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasDraft && oldWidget.profile.fullName != widget.profile.fullName) {
      _setName(widget.profile.fullName);
    }
  }

  void _setName(String name) {
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
  }

  /// Reports success only while the same account's form is still mounted.
  Future<void> _save() async {
    final controller = context.read<ProfileController>();
    if (controller.isSaving ||
        !_hasDraft ||
        _name.text.trim() == widget.profile.fullName ||
        !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await controller.updateFullName(_name.text);
    if (!mounted || !success) {
      return;
    }

    setState(() {
      _hasDraft = false;
      _setName(widget.profile.fullName);
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Nombre actualizado.')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final errorMessage = controller.errorMessage;
    var saveLabel = 'Guardar cambios';
    Widget saveIcon = const Icon(Icons.save_outlined);
    VoidCallback? save;
    if (controller.isSaving) {
      saveLabel = 'Guardando...';
      saveIcon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_hasDraft && _name.text.trim() != widget.profile.fullName) {
      save = _save;
    }

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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  enabled: !controller.isSaving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  onChanged: (_) => setState(() => _hasDraft = true),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresá tu nombre completo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _ProfileField(
                  label: 'Correo electrónico',
                  value: widget.profile.email,
                ),
                const SizedBox(height: 20),
                _ProfileField(label: 'Rol', value: widget.profile.role.label),
                const SizedBox(height: 24),
                if (errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('profile-save'),
                    onPressed: save,
                    icon: saveIcon,
                    label: Text(saveLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
