import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'dart:io';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _logger = Logger('StorageService');

  Future<String?> uploadOutfitImage(String userId, File imageFile) async {
    try {
      final String fileName = 'outfits/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.severe('Error uploading image: $e');
      return null;
    }
  }
}