// screen/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_page.dart';
import 'settings_screen.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../../preferences_provider.dart';
import '../../providers/user_provider.dart';
//import 'package:firebase_storage/firebase_storage.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _initializeUserPreferences();
  }

  Future<void> _initializeUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        setState(() => _isLoading = true);

        // Get user document
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          // Initialize document with empty preferences if it doesn't exist
          await _firestoreService.initializeUserDocument(user.uid);
        }

        // Load preferences
        final preferences = doc.data()?['preferences'] as Map<String, dynamic>? ?? {};

        if (mounted) {
          final provider = Provider.of<PreferencesProvider>(context, listen: false);
          provider.setGender(preferences['gender'] ?? '');
          provider.setBodyType(preferences['bodyType'] ?? '');
          provider.setStyle(preferences['style'] ?? '');
          provider.setRace(preferences['race'] ?? '');
        }
      } catch (e) {
        debugPrint('Error initializing preferences: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  Future<void> _loadUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          final preferences = doc.data()?['preferences'] as Map<String, dynamic>?;
          if (preferences != null) {
            final provider = Provider.of<PreferencesProvider>(context, listen: false);
            provider.setGender(preferences['gender'] ?? '');
            provider.setBodyType(preferences['bodyType'] ?? '');
            provider.setStyle(preferences['style'] ?? '');
            provider.setRace(preferences['race'] ?? '');
          }
        }
      } catch (e) {
        debugPrint('Error loading preferences: $e');
      }
    }
  }

  Future<void> _editPreferences() async {
    if (!mounted) return;

    final preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => PreferencesDialog(
        initialGender: preferencesProvider.gender,
        initialBodyType: preferencesProvider.bodyType,
        initialStyle: preferencesProvider.style,
        initialRace: preferencesProvider.race,
      ),
    );

    if (result != null && mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Save to Firestore
          await _firestoreService.saveOutfitPreferences(user.uid, result);

          // Update provider
          preferencesProvider.setGender(result['gender'] ?? '');
          preferencesProvider.setBodyType(result['bodyType'] ?? '');
          preferencesProvider.setStyle(result['style'] ?? '');
          preferencesProvider.setRace(result['race'] ?? '');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving preferences: $e')),
          );
        }
      }
    }
  }
  Future<void> _handleImageUpload() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to update profile photo');
      }

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(pickedFile.path);
      double? uploadProgress;

      // Use StorageService instead of direct Firebase Storage calls
      final url = await _storageService.uploadProfileImage(
        user.uid,
        file,
        onProgress: (progress) {
          if (mounted && (uploadProgress == null || progress - uploadProgress! > 0.1)) {
            setState(() => uploadProgress = progress);
          }
        },
      );

      if (url != null && mounted) {
        // Update user provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateUserPhoto(url);

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'photoURL': url,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red[400],
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _editProfile() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _EditProfileDialog(),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(result['name']);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final preferencesProvider = Provider.of<PreferencesProvider>(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image Section
                Center(
                  child: Consumer<UserProvider>(
                    builder: (context, userProvider, _) => GestureDetector(
                      onTap: _handleImageUpload,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50.r,
                            backgroundImage: userProvider.user?.photoURL != null
                                ? NetworkImage(userProvider.user!.photoURL!)
                                : null,
                            child: (userProvider.user?.photoURL == null)
                                ? Icon(Icons.person, size: 50.sp)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 15.r,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Icon(Icons.camera_alt, size: 15.sp, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // User Info Section
                Center(
                  child: Column(
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Preferences Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Personal Preferences',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: _editPreferences,
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        _buildPreferenceItem('Gender', preferencesProvider.gender),
                        _buildPreferenceItem('Body Type', preferencesProvider.bodyType),
                        _buildPreferenceItem('Style', preferencesProvider.style),
                        _buildPreferenceItem('Race', preferencesProvider.race),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Actions Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildActionTile(
                        icon: Icons.edit,
                        title: 'Edit Profile',
                        onTap: _editProfile,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        icon: Icons.settings,
                        title: 'Settings',
                        onTap: _handleSettings,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        onTap: _handleLogout,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildPreferenceItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value ?? 'Not set',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

// Dialog classes
class _EditProfileDialog extends StatelessWidget {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {'name': _nameController.text}),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PreferencesDialog extends StatefulWidget {
  final String? initialGender;
  final String? initialBodyType;
  final String? initialStyle;
  final String? initialRace;

  const PreferencesDialog({
    super.key,  // Changed this line to use super parameter
    this.initialGender,
    this.initialBodyType,
    this.initialStyle,
    this.initialRace,
  });

  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  late String? _gender;
  late String? _bodyType;
  late String? _style;
  late String? _race;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bodyTypes = ['Slim', 'Average', 'Athletic', 'Plus Size'];
  final List<String> _styles = ['Casual', 'Formal', 'Sporty', 'Elegant'];
  final List<String> _races = ['Asian', 'Black', 'Hispanic', 'White', 'Other'];

  @override
  void initState() {
    super.initState();
    _gender = widget.initialGender;
    _bodyType = widget.initialBodyType;
    _style = widget.initialStyle;
    _race = widget.initialRace;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Preferences'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown(
              label: 'Gender',
              value: _gender,
              items: _genders,
              onChanged: (value) => setState(() => _gender = value),
            ),
            _buildDropdown(
              label: 'Body Type',
              value: _bodyType,
              items: _bodyTypes,
              onChanged: (value) => setState(() => _bodyType = value),
            ),
            _buildDropdown(
              label: 'Style',
              value: _style,
              items: _styles,
              onChanged: (value) => setState(() => _style = value),
            ),
            _buildDropdown(
              label: 'Race',
              value: _race,
              items: _races,
              onChanged: (value) => setState(() => _race = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'gender': _gender ?? '',
            'bodyType': _bodyType ?? '',
            'style': _style ?? '',
            'race': _race ?? '',
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: value,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

