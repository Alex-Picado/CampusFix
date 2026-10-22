import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads category documents and performs administrator catalog writes.
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

  /// Watches all categories; Firestore rules require an administrator.
  ///
  /// Includes inactive documents and forwards database errors. The caller must
  /// cancel the subscription when its view or authenticated session ends.
  Stream<Map<String, Map<String, dynamic>>> watchAll() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return {
        for (final document in snapshot.docs) document.id: document.data(),
      };
    });
  }

  /// Watches one category, including inactive ones, for authenticated sessions.
  ///
  /// Emits null for a missing document and forwards database errors. The caller
  /// must cancel the subscription when it no longer needs the category.
  Stream<Map<String, dynamic>?> watchById(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  /// Creates an active category and returns its assigned document ID.
  ///
  /// Expects a validated name. Database rules authorize the administrator and
  /// validate stored fields. Propagates denied writes and connection failures.
  Future<String> create({required String name}) async {
    final reference = await _firestore.collection('categories').add({
      'name': name,
      'isActive': true,
    });
    return reference.id;
  }

  /// Updates an existing category without deleting or replacing its identity.
  ///
  /// Expects validated inputs. Propagates missing documents, permission errors
  /// and connection failures. Existing incident references remain unchanged.
  Future<void> update({
    required String categoryId,
    required String name,
    required bool isActive,
  }) {
    return _firestore.collection('categories').doc(categoryId).update({
      'name': name,
      'isActive': isActive,
    });
  }
}
