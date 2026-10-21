final _records = <String, String>{};
void clearPendingUser(String uid) => _records.removeWhere(
  (key, _) => key.startsWith('campusfix:evidence:$uid:'),
);
String? readPending(String key) => _records[key];
void writePending(String key, String? value) {
  if (value == null) {
    _records.remove(key);
  } else {
    _records[key] = value;
  }
}
