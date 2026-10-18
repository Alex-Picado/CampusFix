import 'package:flutter/material.dart';

import '../../app/theme/campus_theme.dart';

/// Displays a consistent page title and short description.
class PageHeading extends StatelessWidget {
  final String title;
  final String description;

  const PageHeading({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: CampusTheme.secondaryText),
        ),
      ],
    );
  }
}
