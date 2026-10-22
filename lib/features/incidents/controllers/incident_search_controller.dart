import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/models/category.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../../users/models/user_profile.dart';
import '../../users/repositories/user_repository.dart';
import '../models/incident.dart';
import '../models/incident_filters.dart';
import '../models/incident_search.dart';
import '../models/incident_status.dart';

/// Filters authorized snapshots and resolves display names for one session.
///
/// The owning list controller supplies its existing incident stream. Changing a
/// query does not issue incident reads. One category listener is kept per used
/// ID, including a selected ID, and is released on pause or session invalidation.
class IncidentSearchController extends ChangeNotifier {
  final CategoryRepository _categories;
  final SessionController _session;
  final String _uid;
  final UserRole _role;
  final UserRepository? _users;
  StreamSubscription<List<UserProfile>>? _technicianSubscription;
  final _technicians = <String, UserProfile>{};
  int _technicianVersion = 0;
  bool _techniciansStarted = false;
  bool _techniciansLoading = false;
  String? _technicianError;
  final _subscriptions = <String, StreamSubscription<Category?>>{};
  final _versions = <String, int>{};
  final _names = <String, Category>{};
  final _failedIds = <String>{};
  List<Incident> _incidents = const [];
  List<Incident> _results = const [];
  IncidentSearch _criteria = const IncidentSearch();
  bool _hasSnapshot = false;
  bool _disposed = false;
  bool _invalidated = false;
  int _version = 0;
  int _editorVersion = 0;

  /// Binds local search and category reads to the original UID and role.
  ///
  /// The owner must dispose this instance. It starts no incident query.
  /// Administrators supply the user repository for protected technician labels.
  IncidentSearchController({
    required this._categories,
    required this._session,
    required this._uid,
    required this._role,
    this._users,
  }) {
    _session.addListener(_sessionChanged);
  }

  /// Whether the same authenticated account and role still own this search.
  bool get active =>
      !_disposed &&
      !_invalidated &&
      _session.status == SessionStatus.authenticated &&
      _session.profile?.id == _uid &&
      _session.profile?.role == _role;

  /// Immutable matching incidents, preserving repository order.
  List<Incident> get results => _results;

  /// Number of authorized incidents before applying local search.
  int get total => _incidents.length;

  /// Whether the owner has supplied a current snapshot rather than paused data.
  bool get hasSnapshot => _hasSnapshot;

  /// Whether administrative filter controls belong to this active session.
  bool get administrative => active && _role == UserRole.administrator;

  /// Whether the administrator's technician names are awaiting their first list.
  bool get techniciansLoading => _techniciansLoading;

  /// Spanish technician-query feedback; incident results remain usable.
  String? get technicianError => _technicianError;

  /// Current technician UIDs plus assigned or selected historical UIDs.
  ///
  /// Uses only an administrator-authorized profile stream and the loaded source.
  List<String> get technicianIds {
    final ids = <String>{
      for (final profile in _technicians.values)
        if (profile.role == UserRole.technician) profile.id,
      for (final incident in _incidents)
        if (incident.assignedTechnicianId != null)
          incident.assignedTechnicianId!,
      if (_criteria.filters.technicianId != null)
        _criteria.filters.technicianId!,
    }.toList();
    ids.sort((a, b) {
      final name = IncidentSearch.normalizeText(technicianLabel(a))
          .compareTo(IncidentSearch.normalizeText(technicianLabel(b)));
      return name != 0 ? name : a.compareTo(b);
    });
    return List.unmodifiable(ids);
  }

  /// Presents a technician's name and email, or an explicit unavailable label.
  String technicianLabel(String id) {
    final profile = _technicians[id];
    return profile == null
        ? 'Técnico no disponible ($id)'
        : '${profile.fullName} · ${profile.email}';
  }

  /// Current immutable criteria; cleared when the owning session ends.
  IncidentSearch get criteria => _criteria;

  /// Version used to replace the presentation's text editor on explicit reset.
  int get editorVersion => _editorVersion;

  /// Whether some referenced category names could not be resolved.
  bool get hasCategoryErrors => _failedIds.isNotEmpty;

