import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'launch_screen.dart';
import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging with more detailed output
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
      debugPrint('Stack trace: ${record.stackTrace}');
    }
  });

  try {
    debugPrint('Attempting to initialize Firebase...');
    // Initialize Firebase with explicit platform check
    if (kIsWeb) {
      debugPrint('Initializing Firebase for Web...');
    } else {
      debugPrint('Initializing Firebase for Mobile...');
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase core initialization successful');

    // Set persistence based on platform with error handling
    try {
      if (!kIsWeb) {
        debugPrint('Setting LOCAL persistence for mobile...');
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        debugPrint('LOCAL persistence set successfully');
      } else {
        debugPrint('Setting SESSION persistence for web...');
        await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
        debugPrint('SESSION persistence set successfully');
      }
    } catch (persistenceError) {
      debugPrint('Error setting persistence: $persistenceError');
      // Continue anyway as this is not critical
    }

    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Detailed initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    Logger('main').severe('Error initializing Firebase', e, stackTrace);
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outfit System Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LaunchScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Proper retry initialization
                    try {
                      await Firebase.initializeApp(
                        options: DefaultFirebaseOptions.currentPlatform,
                      );
                      if (!kIsWeb) {
                        await FirebaseAuth.instance
                            .setPersistence(Persistence.LOCAL);
                      } else {
                        await FirebaseAuth.instance
                            .setPersistence(Persistence.SESSION);
                      }
                      runApp(const MyApp());
                    } catch (e) {
                      Logger('ErrorApp')
                          .severe('Error during retry initialization', e);
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}