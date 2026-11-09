import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/appearance_controller.dart';
import 'theme/campus_theme.dart';
import 'widgets/session_gate.dart';

/// Configures the shared theme and session-driven application entry point.
class CampusFixApp extends StatelessWidget {
  const CampusFixApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AppearanceController(),
    child: const _ThemedApp(),
  );
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFix',
      debugShowCheckedModeBanner: false,
      theme: CampusTheme.light,
      darkTheme: CampusTheme.dark,
      themeMode: context.watch<AppearanceController>().mode,
      home: const SessionGate(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null &&
            uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'incidents') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => SessionGate(incidentId: uri.pathSegments[1]),
          );
        }
        return null;
      },
    );
  }
}
