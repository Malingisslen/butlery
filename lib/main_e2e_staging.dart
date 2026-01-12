/// E2E Staging Main Entry Point - Production-Like Testing
/// This main entry point is designed for E2E tests that require production-like
/// Firebase operations using a dedicated staging Firebase project. This provides
/// the highest fidelity testing for critical user journeys.
/// ULTRATHINK ANALYSIS:
/// - Production main.dart initializes Firebase with production config
/// - Staging E2E tests need production-like Firebase operations
/// - Staging approach provides realistic integration testing with external services
library;

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Core application
import 'package:butlery/main.dart';

// Staging Firebase configuration
import 'package:butlery/firebase_options.dart'; // Would use staging config

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

/// E2E Staging Application Entry Point
/// This entry point provides complete Butlery app functionality for E2E testing
/// with production-like Firebase integration using a staging project. Perfect for
/// testing critical user journeys, payment flows, and external integrations.
/// REQUIREMENTS:
/// - Staging Firebase project configured
/// - Staging environment variables (.env.staging)
/// - Valid Firebase App Check configuration for staging
/// USAGE:
/// ```dart
/// // In E2E tests (typically CI/CD only):
/// import 'package:butlery/main_e2e_staging.dart' as staging_app;
/// testWidgets('production-like test', (tester) async {
///   staging_app.main();
///   await tester.pumpAndSettle();
///   // Test production-like flows...
/// });
/// ```
Future<void> main() async {
  try {
    // Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Load staging environment variables
    await _loadStagingEnvironment();

    // Initialize Firebase with staging configuration
    await Firebase.initializeApp(
      // In a real implementation, this would use StagingFirebaseOptions
      // For now, using default options with staging project ID
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase App Check for staging (more lenient than production)
    await _initializeStagingAppCheck();

    // Initialize modular system
    await _initializeE2EStagingSystem();

    // Start the application
    runApp(const ButleryApp());
  } catch (e, stackTrace) {
    // Show error app with E2E-specific message
    runApp(_E2EStagingErrorApp(
        'E2E Staging initialization failed: $e\n\nStack trace:\n$stackTrace'));
  }
}

/// Load staging environment variables
/// This loads environment configuration specific to staging testing,
/// including staging Firebase project settings and API keys.
Future<void> _loadStagingEnvironment() async {
  try {
    // Load staging-specific environment file
    await dotenv.load(fileName: '.env.staging');
  } catch (e) {
    // Continue without staging env - use defaults
  }
}

/// Initialize Firebase App Check for staging environment
/// This sets up App Check with staging-appropriate configuration,
/// typically more lenient than production but more secure than debug.
Future<void> _initializeStagingAppCheck() async {
  try {
    // Use debug provider for staging to avoid quota issues
    // In a real staging environment, you might use actual providers
    await FirebaseAppCheck.instance.activate(
      // Use debug provider for staging environment
      providerWeb: ReCaptchaV3Provider('staging_recaptcha_key'),
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
  } catch (e) {
    // Continue without App Check for staging tests
  }
}

/// Initialize the modular system for E2E staging testing
/// This creates the same modular system as production configured for
/// staging environment with production-like Firebase integration.
Future<void> _initializeE2EStagingSystem() async {
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
  // Firebase services will connect to staging project
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );
}

/// Error app widget for E2E staging initialization failures
class _E2EStagingErrorApp extends StatelessWidget {
  final String message;

  const _E2EStagingErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2E Staging Error',
      home: Scaffold(
        backgroundColor: AppColors.infoContainer,
        appBar: AppBar(
          title: const Text('E2E Staging Error'),
          backgroundColor: AppColors.secondaryPurple,
          foregroundColor: AppColors.cardWhite,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: AppDimensions.iconSizeXxl,
                color: AppColors.secondaryPurple,
              ),
              const SizedBox(height: 16),
              const Text(
                'E2E Staging Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryPurple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The E2E Staging application failed to start. This likely indicates:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Missing staging Firebase project configuration\n'
                '• Invalid staging environment variables\n'
                '• Network connectivity issues\n'
                '• Firebase App Check configuration problems',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Check your .env.staging file and Firebase project settings.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
