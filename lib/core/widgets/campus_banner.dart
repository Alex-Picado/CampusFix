import 'package:material_ui/material_ui.dart';

import '../../app/theme/campus_palette.dart';

class CampusBanner extends StatelessWidget {
  final bool compact;
  const CampusBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 140 : 170),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/campus-ucr.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              semanticLabel:
                  'Edificio de nuestra sede de la Universidad de Costa Rica',
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: CampusPalette.navy),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0, 0.55, 1],
                  colors: [
                    CampusPalette.navy,
                    CampusPalette.navy.withValues(alpha: 0.92),
                    CampusPalette.navy.withValues(
                      alpha: MediaQuery.sizeOf(context).width < 650
                          ? 0.84
                          : 0.42,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'UNIVERSIDAD DE COSTA RICA',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CampusPalette.sky,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cuidemos nuestro campus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CampusPalette.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Cada reporte ayuda a construir un mejor espacio para todos.',
                      style: TextStyle(color: CampusPalette.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
