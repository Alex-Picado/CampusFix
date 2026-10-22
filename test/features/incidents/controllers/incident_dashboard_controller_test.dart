import 'package:campusfix/features/auth/controllers/session_controller.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/incidents/controllers/incident_dashboard_controller.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/category_service.dart';
import '../../../support/dashboard_repositories.dart';
import '../../../support/test_repositories.dart';

void main() {
  test(
    'Loads global counts and the complete catalog without enumerating users',
    () async {
      final app = await _mount();
      expect(app.dashboard.indicators?.total, 9);
      expect(app.dashboard.indicators?.open, 4);
      expect(app.dashboard.categories['network']?.isActive, false);
      expect(app.reports.activeWatches, 1);
      expect(app.categories.activeAllWatches, 1);
      expect(app.users.allUsersWatchCalls, 0);
    },
  );

  test(
    'Live transitions and removals replace counts without duplicate queries',
    () async {
      final app = await _mount();
      app.reports.replace([
        app.reports.rows.first.copyWith(status: IncidentStatus.resolved),
      ]);
      await _flush();
      expect(app.dashboard.indicators?.total, 1);
      expect(app.dashboard.indicators?.open, 0);
      expect(app.dashboard.indicators?.resolved, 1);
      expect(app.dashboard.indicators?.byCategory, {'lighting': 1});
      app.reports.replace([]);
      await _flush();
      expect(app.dashboard.indicators?.total, 0);
      expect(app.dashboard.error, isNull);
      expect(app.reports.calls, 1);
      expect(app.categories.allCalls, 1);
    },
  );

  test(
    'Category rename and deactivation preserve stable separate ID groups',
    () async {
      final app = await _mount();
      app.categories.documents['lighting'] = {
        'name': 'Redes',
        'isActive': false,
      };
      app.categories.changes.add(null);
      await _flush();
      expect(app.dashboard.categories['lighting']?.name, 'Redes');
      expect(app.dashboard.categories['network']?.name, 'Redes');
      expect(app.dashboard.indicators?.byCategory['lighting'], 4);
      expect(app.dashboard.indicators?.byCategory['network'], 3);
      expect(app.reports.calls, 1);
    },
  );

  test(
    'Pending streams expose loading rather than invented zero results',
    () async {
      final app = await _mount(pending: true);
      expect(app.dashboard.loading, true);
      expect(app.dashboard.indicators, isNull);
      expect(app.dashboard.categoriesLoading, true);
      app.reports.replace([]);
      await _flush();
      expect(app.dashboard.loading, false);
      expect(app.dashboard.indicators?.total, 0);
      expect(app.dashboard.categoriesLoading, true);
    },
  );

  test(
    'Source errors clear counts and retry without restarting catalog reads',
    () async {
      final app = await _mount();
      app.reports.changes.addError(_unavailable());
      await _flush();
      expect(app.dashboard.indicators, isNull);
      expect(app.dashboard.error, isNotNull);
      expect(app.dashboard.loading, false);
      expect(app.reports.activeWatches, 0);
      app.dashboard.retryIncidents();
      await _flush();
      expect(app.dashboard.indicators?.total, 9);
      expect(app.dashboard.error, isNull);
      expect(app.reports.activeWatches, 1);
      expect(app.categories.allCalls, 1);
    },
  );

  test(
    'Malformed catalog errors preserve counts and recover independently',
    () async {
      final app = await _mount();
      app.categories.documents['network'] = {'name': 17, 'isActive': false};
      app.categories.changes.add(null);
      await _flush();
      expect(app.dashboard.categoryError, isNotNull);
      expect(app.dashboard.categories, isEmpty);
      expect(app.dashboard.indicators?.total, 9);
      expect(app.dashboard.indicators?.byCategory['network'], 3);
      expect(app.categories.activeAllWatches, 0);
      app.categories.documents['network'] = {
        'name': 'Redes',
        'isActive': false,
      };
      app.dashboard.retryCategories();
      await _flush();
      expect(app.dashboard.categoryError, isNull);
      expect(app.dashboard.categories['network']?.name, 'Redes');
      expect(app.reports.calls, 1);
    },
  );

  test(
    'Synchronous query errors are recoverable and do not leak listeners',
    () async {
      final app = await _mount();
      app.reports.watchError = _unavailable();
      app.dashboard.retryIncidents();
      expect(app.dashboard.indicators, isNull);
      expect(app.dashboard.error, isNotNull);
      expect(app.reports.activeWatches, 0);
      app.reports.watchError = null;
      app.dashboard.retryIncidents();
      await _flush();
      expect(app.dashboard.indicators?.total, 9);
      expect(app.reports.activeWatches, 1);
    },
  );

  test(
    'An interrupted source is an error rather than a stale or empty dashboard',
    () async {
      final app = await _mount();
      await app.reports.close();
      await _flush();
      expect(app.dashboard.indicators, isNull);
      expect(app.dashboard.error, contains('interrumpió'));
      expect(app.reports.activeWatches, 0);
    },
  );

  test(
    'Retry rejects a buffered snapshot from the previous observation',
    () async {
      final app = await _mount();
      app.reports.replace([]);
      app.reports.rows = dashboardFixtures();
      app.dashboard.retryIncidents();
      await _flush();
      expect(app.dashboard.indicators?.total, 9);
      expect(app.reports.activeWatches, 1);
    },
  );

  for (final change in ['sign-out', 'account', 'role']) {
    test(
      '$change cancels both queries and permanently invalidates old callbacks',
      () async {
        final app = await _mount();
        app.reports.replace([]);
        if (change == 'role') {
          app.users.put(_profile(role: UserRole.reporter));
        } else {
          app.auth.setUser(change == 'sign-out' ? null : 'other-admin');
        }
        await _flush();
        expect(app.dashboard.active, false);
        expect(app.dashboard.indicators, isNull);
        expect(app.dashboard.categories, isEmpty);
        expect(app.reports.activeWatches, 0);
        expect(app.categories.activeAllWatches, 0);
        app.users.put(_profile());
        app.auth.setUser('admin');
        await _flush();
        app.dashboard.retryIncidents();
        app.dashboard.retryCategories();
        expect(app.dashboard.active, false);
        expect(app.reports.calls, 1);
        expect(app.categories.allCalls, 1);
      },
    );
  }

  for (final role in [UserRole.reporter, UserRole.technician]) {
    test('${role.name} never starts either global query', () async {
      final app = await _mount(role: role);
      expect(app.dashboard.active, false);
      expect(app.reports.calls, 0);
      expect(app.categories.allCalls, 0);
      expect(app.dashboard.indicators, isNull);
    });
  }
}

