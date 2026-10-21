import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/models/category.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../models/incident.dart';
import '../models/incident_draft.dart';
import '../repositories/incident_repository.dart';

/// Manages one reporter's draft, category observation and confirmed submission.
///
/// A changed or unavailable session permanently invalidates this instance.
/// Its owner must dispose it when the report view closes.
class IncidentReportController extends ChangeNotifier {
  final IncidentRepository _incidentRepository;
  final CategoryRepository _categoryRepository;
  final SessionController _sessionController;
  final String _userId;

  StreamSubscription<List<Category>>? _categorySubscription;
  StreamIterator<Incident?>? _reviewIterator;
  IncidentDraft _draft = const IncidentDraft();
  IncidentDraft? _pendingSubmission;
  Incident? _createdIncident;
  String? _submissionId;
  String? _selectedCategoryName;
  List<Category> _categories = const [];
  Map<String, String> _fieldErrors = const {};
  String? _loadErrorMessage;
  String? _submitErrorMessage;
  bool _isLoadingCategories = false;
  bool _isSubmitting = false;
  bool _isReviewing = false;
  bool _isActive = false;
  bool _disposed = false;
  int _watchVersion = 0;
  int _scopeVersion = 0;

  /// Creates an account-bound controller and observes active report categories.
  IncidentReportController({
    required this._incidentRepository,
    required this._categoryRepository,
    required this._sessionController,
    required this._userId,
  }) {
    _isActive = _matchesSession();
    if (_isActive) {
      _sessionController.addListener(_handleSession);
      startCategories();
    }
  }

  /// Raw editable input, replaced with server fields after confirmation.
  IncidentDraft get draft => _draft;

  /// The latest active category list, protected against consumer mutation.
  List<Category> get categories => _categories;

  /// Spanish field errors keyed by title, description, location or categoryId.
  Map<String, String> get fieldErrors => _fieldErrors;

  /// Last known selection label, retained for an unresolved submission.
  String? get selectedCategoryName => _selectedCategoryName;

  /// Category observation feedback, independent from submission feedback.
  String? get loadErrorMessage => _loadErrorMessage;

  /// Latest submission or reconciliation failure translated for the form.
  String? get submitErrorMessage => _submitErrorMessage;

  /// Confirmed saved report; null does not prove a failed write was rejected.
  Incident? get createdIncident => _createdIncident;

  /// Whether this instance still belongs to its original reporter session.
  bool get isActive => _isActive && !_disposed;

  /// Whether category observation is awaiting its first result.
  bool get isLoadingCategories => _isLoadingCategories;

  /// Whether a create or retry operation is awaiting confirmation.
  bool get isSubmitting => _isSubmitting;

  /// Whether an unresolved ID is being checked before editing.
  bool get isReviewing => _isReviewing;

  /// Whether an operation currently locks submission and draft actions.
  bool get isBusy => _isSubmitting || _isReviewing;

  /// Whether an attempted write still requires confirmation or reconciliation.
  bool get hasUnconfirmedSubmission =>
      _pendingSubmission != null && _createdIncident == null;

  /// Whether draft changes can be applied without changing an uncertain write.
  bool get canEditDraft =>
      isActive &&
      !isBusy &&
      !hasUnconfirmedSubmission &&
      _createdIncident == null;

  /// Whether a server check can reconcile the unresolved submission.
  bool get canResumeEditing => isActive && !isBusy && hasUnconfirmedSubmission;

  /// Whether the form can submit new fields or retry its frozen payload.
  bool get canSubmit =>
      isActive &&
      !isBusy &&
      _createdIncident == null &&
      (hasUnconfirmedSubmission ||
          (!_isLoadingCategories &&
              _loadErrorMessage == null &&
              _categories.isNotEmpty));

  /// Saved-report feedback containing only a server-confirmed sequence.
  String? get successMessage => _createdIncident == null
      ? null
      : 'Incidencia #${_createdIncident!.sequenceNumber} guardada correctamente.';

