import 'package:flutter/material.dart';

import '../../../core/widgets/page_heading.dart';
import '../../../core/widgets/section_card.dart';

/// Gives access and recovery forms a shared, scrollable layout.
class AuthPage extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const AuthPage({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CampusFix')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeading(title: title, description: description),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
