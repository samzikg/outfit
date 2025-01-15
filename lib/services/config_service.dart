import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

class ConfigService {
  final _logger = Logger('ConfigService');
  static const String _sdUrlKey = 'sd_url';

  static const String _defaultUrl = 'http://192.168.32.243:7860';
  //static const String _defaultUrl = 'http://192.168.51.226:7860'; usb

  Future<String> getStableDiffusionUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_sdUrlKey);

      if (savedUrl != null) {
        // Verify if the saved URL is still accessible
        if (await _isUrlAccessible(savedUrl)) {
          return savedUrl;
        }
      }

      return _defaultUrl;
    } catch (e) {
      _logger.warning('Error getting SD URL: $e');
      return _defaultUrl;
    }
  }

  Future<bool> setStableDiffusionUrl(String url) async {
    try {
      // Validate URL format
      final uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid URL format');
      }

      // Check if URL is accessible
      if (!await _isUrlAccessible(url)) {
        throw Exception('URL is not accessible');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sdUrlKey, url);
      _logger.info('Successfully saved SD URL: $url');
      return true;
    } catch (e) {
      _logger.severe('Error saving SD URL: $e');
      return false;
    }
  }

  Future<bool> _isUrlAccessible(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$url/sdapi/v1/sd-models'),
        headers: {'Accept': '*/*'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('URL accessibility check failed: $e');
      return false;
    }
  }

  Future<void> resetToDefaultUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sdUrlKey, _defaultUrl);
      _logger.info('Reset to default URL successful');
    } catch (e) {
      _logger.severe('Error resetting to default URL: $e');
    }
  }
}