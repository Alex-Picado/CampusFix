import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../incidents/models/incident.dart';
import '../../incidents/models/incident_history_event.dart';
import '../../incidents/models/incident_status.dart';
import '../../incidents/repositories/incident_repository.dart';
import '../../users/models/user_profile.dart';
import '../../users/models/user_role.dart';

class CampusNotification {
  final Incident incident;
  final IncidentHistoryEvent event;
  const CampusNotification(this.incident, this.event);
  String get id => '${incident.id}:${event.id}';
}

/// Observes only cases authorized for the account's current role. Read receipts
/// persist on this device and are isolated by both account and role.
class NotificationController extends ChangeNotifier {
  final IncidentRepository repository;
  final UserProfile profile;
  final _history = <String, StreamSubscription<List<IncidentHistoryEvent>>>{};
  final _events = <String, List<IncidentHistoryEvent>>{};
  final _cases = <String, Incident>{};
  final _read = <String>{};
  StreamSubscription<List<Incident>>? _source;
  SharedPreferences? _preferences;
  bool _disposed = false;
  bool loading = true;
  String? error;
  int _generation = 0;
  String get _storageKey =>
      'notifications.read.${profile.id}.${profile.role.name}';

  NotificationController({required this.repository, required this.profile}) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      _read.addAll(_preferences!.getStringList(_storageKey) ?? []);
    } catch (_) {
      // The live feed remains usable if device storage is unavailable.
    }
    if (!_disposed) retry();
  }

  List<CampusNotification> get entries {
    final result = <CampusNotification>[
      for (final row in _cases.values)
        for (final event in _events[row.id] ?? <IncidentHistoryEvent>[])
          if (event.actorUserId != profile.id &&
              (profile.role != UserRole.reporter ||
                  (event.toStatus == IncidentStatus.resolved &&
                      event.fromStatus != IncidentStatus.resolved)))
            CampusNotification(row, event),
    ]..sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));
    return result;
  }

  bool isUnread(CampusNotification entry) => !_read.contains(entry.id);
  int get unread => entries.where(isUnread).length;

  void retry() {
    if (_disposed) return;
    _stop();
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = switch (profile.role) {
        UserRole.reporter => repository.watchOwn(userId: profile.id),
        UserRole.technician => repository.watchAssigned(userId: profile.id),
        UserRole.administrator => repository.watchAll(),
      };
      _source = source.listen(
        (rows) {
          if (_disposed || generation != _generation) return;
          if (rows.any(
            (row) => switch (profile.role) {
              UserRole.reporter => row.createdByUserId != profile.id,
              UserRole.technician => row.assignedTechnicianId != profile.id,
              UserRole.administrator => false,
            },
          )) {
            _fail();
            return;
          }
          final ids = rows.map((row) => row.id).toSet();
          for (final id in _history.keys.toList()) {
            if (!ids.contains(id)) {
              _history.remove(id)?.cancel().ignore();
              _events.remove(id);
            }
          }
          _cases
            ..clear()
            ..addAll({for (final row in rows) row.id: row});
          for (final row in rows) {
            if (_history.containsKey(row.id)) continue;
            try {
              _history[row.id] = repository
                  .watchHistory(incidentId: row.id)
                  .listen(
                    (events) {
                      if (_disposed ||
                          generation != _generation ||
                          !_cases.containsKey(row.id)) {
                        return;
                      }
                      _events[row.id] = events;
                      notifyListeners();
                    },
                    onError: (Object _) {
                      if (_disposed ||
                          generation != _generation ||
                          !_cases.containsKey(row.id)) {
                        return;
                      }
                      _events.remove(row.id);
                      error = 'No pudimos actualizar algunas notificaciones.';
                      notifyListeners();
                    },
                  );
            } catch (_) {
              error = 'No pudimos actualizar algunas notificaciones.';
            }
          }
          loading = false;
          notifyListeners();
        },
        onError: (Object _) {
          if (!_disposed && generation == _generation) _fail();
        },
      );
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    _stop();
    loading = false;
    error = 'No pudimos cargar las notificaciones. Intentá nuevamente.';
    notifyListeners();
  }

  Future<void> markRead(Iterable<CampusNotification> entries) async {
    if (_disposed) return;
    _read.addAll(entries.map((entry) => entry.id));
    notifyListeners();
    try {
      await _preferences?.setStringList(_storageKey, _read.toList());
    } catch (_) {
      if (!_disposed) {
        error = 'La lectura se guardó solo durante esta sesión.';
        notifyListeners();
      }
    }
  }

  void _stop() {
    _generation++;
    _source?.cancel().ignore();
    _source = null;
    for (final subscription in _history.values) {
      subscription.cancel().ignore();
    }
    _history.clear();
    _events.clear();
    _cases.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }
}
