/// E2E Emulator Main Entry Point - Firebase Emulator Integration
/// This main entry point is designed for E2E tests that require Firebase
/// operations but use the Firebase emulator for isolated, reproducible testing.
/// It provides real Firebase functionality without affecting production data.
/// ULTRATHINK ANALYSIS:
/// - Production main.dart initializes Firebase with production config
/// - E2E tests need real Firebase operations for authentication/data flows
/// - Emulator approach provides realistic Firebase testing with isolation
library;

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Core application
import 'package:butlery/main.dart';

// Firebase configuration - using a test/demo project
import 'package:butlery/firebase_options.dart';

// Bootstrap system
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/stages/platform_stage.dart';
import 'package:butlery/core/bootstrap/stages/core_stage.dart';
import 'package:butlery/core/bootstrap/stages/content_stage.dart';
import 'package:butlery/core/bootstrap/stages/social_stage.dart';
import 'package:butlery/core/bootstrap/stages/ui_stage.dart';

// DI modules
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/performance_module.dart';
import 'package:butlery/core/di/modules/ui_module.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// E2E Emulator Application Entry Point
/// This entry point provides complete Butlery app functionality for E2E testing
/// with Firebase emulator integration. Perfect for testing authentication flows,
/// data persistence, real-time features, and Firebase operations.
/// REQUIREMENTS:
/// - Firebase emulators must be running: `firebase emulators:start`
/// - Emulator ports: Firestore (8080), Auth (9099), Storage (9199)
/// USAGE:
/// ```dart
/// // In E2E tests:
/// import 'package:butlery/main_e2e_emulator.dart' as emulator_app;
/// testWidgets('Firebase flow test', (tester) async {
///   emulator_app.main();
///   await tester.pumpAndSettle();
///   // Test Firebase operations...
/// });
/// ```
Future<void> main() async {
  try {
    // Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with default options (will connect to emulators)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Connect to Firebase emulators
    await _connectToE2EEmulators();

    // Initialize modular system
    await _initializeE2EEmulatorSystem();

    // Start the application
    runApp(const ButleryApp());
  } catch (e, stackTrace) {
    // Show error app with E2E-specific message
    runApp(_E2EEmulatorErrorApp(
        'E2E Emulator initialization failed: $e\n\nStack trace:\n$stackTrace'));
  }
}

/// Connect to Firebase emulators for E2E testing
/// This connects all Firebase services to their respective emulators
/// using the standard emulator ports from firebase.json configuration.
Future<void> _connectToE2EEmulators() async {
  try {
    const emulatorHost = 'localhost';

    // Connect Firestore emulator (port 8080)
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);

    // Connect Auth emulator (port 9099)
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);

    // Connect Storage emulator (port 9199)
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  } catch (e) {
    throw Exception('Firebase emulator connection failed: $e');
  }
}

/// Initialize the modular system for E2E emulator testing
/// This creates the same modular system as production but configured for
/// E2E emulator testing with Firebase emulator connections.
Future<void> _initializeE2EEmulatorSystem() async {
  // Create DI modules in dependency order - same as production
  final modules = [
    CoreModule(),
    ContentModule(),
    SocialModule(),
    MessagingModule(),
    CollaborationModule(),
    PerformanceModule(),
    UIModule(), // ViewModels and UI services
  ];

  // Create bootstrap stages - same as production
  final stages = [
    PlatformStage(),
    CoreStage(),
    ContentStage(),
    SocialStage(),
    UIStage(),
  ];

  // Initialize with modules and stages
  // Firebase services will connect to emulators automatically
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );
}

/// Error app widget for E2E emulator initialization failures
class _E2EEmulatorErrorApp extends StatelessWidget {
  final String message;

  const _E2EEmulatorErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2E Emulator Error',
      home: Scaffold(
        backgroundColor: AppColors.warningContainer,
        appBar: AppBar(
          title: const Text('E2E Emulator Error'),
          backgroundColor: AppColors.warning,
          foregroundColor: AppColors.cardWhite,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_outlined,
                size: AppDimensions.iconSizeXxl,
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              const Text(
                'E2E Emulator Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The E2E Emulator application failed to start. Make sure Firebase emulators are running:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                child: const Text(
                  'firebase emulators:start --only firestore,auth,storage',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
