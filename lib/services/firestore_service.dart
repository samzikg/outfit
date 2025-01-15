import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('FirestoreService');

  // Save outfit preferences
  Future<void> saveOutfitPreferences(String userId, Map<String, dynamic> preferences) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error saving preferences: ${e.code}', e);
      if (e.code == 'permission-denied') {
        throw Exception('You don\'t have permission to save preferences. Please sign in again.');
      }
      throw Exception('Failed to save preferences: ${e.message}');
    } catch (e) {
      _logger.severe('Error saving preferences', e);
      throw Exception('Failed to save preferences: $e');
    }
  }

  // Save favorite outfits
  Future<void> saveFavoriteOutfit(String userId, Map<String, dynamic> outfit) async {
    try {
      await _firestore.collection('users')
          .doc(userId)
          .collection('favorites')
          .add({
        ...outfit,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error saving favorite: ${e.code}', e);
      if (e.code == 'permission-denied') {
        throw Exception('You don\'t have permission to save favorites. Please sign in again.');
      }
      throw Exception('Failed to save favorite: ${e.message}');
    } catch (e) {
      _logger.severe('Error saving favorite', e);
      throw Exception('Failed to save favorite: $e');
    }
  }

  // Get user's favorite outfits
  Stream<QuerySnapshot> getFavoriteOutfits(String userId) {
    try {
      return _firestore.collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error getting favorites: ${e.code}', e);
      throw Exception('Failed to get favorites: ${e.message}');
    } catch (e) {
      _logger.severe('Error getting favorites', e);
      throw Exception('Failed to get favorites: $e');
    }
  }

  // Get user's designs
  Stream<QuerySnapshot> getUserDesigns(String userId) {
    try {
      return _firestore.collection('users')
          .doc(userId)
          .collection('designs')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error getting designs: ${e.code}', e);
      throw Exception('Failed to get designs: ${e.message}');
    } catch (e) {
      _logger.severe('Error getting designs', e);
      throw Exception('Failed to get designs: $e');
    }
  }

  // Initialize user document
  Future<void> initializeUserDocument(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userId).set({
          'createdAt': FieldValue.serverTimestamp(),
          'preferences': {},
        });
      }
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error initializing user: ${e.code}', e);
      throw Exception('Failed to initialize user: ${e.message}');
    } catch (e) {
      _logger.severe('Error initializing user', e);
      throw Exception('Failed to initialize user: $e');
    }
  }

  // Delete user data
  Future<void> deleteUserData(String userId) async {
    try {
      // Get reference to user document
      final userRef = _firestore.collection('users').doc(userId);

      // Delete favorites subcollection
      final favoritesSnapshot = await userRef.collection('favorites').get();
      for (var doc in favoritesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete designs subcollection
      final designsSnapshot = await userRef.collection('designs').get();
      for (var doc in designsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Finally, delete the user document itself
      await userRef.delete();

      _logger.info('Successfully deleted all data for user: $userId');
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error deleting user data: ${e.code}', e);
      throw Exception('Failed to delete user data: ${e.message}');
    } catch (e) {
      _logger.severe('Error deleting user data', e);
      throw Exception('Failed to delete user data: $e');
    }
  }
}
