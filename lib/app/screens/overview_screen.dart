import 'package:flutter/material.dart';

import '../../core/widgets/page_heading.dart';
import '../../core/widgets/section_card.dart';
import '../navigation/campus_destination.dart';

/// Shows the landing page and shortcuts available to the current role.
class OverviewScreen extends StatelessWidget {
  final ValueChanged<CampusDestination> onNavigate;
  final List<CampusDestination> destinations;

  const OverviewScreen({
    super.key,
    required this.onNavigate,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Inicio',
          description: 'Gestión de incidencias del campus.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accesos rápidos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final destination
                      in destinations
                          .where((item) => item != CampusDestination.overview)
                          .take(3))
                    OutlinedButton.icon(
                      onPressed: () => onNavigate(destination),
                      icon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cómo funciona?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text('1. Reportá el problema e indicá dónde ocurre.'),
              const SizedBox(height: 8),
              const Text('2. Consultá su estado y los avances registrados.'),
              const SizedBox(height: 8),
              const Text(
                '3. Da seguimiento a la solución y al cierre del reporte.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
