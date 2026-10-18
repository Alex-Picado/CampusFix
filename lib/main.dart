import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/campusfix_app.dart';
import 'app/providers/app_providers.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/auth_service.dart';
import 'features/users/repositories/user_repository.dart';
import 'features/users/services/user_service.dart';
import 'firebase_options.dart';

/// Initializes Firebase before launching the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final userRepository = UserRepository(
    userService: UserService(firestore: FirebaseFirestore.instance),
  );
  final authRepository = AuthRepository(
    authService: AuthService(auth: FirebaseAuth.instance),
    userRepository: userRepository,
  );

  runApp(
    AppProviders(
      authRepository: authRepository,
      userRepository: userRepository,
      child: const MyApp(),
    ),
  );
}

/// Delegates the application entry widget to the shared presentation layer.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CampusFixApp();
  }
}
