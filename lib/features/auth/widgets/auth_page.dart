import 'package:flutter/material.dart';

import '../../../core/widgets/page_heading.dart';

/// Shared, responsive UCR identity for sign-in, registration and recovery.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071A28) : const Color(0xFFEEF5FA),
      body: SafeArea(
        child: Column(
          children: [
            const _UniversityHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final wide = viewport.maxWidth >= 960;
                  final form = Container(
                    padding: EdgeInsets.all(wide ? 40 : 24),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF102B3D) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF26475D)
                            : const Color(0xFFD8E5EE),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF173E56)
                                    : const Color(0xFFE4F7FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                color: dark
                                    ? const Color(0xFF8ED8F8)
                                    : const Color(0xFF02477B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'CampusFix',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        PageHeading(title: title, description: description),
                        const SizedBox(height: 28),
                        child,
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Un campus mejor empieza con vos.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(wide ? 40 : 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: _CampusIdentity(
                                          height: (viewport.maxHeight - 80)
                                              .clamp(650.0, 900.0),
                                        ),
                                      ),
                                      const SizedBox(width: 40),
                                      Expanded(flex: 5, child: form),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _CampusIdentity(
                                        height: 340,
                                        compact: true,
                                      ),
                                      const SizedBox(height: 20),
                                      form,
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UniversityHeader extends StatelessWidget {
  const _UniversityHeader();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: const BoxDecoration(
      color: Color(0xFF0C344E),
      border: Border(top: BorderSide(color: Color(0xFF00C0F3), width: 5)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF00C0F3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'UCR',
            style: TextStyle(
              color: Color(0xFF0C344E),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Universidad de Costa Rica',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 800) ...[
          const SizedBox(width: 16),
          const Text(
            'GESTIÓN DE INCIDENCIAS DEL CAMPUS',
            style: TextStyle(
              color: Color(0xFF8ED8F8),
              letterSpacing: 1.3,
              fontSize: 11,
            ),
          ),
        ],
      ],
    ),
  );
}

class _CampusIdentity extends StatelessWidget {
  final double height;
  final bool compact;
  const _CampusIdentity({required this.height, this.compact = false});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/campus-ucr.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.25, 0),
            semanticLabel: 'Mural del girasol en la Universidad de Costa Rica',
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF02477B)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.4, 1],
                colors: [
                  Color(0x300C344E),
                  Color(0x550C344E),
                  Color(0xFA0C344E),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0C344E),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'NUESTRO CAMPUS · NUESTRA COMUNIDAD',
                    style: TextStyle(
                      color: Color(0xFF8ED8F8),
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Cuidemos\nnuestro campus.',
                  style: TextStyle(
                    fontSize: compact ? 32 : 46,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  compact
                      ? 'Reportá. Dale seguimiento. Seamos parte de la solución.'
                      : 'Conectamos a nuestra comunidad para reportar, atender y resolver los problemas del campus.',
                  style: TextStyle(
                    fontSize: compact ? 14 : 18,
                    height: 1.5,
                    color: const Color(0xFFE2F3FA),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 28),
                  const Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _Feature(Icons.edit_location_alt_outlined, 'Reportá'),
                      _Feature(Icons.timeline_outlined, 'Dale seguimiento'),
                      _Feature(Icons.handyman_outlined, 'Resolvé'),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Mural del girasol · Sede Rodrigo Facio',
                    style: TextStyle(color: Color(0xFFBAD2ED), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFF00C0F3), size: 20),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ],
  );
}
