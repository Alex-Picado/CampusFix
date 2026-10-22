import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/repositories/auth_repository.dart';
import '../features/auth/services/auth_service.dart';
import '../features/catalogs/repositories/category_repository.dart';
import '../features/catalogs/services/category_service.dart';
import '../features/incidents/repositories/evidence_repository.dart';
import '../features/incidents/repositories/incident_repository.dart';
import '../features/incidents/services/incident_service.dart';
import '../features/incidents/services/local_evidence_service.dart';
import '../features/users/repositories/user_repository.dart';
import '../features/users/services/user_service.dart';
import 'campusfix_app.dart';
import 'providers/app_providers.dart';

/// Composes repositories once after Firebase initialization.
///
/// Receives initialized clients; has no emulator configuration or fixture data.
/// Local photographs require an explicit compile-time capability opt-in.
Widget createCampusApplication({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) {
  final authService = AuthService(auth: auth);
  final users = UserRepository(userService: UserService(firestore: firestore));
  final incidents = IncidentService(
    firestore: firestore,
    authService: authService,
  );
  return AppProviders(
    authRepository: AuthRepository(
      authService: authService,
      userRepository: users,
    ),
    userRepository: users,
    categoryRepository: CategoryRepository(
      categoryService: CategoryService(firestore: firestore),
    ),
    incidentRepository: IncidentRepository(incidentService: incidents),
    evidenceRepository: const bool.fromEnvironment('ENABLE_LOCAL_PHOTOS')
        ? EvidenceRepository(
            incidents: incidents,
            files: LocalEvidenceService(auth: auth),
          )
        : null,
    child: const MyApp(),
  );
}

/// The application entry widget, also used with injected test repositories.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const CampusFixApp();
}
