import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/models/session_status.dart';

/// Keeps a confirmation tied to the account and role that opened it.
Future<bool> showSessionConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  String? cancelLabel,
  Key? cancelKey,
  IconData icon = Icons.info_outline,
}) async {
  final session = context.read<SessionController>();
  final profile = session.profile;
  if (profile == null || session.status != SessionStatus.authenticated) {
    return false;
  }
  final navigator = Navigator.of(context);
  bool valid() =>
      session.status == SessionStatus.authenticated &&
      session.profile?.id == profile.id &&
      session.profile?.role == profile.role;
  late final DialogRoute<bool> route;
  void sessionChanged() {
    if (valid()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!valid() && navigator.mounted && route.isActive) {
        navigator.removeRoute(route, false);
      }
    });
  }

  route = DialogRoute<bool>(
    context: context,
    barrierDismissible: cancelLabel != null,
    builder: (context) => AnimatedBuilder(
      animation: session,
      builder: (context, _) => valid()
          ? PopScope(
              canPop: cancelLabel != null,
              child: AlertDialog(
                icon: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 36,
                ),
                title: Text(title),
                content: Text(message),
                actions: [
                  if (cancelLabel != null)
                    TextButton(
                      key: cancelKey,
                      onPressed: () => navigator.pop(false),
                      child: Text(cancelLabel),
                    ),
                  FilledButton(
                    key: confirmKey,
                    onPressed: () => navigator.pop(true),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
  session.addListener(sessionChanged);
  try {
    return await navigator.push(route) == true && valid();
  } finally {
    session.removeListener(sessionChanged);
  }
}
