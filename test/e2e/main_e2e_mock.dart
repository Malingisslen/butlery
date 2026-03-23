/// E2E Mock Main Entry Point - Skips Firebase Initialization
/// This main entry point is designed for E2E tests that focus on UI/UX flows
/// without Firebase dependencies. It provides the fastest E2E test execution
/// by completely bypassing Firebase initialization and using mock services.
/// ULTRATHINK ANALYSIS:
/// - Production main.dart initializes Firebase with production config
/// - E2E tests need app functionality without Firebase platform dependencies
/// - Mock approach provides pure UI/UX testing with maximum speed
library;

import 'package:flutter/material.dart';

// Core application
import 'package:butlery/main.dart';

// Bootstrap system - but without Firebase
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/stages/platform_stage.dart';
import 'package:butlery/core/bootstrap/stages/core_stage.dart';
import 'package:butlery/core/bootstrap/stages/content_stage.dart';
import 'package:butlery/core/bootstrap/stages/social_stage.dart';
import 'package:butlery/core/bootstrap/stages/ui_stage.dart';

// DI modules - mock versions
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/performance_module.dart';
import 'package:butlery/core/di/modules/ui_module.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// E2E Mock Application Entry Point
/// This entry point provides complete Butlery app functionality for E2E testing
/// without Firebase dependencies. Perfect for testing UI flows, navigation,
/// form validation, and user interactions with maximum speed.
/// USAGE:
/// ```dart
/// // In E2E tests:
/// import 'package:butlery/main_e2e_mock.dart' as mock_app;
/// testWidgets('UI flow test', (tester) async {
///   mock_app.main();
///   await tester.pumpAndSettle();
///   // Test UI interactions...
/// });
/// ```
Future<void> main() async {
  try {
    // Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Skip Firebase initialization completely for mock E2E tests
    // This prevents Firebase platform channel errors in test environment

    // Initialize modular system with mock configuration
    await _initializeE2EMockSystem();

    // Start the application
    runApp(const ButleryApp());
  } catch (e, stackTrace) {
    // Show error app with E2E-specific message
    runApp(_E2EMockErrorApp(
        'E2E Mock initialization failed: $e\n\nStack trace:\n$stackTrace'));
  }
}

/// Initialize the modular system for E2E mock testing
/// This creates the same modular system as production but configured for
/// E2E mock testing with no Firebase dependencies.
Future<void> _initializeE2EMockSystem() async {
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
  // The test infrastructure will override services with mocks
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );
}

/// Error app widget for E2E mock initialization failures
class _E2EMockErrorApp extends StatelessWidget {
  final String message;

  const _E2EMockErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2E Mock Error',
      home: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: cs.errorContainer,
          appBar: AppBar(
            title: const Text('E2E Mock Error'),
            backgroundColor: cs.error,
            foregroundColor: cs.surfaceContainerHighest,
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: AppDimensions.iconSizeXxl,
                  color: cs.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'E2E Mock Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The E2E Mock application failed to start. This is likely a configuration issue.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusM),
                        border: Border.all(color: cs.outlineVariant),
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
        );
      }),
    );
  }
}
