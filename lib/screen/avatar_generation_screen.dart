import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/outfit_generation_coordinator.dart';
import '../services/firestore_service.dart';
import '../preferences_provider.dart';
import '../models/clothing_item.dart';
import '../widgets/generation_process_widget.dart';
import '../widgets/loading_overlay.dart';
class AvatarGenerationScreen extends StatefulWidget {
  final Map<String, ClothingItem?> selectedOutfits;
  final String avatarFace;

  const AvatarGenerationScreen({
    super.key,
    required this.selectedOutfits,
    required this.avatarFace,
  });

  @override
  State<AvatarGenerationScreen> createState() => _AvatarGenerationScreenState();
}

class _AvatarGenerationScreenState extends State<AvatarGenerationScreen> {
  late final OutfitGenerationCoordinator _coordinator;
  late final FirestoreService _firestoreService;
  GenerationStatus? _status;
  String? _generatedImage;
  bool _isGenerating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _coordinator = OutfitGenerationCoordinator();
    _firestoreService = FirestoreService();
    _startGeneration();

    // Listen to generation status updates
    _coordinator.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _generatedImage = null;
    });

    try {
      final preferences = Provider.of<PreferencesProvider>(context, listen: false);

      final result = await _coordinator.generateCompleteOutfit(
        selectedOutfits: widget.selectedOutfits,
        avatarFace: widget.avatarFace,
        preferences: preferences,
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          if (result.success && result.image != null) {
            _generatedImage = result.image;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  Future<void> _saveOutfit() async {
    if (_generatedImage == null || _isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save outfits')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final preferences = Provider.of<PreferencesProvider>(context, listen: false);

      await _firestoreService.saveFavoriteOutfit(user.uid, {
        'imageUrl': _generatedImage,
        'outfitName': 'Generated Outfit',
        'description': _generateOutfitDescription(),
        'preferences': preferences.toMap(),
        'selectedOutfits': widget.selectedOutfits.map(
                (key, value) => MapEntry(key, value?.title ?? 'None')
        ),
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outfit saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save outfit: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _generateOutfitDescription() {
    final outfitParts = widget.selectedOutfits.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}: ${entry.value!.title}')
        .join(', ');
    return 'Custom outfit with $outfitParts';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Avatar'),
        actions: [
          if (!_isGenerating && _generatedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startGeneration,
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (_status != null)
                  GenerationProgressWidget(
                    message: _status!.message,
                    progress: _status!.progress,
                    isError: _status!.error != null,
                    onRetry: !_isGenerating ? _startGeneration : null,
                  ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
          if (_isSaving)
            const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isGenerating && _generatedImage == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating your custom outfit...'),
          ],
        ),
      );
    }

    if (_generatedImage == null) {
      return const Center(
        child: Text('No image generated yet'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(_generatedImage!),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildOutfitDetails(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startGeneration,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveOutfit,
                  icon: const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.selectedOutfits.entries.map((entry) {
              final item = entry.value;
              return ListTile(
                leading: item?.imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item!.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
                    : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.brush, color: Colors.grey),
                ),
                title: Text(entry.key.toUpperCase()),
                subtitle: Text(
                  item?.title ?? 'None selected',
                  style: TextStyle(
                    color: item == null ? Colors.grey : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}