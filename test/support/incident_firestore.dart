import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/auth/services/auth_service.dart';

/// Supplies a controllable session without initializing Firebase Authentication.
class IncidentTestAuth extends Fake implements AuthService {
  String? userId = 'reporter-1';

  @override
  User? getCurrentUser() => userId == null ? null : _TestUser(userId!);
}

class _TestUser extends Fake implements User {
  @override
  final String uid;

  _TestUser(this.uid);
}

/// Exercises production transaction callbacks with optimistic read conflicts.
///
/// This double verifies staged atomic writes, retry behavior and confirmed
/// timestamp handling. It does not simulate Firestore rules or transport.
class IncidentTestFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final _versions = <String, int>{};
  final serverTime = Timestamp.fromDate(DateTime.utc(2026, 10, 21, 12));
  int allocatedIds = 0;
  int transactionAttempts = 0;
  int writeCommits = 0;
  bool pendingServerWrites = false;
  bool cachedServerRead = false;
  Object? nextCommitError;
  Object? nextServerReadError;
  void Function(String path)? onTransactionRead;
  void Function(String path)? beforeServerRead;
  void Function()? beforeCommit;

  /// Creates reference records required for report creation.
  IncidentTestFirestore() {
    store('users/reporter-1', {'role': 'reporter'});
    store('categories/lighting', {'name': 'Lighting', 'isActive': true});
  }

  /// Simulates an independent confirmed change for conflict detection.
  void store(String path, Map<String, dynamic> data) {
    documents[path] = Map.of(data);
    _versions[path] = (_versions[path] ?? 0) + 1;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _TestCollection(this, collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      transactionAttempts++;
      final transaction = _TestTransaction(this);
      final result = await transactionHandler(transaction);
      if (transaction.readVersions.entries.any(
        (entry) => (_versions[entry.key] ?? 0) != entry.value,
      )) {
        continue;
      }

      beforeCommit?.call();
      if (nextCommitError != null) {
        final error = nextCommitError!;
        nextCommitError = null;
        throw error;
      }

      final resolved = {
        for (final entry in transaction.writes.entries)
          entry.key: {
            for (final field in entry.value.entries)
              field.key: field.value is FieldValue
                  ? _resolveTimestamp(field.value)
                  : field.value,
          },
      };
      // No await occurs between validation and application of the entire batch.
      for (final entry in resolved.entries) {
        store(entry.key, entry.value);
      }
      if (resolved.isNotEmpty) writeCommits++;
      return result;
    }
    throw FirebaseException(plugin: 'cloud_firestore', code: 'aborted');
  }

  Timestamp _resolveTimestamp(FieldValue value) {
    expect(value, FieldValue.serverTimestamp());
    return serverTime;
  }
}

// SDK reference doubles are used only to exercise transaction callbacks.
// ignore: subtype_of_sealed_class
class _TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final IncidentTestFirestore database;
  @override
  final String path;

  _TestCollection(this.database, this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'allocated-${++database.allocatedIds}';
    return _TestDocument(database, '${this.path}/$id');
  }
}

// ignore: subtype_of_sealed_class
class _TestDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final IncidentTestFirestore database;
  @override
  final String path;

  _TestDocument(this.database, this.path);

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _TestCollection(database, '$path/$collectionPath');
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    database.beforeServerRead?.call(path);
    if (database.nextServerReadError != null) {
      final error = database.nextServerReadError!;
      database.nextServerReadError = null;
      throw error;
    }
    final data = database.documents[path];
    return _TestSnapshot(
      data == null ? null : Map.of(data),
      metadata: _TestMetadata(
        hasPendingWrites: database.pendingServerWrites,
        isFromCache: database.cachedServerRead,
      ),
    );
  }
}

// ignore: subtype_of_sealed_class
class _TestSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  final T? _data;
  @override
  final SnapshotMetadata metadata;

  _TestSnapshot(this._data, {SnapshotMetadata? metadata})
    : metadata = metadata ?? _TestMetadata();

  @override
  bool get exists => _data != null;

  @override
  T? data() => _data;
}

class _TestMetadata extends Fake implements SnapshotMetadata {
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;

  _TestMetadata({this.hasPendingWrites = false, this.isFromCache = false});
}

class _TestTransaction extends Fake implements Transaction {
  final IncidentTestFirestore database;
  final readVersions = <String, int>{};
  final writes = <String, Map<String, dynamic>>{};

  _TestTransaction(this.database);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (writes.isNotEmpty) {
      throw StateError('Transaction reads must precede writes.');
    }
    final path = documentReference.path;
    readVersions[path] = database._versions[path] ?? 0;
    final stored = database.documents[path];
    final snapshot = _TestSnapshot<T>(
      stored == null ? null : Map.of(stored) as T,
    );
    database.onTransactionRead?.call(path);
    return snapshot;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    expect(options, isNull);
    writes[documentReference.path] = Map.of(data as Map<String, dynamic>);
    return this;
  }
}
