import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/session_controller.dart';
import '../widgets/auth_error_notice.dart';
import '../widgets/auth_page.dart';
import '../widgets/auth_submit_button.dart';

/// Offers recovery when session or profile observation fails.
class SessionFailureScreen extends StatelessWidget {
  const SessionFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final auth = context.watch<AuthController>();
    VoidCallback? signOut;
    if (!auth.isLoading) {
      signOut = () => auth.signOut();
    }

    return AuthPage(
      title: 'No pudimos cargar tu sesión',
      description: 'Podés intentar nuevamente o cerrar sesión.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthErrorNotice(message: session.errorMessage),
          AuthErrorNotice(message: auth.errorMessage),
          AuthSubmitButton(
            key: const ValueKey('session-retry'),
            label: 'Reintentar',
            isLoading: auth.isLoading,
            onPressed: session.start,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: signOut, child: const Text('Cerrar sesión')),
        ],
      ),
    );
  }
}
