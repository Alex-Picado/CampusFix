import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, Scaffold;

import 'app/bootstrap.dart';
import 'firebase_options.dart';

export 'app/bootstrap.dart' show MyApp;

/// Initializes Firebase before launching the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('CampusFix initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'CampusFix no pudo iniciar. Verificá la configuración de esta versión.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    createCampusApplication(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    ),
  );
}
