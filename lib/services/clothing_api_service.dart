import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';
import 'package:logging/logging.dart';

class ClothingApiService {
  final _logger = Logger('ClothingApiService');
  final String _apiKey = 'GjuRFqFOq6OqLsrYADHN75vZ0aE0omy20WdqYq55LDCAwjzs7iJC93ZX';
  final String _baseUrl = 'https://api.pexels.com/v1';

  Future<List<ClothingItem>> getAllClothing() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search?query=fashion clothing&per_page=80&orientation=portrait'),
        headers: {'Authorization': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['photos'] as List).map((photo) => ClothingItem(
          id: photo['id'],
          title: 'Fashion Item ${photo['id']}',
          price: 0.0,
          description: '',
          category: 'All',
          imageUrl: photo['src']['medium'],
        )).toList();
      }

      throw Exception('Failed to load images: ${response.statusCode}');
    } catch (e, stackTrace) {
      _logger.severe('Error getting clothing items', e, stackTrace);
      throw Exception('Error: $e');
    }
  }

  Future<List<ClothingItem>> getClothingByCategory(String category) async {
    try {
      final query = category.toLowerCase() == 'all'
          ? 'fashion clothing'
          : '$category fashion';

      final response = await http.get(
        Uri.parse('$_baseUrl/search?query=$query&per_page=30&orientation=portrait'),
        headers: {'Authorization': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['photos'] as List).map((photo) => ClothingItem(
          id: photo['id'],
          title: '${category.capitalize()} ${photo['id']}',
          price: 0.0,
          description: '',
          category: category,
          imageUrl: photo['src']['medium'],
        )).toList();
      }

      throw Exception('Failed to load images: ${response.statusCode}');
    } catch (e) {
      _logger.severe('Error getting clothing by category', e);
      throw Exception('Error: $e');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}