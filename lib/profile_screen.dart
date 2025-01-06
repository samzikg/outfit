import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  String? _selectedGender;
  String? _selectedBodyType;
  String? _selectedStyle;
  String? _selectedRace;

  Future<void> _savePreferences() async {
    if (user == null) return;

    await _firestoreService.saveOutfitPreferences(user!.uid, {
      'gender': _selectedGender,
      'bodyType': _selectedBodyType,
      'style': _selectedStyle,
      'race': _selectedRace,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved successfully!')),
      );
    }
  }

  Widget _buildDropdownRow(String label, List<String> options, String? value, Function(String?) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        DropdownButton<String>(
          value: value,
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            user?.displayName ?? 'User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildDropdownRow(
            'Choose Gender:',
            ['Male', 'Female', 'Other'],
            _selectedGender,
                (value) => setState(() => _selectedGender = value),
          ),
          const SizedBox(height: 20),
          _buildDropdownRow(
            'Choose Body Type:',
            ['Slim', 'Athletic', 'Average', 'Heavy'],
            _selectedBodyType,
                (value) => setState(() => _selectedBodyType = value),
          ),
          const SizedBox(height: 20),
          _buildDropdownRow(
            'Choose Style:',
            ['Casual', 'Formal', 'Sporty'],
            _selectedStyle,
                (value) => setState(() => _selectedStyle = value),
          ),
          const SizedBox(height: 20),
          _buildDropdownRow(
            'Choose Race:',
            ['Asian', 'Black', 'Caucasian', 'Hispanic'],
            _selectedRace,
                (value) => setState(() => _selectedRace = value),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _savePreferences,
            child: const Text('Save Preferences'),
          ),
        ],
      ),
    );
  }
}