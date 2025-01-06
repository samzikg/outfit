import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save outfit preferences
  Future<void> saveOutfitPreferences(String userId, Map<String, dynamic> preferences) async {
    await _firestore.collection('users').doc(userId).set({
      'preferences': preferences,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Save favorite outfits
  Future<void> saveFavoriteOutfit(String userId, Map<String, dynamic> outfit) async {
    await _firestore.collection('users')
        .doc(userId)
        .collection('favorites')
        .add({
      ...outfit,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user's favorite outfits
  Stream<QuerySnapshot> getFavoriteOutfits(String userId) {
    return _firestore.collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}