import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _sdUrlKey = 'stable_diffusion_url';

  Future<String> getStableDiffusionUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sdUrlKey) ?? 'http://127.0.0.1:7860';
  }

  Future<void> setStableDiffusionUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sdUrlKey, url);
  }
}