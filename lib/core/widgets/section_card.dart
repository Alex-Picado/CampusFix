import 'package:flutter/material.dart';

/// Provides a simple bordered surface for related page content.
class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
