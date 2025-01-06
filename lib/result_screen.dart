import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:convert';  // Add this for base64Decode
import '../services/stable_diffusion_service.dart';
import '../models/clothing_item.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, ClothingItem?> selectedOutfits;  // Changed type

  const ResultScreen({
    super.key,
    required this.selectedOutfits,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _logger = Logger('ResultScreen');
  final StableDiffusionService _sdService = StableDiffusionService();
  bool _isGenerating = false;
  String? _generatedImageBase64;

  Map<String, String> _getOutfitDescriptions() {
    return {
      'headpiece': widget.selectedOutfits['headpiece']?.title ?? '',
      'shirt': widget.selectedOutfits['shirt']?.title ?? '',
      'pants': widget.selectedOutfits['pants']?.title ?? '',
    };
  }

  @override
  void initState() {
    super.initState();
    _generateOutfit();
  }

  Future<void> _generateOutfit() async {
    setState(() => _isGenerating = true);

    try {
      // Convert ClothingItems to strings for the API
      final outfitDescriptions = _getOutfitDescriptions();
      final imageBase64 = await _sdService.generateOutfitImage(outfitDescriptions);

      if (mounted) {
        setState(() {
          _generatedImageBase64 = imageBase64;
          _isGenerating = false;
        });
      }
    } catch (e) {
      _logger.severe('Error generating outfit image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error generating outfit image')),
        );
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generated Outfit"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateOutfit,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: _isGenerating
                  ? const CircularProgressIndicator()
                  : _buildOutfitImage(),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildOutfitDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitImage() {
    if (_generatedImageBase64 == null) {
      return Container(
        width: 300,
        height: 400,
        color: Colors.grey[300],
        child: const Icon(Icons.person, size: 100),
      );
    }

    return Image.memory(
      base64Decode(_generatedImageBase64!),
      width: 300,
      height: 400,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        _logger.warning('Error displaying image: $error');
        return Container(
          width: 300,
          height: 400,
          color: Colors.grey[300],
          child: const Icon(Icons.error, size: 100),
        );
      },
    );
  }

  Widget _buildOutfitDetails() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Selected Outfit Details",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: widget.selectedOutfits.entries.map((entry) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      "${entry.key}: ${entry.value?.title ?? 'None'}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back to Design"),
          ),
        ],
      ),
    );
  }
}