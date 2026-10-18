import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/campusfix_app.dart';
import 'firebase_options.dart';

/// Initializes Firebase before launching the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

/// Delegates the application entry widget to the shared presentation layer.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CampusFixApp();
  }
}
