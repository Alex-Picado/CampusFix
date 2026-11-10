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
  return await showSessionDialog<bool>(
        context: context,
        barrierDismissible: cancelLabel != null,
        builder: (context) => AlertDialog(
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
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            FilledButton(
              key: confirmKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ==
      true;
}

/// Hides private dialog content and removes only its route on account changes.
Future<T?> showSessionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final session = context.read<SessionController>();
  final profile = session.profile;
  if (profile == null || session.status != SessionStatus.authenticated) {
    return null;
  }
  final navigator = Navigator.of(context);
  bool valid() =>
      session.status == SessionStatus.authenticated &&
      session.profile?.id == profile.id &&
      session.profile?.role == profile.role;
  late final DialogRoute<T> route;
  void sessionChanged() {
    if (valid()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!valid() && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  route = DialogRoute<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AnimatedBuilder(
      animation: session,
      builder: (context, _) => valid()
          ? PopScope(
              canPop: barrierDismissible,
              child: Builder(builder: builder),
            )
          : const SizedBox.shrink(),
    ),
  );
  session.addListener(sessionChanged);
  try {
    final result = await navigator.push(route);
    return valid() ? result : null;
  } finally {
    session.removeListener(sessionChanged);
  }
}
