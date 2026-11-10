import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'session_retention_ports.dart';

SessionRetentionStore createSessionRetentionStore() => _BrowserStore();
SessionPageLifecycle createSessionPageLifecycle() => _BrowserPageLifecycle();

class _BrowserStore implements SessionRetentionStore {
  static const _key = 'campusfix.session.v1';
  @override
  String? read() => web.window.localStorage.getItem(_key);
  @override
  void write(String? value) {
    if (value == null) {
      web.window.localStorage.removeItem(_key);
    } else {
      web.window.localStorage.setItem(_key, value);
    }
  }
}

class _BrowserPageLifecycle implements SessionPageLifecycle {
  final _reopens = StreamController<void>.broadcast(sync: true);
  Timer? _timer;
  bool _attached = false;
  bool _left = false;
  late JSFunction _hide;
  late JSFunction _show;
  late JSFunction _visibility;
  @override
  Stream<void> get reopens => _reopens.stream;
  @override
  void start(void Function() heartbeat, void Function() close) {
    if (!_attached) {
      _hide = ((web.Event _) {
        close();
        _left = true;
        _timer?.cancel();
        _timer = null;
      }).toJS;
      _show = ((web.Event _) {
        if (_left) {
          _left = false;
          _reopens.add(null);
        }
      }).toJS;
      _visibility = ((web.Event _) => heartbeat()).toJS;
      web.window.addEventListener('pagehide', _hide);
      web.window.addEventListener('pageshow', _show);
      web.document.addEventListener('visibilitychange', _visibility);
      _attached = true;
    }
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => heartbeat());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!_attached) return;
    web.window.removeEventListener('pagehide', _hide);
    web.window.removeEventListener('pageshow', _show);
    web.document.removeEventListener('visibilitychange', _visibility);
    _attached = false;
    _left = false;
  }
}
