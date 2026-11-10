import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/auth/controllers/session_controller.dart';
import 'package:campusfix/features/auth/models/session_status.dart';
import 'package:campusfix/features/auth/repositories/auth_repository.dart';
import 'package:campusfix/features/auth/services/auth_service.dart';
import 'package:campusfix/features/auth/services/session_retention.dart';
import 'package:campusfix/features/auth/services/session_retention_ports.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';

import 'support/test_repositories.dart';

void main() {
  for (final remembered in [false, true]) {
    final interval = remembered
        ? const Duration(days: 30)
        : const Duration(minutes: 30);
    for (final expired in [false, true]) {
      test(
        'Closed session remembers=$remembered expires=$expired at the selected boundary',
        () {
          final store = _Store();
          var now = DateTime.utc(2026, 11, 10);
          var retention = SessionRetention(store: store, now: () => now);
          retention.prepareLogin(' ME@Test.invalid ', remembered);
          expect(retention.accept('me', 'me@test.invalid'), isTrue);
          retention.suspend();
          now = now.add(interval).subtract(Duration(seconds: expired ? 0 : 1));
          retention = SessionRetention(store: store, now: () => now);
          expect(retention.accept('me', 'me@test.invalid'), !expired);
        },
      );
    }
  }

  test('An open page stays signed in, while a closed page restored from history must revalidate', () {
    final store = _Store();
    var now = DateTime.utc(2026, 11, 10);
    final retention = SessionRetention(store: store, now: () => now);
    retention.prepareLogin('me@test.invalid', false);
    expect(retention.accept('me', 'me@test.invalid'), isTrue);
    now = now.add(const Duration(days: 35));
    expect(retention.accept('me', 'me@test.invalid'), isTrue);
    retention.suspend();
    now = now.add(const Duration(minutes: 30));
    expect(retention.accept('me', 'me@test.invalid'), isFalse);
  });

  test('Missing, corrupt, future-dated and foreign-account metadata cannot restore a session', () {
    final store = _Store();
    var now = DateTime.utc(2026, 11, 10);
    final retention = SessionRetention(store: store, now: () => now);
    expect(retention.accept('me', 'me@test.invalid'), isFalse);
    store.value = '{broken';
    expect(retention.accept('me', 'me@test.invalid'), isFalse);
    retention.prepareLogin('me@test.invalid', false);
    expect(retention.accept('me', 'me@test.invalid'), isTrue);
    retention.release();
    expect(retention.accept('other', 'me@test.invalid'), isFalse);
    expect(retention.accept('me', 'other@test.invalid'), isFalse);
    now = now.subtract(const Duration(minutes: 1));
    expect(retention.accept('me', 'me@test.invalid'), isFalse);
  });

  test('Failed sign-in restores the prior preference; sign-out clears the matching session', () {
    final store = _Store();
    final retention = SessionRetention(store: store);
    retention.prepareLogin('me@test.invalid', true);
    retention.accept('me', 'me@test.invalid');
    final previous = store.value;
    retention.prepareLogin('other@test.invalid', false);
    retention.cancelLogin();
    expect(store.value, previous);
    retention.end('other');
    expect(store.value, previous);
    retention.end('me');
    expect(store.value, isNull);
  });

  test('An expired Firebase account is never exposed to profile readers on startup', () async {
    final store = _Store();
    var now = DateTime.utc(2026, 11, 10);
    final previous = SessionRetention(store: store, now: () => now);
    previous.prepareLogin('me@test.invalid', false);
    previous.accept('me', 'me@test.invalid');
    previous.suspend();
    now = now.add(const Duration(minutes: 31));
    final auth = _Auth()..user = _User();
    final users = _Users();
    final lifecycle = _Lifecycle();
    final repository = AuthRepository(
      authService: auth,
      userRepository: users,
      sessionRetention: SessionRetention(store: store, now: () => now),
      pageLifecycle: lifecycle,
    );
    final session = SessionController(
      authRepository: repository,
      userRepository: users,
    );
    await _flush();
    expect(session.status, SessionStatus.signedOut);
    expect(session.profile, isNull);
    expect(users.profileReads, 0);
    expect(auth.signOutCalls, 1);
    session.dispose();
    await _flush();
    await auth.changes.close();
    await lifecycle.events.close();
    await users.close();
  });

  test('Recordarme reaches real authentication and closed-page expiry signs out before reopening', () async {
    final store = _Store();
    var now = DateTime.utc(2026, 11, 10);
    final auth = _Auth();
    final users = _Users()
      ..profiles['me'] = const UserProfile(
        id: 'me',
        fullName: 'Me',
        email: 'me@test.invalid',
        role: UserRole.reporter,
      );
    final lifecycle = _Lifecycle();
    final repository = AuthRepository(
      authService: auth,
      userRepository: users,
      sessionRetention: SessionRetention(store: store, now: () => now),
      pageLifecycle: lifecycle,
    );
    final session = SessionController(
      authRepository: repository,
      userRepository: users,
    );
    await _flush();
    await repository.signIn(
      email: 'me@test.invalid',
      password: 'secret',
      rememberMe: true,
    );
    await _flush();
    expect(jsonDecode(store.value!)['rememberMe'], true);
    expect(auth.persistenceCalls, 1);
    expect(session.status, SessionStatus.authenticated);
    lifecycle.closePage!();
    now = now.add(const Duration(days: 29));
    lifecycle.events.add(null);
    await _flush();
    expect(session.status, SessionStatus.authenticated);
    lifecycle.closePage!();
    now = now.add(const Duration(days: 30));
    lifecycle.events.add(null);
    await _flush();
    expect(session.status, SessionStatus.signedOut);
    expect(session.profile, isNull);
    session.dispose();
    await _flush();
    await auth.changes.close();
    await lifecycle.events.close();
    await users.close();
  });
}

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Store implements SessionRetentionStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String? next) => value = next;
}

class _Lifecycle implements SessionPageLifecycle {
  final events = StreamController<void>.broadcast(sync: true);
  void Function()? closePage;
  @override
  Stream<void> get reopens => events.stream;
  @override
  void start(void Function() heartbeat, void Function() close) =>
      closePage = close;
  @override
  void stop() => closePage = null;
}

class _User extends Fake implements User {
  @override
  String get uid => 'me';
  @override
  String get email => 'me@test.invalid';
}

class _Credential extends Fake implements UserCredential {
  @override
  User get user => _User();
}

class _Auth extends Fake implements AuthService {
  User? user;
  final changes = StreamController<User?>.broadcast(sync: true);
  int signOutCalls = 0;
  int persistenceCalls = 0;
  @override
  User? getCurrentUser() => user;
  @override
  Stream<User?> watchAuthState() => Stream.multi((sink) {
    sink.add(user);
    final sub = changes.stream.listen(sink.add);
    sink.onCancel = sub.cancel;
  });
  @override
  Future<void> useLocalPersistence() async {
    persistenceCalls++;
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    user = _User();
    changes.add(user);
    return _Credential();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
    changes.add(null);
  }
}

class _Users extends TestUserRepository {
  int profileReads = 0;
  @override
  Stream<UserProfile?> watchById(String userId) {
    profileReads++;
    return super.watchById(userId);
  }
}