FirebaseException _unavailable() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

UserProfile _profile({UserRole role = UserRole.administrator}) => UserProfile(
  id: 'admin',
  fullName: 'Daniel',
  email: 'daniel@campusfix.test',
  role: role,
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<
  ({
    IncidentDashboardController dashboard,
    TestDashboardIncidents reports,
    TestCategoryService categories,
    TestAuthRepository auth,
    TestUserRepository users,
  })
>
_mount({UserRole role = UserRole.administrator, bool pending = false}) async {
  final users = TestUserRepository()..put(_profile(role: role));
  final auth = TestAuthRepository(users: users, currentUserId: 'admin');
  final session = SessionController(
    authRepository: auth,
    userRepository: users,
  );
  await _flush();
  final reports = TestDashboardIncidents()..loadImmediately = !pending;
  final categories = TestCategoryService()
    ..loadImmediately = !pending
    ..documents.addAll({
      'lighting': {'name': 'Iluminación', 'isActive': true},
      'network': {'name': 'Redes', 'isActive': false},
    });
  final dashboard = IncidentDashboardController(
    repository: reports,
    categoryRepository: CategoryRepository(categoryService: categories),
    session: session,
    uid: 'admin',
  );
  addTearDown(() async {
    dashboard.dispose();
    session.dispose();
    expect(reports.activeWatches, 0);
    expect(categories.activeAllWatches, 0);
    await auth.close();
    await users.close();
    await reports.close();
    await categories.close();
  });
  await _flush();
  return (
    dashboard: dashboard,
    reports: reports,
    categories: categories,
    auth: auth,
    users: users,
  );
}
