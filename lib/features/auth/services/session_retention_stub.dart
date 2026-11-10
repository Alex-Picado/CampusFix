import 'session_retention_ports.dart';

SessionRetentionStore createSessionRetentionStore() => _MemoryStore();
SessionPageLifecycle createSessionPageLifecycle() => _NoPageLifecycle();

class _MemoryStore implements SessionRetentionStore {
  String? _value;
  @override
  String? read() => _value;
  @override
  void write(String? value) => _value = value;
}

class _NoPageLifecycle implements SessionPageLifecycle {
  @override
  Stream<void> get reopens => const Stream.empty();
  @override
  void start(void Function() heartbeat, void Function() close) {}
  @override
  void stop() {}
}
