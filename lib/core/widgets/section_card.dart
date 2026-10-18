import 'package:flutter/material.dart';

import '../../app/theme/campus_theme.dart';

/// Provides a simple bordered surface for related page content.
class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CampusTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
