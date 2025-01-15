import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '533839323676-4f8b61a638b2bcc8a3b5d9.apps.googleusercontent.com'
        : null,
  );
  final FirestoreService _firestoreService = FirestoreService();
  final _logger = Logger('AuthService');

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _logger.info('Google sign in aborted by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _firestoreService.initializeUserDocument(userCredential.user!.uid);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth error during Google sign in: ${e.code}', e);
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception('An account already exists with the same email address but different sign-in credentials.');
        case 'invalid-credential':
          throw Exception('The credential is malformed or has expired.');
        case 'operation-not-allowed':
          throw Exception('Google sign-in is not enabled. Please contact support.');
        case 'user-disabled':
          throw Exception('This user account has been disabled.');
        case 'user-not-found':
          throw Exception('No user found for that email.');
        case 'wrong-password':
          throw Exception('Wrong password provided for that user.');
        default:
          throw Exception('An error occurred during Google sign in: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during Google sign in', e, stackTrace);
      throw Exception('An unexpected error occurred during Google sign in. Please try again.');
    }
  }

  // Email Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestoreService.initializeUserDocument(userCredential.user!.uid);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth error during email sign in: ${e.code}', e);
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-disabled':
          throw Exception('This user account has been disabled.');
        case 'user-not-found':
          throw Exception('No user found for that email.');
        case 'wrong-password':
          throw Exception('Wrong password provided for that user.');
        default:
          throw Exception('An error occurred during sign in: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during email sign in', e, stackTrace);
      throw Exception('Failed to sign in: $e');
    }
  }

  // Email Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestoreService.initializeUserDocument(userCredential.user!.uid);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth error during email sign up: ${e.code}', e);
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account already exists for that email.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled.');
        case 'weak-password':
          throw Exception('The password provided is too weak.');
        default:
          throw Exception('An error occurred during sign up: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during email sign up', e, stackTrace);
      throw Exception('An unexpected error occurred during sign up. Please try again.');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e, stackTrace) {
      _logger.severe('Error signing out', e, stackTrace);
      throw Exception('Failed to sign out. Please try again.');
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');

      await _firestoreService.deleteUserData(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth error deleting account: ${e.code}', e);
      switch (e.code) {
        case 'requires-recent-login':
          throw Exception('Please sign in again before deleting your account.');
        default:
          throw Exception('An error occurred deleting account: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error deleting account', e, stackTrace);
      throw Exception('Failed to delete account. Please try again.');
    }
  }
}