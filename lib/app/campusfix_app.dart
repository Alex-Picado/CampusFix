import 'package:flutter/material.dart';

import 'theme/campus_theme.dart';
import 'widgets/session_gate.dart';

/// Configures the shared theme and session-driven application entry point.
class CampusFixApp extends StatelessWidget {
  const CampusFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFix',
      debugShowCheckedModeBanner: false,
      theme: CampusTheme.light,
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
