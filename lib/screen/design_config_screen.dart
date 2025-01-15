import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../result_screen.dart';
import '../../services/clothing_api_service.dart';
import '../../models/clothing_item.dart';

class DesignConfigScreen extends StatefulWidget {
  const DesignConfigScreen({super.key});

  @override
  State<DesignConfigScreen> createState() => _DesignConfigScreenState();
}

class _DesignConfigScreenState extends State<DesignConfigScreen> {
  final ClothingApiService _apiService = ClothingApiService();
  final _logger = Logger('DesignConfigScreen');
  final ScrollController _scrollController = ScrollController();

  List<ClothingItem> clothingItems = [];
  bool isLoading = true;

  final Map<String, ClothingItem?> selectedOutfits = {
    'shirt': null,
    'pants': null,
  };

  @override
  void initState() {
    super.initState();
    _loadClothingItems();
  }

  Future<void> _loadClothingItems() async {
    setState(() => isLoading = true);
    try {
      final items = await _apiService.getAllClothing();
      setState(() {
        clothingItems = items;
        isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading items: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Your Outfit'),
        actions: [
          IconButton(
            onPressed: _loadClothingItems,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // Items Grid
                Expanded(
                  flex: 1,
                  child: _buildItemsList(),
                ),
                // Drop Zones
                Expanded(
                  flex: 1,
                  child: _buildDropZones(),
                ),
              ],
            ),
          ),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (clothingItems.isEmpty) {
      return const Center(
        child: Text('No items available'),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        padding: const EdgeInsets.all(8),
        itemCount: clothingItems.length,
        itemBuilder: (context, index) {
          final item = clothingItems[index];
          return Draggable<ClothingItem>(
            data: item,
            feedback: _buildDragFeedback(item),
            childWhenDragging: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropZones() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDropZone('shirt'),
          const SizedBox(height: 16),
          _buildDropZone('pants'),
        ],
      ),
    );
  }

  Widget _buildDropZone(String category) {
    return DragTarget<ClothingItem>(
      onAcceptWithDetails: (details) {
        setState(() {
          selectedOutfits[category] = details.data;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final selectedItem = selectedOutfits[category];
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: selectedItem != null
              ? Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    selectedItem.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      selectedOutfits[category] = null;
                    });
                  },
                ),
              ),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category == 'shirt' ? Icons.person : Icons.straighten,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                'Drop ${category.toLowerCase()} here',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragFeedback(ClothingItem item) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: selectedOutfits.values.any((item) => item != null)
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                selectedOutfits: selectedOutfits,
              ),
            ),
          )
              : null,
          icon: const Icon(Icons.style),
          label: const Text('Generate Outfit'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}