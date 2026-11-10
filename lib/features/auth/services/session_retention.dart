import 'dart:convert';

import 'session_retention_ports.dart';

/// Browser restoration policy: open pages keep their session; closing starts
/// the selected retention interval. Missing legacy metadata requires sign-in.
class SessionRetention {
  static const standardDuration = Duration(minutes: 30);
  static const rememberedDuration = Duration(days: 30);
  final SessionRetentionStore store;
  final DateTime Function() now;
  String? _activeUid;
  bool _suspended = false;
  String? _prepared;
  String? _previous;

  SessionRetention({required this.store, DateTime Function()? now})
    : now = now ?? DateTime.now;

  void prepareLogin(String email, bool rememberMe) {
    _previous = store.read();
    _prepared = jsonEncode({
      'uid': null,
      'email': email.trim().toLowerCase(),
      'rememberMe': rememberMe,
      'lastSeen': now().millisecondsSinceEpoch,
    });
    store.write(_prepared);
  }

  void cancelLogin() {
    if (_prepared != null && store.read() == _prepared) store.write(_previous);
    _prepared = null;
    _previous = null;
  }

  Map<String, dynamic>? _record() {
    try {
      final raw = store.read();
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['email'] is! String ||
          data['rememberMe'] is! bool ||
          data['lastSeen'] is! int ||
          (data['uid'] != null && data['uid'] is! String)) {
        return null;
      }
      return data;
    } on FormatException {
      return null;
    }
  }

  bool accept(String uid, String? email) {
    final record = _record();
    if (record == null ||
        email == null ||
        record['email'] != email.trim().toLowerCase() ||
        (record['uid'] != null && record['uid'] != uid)) {
      return false;
    }
    final elapsed = now().millisecondsSinceEpoch - (record['lastSeen'] as int);
    final duration = record['rememberMe'] == true
        ? rememberedDuration
        : standardDuration;
    if ((_activeUid != uid || _suspended) &&
        (elapsed < 0 || elapsed >= duration.inMilliseconds)) {
      return false;
    }
    _activeUid = uid;
    _suspended = false;
    store.write(
      jsonEncode({
        ...record,
        'uid': uid,
        'lastSeen': now().millisecondsSinceEpoch,
      }),
    );
    _prepared = null;
    _previous = null;
    return true;
  }

  void touch() {
    if (_activeUid == null || _suspended) return;
    final record = _record();
    if (record == null || record['uid'] != _activeUid) return;
    store.write(
      jsonEncode({...record, 'lastSeen': now().millisecondsSinceEpoch}),
    );
  }

  void suspend() {
    touch();
    _suspended = true;
  }

  void release() {
    _activeUid = null;
    _suspended = false;
  }

  void end(String? uid) {
    final record = _record();
    if (uid != null && record?['uid'] == uid) store.write(null);
    release();
  }
}
