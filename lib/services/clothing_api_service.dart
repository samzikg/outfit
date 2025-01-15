import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';
import 'package:logging/logging.dart';

class ClothingApiService {
  final _logger = Logger('ClothingApiService');
  final String _apiKey = 'GjuRFqFOq6OqLsrYADHN75vZ0aE0omy20WdqYq55LDCAwjzs7iJC93ZX';
  final String _baseUrl = 'https://api.pexels.com/v1';

  // Category-specific search terms to get more relevant images
  final Map<String, String> _categoryQueries = {
    'Shirt': 'tshirt fashion clothing top',
    'Pants': 'pants trousers jeans',
    'Headpiece': 'hat cap headwear',
  };

  Future<List<ClothingItem>> getAllClothing() async {
    try {
      List<ClothingItem> allItems = [];

      // Fetch items for each category
      for (var category in _categoryQueries.keys) {
        final items = await getClothingByCategory(category);
        allItems.addAll(items);
      }

      return allItems;
    } catch (e, stackTrace) {
      _logger.severe('Error getting all clothing items', e, stackTrace);
      throw Exception('Error: $e');
    }
  }

  Future<List<ClothingItem>> getClothingByCategory(String category) async {
    try {
      final query = category == 'All'
          ? 'fashion clothing'
          : _categoryQueries[category] ?? '$category fashion';

      final response = await http.get(
        Uri.parse('$_baseUrl/search?query=$query&per_page=30&orientation=portrait'),
        headers: {'Authorization': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['photos'] as List).map((photo) {
          // Generate realistic-looking price
          final price = 20.0 + (photo['id'] % 80); // Prices between $20 and $100

          return ClothingItem(
            id: photo['id'],
            title: _generateItemTitle(category, photo['id']),
            price: price,
            description: _generateDescription(category, price),
            category: category,
            imageUrl: photo['src']['medium'],
          );
        }).toList();
      }

      throw Exception('Failed to load images: ${response.statusCode}');
    } catch (e, stackTrace) {
      _logger.severe('Error getting clothing by category: $category', e, stackTrace);
      throw Exception('Error: $e');
    }
  }

  String _generateItemTitle(String category, int id) {
    final styles = ['Classic', 'Modern', 'Casual', 'Elegant', 'Trendy'];
    final style = styles[id % styles.length];

    switch (category) {
      case 'Shirt':
        return '$style ${_getShirtType(id)} Shirt';
      case 'Pants':
        return '$style ${_getPantsType(id)}';
      case 'Headpiece':
        return '$style ${_getHeadpieceType(id)}';
      default:
        return '$style Fashion Item';
    }
  }

  String _getShirtType(int id) {
    final types = ['Crew Neck', 'V-Neck', 'Polo', 'Button-Up', 'Henley'];
    return types[id % types.length];
  }

  String _getPantsType(int id) {
    final types = ['Jeans', 'Chinos', 'Slacks', 'Khakis', 'Dress Pants'];
    return types[id % types.length];
  }

  String _getHeadpieceType(int id) {
    final types = ['Baseball Cap', 'Beanie', 'Fedora', 'Bucket Hat', 'Snapback'];
    return types[id % types.length];
  }

  String _generateDescription(String category, double price) {
    final quality = price > 60 ? 'Premium' : 'Standard';
    return 'High-quality $quality $category. Perfect for any occasion. Comfortable and stylish.';
  }
}