import 'package:flutter/material.dart';
import '../../services/config_service.dart';
import '../../services/stable_diffusion_checker.dart';
import 'package:logging/logging.dart';

class StableDiffusionSettingsScreen extends StatefulWidget {
  const StableDiffusionSettingsScreen({super.key});

  @override
  State<StableDiffusionSettingsScreen> createState() => _StableDiffusionSettingsScreenState();
}

class _StableDiffusionSettingsScreenState extends State<StableDiffusionSettingsScreen> {
  final ConfigService _configService = ConfigService();
  final StableDiffusionChecker _checker = StableDiffusionChecker();
  final _urlController = TextEditingController();
  final _logger = Logger('StableDiffusionSettingsScreen');

  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    setState(() => _isLoading = true);
    try {
      final url = await _configService.getStableDiffusionUrl();
      _urlController.text = url;
      await _checkConnection(url);
    } catch (e) {
      _logger.severe('Error loading current URL: $e');
      setState(() {
        _errorMessage = 'Failed to load current URL';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConnection(String url) async {
    setState(() => _isLoading = true);
    try {
      final isConnected = await _checker.checkConnection(url);
      setState(() {
        _isConnected = isConnected;
        _errorMessage = isConnected ? null : 'Could not connect to server';
      });
    } catch (e) {
      _logger.warning('Connection check failed: $e');
      setState(() {
        _isConnected = false;
        _errorMessage = 'Connection failed: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stable Diffusion Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Server Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _isConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.error_outline, color: Colors.red),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // URL Input Field
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'Enter Stable Diffusion server URL',
                          errorText: _errorMessage,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                        ),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () async {
                                await _checkConnection(_urlController.text);
                                if (_isConnected) {
                                  await _configService.setStableDiffusionUrl(_urlController.text);
                                }
                              },
                              child: _isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text('Save & Test'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _isLoading ? null : () async {
                              await _configService.resetToDefaultUrl();
                              await _loadCurrentUrl();
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Setup Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionStep(
                        1,
                        'Install Stable Diffusion',
                        'Download and install Stable Diffusion WebUI',
                      ),
                      _buildInstructionStep(
                        2,
                        'Start the Server',
                        'Launch with the --api flag enabled',
                      ),
                      _buildInstructionStep(
                        3,
                        'Configure Connection',
                        'Enter the server URL and test connection',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}