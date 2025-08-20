/// Base test class providing common setup and utilities for all test types
/// 
/// This abstract class serves as the foundation for all tests in the Butlery
/// application, providing consistent initialization, cleanup, and access to
/// common test utilities and mocks.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/mocks/firestore_singleton.dart';
import 'test_mode_config.dart';

/// Base class for all tests in the Butlery test suite
/// 
/// Provides:
/// - Automatic service locator initialization and cleanup
/// - Common test utilities and helpers
/// - Consistent error handling
/// - Test lifecycle management
abstract class BaseTest {
  /// Whether the service locator has been initialized
  static bool _initialized = false;
  
  /// Temporary directory for Hive boxes
  static Directory? _hiveTempDir;
  
  /// Common setup for all tests
  /// 
  /// Call this in your test's setUp() method or use setUpAll() for
  /// one-time initialization across a test suite.
  static Future<void> setup() async {
    if (!_initialized) {
      // Enable test mode for repositories
      TestModeConfig.enableTestMode();
      
      // Initialize Hive for tests
      await _initializeHive();
      
      // Initialize service locator
      await TestServiceLocator.initialize();
      _initialized = true;
    }
  }
  
  /// Initialize Hive for testing
  static Future<void> _initializeHive() async {
    // Use a temporary directory for Hive boxes during tests
    _hiveTempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_hiveTempDir!.path);
    
    // Register Hive adapters for models that use Hive
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RecipeCoreAdapter());
    }
  }
  
  /// Common teardown for all tests
  /// 
  /// Call this in your test's tearDown() method to ensure proper cleanup
  static Future<void> teardown() async {
    // Clear any test-specific state but keep service locator initialized
    // for performance across test suites
    await TestServiceLocator.clearState();
    
    // Clear Firestore data to prevent memory accumulation between tests
    await FirestoreSingleton.clearData();
  }
  
  /// Complete reset of the test environment
  /// 
  /// Use this in tearDownAll() to completely reset the test environment
  /// after a test suite completes
  static Future<void> reset() async {
    if (_initialized) {
      // Close all Hive boxes
      await Hive.close();
      
      // Clean up Hive temp directory
      if (_hiveTempDir != null && _hiveTempDir!.existsSync()) {
        try {
          _hiveTempDir!.deleteSync(recursive: true);
        } catch (e) {
          // Ignore cleanup errors in tests
        }
        _hiveTempDir = null;
      }
      
      // Reset service locator
      await TestServiceLocator.reset();
      
      // Force reset Firestore singleton when all tests complete
      FirestoreSingleton.forceReset();
      
      // Disable test mode
      TestModeConfig.disableTestMode();
      
      _initialized = false;
    }
  }
  
  /// Get a service from the test container
  static T get<T extends Object>() {
    if (!_initialized) {
      throw StateError(
        'BaseTest not initialized. Call BaseTest.setup() in your setUp() method.',
      );
    }
    return TestServiceLocator.get<T>();
  }
  
  /// Check if a service is registered
  static bool isRegistered<T extends Object>() {
    return _initialized && TestServiceLocator.isRegistered<T>();
  }
  
  /// Register a mock factory for testing
  static void registerMockFactory<T extends Object>(T Function() factory) {
    if (!_initialized) {
      throw StateError(
        'BaseTest not initialized. Call BaseTest.setup() in your setUp() method.',
      );
    }
    TestServiceLocator.registerFactory<T>(factory);
  }
  
  /// Register a mock singleton for testing
  static void registerMockSingleton<T extends Object>(T mock) {
    if (!_initialized) {
      throw StateError(
        'BaseTest not initialized. Call BaseTest.setup() in your setUp() method.',
      );
    }
    TestServiceLocator.registerSingleton<T>(mock);
  }
  
  /// Run a test with automatic setup and teardown
  static void testWithSetup(
    String description,
    Future<void> Function() body, {
    bool skip = false,
    Timeout? timeout,
    dynamic tags,
  }) {
    test(
      description,
      () async {
        await setup();
        try {
          await body();
        } finally {
          await teardown();
        }
      },
      skip: skip,
      timeout: timeout,
      tags: tags,
    );
  }
  
  /// Run a test group with automatic setup and teardown
  static void groupWithSetup(
    String description,
    void Function() body, {
    bool skip = false,
  }) {
    group(description, () {
      setUpAll(() async {
        await setup();
      });
      
      tearDown(() async {
        await teardown();
      });
      
      tearDownAll(() async {
        await reset();
      });
      
      body();
    }, skip: skip);
  }
}

/// Extension methods for enhanced test functionality
extension BaseTestExtensions on Object {
  /// Quick access to check if this type is registered in the test container
  bool get isRegistered => BaseTest.isRegistered<Object>();
}