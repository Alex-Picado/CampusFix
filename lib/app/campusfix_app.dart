import 'package:flutter/material.dart';

import 'theme/campus_theme.dart';
import 'widgets/campus_shell.dart';

/// Configures the shared theme and current visual prototype.
class CampusFixApp extends StatelessWidget {
  const CampusFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFix',
      debugShowCheckedModeBanner: false,
      theme: CampusTheme.light,
      home: const CampusShell(),
    );
  }
}
