import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../users/models/user_role.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

/// Owns catalog observation, editing and writes for one administrator session.
class CategoryManagementController extends ChangeNotifier {
  final CategoryRepository _repository;
  final SessionController _session;
  final String _uid;
  StreamSubscription<List<Category>>? _subscription;
  bool _disposed = false;
  bool _invalidated = false;
  int _watchVersion = 0;
  List<Category> _categories = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;
  String? _success;
  String? _editingId;
  String _draftName = '';
  int _editorVersion = 0;

  /// Starts observation only if [uid] owns the current administrator session.
  ///
  /// Dependencies are injected. The owning screen must dispose this controller.
  CategoryManagementController({
    required this._repository,
    required this._session,
    required this._uid,
  }) {
    _session.addListener(_sessionChanged);
    start();
  }

  /// Whether the original account still has an authenticated administrator role.
  bool get active =>
      !_disposed &&
      !_invalidated &&
      _session.status == SessionStatus.authenticated &&
      _session.profile?.id == _uid &&
      _session.profile?.role == UserRole.administrator;

  /// Latest immutable catalog, including inactive categories.
  List<Category> get categories => _categories;

  /// Whether the first or retried catalog result is pending.
  bool get isLoading => _isLoading;

  /// Whether an acknowledged catalog write is still pending.
  bool get isSaving => _isSaving;

  /// Whether editing and writing are currently available.
  bool get canEdit => active && !_isLoading && !_isSaving && _loadError == null;

  /// Spanish query feedback; errors never become empty successful lists.
  String? get loadError => _loadError;

  /// Spanish validation or write feedback for the last attempted operation.
  String? get saveError => _saveError;

  /// Confirmation of an acknowledged write in this same session.
  String? get success => _success;

  /// Category being renamed, or null when creating a new category.
  String? get editingId => _editingId;

  /// Current name draft, cleared when its editor or session ends.
  String get draftName => _draftName;

  /// Changes when the presentation must replace its name editor.
  int get editorVersion => _editorVersion;

  /// Retries observation, clearing stale records and ignoring old callbacks.
  ///
  /// Returns without effect when the session is invalid or a write is pending.
  void start() {
    if (!active || _isSaving) return;
    _stop();
    final version = _watchVersion;
    _categories = const [];
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    if (!active || version != _watchVersion) return;
    try {
      final subscription = _repository.watchAll().listen(
        (rows) {
          if (!active || version != _watchVersion) return;
          _categories = List.unmodifiable(rows);
          _isLoading = false;
          _loadError = null;
          notifyListeners();
        },
        onError: (Object error) {
          if (active && version == _watchVersion) _fail(error);
        },
        onDone: () {
          if (active && version == _watchVersion) {
            _fail(StateError('Category observation ended.'));
          }
        },
        cancelOnError: true,
      );
      if (active && version == _watchVersion) {
        _subscription = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (error) {
      if (active && version == _watchVersion) _fail(error);
    }
  }

  /// Replaces the draft name while editing is available; performs no write.
  void setName(String name) {
    if (canEdit) _draftName = name;
  }

  /// Loads an existing category into the rename form without changing its flag.
  void edit(Category category) {
    if (!canEdit) return;
    _editingId = category.id;
    _draftName = category.name;
    _editorVersion++;
    _saveError = null;
    _success = null;
    notifyListeners();
  }

  /// Returns to creation and discards the name draft and write feedback.
  void cancelEdit() {
    if (!canEdit) return;
    _resetEditor();
    _saveError = null;
    _success = null;
    notifyListeners();
  }

  /// Creates or renames a category using the validated draft.
  ///
  /// Returns false for invalid data, errors, overlapping calls or a lost
  /// session. Observations supply the catalog; no optimistic row is inserted.
  Future<bool> save() async {
    if (!canEdit) return false;
    final name = _draftName.trim();
    if (name.isEmpty) {
      _saveError = 'Ingresá el nombre de la categoría.';
      _success = null;
      notifyListeners();
      return false;
    }
    final id = _editingId;
    final current = _categories.where((row) => row.id == id).firstOrNull;
    if (id != null && current == null) return false;
    return _write(
      () async {
        if (id == null) {
          await _repository.create(name: name);
        } else {
          await _repository.update(
            categoryId: id,
            name: name,
            isActive: current!.isActive,
          );
        }
      },
      id == null ? 'Categoría creada.' : 'Categoría actualizada.',
      resetEditor: true,
    );
  }

  /// Changes only the selected category's availability, preserving its identity.
  ///
  /// Returns false when unavailable, unchanged, rejected or obsolete. Previously
  /// authorized in-flight writes may finish after the session ends, without UI
  /// confirmation. The repository and database independently validate writes.
  Future<bool> setActive(Category category, bool isActive) async {
    if (!canEdit) return false;
    final current = _categories
        .where((row) => row.id == category.id)
        .firstOrNull;
    if (current == null || current.isActive == isActive) return false;
    return _write(
      () => _repository.update(
        categoryId: current.id,
        name: current.name,
        isActive: isActive,
      ),
      isActive ? 'Categoría activada.' : 'Categoría desactivada.',
    );
  }

  Future<bool> _write(
    Future<void> Function() operation,
    String message, {
    bool resetEditor = false,
  }) async {
    _isSaving = true;
    _saveError = null;
    _success = null;
    notifyListeners();
    try {
      if (!active) return false;
      await operation();
      if (!active) return false;
      if (resetEditor) _resetEditor();
      _success = message;
      return true;
    } catch (error) {
      if (active) _saveError = AppErrorMessages.fromError(error);
      return false;
    } finally {
      if (active) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  void _resetEditor() {
    _editingId = null;
    _draftName = '';
    _editorVersion++;
  }

  void _fail(Object error) {
    _stop();
    _categories = const [];
    _isLoading = false;
    _loadError = AppErrorMessages.fromError(error);
    notifyListeners();
  }

  void _stop() {
    _watchVersion++;
    _subscription?.cancel().ignore();
    _subscription = null;
  }

  void _clear() {
    _stop();
    _categories = const [];
    _isLoading = false;
    _isSaving = false;
    _loadError = null;
    _saveError = null;
    _success = null;
    _resetEditor();
  }

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    _clear();
    notifyListeners();
  }

  /// Cancels catalog observation and clears all draft and session-bound data.
  @override
  void dispose() {
    _disposed = true;
    _clear();
    _session.removeListener(_sessionChanged);
    super.dispose();
  }
}
