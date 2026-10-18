import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_error_notice.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/password_field.dart';

/// Collects sign-in or registration data and delegates actions to its controller.
///
/// SessionGate handles successful navigation. Form controllers are disposed when
/// this screen is removed, so passwords are not retained across sessions.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _registering = false;

  /// Validates visible inputs and leaves session navigation to SessionGate.
  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    if (_registering) {
      await auth.register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      return;
    }

    await auth.signIn(email: _email.text, password: _password.text);
  }

  /// Clears old validation and password data when switching form modes.
  void _switchMode() {
    context.read<AuthController>().clearError();
    _password.clear();
    _confirmation.clear();
    setState(() {
      _registering = !_registering;
      _formKey = GlobalKey<FormState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    var title = 'Iniciar sesión';
    var description = 'Ingresá para gestionar las incidencias del campus.';
    var switchLabel = '¿No tenés cuenta? Registrate';
    var passwordHints = const [AutofillHints.password];
    var passwordAction = TextInputAction.done;
    if (_registering) {
      title = 'Crear cuenta';
      description = 'Registrate para reportar y dar seguimiento a incidencias.';
      switchLabel = '¿Ya tenés cuenta? Iniciá sesión';
      passwordHints = const [AutofillHints.newPassword];
      passwordAction = TextInputAction.next;
    }

    VoidCallback? switchMode;
    if (!auth.isLoading) {
      switchMode = _switchMode;
    }

    return AuthPage(
      title: title,
      description: description,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_registering) ...[
                TextFormField(
                  key: const ValueKey('auth-name'),
                  controller: _name,
                  enabled: !auth.isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresá tu nombre completo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const ValueKey('auth-email'),
                controller: _email,
                enabled: !auth.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Ingresá un correo electrónico válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const ValueKey('auth-password'),
                controller: _password,
                label: 'Contraseña',
                enabled: !auth.isLoading,
                autofillHints: passwordHints,
                textInputAction: passwordAction,
                onSubmitted: (_) {
                  if (!_registering) {
                    _submit();
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresá tu contraseña.';
                  }
                  if (_registering && value.length < 6) {
                    return 'Usá al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              if (_registering) ...[
                const SizedBox(height: 16),
                PasswordField(
                  key: const ValueKey('auth-confirmation'),
                  controller: _confirmation,
                  label: 'Confirmar contraseña',
                  enabled: !auth.isLoading,
                  autofillHints: const [],
                  onSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirmá tu contraseña.';
                    }
                    if (value != _password.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              AuthErrorNotice(message: auth.errorMessage),
              AuthSubmitButton(
                key: const ValueKey('auth-submit'),
                label: title,
                isLoading: auth.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('auth-switch'),
                onPressed: switchMode,
                child: Text(switchLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}
