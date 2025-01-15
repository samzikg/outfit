import 'package:flutter/material.dart';

class PhotoGuidelinesSheet extends StatelessWidget {
  const PhotoGuidelinesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Photo Guidelines',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildGuideline(
              icon: Icons.face,
              title: 'Clear Face',
              description: 'Ensure your face is clearly visible and well-lit',
            ),
            _buildGuideline(
              icon: Icons.rotate_right,
              title: 'Straight Ahead',
              description: 'Look directly at the camera, avoid tilting your head',
            ),
            _buildGuideline(
              icon: Icons.wb_sunny,
              title: 'Good Lighting',
              description: 'Take photo in well-lit conditions, avoid harsh shadows',
            ),
            _buildGuideline(
              icon: Icons.crop_free,
              title: 'No Filters',
              description: 'Use original photos without filters or effects',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideline({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}