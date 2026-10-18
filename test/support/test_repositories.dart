import 'dart:async';

import 'package:campusfix/features/auth/repositories/auth_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/features/users/repositories/user_repository.dart';

/// Supplies controllable profile observations without contacting Firestore.
class TestUserRepository implements UserRepository {
  final profiles = <String, UserProfile>{};
  final _changes = StreamController<String>.broadcast(sync: true);
  final _listErrors = StreamController<Object>.broadcast(sync: true);
  Object? saveError;
  Completer<void>? nameUpdateBlocker;
  int nameUpdateCalls = 0;
  Completer<void>? roleUpdateBlocker;
  int roleUpdateCalls = 0;
  int allUsersWatchCalls = 0;
  int activeAllUsersWatches = 0;

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

  /// Updates a local profile name while preserving its identity, email and role.
  ///
  /// Uses saveProfile so configured failures and profile observations still work.
  @override
  Future<void> updateFullName({
    required String userId,
    required String fullName,
  }) async {
    nameUpdateCalls++;
    await nameUpdateBlocker?.future;
    final profile = profiles[userId];

    if (profile == null) {
      throw StateError('The test profile does not exist.');
    }

    await saveProfile(
      UserProfile(
        id: profile.id,
        fullName: fullName.trim(),
        email: profile.email,
        role: profile.role,
      ),
    );
  }

  /// Emits all local profiles initially and whenever a profile changes.
  @override
  Stream<List<UserProfile>> watchAll() {
    return Stream<List<UserProfile>>.multi((sink) {
      allUsersWatchCalls++;
      activeAllUsersWatches++;
      void emitProfiles() {
        final current = profiles.values.toList();
        current.sort((first, second) {
          return first.fullName.toLowerCase().compareTo(
            second.fullName.toLowerCase(),
          );
        });
        sink.add(List<UserProfile>.unmodifiable(current));
      }

      emitProfiles();
      final subscription = _changes.stream.listen(
        (_) => emitProfiles(),
        onError: sink.addError,
        onDone: sink.close,
      );
      final errors = _listErrors.stream.listen(sink.addError);
      sink.onCancel = () {
        activeAllUsersWatches--;
        subscription.cancel().ignore();
        errors.cancel().ignore();
      };
    });
  }

  /// Updates a local role while preserving the remaining profile fields.
  @override
  Future<void> updateRole({
    required String userId,
    required UserRole role,
  }) async {
    roleUpdateCalls++;
    await roleUpdateBlocker?.future;
    final profile = profiles[userId];
    if (profile == null) {
      throw StateError('The test profile does not exist.');
    }

    await saveProfile(
      UserProfile(
        id: profile.id,
        fullName: profile.fullName,
        email: profile.email,
        role: role,
      ),
    );
  }

  void put(UserProfile profile) {
    profiles[profile.id] = profile;
    _changes.add(profile.id);
  }

  void failObservation(Object error) => _changes.addError(error);

  /// Fails only administrative queries while preserving profile observation.
  void failUserList(Object error) => _listErrors.add(error);

  Future<void> close() async {
    await _changes.close();
    await _listErrors.close();
  }
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
