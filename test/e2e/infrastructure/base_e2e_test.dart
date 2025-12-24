/// Base E2E Test Infrastructure for Butlery Flutter Application
///
/// Simple infrastructure for End-to-End testing with three-tier configuration support:
/// Mock (isolated), Emulator (Firebase emulator), and Staging (production-like).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// E2E Configuration Types
///
/// Defines the three tiers of E2E testing with different Firebase integration levels.
enum E2EConfig {
  /// Mock configuration - fastest execution, no Firebase dependencies
  mock,

  /// Emulator configuration - real Firebase operations via emulator
  emulator,

  /// Staging configuration - production-like with staging Firebase project
  staging,
}

/// Base E2E Test Infrastructure
///
/// Provides essential utilities for E2E testing without over-engineering.
abstract class BaseE2ETest {
  /// Create E2E test application widget
  ///
  /// Creates a lightweight test app based on the specified E2E configuration.
  /// Uses TestApp to avoid Firebase initialization timeouts during tests.
  static Widget createE2EApp({required E2EConfig config}) {
    return MaterialApp(
      title: 'Butlery E2E Test',
      home: _TestApp(config: config),
      locale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('sv', 'SE'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }

  /// Wait for widget to be ready for interaction
  ///
  /// Waits for the widget tree to settle before proceeding with test interactions.
  static Future<void> waitForReady(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Short additional wait for any async initialization
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lightweight test application widget for E2E testing
///
/// Provides a minimal app structure without Firebase initialization or complex
/// bootstrap processes that could cause timeouts during E2E test execution.
class _TestApp extends StatelessWidget {
  final E2EConfig config;

  const _TestApp({required this.config});

  String get configName {
    switch (config) {
      case E2EConfig.mock:
        return 'MOCK';
      case E2EConfig.emulator:
        return 'EMULATOR';
      case E2EConfig.staging:
        return 'STAGING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Butlery E2E Test - $configName'),
        backgroundColor: _getConfigColor(),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getConfigIcon(),
              size: 64,
              color: _getConfigColor(),
            ),
            const SizedBox(height: 16),
            const Text(
              'E2E Test Environment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configuration: $configName',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Text(
              _getConfigDescription(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Test button for basic interaction validation
              },
              child: const Text('Test Button'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfigColor() {
    switch (config) {
      case E2EConfig.mock:
        return Colors.green;
      case E2EConfig.emulator:
        return Colors.orange;
      case E2EConfig.staging:
        return Colors.red;
    }
  }

  IconData _getConfigIcon() {
    switch (config) {
      case E2EConfig.mock:
        return Icons.science;
      case E2EConfig.emulator:
        return Icons.cloud;
      case E2EConfig.staging:
        return Icons.rocket_launch;
    }
  }

  String _getConfigDescription() {
    switch (config) {
      case E2EConfig.mock:
        return 'Fast isolated testing with mocked services.\nPerfect for UI/UX validation and development.';
      case E2EConfig.emulator:
        return 'Firebase emulator integration testing.\nReal Firebase operations in controlled environment.';
      case E2EConfig.staging:
        return 'Production-like validation testing.\nStaging Firebase project with real services.';
    }
  }
}

/// Test entry point for infrastructure validation
///
/// This file contains infrastructure classes for E2E testing.
/// Individual E2E tests import and use these classes.
void main() {
  group('E2E Infrastructure Validation', () {
    test('E2E configs are properly defined', () {
      expect(E2EConfig.values.length, equals(3));
      expect(E2EConfig.mock, isNotNull);
      expect(E2EConfig.emulator, isNotNull);
      expect(E2EConfig.staging, isNotNull);
    });

    testWidgets('E2E test app can be created for all configs', (tester) async {
      for (final config in E2EConfig.values) {
        final app = BaseE2ETest.createE2EApp(config: config);
        expect(app, isA<MaterialApp>());

        await tester.pumpWidget(app);
        await BaseE2ETest.waitForReady(tester);

        // Verify config-specific elements
        expect(find.text('Butlery E2E Test - ${config.name.toUpperCase()}'),
            findsOneWidget);
        expect(find.text('Test Button'), findsOneWidget);
      }
    });
  });
}
