import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/users/repositories/user_repository.dart';

/// Shares repositories and owns the application's authentication controllers.
///
/// Accepts repositories so tests can supply local implementations. Provider
/// disposes both controllers when this scope is removed from the widget tree.
class AppProviders extends StatelessWidget {
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final Widget child;

  const AppProviders({
    super.key,
    required this.authRepository,
    required this.userRepository,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<UserRepository>.value(value: userRepository),
        ChangeNotifierProvider(
          create: (context) =>
              AuthController(authRepository: context.read<AuthRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => SessionController(
            authRepository: context.read<AuthRepository>(),
            userRepository: context.read<UserRepository>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
