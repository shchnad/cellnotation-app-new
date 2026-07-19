import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';

class CompositionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('compositions');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Saves a new composition or updates an existing one (if it has an id).
  Future<String> saveComposition(Composition composition) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not signed in');

    final data = composition.copyWith(
      userId: uid,
      editedAt: DateTime.now(),
    ).toJson();

    if (composition.id == null) {
      final docRef = await _collection.add(data);
      return docRef.id;
    } else {
      await _collection.doc(composition.id).update(data);
      return composition.id!;
    }
  }

  /// Returns a live stream of the current user's compositions,
  /// most recently edited first.
  Stream<List<Composition>> getUserCompositions() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _collection
        .where('userId', isEqualTo: uid)
        .orderBy('editedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Composition.fromJson(doc.data(), id: doc.id))
        .toList());
  }

  /// Returns a live stream of every public composition from all users,
  /// most recently edited first. Used for the Cloud Library screen.
  Stream<List<Composition>> getPublicCompositions() {
    return _collection
        .where('isPublic', isEqualTo: true)
        .orderBy('editedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Composition.fromJson(doc.data(), id: doc.id))
        .toList());
  }

  Future<Composition> loadComposition(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) throw Exception('Composition not found');
    return Composition.fromJson(doc.data()!, id: doc.id);
  }

  Future<void> deleteComposition(String id) async {
    await _collection.doc(id).delete();
  }

  /// Copies a (typically public, someone-else's) composition into the
  /// current user's own library as a brand-new document, so they can
  /// edit it freely without touching the original.
  Future<String> copyToMyLibrary(Composition source) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not signed in');

    final copy = source.copyWith(
      id: null, // force a new document
      userId: uid,
      isPublic: false, // copies start private
      createdAt: DateTime.now(),
      editedAt: DateTime.now(),
    );

    final docRef = await _collection.add(copy.toJson());
    return docRef.id;
  }
}