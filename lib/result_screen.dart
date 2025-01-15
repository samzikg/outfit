import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/stable_diffusion_service.dart';
import '../services/firestore_service.dart';
import '../models/clothing_item.dart';
import '../preferences_provider.dart';
import '../widgets/generation_process_widget.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, ClothingItem?> selectedOutfits;

  const ResultScreen({
    super.key,
    required this.selectedOutfits,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final StableDiffusionService _sdService = StableDiffusionService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _generatedImage;
  String? _error;
  late final PreferencesProvider _preferencesProvider;

  @override
  void initState() {
    super.initState();
    _preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);
    _generateOutfit();
  }

  Future<void> _generateOutfit() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final isServerAvailable = await _sdService.checkServerStatus();
      if (!isServerAvailable) {
        throw Exception('Server not available. Check your connection.');
      }

      final outfitDetails = widget.selectedOutfits.map(
              (key, value) => MapEntry(key, value?.title ?? '')
      );

      final result = await _sdService.generateOutfitImage(
        outfitDetails,
        _preferencesProvider.toMap(),
      );

      if (!mounted) return;

      setState(() {
        if (result.success && result.image != null) {
          _generatedImage = result.image;
          _error = null;
          _saveToDesignHistory(result);
        } else {
          _error = result.error ?? 'Generation failed';
          _generatedImage = null;
        }
        _isGenerating = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveToDesignHistory(StableDiffusionResponse result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || result.image == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('designs')
          .add({
        'imageUrl': result.image,
        'outfitName': 'Generated Outfit',
        'description': _getOutfitDescription(),
        'createdAt': FieldValue.serverTimestamp(),
        'prompt': result.prompt,
        'negativePrompt': result.negativePrompt,
        'metadata': result.metadata,
      });
    } catch (e) {
      debugPrint('Error saving to design history: $e');
    }
  }

  Future<void> _saveToFavorites() async {
    if (_isSaving || _generatedImage == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save favorites'))
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestoreService.saveFavoriteOutfit(user.uid, {
        'imageUrl': _generatedImage,
        'outfitName': 'Generated Outfit',
        'description': _getOutfitDescription(),
        'timestamp': DateTime.now().toIso8601String(),
        'preferences': _preferencesProvider.toMap(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to favorites!'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getOutfitDescription() {
    return widget.selectedOutfits.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}: ${entry.value!.title}')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Outfit'),
        actions: [
          if (!_isGenerating && _generatedImage != null)
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: _isSaving ? null : _saveToFavorites,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateOutfit,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildGenerationContent(),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildSelectedItems(),
              ),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _generatedImage != null ? FloatingActionButton(
        onPressed: _saveToFavorites,
        child: const Icon(Icons.favorite),
      ) : null,
    );
  }

  Widget _buildGenerationContent() {
    if (_isGenerating) {
      return const GenerationProgressWidget(
        message: 'Generating your outfit...',
        progress: 0.5,
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateOutfit,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_generatedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            base64Decode(_generatedImage!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Failed to display generated image'),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'save',
                  onPressed: _saveToFavorites,
                  child: const Icon(Icons.favorite_border),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'regenerate',
                  onPressed: _generateOutfit,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text('No image generated yet'),
    );
  }

  Widget _buildSelectedItems() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: widget.selectedOutfits.entries.map((entry) {
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: item?.imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item!.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.image_not_supported),
                    title: Text(item?.title ?? 'No ${entry.key} selected'),
                    subtitle: item?.price != null
                        ? Text('\$${item!.price.toStringAsFixed(2)}')
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}