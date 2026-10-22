import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/models/category.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../models/incident.dart';
import '../models/incident_indicators.dart';
import '../repositories/incident_repository.dart';

/// Observes global counts and category labels for a single administrator session.
class IncidentDashboardController extends ChangeNotifier {
  final IncidentRepository repository;
  final CategoryRepository categoryRepository;
  final SessionController session;
  final String uid;
  StreamSubscription<List<Incident>>? _incidents;
  StreamSubscription<List<Category>>? _catalog;
  int _incidentVersion = 0;
  int _categoryVersion = 0;
  bool _disposed = false;
  bool _invalidated = false;

  IncidentIndicators? indicators;
  Map<String, Category> categories = const {};
  bool loading = true;
  bool categoriesLoading = true;
  String? error;
  String? categoryError;

  IncidentDashboardController({
    required this.repository,
    required this.categoryRepository,
    required this.session,
    required this.uid,
  }) {
    session.addListener(_sessionChanged);
    retryIncidents();
    retryCategories();
  }

  bool get active =>
      !_disposed &&
      !_invalidated &&
      session.status == SessionStatus.authenticated &&
      session.profile?.id == uid &&
      session.profile?.role == UserRole.administrator;

  /// Retries the authorized global source without restarting the catalog query.
  void retryIncidents() {
    if (!active) return;
    _cancelIncidents();
    final version = _incidentVersion;
    indicators = null;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final subscription = repository.watchAll().listen(
        (rows) {
          if (!active || version != _incidentVersion) return;
          indicators = IncidentIndicators.fromIncidents(rows);
          loading = false;
          error = null;
          notifyListeners();
        },
        onError: (Object failure) {
          if (active && version == _incidentVersion) {
            _failIncidents(AppErrorMessages.fromError(failure));
          }
        },
        onDone: () {
          if (active && version == _incidentVersion) {
            _failIncidents(
              'Se interrumpió la actualización. Intentá nuevamente.',
            );
          }
        },
      );
      if (active && version == _incidentVersion) {
        _incidents = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      if (active && version == _incidentVersion) {
        _failIncidents(AppErrorMessages.fromError(failure));
      }
    }
  }

  /// Names include inactive categories; catalog failures never zero the counts.
  void retryCategories() {
    if (!active) return;
    _cancelCategories();
    final version = _categoryVersion;
    categories = const {};
    categoriesLoading = true;
    categoryError = null;
    notifyListeners();
    try {
      final subscription = categoryRepository.watchAll().listen(
        (rows) {
          if (!active || version != _categoryVersion) return;
          categories = Map.unmodifiable({for (final row in rows) row.id: row});
          categoriesLoading = false;
          categoryError = null;
          notifyListeners();
        },
        onError: (Object failure) {
          if (active && version == _categoryVersion) {
            _failCategories(AppErrorMessages.fromError(failure));
          }
        },
        onDone: () {
          if (active && version == _categoryVersion) {
            _failCategories('Se interrumpió la consulta de categorías.');
          }
        },
      );
      if (active && version == _categoryVersion) {
        _catalog = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      if (active && version == _categoryVersion) {
        _failCategories(AppErrorMessages.fromError(failure));
      }
    }
  }

  void _failIncidents(String message) {
    _cancelIncidents();
    indicators = null;
    loading = false;
    error = message;
    notifyListeners();
  }

  void _failCategories(String message) {
    _cancelCategories();
    categories = const {};
    categoriesLoading = false;
    categoryError = message;
    notifyListeners();
  }

  void _cancelIncidents() {
    _incidentVersion++;
    _incidents?.cancel().ignore();
    _incidents = null;
  }

  void _cancelCategories() {
    _categoryVersion++;
    _catalog?.cancel().ignore();
    _catalog = null;
  }

  void _clear() {
    _cancelIncidents();
    _cancelCategories();
    indicators = null;
    categories = const {};
    loading = false;
    categoriesLoading = false;
    error = null;
    categoryError = null;
  }

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_sessionChanged);
    _clear();
    super.dispose();
  }
}
