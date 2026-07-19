import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/composition.dart';



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

  Future<Composition> loadComposition(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) throw Exception('Composition not found');
    return Composition.fromJson(doc.data()!, id: doc.id);
  }

  Future<void> deleteComposition(String id) async {
    await _collection.doc(id).delete();
  }
}