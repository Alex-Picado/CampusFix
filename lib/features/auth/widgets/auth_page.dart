import 'package:material_ui/material_ui.dart';

import '../../../app/theme/campus_palette.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
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
                      color: theme.brightness == Brightness.dark
                          ? colors.surfaceContainerLow
                          : colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor),
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
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'CampusFix',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
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
                                      form,
                                      const SizedBox(height: 20),
                                      const _CampusIdentity(
                                        height: 300,
                                        compact: true,
                                      ),
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 8 : 12,
      ),
      decoration: const BoxDecoration(
        color: CampusPalette.navy,
        border: Border(top: BorderSide(color: CampusPalette.cyan, width: 4)),
      ),
      child: Image.asset(
        'assets/images/ucr-logo-dark.png',
        width: compact ? 146 : 160,
        height: compact ? 72 : 80,
        fit: BoxFit.contain,
        semanticLabel: 'Universidad de Costa Rica',
      ),
    );
  }
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
            'assets/images/campus-ucr.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            semanticLabel:
                'Edificio de nuestra sede de la Universidad de Costa Rica',
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: CampusPalette.blue),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35, 0.64, 1],
                colors: [
                  CampusPalette.navy.withValues(alpha: 0.18),
                  CampusPalette.navy.withValues(alpha: 0.68),
                  CampusPalette.navy.withValues(alpha: 0.88),
                  CampusPalette.navy,
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
                    color: CampusPalette.navy,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'NUESTRO CAMPUS · NUESTRA COMUNIDAD',
                    style: TextStyle(
                      color: CampusPalette.sky,
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
                    color: CampusPalette.white,
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
                    color: CampusPalette.white,
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
                    'Nuestra sede · Universidad de Costa Rica',
                    style: TextStyle(
                      color: CampusPalette.paleBlue,
                      fontSize: 12,
                    ),
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
      Icon(icon, color: CampusPalette.cyan, size: 20),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(color: CampusPalette.white, fontSize: 13),
      ),
    ],
  );
}
