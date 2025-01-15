// lib/preferences_provider.dart
import 'package:flutter/foundation.dart';

class PreferencesProvider with ChangeNotifier {
  String? _gender;
  String? _bodyType;
  String? _style;
  String? _race;

  String? get gender => _gender;
  String? get bodyType => _bodyType;
  String? get style => _style;
  String? get race => _race;

  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  void setBodyType(String value) {
    _bodyType = value;
    notifyListeners();
  }

  void setStyle(String value) {
    _style = value;
    notifyListeners();
  }

  void setRace(String value) {
    _race = value;
    notifyListeners();
  }

  Map<String, dynamic> toMap() {
    return {
      'gender': _gender,
      'bodyType': _bodyType,
      'style': _style,
      'race': _race,
    };
  }
}