  /// Whether any referenced category is still awaiting its first result.
  bool get categoriesLoading => _versions.keys.any(
    (id) => !_names.containsKey(id) && !_failedIds.contains(id),
  );

  /// IDs available in the loaded data or retained by the selected category.
  ///
  /// Ordered by normalized display name and then ID. No full catalog is read.
  List<String> get categoryIds {
    final ids = _versions.keys.toList();
    ids.sort((a, b) {
      final byName = IncidentSearch.normalizeText(categoryLabel(a))
          .compareTo(IncidentSearch.normalizeText(categoryLabel(b)));
      return byName != 0 ? byName : a.compareTo(b);
    });
    return List.unmodifiable(ids);
  }

  /// Returns a resolved name, inactive label or explicit pending/error label.
  String categoryLabel(String id) {
    final category = _names[id];
    if (category != null) {
      return '${category.name}${category.isActive ? '' : ' (inactiva)'}';
    }
    return _failedIds.contains(id)
        ? 'Categoría no disponible ($id)'
        : 'Cargando categoría ($id)';
  }

  /// Replaces the source with an authorized snapshot and reapplies criteria.
  ///
  /// The owner must supply own, assigned or administrative records according to
  /// its repository contract. Category observation never grants incident access.
  void replaceIncidents(List<Incident> incidents) {
    if (!active) return;
    _hasSnapshot = true;
    _incidents = List.unmodifiable(incidents);
    _results = _criteria.applyTo(_incidents);
    _syncCategories();
    if (administrative && !_techniciansStarted) _watchTechnicians();
    notifyListeners();
  }

  /// Updates text immediately without restarting any database observation.
  void setQuery(String query) {
    if (!active || !_hasSnapshot || query == _criteria.query) return;
    _criteria = _criteria.copyWith(query: query);
    _results = _criteria.applyTo(_incidents);
    notifyListeners();
  }

  /// Selects an available category ID, or null for every category.
  ///
  /// Ignores IDs absent from the authorized source and current selection.
  void selectCategory(String? id) {
    if (!active ||
        !_hasSnapshot ||
        (id != null && !_versions.containsKey(id))) {
      return;
    }
    _criteria = _criteria.copyWith(categoryId: id, clearCategory: id == null);
    _results = _criteria.applyTo(_incidents);
    _syncCategories();
    notifyListeners();
  }

  /// Selects a lifecycle state for administrators, or null to clear that choice.
  void selectStatus(IncidentStatus? status) => _setFilters(
    _criteria.filters.copyWith(status: status, clearStatus: status == null),
  );

  /// Selects a priority or the explicit all/unclassified choice for administrators.
  void selectPriority(IncidentPriorityFilter priority) =>
      _setFilters(_criteria.filters.copyWith(priority: priority));

  /// Selects a current/historical responsible UID or the unassigned-only choice.
  ///
  /// Null with [unassignedOnly] false clears assignment criteria. Unknown UIDs,
  /// contradictory inputs and calls outside the administrator session are ignored.
  void selectTechnician(String? id, {bool unassignedOnly = false}) {
    if ((id != null && unassignedOnly) ||
        (id != null && !technicianIds.contains(id))) {
      return;
    }
    _setFilters(
      _criteria.filters.copyWith(
        technicianId: id,
        clearTechnician: id == null,
        unassignedOnly: unassignedOnly,
      ),
    );
  }

  void _setFilters(IncidentFilters filters) {
    if (!administrative || !_hasSnapshot) return;
    _criteria = _criteria.copyWith(filters: filters);
    _results = _criteria.applyTo(_incidents);
    notifyListeners();
  }

  /// Clears every criterion and replaces the text editor; preserves source order.
  void reset() {
    if (!active) return;
    _criteria = const IncidentSearch();
    _editorVersion++;
    _results = _incidents;
    _syncCategories();
    notifyListeners();
  }

