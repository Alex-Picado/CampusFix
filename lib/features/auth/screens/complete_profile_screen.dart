import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_error_notice.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_submit_button.dart';

/// Completes the missing profile of an account that is already signed in.
///
/// Retrying invokes completeProfile and never creates a second account.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    await auth.completeProfile(fullName: _name.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    VoidCallback? signOut;
    if (!auth.isLoading) {
      signOut = () => auth.signOut();
    }

    return AuthPage(
      title: 'Completá tu perfil',
      description: 'Tu cuenta ya existe. Guardá tu nombre para continuar.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('complete-profile-name'),
              controller: _name,
              enabled: !auth.isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.name],
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresá tu nombre completo.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthErrorNotice(message: auth.errorMessage),
            AuthSubmitButton(
              key: const ValueKey('complete-profile-submit'),
              label: 'Guardar y continuar',
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: signOut, child: const Text('Cerrar sesión')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
