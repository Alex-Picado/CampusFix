import 'package:flutter/material.dart';

import '../../core/widgets/page_heading.dart';
import '../../core/widgets/section_card.dart';
import '../navigation/campus_destination.dart';
import '../theme/campus_theme.dart';

/// Shows the prototype landing page and simple module shortcuts.
class OverviewScreen extends StatelessWidget {
  final ValueChanged<CampusDestination> onNavigate;

  const OverviewScreen({super.key, required this.onNavigate});

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
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(CampusDestination.incidents),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Mis incidencias'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(CampusDestination.workspace),
                    icon: const Icon(Icons.handyman_outlined),
                    label: const Text('Mi trabajo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(CampusDestination.profile),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Mi perfil'),
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
        const SizedBox(height: 20),
        const Text(
          'Vista previa: podés recorrer las pantallas. Las funciones pendientes se indican como Próximamente.',
          style: TextStyle(color: CampusTheme.secondaryText),
        ),
      ],
    );
  }
}
