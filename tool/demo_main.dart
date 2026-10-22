import 'package:campusfix/app/bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Isolated development entry point; production main never imports this file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:123456789:web:demo',
      messagingSenderId: '123456789',
      projectId: 'demo-campusfix',
      authDomain: 'demo-campusfix.firebaseapp.com',
    ),
  );
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  await auth.useAuthEmulator('127.0.0.1', 9099);
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator('127.0.0.1', 8085);
  runApp(createCampusApplication(auth: auth, firestore: firestore));
}
