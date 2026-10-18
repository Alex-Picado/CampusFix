import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/models/session_status.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/auth/screens/session_failure_screen.dart';
import 'campus_shell.dart';

/// Selects the visible screen from authentication and profile observation.
///
/// Never mounts the private shell until a profile is available. Account changes
/// replace the shell's state, and signing out removes its private widgets.
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    switch (session.status) {
      case SessionStatus.signedOut:
        return const AuthScreen();
      case SessionStatus.profileRequired:
        return const CompleteProfileScreen();
      case SessionStatus.failure:
        return const SessionFailureScreen();
      case SessionStatus.authenticated:
        final profile = session.profile;
        if (profile != null) {
          return CampusShell(key: ValueKey(profile.id), profile: profile);
        }
        return const _SessionLoadingScreen();
      case SessionStatus.loading:
        return const _SessionLoadingScreen();
    }
  }
}

/// Hides private content while authentication or the profile is loading.
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando sesión...'),
          ],
        ),
      ),
    );
  }
}
