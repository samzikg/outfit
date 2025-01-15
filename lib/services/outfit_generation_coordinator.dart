import 'dart:async';
import 'package:logging/logging.dart';
import '../models/clothing_item.dart';
import '../services/roop_stable_diffusion_service.dart';
import '../preferences_provider.dart';

enum GenerationStep {
  preparingData,
  generatingOutfit,
  completed,
  error
}

class GenerationStatus {
  final GenerationStep step;
  final double progress;
  final String message;
  final String? error;

  GenerationStatus({
    required this.step,
    required this.progress,
    required this.message,
    this.error,
  });
}

class GenerationResult {
  final bool success;
  final String? image;
  final String? error;
  final Map<String, dynamic>? metadata;

  GenerationResult({
    required this.success,
    this.image,
    this.error,
    this.metadata,
  });
}

class OutfitGenerationCoordinator {
  final _logger = Logger('OutfitGenerationCoordinator');
  final RoopStableDiffusionService _sdService;

  final _statusController = StreamController<GenerationStatus>.broadcast();
  Stream<GenerationStatus> get statusStream => _statusController.stream;

  OutfitGenerationCoordinator({
    RoopStableDiffusionService? sdService,
  }) : _sdService = sdService ?? RoopStableDiffusionService();

  Future<GenerationResult> generateCompleteOutfit({
    required Map<String, ClothingItem?> selectedOutfits,
    required String avatarFace,
    required PreferencesProvider preferences,
  }) async {
    try {
      _updateStatus(
        GenerationStep.preparingData,
        0.1,
        'Preparing generation data...',
      );

      final outfitDetails = _prepareOutfitDetails(selectedOutfits);
      final userPrefs = preferences.toMap();

      _updateStatus(
        GenerationStep.generatingOutfit,
        0.3,
        'Generating outfit...',
      );

      final result = await _sdService.generateImageWithFaceSwap(
        outfitDetails: outfitDetails,
        preferences: userPrefs,
        sourceImage: avatarFace,
      );

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Generation failed');
      }

      _updateStatus(
        GenerationStep.completed,
        1.0,
        'Generation completed successfully!',
      );

      return GenerationResult(
        success: true,
        image: result['image'],
        metadata: result['metadata'],
      );

    } catch (e, stackTrace) {
      _logger.severe('Error during outfit generation', e, stackTrace);

      _updateStatus(
        GenerationStep.error,
        0,
        'Generation failed',
        error: e.toString(),
      );

      return GenerationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Map<String, String> _prepareOutfitDetails(Map<String, ClothingItem?> selectedOutfits) {
    return Map.fromEntries(
        selectedOutfits.entries
            .where((entry) => entry.value != null)
            .map((entry) => MapEntry(entry.key, entry.value!.title))
    );
  }

  void _updateStatus(
      GenerationStep step,
      double progress,
      String message, {
        String? error,
      }) {
    _statusController.add(GenerationStatus(
      step: step,
      progress: progress,
      message: message,
      error: error,
    ));
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}