import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'result_screen.dart';
import '../services/clothing_api_service.dart';
import '../models/clothing_item.dart';

class DesignConfigScreen extends StatefulWidget {
  const DesignConfigScreen({super.key});

  @override
  State<DesignConfigScreen> createState() => _DesignConfigScreenState();
}

class _DesignConfigScreenState extends State<DesignConfigScreen> {
  final ClothingApiService _apiService = ClothingApiService();
  final _logger = Logger('DesignConfigScreen');
  List<ClothingItem> clothingItems = [];
  bool isLoading = true;

  final Map<String, ClothingItem?> selectedOutfits = {
    'headpiece': null,
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
          : Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildItemsList(),
          ),
          Expanded(
            flex: 3,
            child: _buildDropZones(),
          ),
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      padding: const EdgeInsets.all(10),
      itemCount: clothingItems.length,
      itemBuilder: (context, index) {
        final item = clothingItems[index];
        return Draggable<ClothingItem>(
          data: item,
          feedback: _buildDragFeedback(item),
          childWhenDragging: Container(),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropZones() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildDropZone('shirt'),
        _buildDropZone('pants'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: ElevatedButton.icon(
            onPressed: _handleGenerateOutfit,
            icon: const Icon(Icons.style),
            label: const Text('Generate Outfit'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropZone(String category) {
    return DragTarget<ClothingItem>(
      onAcceptWithDetails: (details) {
        if (details.data.category.toLowerCase() == category.toLowerCase()) {
          setState(() {
            selectedOutfits[category] = details.data;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This item is not a $category'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final selectedItem = selectedOutfits[category];
        return Container(
          width: 200,
          height: 200,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey,
              width: 2,
              style: BorderStyle.solid, // Changed from dashed to solid
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: selectedItem != null
              ? _buildSelectedItemView(selectedItem, category)
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category),
                  size: 32,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  'Drop $category here',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'shirt':
        return Icons.person_outline;
      case 'pants':
        return Icons.straight;
      case 'headpiece':
        return Icons.face;
      default:
        return Icons.category;
    }
  }

  Widget _buildSelectedItemView(ClothingItem item, String category) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            onPressed: () => setState(() {
              selectedOutfits[category] = null;
            }),
            icon: const Icon(Icons.clear),
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildDragFeedback(ClothingItem item) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGenerateOutfit() {
    if (selectedOutfits.values.any((item) => item != null)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            selectedOutfits: selectedOutfits,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}