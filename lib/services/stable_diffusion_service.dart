import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class StableDiffusionService {
  final String baseUrl;
  final _logger = Logger('StableDiffusionService');

  StableDiffusionService({this.baseUrl = 'http://127.0.0.1:7860'});

  Future<String?> generateOutfitImage(Map<String, String?> outfitDetails) async {
    try {
      final prompt = _createDetailedPrompt(outfitDetails);
      final negativePrompt = _createNegativePrompt();

      _logger.info('Generating image with prompt: $prompt');

      final response = await http.post(
        Uri.parse('$baseUrl/sdapi/v1/txt2img'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'prompt': prompt,
          'negative_prompt': negativePrompt,
          'steps': 30,
          'width': 512,
          'height': 768,
          'cfg_scale': 7.5,
          'sampler_name': 'DPM++ 2M Karras',
          'restore_faces': true,
        }),
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Image generation timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['images'] != null && data['images'].isNotEmpty) {
          return data['images'][0];
        }
        throw Exception('No image generated in response');
      }

      throw Exception('Failed to generate image: ${response.statusCode}');
    } catch (e, stackTrace) {
      _logger.severe('Error generating image', e, stackTrace);
      return null;
    }
  }

  String _createDetailedPrompt(Map<String, String?> outfitDetails) {
    final List<String> promptParts = [];

    // Base prompt for high-quality fashion photography
    promptParts.add('high quality fashion photography of a person');

    // Add outfit details
    if (outfitDetails['headpiece'] != null) {
      promptParts.add('wearing ${outfitDetails['headpiece']} on head');
    }

    if (outfitDetails['shirt'] != null) {
      promptParts.add('wearing ${outfitDetails['shirt']} on upper body');
    }

    if (outfitDetails['pants'] != null) {
      promptParts.add('wearing ${outfitDetails['pants']} on lower body');
    }

    // Add quality modifiers
    promptParts.addAll([
      'professional lighting',
      'studio photography',
      'high detail',
      'high resolution',
      '8k',
      'fashion magazine style',
      'clean background',
      'professional fashion photography',
    ]);

    return promptParts.join(', ');
  }

  String _createNegativePrompt() {
    return [
      'unrealistic',
      'blurry',
      'low quality',
      'pixelated',
      'poor lighting',
      'deformed',
      'disfigured',
      'bad anatomy',
      'extra limbs',
      'poorly drawn face',
      'poorly drawn hands',
      'text',
      'watermark',
      'signature',
      'out of frame',
      'ugly',
      'duplicate',
      'morbid',
      'mutilated',
      'cartoon',
      'anime',
      '3d render'
    ].join(', ');
  }
}