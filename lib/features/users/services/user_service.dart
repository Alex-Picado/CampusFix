import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads, watches, and writes user profile documents in Firestore.
class UserService {
  final FirebaseFirestore _firestore;

  /// Creates a service using the provided Firestore instance.
  UserService({required this._firestore});

  /// Reads the profile document identified by [userId].
  ///
  /// Returns its fields, or null if the document does not exist.
  /// Propagates errors reported by Firestore.
  Future<Map<String, dynamic>?> getById(String userId) async {
    final document = await _firestore.collection('users').doc(userId).get();

    return document.data();
  }

  /// Watches the profile document identified by [userId].
  ///
  /// Emits its initial fields and subsequent changes.
  /// Emits null if the document does not exist.
  /// Forwards Firestore errors to the stream listener.
  /// The caller must cancel its subscription when no longer needed.
  Stream<Map<String, dynamic>?> watchById(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      document,
    ) {
      return document.data();
    });
  }

  /// Creates or replaces the complete profile document with [data].
  ///
  /// Uses [userId] as the document ID.
  /// Existing fields omitted from [data] are removed.
  /// All writes remain subject to Firestore security rules.
  /// Propagates errors reported by Firestore.
  Future<void> setProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return _firestore.collection('users').doc(userId).set(data);
  }

  /// Updates only the full name of an existing profile.
  ///
  /// Preserves all other document fields.
  /// Propagates Firestore errors, including missing documents and denied writes.
  Future<void> updateFullName({
    required String userId,
    required String fullName,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'fullName': fullName,
    });
  }


    /// Watches all stored profiles, indexed by document ID.
  ///
  /// Emits the initial collection and subsequent changes.
  /// Firestore rules restrict this query to administrators.
  /// The caller must cancel its subscription when no longer needed.
  Stream<Map<String, Map<String, dynamic>>> watchAll() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final profiles = <String, Map<String, dynamic>>{};

      for (final document in snapshot.docs) {
        profiles[document.id] = document.data();
      }

      return profiles;
    });
  }

  /// Updates only the role of an existing profile.
  ///
  /// Preserves the remaining document fields.
  /// Firestore rules enforce administrator permissions and valid roles.
  /// Propagates errors reported by Firestore.
  Future<void> updateRole({
    required String userId,
    required String role,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'role': role,
    });
  }


}
