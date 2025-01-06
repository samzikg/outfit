import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '533839323676-4f8b61a638b2bcc8a3b5d9.apps.googleusercontent.com'  // Web client ID
        : null,  // Android/iOS will use google-services.json/GoogleService-Info.plist
  );
  final _logger = Logger('AuthService');

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Begin interactive sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.info('Google sign in aborted by user');
        return null;
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with credential
      return await _auth.signInWithCredential(credential);
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with Google', e, stackTrace);
      rethrow;
    }
  }

  // Email Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error signing up with email', e, stackTrace);
      rethrow;
    }
  }

  // Email Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with email', e, stackTrace);
      rethrow;
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
      rethrow;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}