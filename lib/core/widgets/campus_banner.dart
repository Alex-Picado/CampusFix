import 'package:flutter/material.dart';

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
                  const ColoredBox(color: Color(0xFF0C344E)),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xF50C344E),
                    Color(0xAF02477B),
                    Color(0x200C344E),
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
                      color: const Color(0xFF8ED8F8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cuidemos nuestro campus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Cada reporte ayuda a construir un mejor espacio para todos.',
                      style: TextStyle(color: Colors.white),
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
