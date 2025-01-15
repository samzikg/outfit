import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img;

class AvatarService {
  final _logger = Logger('AvatarService');

  Future<String?> processAvatarImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if necessary
      if (image.width > 512 || image.height > 512) {
        image = img.copyResize(
          image,
          width: 512,
          height: (512 * image.height / image.width).round(),
        );
      }

      final processedBytes = img.encodeJpg(image, quality: 85);
      return base64Encode(processedBytes);

    } catch (e) {
      _logger.severe('Error processing avatar image: $e');
      return null;
    }
  }

  bool validateAvatarImage(String base64Image) {
    try {
      final bytes = base64Decode(base64Image);
      final image = img.decodeImage(bytes);

      if (image == null) return false;

      if (image.width < 256 || image.height < 256) return false;

      final aspectRatio = image.width / image.height;
      if (aspectRatio < 0.5 || aspectRatio > 2.0) return false;

      return true;
    } catch (e) {
      _logger.warning('Error validating avatar image: $e');
      return false;
    }
  }
}