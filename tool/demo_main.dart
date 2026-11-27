import 'package:campusfix/app/bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Isolated development entry point; production main never imports this file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !kDebugMode) {
    throw StateError('Use the Android evaluation backend for release builds.');
  }
  final emulatorHost = kIsWeb ? '127.0.0.1' : '10.0.2.2';
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: kIsWeb ? '1:123456789:web:demo' : '1:123456789:android:demo',
      messagingSenderId: '123456789',
      projectId: 'demo-campusfix',
      authDomain: 'demo-campusfix.firebaseapp.com',
    ),
  );
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  await auth.useAuthEmulator(emulatorHost, 9099, automaticHostMapping: false);
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    emulatorHost,
    8085,
    automaticHostMapping: false,
  );
  runApp(createCampusApplication(auth: auth, firestore: firestore));
}