  /// Retries only failed category reads, leaving incident results available.
  void retryCategories() {
    if (!active || !_hasSnapshot) return;
    for (final id in _failedIds.toList()) {
      _subscriptions.remove(id)?.cancel().ignore();
      _versions.remove(id);
      _failedIds.remove(id);
    }
    _syncCategories();
    notifyListeners();
  }

  /// Clears records and subscriptions on navigation or a failed source query.
  ///
  /// Criteria survive a pause in the same session unless [resetCriteria] is true.
  void clearIncidents({bool resetCriteria = false}) {
    if (_disposed) return;
    for (final subscription in _subscriptions.values) {
      subscription.cancel().ignore();
    }
    _subscriptions.clear();
    _versions.clear();
    _names.clear();
    _failedIds.clear();
    _stopTechnicians();
    _incidents = const [];
    _results = const [];
    _hasSnapshot = false;
    if (resetCriteria) {
      _criteria = const IncidentSearch();
      _editorVersion++;
    }
    notifyListeners();
  }

  /// Retries administrative profile names without restarting incident queries.
  void retryTechnicians() {
    if (!administrative || !_hasSnapshot) return;
    _stopTechnicians();
    _watchTechnicians();
    notifyListeners();
  }

  void _watchTechnicians() {
    _techniciansStarted = true;
    _techniciansLoading = true;
    _technicianError = null;
    final version = ++_technicianVersion;
    bool current() =>
        administrative && _hasSnapshot && version == _technicianVersion;
    void fail(Object error) {
      if (!current()) return;
      _technicians.clear();
      _techniciansLoading = false;
      _technicianError = AppErrorMessages.fromError(error);
      notifyListeners();
    }

    if (_users == null) {
      fail(StateError('The administrative user repository is required.'));
      return;
    }
    try {
      final subscription = _users.watchAll().listen(
        (profiles) {
          if (!current()) return;
          _technicians.clear();
          _technicians.addEntries(
            profiles.map((profile) => MapEntry(profile.id, profile)),
          );
          _techniciansLoading = false;
          _technicianError = null;
          notifyListeners();
        },
        onError: (Object error) => fail(error),
        onDone: () => fail(StateError('Technician observation ended.')),
        cancelOnError: true,
      );
      if (current()) {
        _technicianSubscription = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (error) {
      fail(error);
    }
  }

  void _stopTechnicians() {
    _technicianVersion++;
    _technicianSubscription?.cancel().ignore();
    _technicianSubscription = null;
    _technicians.clear();
    _techniciansStarted = false;
    _techniciansLoading = false;
    _technicianError = null;
  }

  void _syncCategories() {
    if (!active || !_hasSnapshot) return;
    final wanted = {
      for (final row in _incidents) row.categoryId,
      if (_criteria.categoryId != null) _criteria.categoryId!,
    };
    for (final id in _versions.keys.toList()) {
      if (wanted.contains(id)) continue;
      _subscriptions.remove(id)?.cancel().ignore();
      _versions.remove(id);
      _names.remove(id);
      _failedIds.remove(id);
    }
    for (final id in wanted) {
      if (!_versions.containsKey(id)) _watchCategory(id);
    }
  }

  void _watchCategory(String id) {
    final version = ++_version;
    _versions[id] = version;
    bool current() => active && _versions[id] == version;
    void fail() {
      if (!current()) return;
      _names.remove(id);
      _failedIds.add(id);
      notifyListeners();
    }

    try {
      final subscription = _categories
          .watchById(id)
          .listen(
            (category) {
              if (!current()) return;
              if (category == null) {
                fail();
                return;
              }
              _names[id] = category;
              _failedIds.remove(id);
              notifyListeners();
            },
            onError: (Object error) => fail(),
            onDone: fail,
            cancelOnError: true,
          );
      if (current()) {
        _subscriptions[id] = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (_) {
      fail();
    }
  }

  void _sessionChanged() {
    if (_disposed || active) return;
    _invalidated = true;
    clearIncidents(resetCriteria: true);
  }

  /// Cancels category/profile observations and removes the session listener.
  @override
  void dispose() {
    clearIncidents(resetCriteria: true);
    _disposed = true;
    _session.removeListener(_sessionChanged);
    super.dispose();
  }
}
