import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  UserProvider() {
    _initUser();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;

  void _initUser() {
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  void setUser(User? user) {
    if (_user?.uid != user?.uid) {
      _user = user;
      notifyListeners();
    }
  }

  Future<void> updateUserPhoto(String photoURL) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();

      try {
        await _user!.updateProfile(photoURL: photoURL);
        _user = FirebaseAuth.instance.currentUser; // Refresh user data
        notifyListeners();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}