  /// Restarts categories without clearing draft text or submission feedback.
  void startCategories() {
    if (!isActive || isBusy) return;
    final version = ++_watchVersion;
    _categorySubscription?.cancel().ignore();
    _categorySubscription = null;
    _categories = const [];
    _isLoadingCategories = true;
    _loadErrorMessage = null;
    notifyListeners();
    if (!_canUseScope(_scopeVersion) || version != _watchVersion) return;
    try {
      final subscription = _categoryRepository.watchActive().listen(
        (categories) {
          if (!isActive || version != _watchVersion) return;
          _categories = List<Category>.unmodifiable(categories);
          _isLoadingCategories = false;
          _loadErrorMessage = null;
          _reconcileCategory();
          notifyListeners();
        },
        onError: (Object error) {
          if (!isActive || version != _watchVersion) return;
          _categories = const [];
          _isLoadingCategories = false;
          _loadErrorMessage = AppErrorMessages.fromError(error);
          notifyListeners();
        },
        onDone: () {
          if (!isActive ||
              version != _watchVersion ||
              _loadErrorMessage != null) {
            return;
          }
          _categories = const [];
          _isLoadingCategories = false;
          _loadErrorMessage =
              'No se pudo mantener la lista de categorías. Intentá nuevamente.';
          notifyListeners();
        },
        cancelOnError: true,
      );
      if (!isActive || version != _watchVersion) {
        subscription.cancel().ignore();
      } else {
        _categorySubscription = subscription;
      }
    } catch (error) {
      if (isActive && version == _watchVersion) {
        _isLoadingCategories = false;
        _loadErrorMessage = AppErrorMessages.fromError(error);
        notifyListeners();
      }
    }
  }

  /// Updates editable fields while preserving raw input until confirmation.
  ///
  /// In-flight, confirmed and unresolved submissions are read-only.
  void updateDraft({
    String? title,
    String? description,
    String? categoryId,
    String? location,
    bool clearCategory = false,
  }) {
    if (!canEditDraft) return;
    final errors = Map<String, String>.of(_fieldErrors);
    if (title != null) errors.remove('title');
    if (description != null) errors.remove('description');
    if (location != null) errors.remove('location');
    var selectedId = categoryId;
    final invalidCategory =
        categoryId != null &&
        !_categories.any(
          (category) => category.id == categoryId && category.isActive,
        );
    if (invalidCategory) {
      selectedId = null;
      errors['categoryId'] = 'Seleccioná una categoría activa.';
    } else if (categoryId != null || clearCategory) {
      errors.remove('categoryId');
    }
    _draft = _draft.copyWith(
      title: title,
      description: description,
      categoryId: selectedId,
      location: location,
      clearCategory: clearCategory || invalidCategory,
    );
    if (clearCategory || invalidCategory) _selectedCategoryName = null;
    if (selectedId != null && !clearCategory) {
      _selectedCategoryName = _categories
          .firstWhere((category) => category.id == selectedId)
          .name;
    }
    _fieldErrors = Map.unmodifiable(errors);
    notifyListeners();
  }

  /// Validates required fields and the currently active category selection.
  bool validate() {
    if (!canEditDraft) return false;
    final valid = _validateFields();
    notifyListeners();
    return valid;
  }

  /// Updates field errors without notifying before a submission lock is set.
  bool _validateFields() {
    final errors = <String, String>{};
    if (_draft.title.trim().isEmpty) errors['title'] = 'Ingresá un título.';
    if (_draft.description.trim().isEmpty) {
      errors['description'] = 'Describí el problema.';
    }
    if (_draft.location.trim().isEmpty) {
      errors['location'] = 'Indicá la ubicación.';
    }
    if (!_categories.any(
      (category) => category.id == _draft.categoryId && category.isActive,
    )) {
      errors['categoryId'] = 'Seleccioná una categoría activa.';
    }
    _fieldErrors = Map.unmodifiable(errors);
    return errors.isEmpty;
  }

