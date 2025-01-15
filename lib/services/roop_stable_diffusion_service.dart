import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../services/config_service.dart';

class RoopStableDiffusionService {
  final _logger = Logger('RoopStableDiffusionService');
  final ConfigService _configService = ConfigService();

  String _generatePrompt(Map<String, dynamic> preferences, Map<String, dynamic> outfitDetails) {
    final List<String> promptParts = [];

    // Add base prompt parts
    promptParts.addAll([
      '(RAW photo, 8k uhd:1.4)',
      '(masterpiece, best quality, ultra detailed:1.2)',
      '(photorealistic, professional photograph:1.3)',
    ]);

    // Add identity-based modifiers
    if (preferences['gender'] != null) {
      promptParts.add('${preferences['gender']} person');
    }

    // Add race-specific details
    if (preferences['race'] != null) {
      switch (preferences['race'].toString().toLowerCase()) {
        case 'asian':
          promptParts.addAll(['asian', 'asian ethnicity', 'asian features']);
          break;
        case 'black':
          promptParts.addAll(['dark skin', 'african features']);
          break;
        case 'white':
          promptParts.addAll(['caucasian', 'european features']);
          break;
      }
    }

    // Add clothing descriptions
    outfitDetails.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        promptParts.add('wearing $value');
      }
    });

    // Add photography and quality modifiers
    promptParts.addAll([
      'professional studio lighting',
      'high-end fashion photography',
      'clean studio background',
      'professional color grading',
      'detailed skin texture',
      'detailed fabric texture',
      'fashion magazine style'
    ]);

    return promptParts.join(', ');
  }

  String _generateNegativePrompt(Map<String, dynamic> preferences) {
    final List<String> negativePrompts = [
      'deformed', 'distorted', 'disfigured',
      'bad anatomy', 'bad proportions', 'mutation',
      'extra limbs', 'cloned face', 'weird colors',
      'blurry', 'duplicate', 'watermark', 'signature',
      'text', 'oversaturated', 'low quality'
    ];

    // Add race-specific negative prompts
    if (preferences['race'] != null) {
      switch (preferences['race'].toString().toLowerCase()) {
        case 'asian':
          negativePrompts.addAll(['western features', 'european features']);
          break;
        case 'black':
          negativePrompts.addAll(['pale skin', 'asian features']);
          break;
        case 'white':
          negativePrompts.addAll(['asian features', 'african features']);
          break;
      }
    }

    return negativePrompts.join(', ');
  }

  Future<Map<String, dynamic>> generateImageWithFaceSwap({
    required Map<String, dynamic> outfitDetails,
    required Map<String, dynamic> preferences,
    required String sourceImage,
  }) async {
    try {
      final baseUrl = await _configService.getStableDiffusionUrl();
      _logger.info('Generating image with preferences: $preferences');

      // Generate prompts
      final prompt = _generatePrompt(preferences, outfitDetails);
      final negativePrompt = _generateNegativePrompt(preferences);

      // Initial image generation with Stable Diffusion
      final initialResponse = await http.post(
        Uri.parse('$baseUrl/sdapi/v1/txt2img'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'prompt': prompt,
          'negative_prompt': negativePrompt,
          'steps': 30,
          'cfg_scale': 7,
          'width': 512,
          'height': 768,
          'restore_faces': true,
          'sampler_name': 'DPM++ 2M Karras',
        }),
      );

      if (initialResponse.statusCode != 200) {
        throw Exception('Failed to generate initial image');
      }

      final generatedImage = json.decode(initialResponse.body)['images'][0];

      // Face swap with ROOP
      final roopResponse = await http.post(
        Uri.parse('$baseUrl/roop/swap-face'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'source_image': sourceImage,
          'target_image': generatedImage,
          'face_restore': true,
          'upscaler': 'R-ESRGAN 4x+',
          'upscale': 2,
          'face_restoration_model': 'CodeFormer',
          'restoration_visibility': 0.8,
          'restore_first': true,
        }),
      );

      if (roopResponse.statusCode != 200) {
        throw Exception('Face swap failed');
      }

      return {
        'success': true,
        'image': json.decode(roopResponse.body)['image'],
        'metadata': {
          'prompt': prompt,
          'negative_prompt': negativePrompt,
          'preferences': preferences,
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

    } catch (e) {
      _logger.severe('Error in generation process: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<bool> checkRoopAvailability() async {
    try {
      final baseUrl = await _configService.getStableDiffusionUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/roop/status'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('ROOP extension not available: $e');
      return false;
    }
  }
}