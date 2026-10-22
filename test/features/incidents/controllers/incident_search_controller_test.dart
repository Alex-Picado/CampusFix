import 'package:campusfix/features/auth/controllers/session_controller.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/incidents/controllers/incident_search_controller.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_filters.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/category_service.dart';
import '../../../support/test_repositories.dart';

void main() {
  test('Only administrators load technician profiles or accept administrative criteria', () async {
    final app = await _mount();
    app.search.replaceIncidents([_incident('a')]);
    await _flush();
    app.search.selectStatus(IncidentStatus.closed);
    app.search.selectPriority(IncidentPriorityFilter.high);
    app.search.selectTechnician(null, unassignedOnly: true);
    expect(app.search.criteria.filters.hasCriteria, false);
    expect(app.users.allUsersWatchCalls, 0);
    expect(app.search.results.length, 1);
  });

  test(
    'Administrative criteria survive query category and live source changes',
    () async {
      final app = await _mount(role: UserRole.administrator);
      final matching = _incident('a').copyWith(
        status: IncidentStatus.inProgress,
        priority: IncidentPriority.high,
        assignedTechnicianId: 'tech',
      );
      app.search.replaceIncidents([matching, _incident('b')]);
      await _flush();
      app.search.selectStatus(IncidentStatus.inProgress);
      app.search.selectPriority(IncidentPriorityFilter.high);
      app.search.selectTechnician('tech');
      app.search.setQuery('AULA');
      app.search.selectCategory('lighting');
      expect(app.search.results.single.id, 'a');
      expect(app.search.criteria.filters.technicianId, 'tech');
      app.search.replaceIncidents([
        matching.copyWith(status: IncidentStatus.resolved),
        _incident('b'),
      ]);
      expect(app.search.results, isEmpty);
      app.search.reset();
      expect(app.search.results.length, 2);
      expect(app.search.criteria.hasCriteria, false);
      expect(app.users.allUsersWatchCalls, 1);
    },
  );

  test('Technician labels update live and errors retry independently of the source', () async {
    final app = await _mount(role: UserRole.administrator);
    app.users.put(
      const UserProfile(
        id: 'tech',
        fullName: 'Daniel técnico',
        email: 'tech@campusfix.test',
        role: UserRole.technician,
      ),
    );
    app.search.replaceIncidents([
      _incident('a').copyWith(assignedTechnicianId: 'tech'),
    ]);
    await _flush();
    app.search.selectTechnician('tech');
    expect(app.search.technicianLabel('tech'), contains('Daniel técnico'));
    app.users.put(
      const UserProfile(
        id: 'tech',
        fullName: 'Nombre actualizado',
        email: 'tech@campusfix.test',
        role: UserRole.reporter,
      ),
    );
    await _flush();
    expect(app.search.technicianLabel('tech'), contains('Nombre actualizado'));
    expect(app.search.technicianIds, contains('tech'));
    app.users.failUserList(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await _flush();
    expect(app.search.technicianError, isNotNull);
    expect(app.search.results.single.id, 'a');
    expect(app.users.activeAllUsersWatches, 0);
    app.search.retryTechnicians();
    await _flush();
    expect(app.search.technicianError, isNull);
    expect(app.users.activeAllUsersWatches, 1);
    expect(app.search.criteria.filters.technicianId, 'tech');
  });

  test('Pausing and role loss release technician observations and clear old criteria', () async {
    final app = await _mount(role: UserRole.administrator);
    app.search.replaceIncidents([_incident('a')]);
    await _flush();
    app.search.selectPriority(IncidentPriorityFilter.withoutPriority);
    app.search.clearIncidents();
    expect(app.users.activeAllUsersWatches, 0);
    app.search.replaceIncidents([_incident('b')]);
    await _flush();
    expect(
      app.search.criteria.filters.priority,
      IncidentPriorityFilter.withoutPriority,
    );
    app.users.put(_profile(UserRole.reporter));
    await _flush();
    expect(app.users.activeAllUsersWatches, 0);
    expect(app.search.criteria.hasCriteria, false);
    expect(app.search.results, isEmpty);
    app.users.put(_profile(UserRole.administrator));
    await _flush();
    expect(app.search.active, false);
  });

  test('Unknown or contradictory technician selections leave valid criteria intact', () async {
    final app = await _mount(role: UserRole.administrator);
    app.search.replaceIncidents([
      _incident('a').copyWith(assignedTechnicianId: 'tech'),
    ]);
    await _flush();
    app.search.selectTechnician('tech');
    app.search.selectTechnician('not-in-the-source');
    app.search.selectTechnician('tech', unassignedOnly: true);
    expect(app.search.criteria.filters.technicianId, 'tech');
    app.search.selectTechnician(null, unassignedOnly: true);
    expect(app.search.results, isEmpty);
    app.search.selectTechnician(null);
    expect(app.search.results.length, 1);
  });

  test(
    'Keeps one listener per category and text changes issue no new reads',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([_incident('a'), _incident('b')]);
      await _flush();
      expect(app.categories.activeIdWatches, 1);
      app.search.setQuery('AULA');
      app.search.replaceIncidents([
        _incident('a'),
        _incident('b'),
        _incident('c'),
      ]);
      await _flush();
      expect(app.categories.activeIdWatches, 1);
      expect(app.search.results.length, 3);
      expect(app.categories.allCalls, 0);
      app.search.clearIncidents();
      expect(app.categories.activeIdWatches, 0);
      expect(app.search.criteria.query, 'AULA');
      expect(app.search.results, isEmpty);
    },
  );

  test(
    'Reapplies text and category when live records change or disappear',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([
        _incident('a'),
        _incident('b', category: 'network'),
      ]);
      await _flush();
      app.search.setQuery('aula');
      app.search.selectCategory('lighting');
      expect(app.search.results.single.id, 'a');
      app.search.replaceIncidents([_incident('b', category: 'network')]);
      expect(app.search.results, isEmpty);
      expect(app.search.criteria.categoryId, 'lighting');
      app.search.replaceIncidents([
        _incident('new'),
        _incident('b', category: 'network'),
      ]);
      expect(app.search.results.single.id, 'new');
      app.search.reset();
      expect(app.search.results.map((row) => row.id), ['new', 'b']);
    },
  );

  test('Inactive names and later renames remain usable without changing selected IDs', () async {
    final app = await _mount();
    app.search.replaceIncidents([_incident('a', category: 'network')]);
    await _flush();
    expect(app.search.categoryLabel('network'), 'Redes (inactiva)');
    app.search.selectCategory('network');
    app.categories.documents['network']!['name'] = 'Conectividad';
    app.categories.changes.add(null);
    await _flush();
    expect(app.search.categoryLabel('network'), 'Conectividad (inactiva)');
    expect(app.search.criteria.categoryId, 'network');
    expect(app.search.results.single.id, 'a');
  });

  test(
    'Category errors do not erase records and retries replace failed listeners',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([_incident('a')]);
      await _flush();
      app.categories.changes.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await _flush();
      expect(app.search.hasCategoryErrors, true);
      expect(app.search.categoryLabel('lighting'), contains('no disponible'));
      expect(app.search.results.length, 1);
      app.search.retryCategories();
      await _flush();
      expect(app.search.hasCategoryErrors, false);
      expect(app.categories.activeIdWatches, 1);
      expect(app.search.categoryLabel('lighting'), 'Iluminación');
    },
  );

  test('Removed categories release observations and unknown selections are ignored', () async {
    final app = await _mount();
    app.search.replaceIncidents([
      _incident('a'),
      _incident('b', category: 'network'),
    ]);
    await _flush();
    app.search.selectCategory('not-in-the-source');
    expect(app.search.criteria.categoryId, isNull);
    app.search.replaceIncidents([_incident('a')]);
    await _flush();
    expect(app.categories.activeIdWatches, 1);
    expect(app.search.categoryIds, ['lighting']);
  });

  test(
    'Missing category lookup remains explicit while ID filtering still works',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([_incident('a', category: 'missing')]);
      await _flush();
      expect(app.search.hasCategoryErrors, true);
      expect(app.search.categoriesLoading, false);
      app.search.selectCategory('missing');
      expect(app.search.results.single.id, 'a');
    },
  );

  test(
    'Role changes permanently clear criteria records and subscriptions',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([_incident('a')]);
      await _flush();
      app.search.setQuery('private');
      app.users.put(_profile(UserRole.technician));
      await _flush();
      expect(app.search.active, false);
      expect(app.search.criteria.hasCriteria, false);
      expect(app.search.results, isEmpty);
      expect(app.categories.activeIdWatches, 0);
      app.users.put(_profile(UserRole.reporter));
      await _flush();
      app.search.replaceIncidents([_incident('late')]);
      expect(app.search.results, isEmpty);
      expect(app.search.active, false);
    },
  );

  test(
    'Signing out clears names and ignores later category notifications',
    () async {
      final app = await _mount();
      app.search.replaceIncidents([_incident('a')]);
      await _flush();
      app.search.setQuery('#12');
      app.auth.setUser(null);
      await _flush();
      app.categories.changes.add(null);
      await _flush();
      expect(app.search.criteria.hasCriteria, false);
      expect(app.search.categoryIds, isEmpty);
      expect(app.search.results, isEmpty);
      expect(app.categories.activeIdWatches, 0);
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
UserProfile _profile(UserRole role) => UserProfile(
  id: 'reporter',
  fullName: 'Daniel',
  email: 'reporter@campusfix.test',
  role: role,
);
Incident _incident(String id, {String category = 'lighting'}) => Incident(
  id: id,
  sequenceNumber: 12,
  title: 'Aula',
  description: 'Inspección',
  categoryId: category,
  location: 'Edificio A',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdByUserId: 'reporter',
);

Future<
  ({
    IncidentSearchController search,
    TestCategoryService categories,
    TestAuthRepository auth,
    TestUserRepository users,
  })
>
_mount({UserRole role = UserRole.reporter}) async {
  final users = TestUserRepository()..profiles['reporter'] = _profile(role);
  final auth = TestAuthRepository(users: users, currentUserId: 'reporter');
  final session = SessionController(
    authRepository: auth,
    userRepository: users,
  );
  await _flush();
  final categories = TestCategoryService()
    ..documents.addAll({
      'lighting': {'name': 'Iluminación', 'isActive': true},
      'network': {'name': 'Redes', 'isActive': false},
    });
  final search = IncidentSearchController(
    categories: CategoryRepository(categoryService: categories),
    session: session,
    uid: 'reporter',
    role: role,
    users: users,
  );
  addTearDown(() async {
    search.dispose();
    session.dispose();
    await auth.close();
    await users.close();
    await categories.close();
  });
  return (search: search, categories: categories, auth: auth, users: users);
}
