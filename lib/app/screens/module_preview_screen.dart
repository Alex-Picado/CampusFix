import 'package:flutter/material.dart';

import '../../core/widgets/page_heading.dart';
import '../../core/widgets/section_card.dart';
import '../navigation/campus_destination.dart';
import '../theme/campus_theme.dart';

/// Presents an explicitly pending module without simulating real data.
class ModulePreviewScreen extends StatelessWidget {
  final CampusDestination destination;
  final VoidCallback onBack;

  const ModulePreviewScreen({
    super.key,
    required this.destination,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: destination.label,
          description: destination.description,
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próximamente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Funcionalidad pendiente',
                style: TextStyle(color: CampusTheme.secondaryText),
              ),
              const SizedBox(height: 16),
              for (final capability in destination.capabilities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(capability)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
