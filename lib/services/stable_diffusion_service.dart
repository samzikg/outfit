import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../services/config_service.dart';

class GenerationProgress {
  final double progress;
  final String stage;
  final String message;

  GenerationProgress({
    required this.progress,
    required this.stage,
    required this.message,
  });
}

class StableDiffusionServiceConfig {
  final String modelName;
  final int steps;
  final int width;
  final int height;
  final double cfgScale;
  final String samplerName;
  final bool restoreFaces;
  final List<String> styles;
  final int clipSkip;
  final String hrUpscaler;  // Changed this to be configurable
  final double hiresUpscale;
  final int hiresSteps;
  final double hiresDenoisingStrength;

  const StableDiffusionServiceConfig({
    this.samplerName = 'Eular_a',
    this.modelName = 'majicmixRealistic_v7.safetensors',
    this.steps = 35,
    this.width = 512,
    this.height = 768,
    this.cfgScale = 7.5,
    this.clipSkip = 2,
    this.restoreFaces = true,
    this.styles = const ['photorealistic'],
    this.hrUpscaler = 'R-ESRGAN 4x+', // Changed to match the actual upscaler name
    this.hiresUpscale = 3.0,
    this.hiresSteps = 15,
    this.hiresDenoisingStrength = 0.4,
  });

  Map<String, dynamic> toJson() {
    return {
      'override_settings': {
        'sd_model_checkpoint': modelName,
        'CLIP_stop_at_last_layers': clipSkip,
      },
      'steps': steps,
      'width': width,
      'height': height,
      'cfg_scale': cfgScale,
      'sampler_name': samplerName,
      'restore_faces': restoreFaces,
      'styles': styles,
      'enable_hr': true,
      'hr_upscaler': hrUpscaler,  // Updated this line
      'hr_scale': hiresUpscale,
      'hr_second_pass_steps': hiresSteps,
      'denoising_strength': hiresDenoisingStrength,
    };
  }
}

class StableDiffusionResponse {
  final bool success;
  final String? image;
  final String? error;
  final Map<String, dynamic>? metadata;
  final String? prompt;
  final String? negativePrompt;

  StableDiffusionResponse({
    required this.success,
    this.image,
    this.error,
    this.metadata,
    this.prompt,
    this.negativePrompt,
  });
}

class StableDiffusionService {
  final _logger = Logger('StableDiffusionService');
  final Duration timeout;
  final StableDiffusionServiceConfig config;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  final _progressController = StreamController<GenerationProgress>.broadcast();
  Stream<GenerationProgress> get progressStream => _progressController.stream;
  final ConfigService _configService = ConfigService();

  StableDiffusionService({
    this.timeout = const Duration(minutes: 2),
    this.config = const StableDiffusionServiceConfig(),
  });

  Future<String> _getBaseUrl() async {
    final url = await _configService.getStableDiffusionUrl();
    _logger.info('Using Stable Diffusion URL: $url');
    return url;
  }

  Future<bool> checkServerStatus() async {
    try {
      final baseUrl = await _getBaseUrl();
      _logger.info('Checking server status at: $baseUrl');

      final response = await http.get(
        Uri.parse('$baseUrl/sdapi/v1/sd-models'),
      ).timeout(const Duration(seconds: 10));

      final isAvailable = response.statusCode == 200;
      _logger.info('Server status check result: $isAvailable');

      if (isAvailable) {
        final models = json.decode(response.body) as List;
        final modelTitles = models.map((m) => m['title'].toString()).join(", ");
        _logger.info('Available models: $modelTitles');
      }

      return isAvailable;
    } catch (e) {
      _logger.warning('Server status check failed: $e');
      return false;
    }
  }

