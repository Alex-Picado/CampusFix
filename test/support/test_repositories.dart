import 'dart:async';

import 'package:campusfix/features/auth/repositories/auth_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/features/users/repositories/user_repository.dart';

/// Supplies controllable profile observations without contacting Firestore.
class TestUserRepository implements UserRepository {
  final profiles = <String, UserProfile>{};
  final _changes = StreamController<String>.broadcast(sync: true);
  Object? saveError;

  @override
  Future<UserProfile?> getById(String userId) async => profiles[userId];

  @override
  Stream<UserProfile?> watchById(String userId) {
    return Stream<UserProfile?>.multi((sink) {
      sink.add(profiles[userId]);
      final subscription = _changes.stream.listen(
        (changedId) {
          if (changedId == userId) {
            sink.add(profiles[userId]);
          }
        },
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    put(profile);
  }

  void put(UserProfile profile) {
    profiles[profile.id] = profile;
    _changes.add(profile.id);
  }

  void failObservation(Object error) => _changes.addError(error);

  Future<void> close() => _changes.close();
}

/// Simulates account events and failures while using the real UI controllers.
class TestAuthRepository implements AuthRepository {
  final TestUserRepository users;
  final _changes = StreamController<String?>.broadcast(sync: true);
  String? currentUserId;
  String signInUserId = 'campus-user';
  String accountEmail = 'alex@campusfix.test';
  String? submittedEmail;
  String? submittedPassword;
  Object? signInError;
  Object? signOutError;
  Completer<void>? signInBlocker;
  int signInCalls = 0;
  int registerCalls = 0;
  int completeProfileCalls = 0;

  TestAuthRepository({required this.users, this.currentUserId});

  @override
  Stream<String?> watchUserId() {
    return Stream<String?>.multi((sink) {
      sink.add(currentUserId);
      final subscription = _changes.stream.listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.onCancel = subscription.cancel;
    });
  }

  void setUser(String? userId) {
    currentUserId = userId;
    _changes.add(userId);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    submittedEmail = email;
    submittedPassword = password;
    await signInBlocker?.future;
    final error = signInError;
    if (error != null) {
      throw error;
    }
    setUser(signInUserId);
  }

  @override
  Future<void> signOut() async {
    final error = signOutError;
    if (error != null) {
      throw error;
    }
    setUser(null);
  }

  @override
  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    accountEmail = email.trim();
    setUser('registered-user');
    return completeProfile(fullName: fullName);
  }

  @override
  Future<UserProfile> completeProfile({required String fullName}) async {
    completeProfileCalls++;
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('No test account is signed in.');
    }

    final existing = await users.getById(userId);
    if (existing != null) {
      return existing;
    }
    final profile = UserProfile(
      id: userId,
      fullName: fullName.trim(),
      email: accountEmail,
      role: UserRole.reporter,
    );
    await users.saveProfile(profile);
    return profile;
  }

  Future<void> close() => _changes.close();
}
