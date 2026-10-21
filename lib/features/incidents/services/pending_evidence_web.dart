import 'package:web/web.dart' as web;

/// Removes private retry metadata when its account leaves the application.
void clearPendingUser(String uid) {
  final storage = web.window.localStorage;
  final keys = <String>[];
  for (var index = 0; index < storage.length; index++) {
    final key = storage.key(index);
    if (key != null && key.startsWith('campusfix:evidence:$uid:')) {
      keys.add(key);
    }
  }
  for (final key in keys) {
    storage.removeItem(key);
  }
}

/// Stores small acknowledged-upload references, never tokens or photograph bytes.
String? readPending(String key) => web.window.localStorage.getItem(key);
void writePending(String key, String? value) {
  if (value == null) {
    web.window.localStorage.removeItem(key);
  } else {
    web.window.localStorage.setItem(key, value);
  }
}
