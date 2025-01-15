import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _logger = Logger('StorageService');

  Future<String?> uploadProfileImage(
      String userId,
      File imageFile, {
        Function(double)? onProgress,
      }) async {
    try {
      // Validate and process image
      final processedImage = await _processImage(imageFile);
      if (processedImage == null) {
        throw Exception('Failed to process image');
      }

      // Check file size after processing
      final fileSize = await processedImage.length();
      if (fileSize > 5 * 1024 * 1024) {
        await processedImage.delete(); // Clean up
        throw Exception('Image size too large (max 5MB)');
      }

      // Create storage reference
      final ref = _storage.ref().child('profiles/$userId/profile.jpg');

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'userId': userId,
        },
      );

      // Start upload task
      final uploadTask = ref.putFile(processedImage, metadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
          _logger.info('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
        onError: (e) => _logger.severe('Upload error: $e'),
      );

      // Wait for upload completion
      await uploadTask;

      // Clean up processed image file
      await processedImage.delete();

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      _logger.info('Successfully uploaded profile image for user: $userId');

      return downloadUrl;
    } on FirebaseException catch (e) {
      _logger.severe('Firebase error uploading profile image: ${e.code}', e);
      throw _getReadableErrorMessage(e.code);
    } catch (e) {
      _logger.severe('Error uploading profile image', e);
      throw 'Failed to upload image. Please try again.';
    }
  }

  Future<File?> _processImage(File imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize if too large
      if (image.width > 1024 || image.height > 1024) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height >= image.width ? 1024 : null,
        );
      }

      // Compress and convert to JPEG
      final compressedBytes = img.encodeJpg(image, quality: 85);

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/processed_profile_image.jpg');

      // Write processed image
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      _logger.severe('Error processing image: $e');
      return null;
    }
  }

  String _getReadableErrorMessage(String code) {
    switch (code) {
      case 'storage/unauthorized':
        return 'Not authorized to upload images. Please sign in again.';
      case 'storage/canceled':
        return 'Upload was cancelled.';
      case 'storage/retry-limit-exceeded':
        return 'Poor network connection. Please try again.';
      case 'storage/invalid-checksum':
        return 'File upload failed. Please try again.';
      default:
        return 'Failed to upload image. Please try again.';
    }
  }
}