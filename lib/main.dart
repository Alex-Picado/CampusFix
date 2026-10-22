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
import 'features/incidents/services/local_evidence_service.dart';
import 'features/incidents/repositories/evidence_repository.dart';
import 'features/users/repositories/user_repository.dart';
import 'features/users/services/user_service.dart';
import 'firebase_options.dart';

/// Initializes Firebase before launching the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const bool.fromEnvironment('USE_FIREBASE_EMULATORS')
        ? const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:123456789:web:demo',
            messagingSenderId: '123456789',
            projectId: 'demo-campusfix',
            authDomain: 'demo-campusfix.firebaseapp.com',
          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator('127.0.0.1', 8085);
  }
  final authService = AuthService(auth: FirebaseAuth.instance);
  final userRepository = UserRepository(
    userService: UserService(firestore: firestore),
  );
  final authRepository = AuthRepository(
    authService: authService,
    userRepository: userRepository,
  );
  final incidentService = IncidentService(
    firestore: firestore,
    authService: authService,
  );

  runApp(
    AppProviders(
      authRepository: authRepository,
      userRepository: userRepository,
      categoryRepository: CategoryRepository(
        categoryService: CategoryService(firestore: firestore),
      ),
      incidentRepository: IncidentRepository(incidentService: incidentService),
      evidenceRepository: const bool.fromEnvironment('ENABLE_LOCAL_PHOTOS')
          ? EvidenceRepository(
              incidents: incidentService,
              files: LocalEvidenceService(auth: FirebaseAuth.instance),
            )
          : null,
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
