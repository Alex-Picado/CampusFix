import 'package:flutter/material.dart';

/// Announces an already translated controller error without exposing exceptions.
class AuthErrorNotice extends StatelessWidget {
  final String? message;

  const AuthErrorNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