  Future<StableDiffusionResponse> generateOutfitImage(
      Map<String, String?> outfitDetails,
      Map<String, dynamic> userPreferences) async {
    final prompt = _processPrompt(outfitDetails, userPreferences);
    final negativePrompt = _generateNegativePrompt(userPreferences);
    int retryCount = 0;
    Exception? lastError;

    while (retryCount < maxRetries) {
      try {
        final baseUrl = await _getBaseUrl();
        _updateProgress(0.1, 'Connection', 'Connecting to server...');

        _logger.info('Attempt ${retryCount + 1}: Using base URL: $baseUrl');

        if (!await checkServerStatus()) {
          _updateProgress(0.0, 'Error', 'Server connection failed');
          throw Exception('Server connection check failed');
        }

        _updateProgress(0.2, 'Preparation', 'Preparing generation parameters...');

        final requestBody = {
          'prompt': _processPrompt(outfitDetails, userPreferences),
          'negative_prompt': _generateNegativePrompt(userPreferences),
          ...config.toJson(),
        };

        _updateProgress(0.3, 'Generation', 'Sending request to server...');
        _logger.info('Sending request with body: ${json.encode(requestBody)}');

        final response = await http.post(
          Uri.parse('$baseUrl/sdapi/v1/txt2img'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': '*/*',
            'Host': baseUrl.replaceAll('http://', ''),
            'Connection': 'keep-alive',
          },
          body: json.encode(requestBody),
        ).timeout(const Duration(minutes: 5));

        _updateProgress(0.8, 'Processing', 'Processing server response...');
        _logger.info('Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['images'] != null && data['images'].isNotEmpty) {
            _updateProgress(1.0, 'Complete', 'Generation completed successfully!');
            return StableDiffusionResponse(
              success: true,
              image: data['images'][0],
              metadata: data['info'] != null ? json.decode(data['info']) : null,
              prompt: prompt,
              negativePrompt: negativePrompt,
            );
          } else {
            throw Exception('No images in response: ${response.body}');
          }
        } else {
          throw Exception('Server returned ${response.statusCode}: ${response.body}');
        }

      } catch (e, stackTrace) {
        lastError = Exception(e.toString());
        _logger.severe('Error during generation (attempt ${retryCount + 1}): $e');
        _logger.severe('Stack trace: $stackTrace');

        retryCount++;
        if (retryCount < maxRetries) {
          _updateProgress(
              (retryCount / maxRetries) * 0.5,
              'Retry',
              'Attempt failed, retrying ${retryCount + 1}/${maxRetries}...'
          );
          await Future.delayed(retryDelay * retryCount);
        }

      }

    }
    return StableDiffusionResponse(
      success: false,
      error: 'Failed after $maxRetries attempts: ${lastError?.toString()}',
    );

  }

  String _processPrompt(Map<String, String?> outfitDetails, Map<String, dynamic> userPreferences) {
    final List<String> promptParts = [];

    // Quality and base tags (with weights)
    promptParts.addAll([
      '(RAW photo, 8k uhd:1.4)',
      '(masterpiece, best quality, ultra detailed:1.2)',
      '(photorealistic, professional photograph:1.3)',
    ]);

    // Lighting and photography setup
    promptParts.addAll([
      'professional photo shoot',
      '(detailed studio lighting:1.2)',
      'rim light',
      'soft diffused lighting',
      'high end fashion photography',
      'commercial photography',
    ]);

    // Character details
    List<String> characterDetails = [];
    if (userPreferences['gender'] != null) {
      characterDetails.add('${userPreferences['gender'].toLowerCase()}');
    }
    if (userPreferences['race'] != null) {
      final race = userPreferences['race'].toLowerCase();
      switch (race) {
        case 'asian':
          characterDetails.addAll([
            'young asian',
            'beautiful face',
            'perfect skin',
            'clear skin',
          ]);
          break;
      // Add other races as needed
      }
    }
    if (characterDetails.isNotEmpty) {
      promptParts.add('(${characterDetails.join(", ")}:1.2)');
    }

    // Clothing details
    for (var entry in outfitDetails.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        switch(entry.key.toLowerCase()) {
          case 'shirt':
            promptParts.add('(wearing detailed ${entry.value}, high-end fashion, perfect fit:1.3)');
            break;
          case 'pants':
            promptParts.add('(wearing luxury ${entry.value}, designer clothing:1.3)');
            break;
          default:
            promptParts.add('(wearing detailed ${entry.value}:1.2)');
        }
      }
    }

    // Scene and composition
    promptParts.addAll([
      'professional modeling pose',
      'fashion magazine style',
      'clean studio background',
      'depth of field',
      'high contrast',
      'award winning photography',
    ]);

    // Details enhancement
    promptParts.addAll([
      '(detailed facial features:1.2)',
      '(intricate clothing details:1.2)',
      '(designer fashion:1.1)',
      'detailed skin texture',
      'detailed fabric texture',
    ]);

    final prompt = promptParts.join(', ');
    _logger.info('Generated prompt: $prompt');
    return prompt;
  }

  String _generateNegativePrompt(Map<String, dynamic> userPreferences) {
    List<String> negativePrompts = [
      // Quality negatives (weighted)
      '(worst quality, low quality, normal quality:1.4)',
      '(bad_prompt:0.8)',
      'nsfw'
      // Anatomical issues
      '(deformed iris, deformed pupils, bad eyes:1.3)',
      '(bad hands, extra fingers, missing fingers, merged fingers:1.4)',
      '(anatomical errors, bad anatomy, bad proportions:1.3)',
      '(mutation, extra limbs, missing limbs:1.2)',

      // Face and skin issues
      '(ugly, blemishes:1.2)',
      'poorly drawn face',
      'asymmetric face',
      'distorted face',

      // Color and image quality issues
      '(monochrome, grayscale:1.1)',
      'color distortion',
      'unusual colors',
      'unnatural skin color',
      'jpeg artifacts',
      'chromatic aberration',
      'noise',
      'film grain',
      'blurry',
      'bokeh',

      // Composition issues
      'cropped',
      'out of frame',
      'close up',
      'duplicate',
      'multiple views',

      // Style negatives
      '(painting, illustration, drawing, cartoon:1.2)',
      '(3d render, cgi, game art:1.2)',
      '(anime, manga:1.3)',

      // Unwanted elements
      'text',
      'watermark',
      'signature',
      'frame',
      'artist name',
      'logo',

      // Photography issues
      'bad lighting',
      'harsh shadows',
      'overexposed',
      'underexposed',
      'flash photography',

      // MajicMix specific issues
      'deformed ears',
      'unnatural pose',
      'stiff pose',
      'unnatural expression',
    ];

    // Add race-specific negatives
    if (userPreferences['race']?.toLowerCase() == 'asian') {
      negativePrompts.addAll([
        '(western features:1.3)',
        '(european features:1.3)',
        'caucasian',
      ]);
    }

    return negativePrompts.join(', ');
  }

  void _updateProgress(double progress, String stage, String message) {
    _logger.info('Progress update: $stage - $message ($progress)');
    _progressController.add(GenerationProgress(
      progress: progress,
      stage: stage,
      message: message,
    ));
  }

  Future<void> dispose() async {
    await _progressController.close();
  }
}