  /// Creates a report or retries the exact unresolved submission with its ID.
  ///
  /// Returns null for failure, invalid input, overlapping calls or an obsolete
  /// session. A failure retains the draft and stable ID without claiming success.
  Future<Incident?> submit() async {
    if (!canSubmit || !_matchesSession()) return null;
    if (!hasUnconfirmedSubmission && !_validateFields()) {
      notifyListeners();
      return null;
    }
    final version = _scopeVersion;
    _isSubmitting = true;
    _submitErrorMessage = null;
    notifyListeners();
    try {
      if (!_canUseScope(version)) return null;
      _submissionId ??= _incidentRepository.newIncidentId();
      _pendingSubmission ??= _draft.normalized();
      final submitted = _pendingSubmission!;
      final result = await _incidentRepository.create(
        incidentId: _submissionId!,
        title: submitted.title,
        description: submitted.description,
        categoryId: submitted.categoryId!,
        location: submitted.location,
      );
      if (!_canUseScope(version)) return null;
      _acceptIncident(result);
      return result;
    } catch (error) {
      if (_canUseScope(version)) {
        _submitErrorMessage = AppErrorMessages.fromError(error);
      }
      return null;
    } finally {
      if (_canUseScope(version)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  /// Checks an unresolved ID before allowing edits to a failed submission.
  ///
  /// A confirmed report becomes the result. A confirmed absence unlocks editing
  /// but retains the reserved ID, protecting against a later competing commit.
  /// A failed check retains the original locked submission for another retry.
  Future<bool> resumeEditing() async {
    if (!canResumeEditing || !_matchesSession()) return false;
    final version = _scopeVersion;
    _isReviewing = true;
    _submitErrorMessage = null;
    notifyListeners();
    StreamIterator<Incident?>? iterator;
    try {
      if (!_canUseScope(version)) return false;
      iterator = StreamIterator(
        _incidentRepository.watchById(incidentId: _submissionId!),
      );
      _reviewIterator = iterator;
      final received = await iterator.moveNext();
      if (!_canUseScope(version)) return false;
      if (!received) {
        throw StateError(
          'The incident check ended without a confirmed result.',
        );
      }
      final result = iterator.current;
      if (result != null) {
        _acceptIncident(result);
        return false;
      }
      _pendingSubmission = null;
      _fieldErrors = const {};
      _reconcileCategory();
      return true;
    } catch (error) {
      if (_canUseScope(version)) {
        _submitErrorMessage = AppErrorMessages.fromError(error);
      }
      return false;
    } finally {
      iterator?.cancel().ignore();
      if (identical(_reviewIterator, iterator)) _reviewIterator = null;
      if (_canUseScope(version)) {
        _isReviewing = false;
        notifyListeners();
      }
    }
  }

  /// Clears an editable or confirmed draft without abandoning an unresolved ID.
  ///
  /// A reserved ID is released only after its report has been confirmed.
  bool resetDraft() {
    if (!isActive || isBusy || hasUnconfirmedSubmission) return false;
    if (_createdIncident != null) _submissionId = null;
    _createdIncident = null;
    _draft = const IncidentDraft();
    _selectedCategoryName = null;
    _fieldErrors = const {};
    _submitErrorMessage = null;
    notifyListeners();
    return true;
  }

  /// Accepts confirmed fields only for this instance's reserved ID and author.
  void _acceptIncident(Incident result) {
    if (result.id != _submissionId || result.createdByUserId != _userId) {
      throw const FormatException(
        'The confirmed incident does not match its submission scope.',
      );
    }
    if (_draft.categoryId != result.categoryId) _selectedCategoryName = null;
    _createdIncident = result;
    _pendingSubmission = null;
    _draft = IncidentDraft(
      title: result.title,
      description: result.description,
      categoryId: result.categoryId,
      location: result.location,
    );
    _fieldErrors = const {};
  }

  /// Refreshes the selected label or invalidates a removed editable selection.
  void _reconcileCategory() {
    final selection = _draft.categoryId;
    if (selection == null) return;
    final matching = _categories.where(
      (category) => category.id == selection && category.isActive,
    );
    if (matching.isNotEmpty) {
      _selectedCategoryName = matching.first.name;
    } else if (!hasUnconfirmedSubmission &&
        _createdIncident == null &&
        !_isSubmitting) {
      _draft = _draft.copyWith(clearCategory: true);
      _selectedCategoryName = null;
      _fieldErrors = Map.unmodifiable({
        ..._fieldErrors,
        'categoryId': 'La categoría seleccionada dejó de estar disponible.',
      });
    }
  }

  /// Requires the original UID and a currently authenticated reporter profile.
  bool _matchesSession() =>
      _sessionController.status == SessionStatus.authenticated &&
      _sessionController.profile?.id == _userId &&
      _sessionController.profile?.role == UserRole.reporter;

  /// Rejects callbacks after disposal, invalidation or a session change.
  bool _canUseScope(int version) =>
      isActive && version == _scopeVersion && _matchesSession();

  /// Permanently invalidates this controller when its session becomes unusable.
  void _handleSession() {
    if (!isActive || _matchesSession()) return;
    _clearScope();
    notifyListeners();
  }

  /// Cancels owned observations and drops all account-specific form state.
  void _clearScope() {
    _isActive = false;
    _scopeVersion++;
    _watchVersion++;
    _sessionController.removeListener(_handleSession);
    _categorySubscription?.cancel().ignore();
    _categorySubscription = null;
    _reviewIterator?.cancel().ignore();
    _reviewIterator = null;
    _draft = const IncidentDraft();
    _pendingSubmission = null;
    _createdIncident = null;
    _submissionId = null;
    _selectedCategoryName = null;
    _categories = const [];
    _fieldErrors = const {};
    _loadErrorMessage = null;
    _submitErrorMessage = null;
    _isLoadingCategories = false;
    _isSubmitting = false;
    _isReviewing = false;
  }

  /// Cancels observations and clears private state; late writes are ignored.
  @override
  void dispose() {
    _disposed = true;
    _clearScope();
    super.dispose();
  }
}
