// lib/services/stable_diffusion_checker.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../services/config_service.dart';

class StableDiffusionChecker {
  final _logger = Logger('StableDiffusionChecker');
  final ConfigService _configService = ConfigService();

  Future<bool> checkConnection(String url) async {
    try {
      _logger.info('Testing connection to Stable Diffusion at: $url');

      final response = await http.get(
        Uri.parse('$url/sdapi/v1/sd-models'),
        headers: {
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('Connection successful! Status: ${response.statusCode}');
        return true;
      } else {
        _logger.warning('Unexpected status code: ${response.statusCode}');
        _logger.warning('Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.severe('Connection error: $e');
      _logger.severe('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> checkNetworkConnectivity() async {
    try {
      final url = await _configService.getStableDiffusionUrl();
      final Uri uri = Uri.parse('$url/sdapi/v1/sd-models');
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain(); // Properly close the response
      return response.statusCode == 200;
    } catch (e) {
      _logger.severe('Network connectivity check failed: $e');
      return false;
    }
  }

  // Check both connection and network
  Future<bool> checkServerStatus() async {
    final hasNetwork = await checkNetworkConnectivity(); // Direct call without self-referencing
    if (!hasNetwork) {
      return false;
    }

    final url = await _configService.getStableDiffusionUrl();
    return checkConnection(url); // Direct call without self-referencing
  }
}
