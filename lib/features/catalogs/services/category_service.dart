import 'package:cloud_firestore/cloud_firestore.dart';

/// Observes the active category documents available to authenticated sessions.
class CategoryService {
  final FirebaseFirestore _firestore;

  /// Creates a service with the provided Firestore connection.
  CategoryService({required this._firestore});

  /// Watches categories filtered by their active flag in Firestore.
  ///
  /// Emits document fields indexed by document ID. The query does not retrieve
  /// inactive categories for local filtering. Forwards Firestore errors.
  /// The caller must cancel its subscription when no longer needed.
  Stream<Map<String, Map<String, dynamic>>> watchActive() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return {
            for (final document in snapshot.docs) document.id: document.data(),
          };
        });
  }
}
