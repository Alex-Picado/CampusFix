import 'package:flutter/material.dart';

/// Disables duplicate submissions and shows a shared progress indicator.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    VoidCallback? action;
    var text = label;
    if (!isLoading) {
      action = onPressed;
    } else {
      text = 'Procesando...';
    }

    return FilledButton(
      onPressed: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}
