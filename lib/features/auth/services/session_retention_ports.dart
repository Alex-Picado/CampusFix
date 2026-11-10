/// Metadata only; Firebase continues to own authentication credentials.
abstract interface class SessionRetentionStore {
  String? read();
  void write(String? value);
}

abstract interface class SessionPageLifecycle {
  Stream<void> get reopens;
  void start(void Function() heartbeat, void Function() close);
  void stop();
}
