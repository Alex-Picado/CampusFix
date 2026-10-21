import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/campusfix_app.dart';
import 'app/providers/app_providers.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/auth_service.dart';
import 'features/catalogs/repositories/category_repository.dart';
import 'features/catalogs/services/category_service.dart';
import 'features/incidents/repositories/incident_repository.dart';
import 'features/incidents/services/incident_service.dart';
import 'features/users/repositories/user_repository.dart';
import 'features/users/services/user_service.dart';
import 'firebase_options.dart';

/// Initializes Firebase before launching the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final authService = AuthService(auth: FirebaseAuth.instance);
  final userRepository = UserRepository(
    userService: UserService(firestore: firestore),
  );
  final authRepository = AuthRepository(
    authService: authService,
    userRepository: userRepository,
  );

  runApp(
    AppProviders(
      authRepository: authRepository,
      userRepository: userRepository,
      categoryRepository: CategoryRepository(
        categoryService: CategoryService(firestore: firestore),
      ),
      incidentRepository: IncidentRepository(
        incidentService: IncidentService(
          firestore: firestore,
          authService: authService,
        ),
      ),
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
