import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/auth/services/auth_service.dart';

/// Controls account changes independently from document delivery.
class ObservationAuth extends Fake implements AuthService {
  String? userId = 'reporter-1';
  final states = StreamController<User?>.broadcast();

  @override
  User? getCurrentUser() => userId == null ? null : _ObservationUser(userId!);

  @override
  Stream<User?> watchAuthState() => states.stream;

  void changeAccount(String? value) {
    userId = value;
    states.add(getCurrentUser());
  }
}

class _ObservationUser extends Fake implements User {
  @override
  final String uid;
  _ObservationUser(this.uid);
}

/// Records real service query construction without initializing a Firebase app.
class ObservationFirestore extends Fake implements FirebaseFirestore {
  final queries = <QueryChannel>[];
  final documents = <DocumentChannel>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _ObservationCollection(this, collectionPath);
  }

  Future<void> dispose() async {
    for (final channel in queries) {
      await channel.events.close();
    }
    for (final channel in documents) {
      await channel.events.close();
    }
  }
}

/// Supplies snapshots and exposes the filters used by the production query.
class QueryChannel {
  final String path;
  final Object? filterField;
  final Object? filterValue;
  final Object? orderField;
  final bool descending;
  final events = StreamController<QuerySnapshot<Map<String, dynamic>>>();

  QueryChannel(
    this.path,
    this.filterField,
    this.filterValue,
    this.orderField,
    this.descending,
  );

  void emit(
    Map<String, Map<String, dynamic>> data, {
    bool cache = false,
    bool pending = false,
  }) {
    events.add(_ObservationQuerySnapshot(data, cache, pending));
  }
}

/// Supplies document existence and metadata independently of record fields.
class DocumentChannel {
  final String path;
  final events = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
  DocumentChannel(this.path);

  void emit(
    Map<String, dynamic>? data, {
    bool cache = false,
    bool pending = false,
  }) {
    events.add(
      _ObservationDocument(
        data,
        metadata: _ObservationMetadata(cache, pending),
      ),
    );
  }
}

// SDK reference doubles are restricted to observation tests.
// ignore: subtype_of_sealed_class
class _ObservationCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final ObservationFirestore database;
  @override
  final String path;
  final Object? filterField;
  final Object? filterValue;
  final Object? orderField;
  final bool descending;

  _ObservationCollection(
    this.database,
    this.path, {
    this.filterField,
    this.filterValue,
    this.orderField,
    this.descending = false,
  });

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _ObservationReference(database, '${this.path}/$path');
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _ObservationCollection(
      database,
      path,
      filterField: field,
      filterValue: isEqualTo,
      orderField: orderField,
      descending: descending,
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return _ObservationCollection(
      database,
      path,
      filterField: filterField,
      filterValue: filterValue,
      orderField: field,
      descending: descending,
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    expect(includeMetadataChanges, isTrue);
    final channel = QueryChannel(
      path,
      filterField,
      filterValue,
      orderField,
      descending,
    );
    database.queries.add(channel);
    return channel.events.stream;
  }
}

// ignore: subtype_of_sealed_class
class _ObservationReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final ObservationFirestore database;
  @override
  final String path;
  _ObservationReference(this.database, this.path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _ObservationCollection(database, '$path/$collectionPath');
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    expect(includeMetadataChanges, isTrue);
    final channel = DocumentChannel(path);
    database.documents.add(channel);
    return channel.events.stream;
  }
}

class _ObservationMetadata extends Fake implements SnapshotMetadata {
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
  _ObservationMetadata(this.isFromCache, this.hasPendingWrites);
}

// ignore: subtype_of_sealed_class
class _ObservationDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? fields;
  @override
  final String id;
  @override
  final SnapshotMetadata metadata;
  _ObservationDocument(
    this.fields, {
    this.id = 'report-1',
    required this.metadata,
  });

  @override
  bool get exists => fields != null;

  @override
  Map<String, dynamic> data() => Map.of(fields!);
}

class _ObservationQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
  _ObservationQuerySnapshot(
    Map<String, Map<String, dynamic>> data,
    bool cache,
    bool pending,
  ) : metadata = _ObservationMetadata(cache, pending),
      docs = [
        for (final entry in data.entries)
          _ObservationDocument(
            entry.value,
            id: entry.key,
            metadata: _ObservationMetadata(cache, pending),
          ),
      ];
}
