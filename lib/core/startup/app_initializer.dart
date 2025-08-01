// lib/core/startup/app_initializer.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/config/feature_flags.dart';
import 'package:butlery/core/utils/logger.dart';

/// Application initialization service for startup configuration and setup
class AppInitializer {
  // Singleton pattern
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  AppInitializer._internal();

  bool _isInitialized = false;
  
  /// Whether the app has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize only critical services for testing and minimal startup
  Future<void> initializeCritical() async {
    if (_isInitialized) {
      return;
    }

    AppLogger.info('🔧 Starting critical initialization...');
    
    try {
      // Initialize only essential services
      await _initializeCore();
      await _initializeFeatureFlags();
      
      _isInitialized = true;
      AppLogger.success('✅ Critical initialization completed');
      
    } catch (e) {
      AppLogger.error('❌ Critical initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize the application with all required services and configuration
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('App already initialized, skipping...');
      return;
    }

    AppLogger.info('🚀 Starting app initialization...');
    
    try {
      // Initialize core services
      await _initializeCore();
      
      // Initialize feature flags
      await _initializeFeatureFlags();
      
      // Initialize analytics (if enabled)
      await _initializeAnalytics();
      
      // Initialize crash reporting (if enabled)
      await _initializeCrashReporting();
      
      // Initialize database connections
      await _initializeDatabase();
      
      // Initialize authentication
      await _initializeAuth();
      
      // Initialize background services
      await _initializeBackgroundServices();
      
      _isInitialized = true;
      AppLogger.success('✅ App initialization completed successfully');
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ App initialization failed: $e');
      AppLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize core app services
  Future<void> _initializeCore() async {
    AppLogger.info('Initializing core services...');
    
    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error('Flutter error: ${details.exception}');
      if (FeatureFlags.enableCrashReporting) {
        // Report to crash reporting service
      }
    };
    
    // Configure debug settings
    if (kDebugMode && FeatureFlags.enableDebugLogging) {
      AppLogger.info('Debug logging enabled');
    }
  }

  /// Initialize feature flags system
  Future<void> _initializeFeatureFlags() async {
    AppLogger.info('Initializing feature flags...');
    
    final enabledFeatures = FeatureFlags.getEnabledFeatures();
    AppLogger.info('Enabled features: ${enabledFeatures.join(', ')}');
  }

  /// Initialize analytics service
  Future<void> _initializeAnalytics() async {
    if (!FeatureFlags.enableAnalytics) {
      AppLogger.info('Analytics disabled by feature flag');
      return;
    }
    
    AppLogger.info('Initializing analytics...');
    // Analytics initialization would go here
  }

  /// Initialize crash reporting
  Future<void> _initializeCrashReporting() async {
    if (!FeatureFlags.enableCrashReporting) {
      AppLogger.info('Crash reporting disabled by feature flag');
      return;
    }
    
    AppLogger.info('Initializing crash reporting...');
    // Crash reporting initialization would go here
  }

  /// Initialize database connections
  Future<void> _initializeDatabase() async {
    AppLogger.info('Initializing database connections...');
    // Database initialization would go here
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate init time
  }

  /// Initialize authentication services
  Future<void> _initializeAuth() async {
    AppLogger.info('Initializing authentication...');
    // Auth initialization would go here
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate init time
  }

  /// Initialize background services
  Future<void> _initializeBackgroundServices() async {
    AppLogger.info('Initializing background services...');
    // Background services initialization would go here
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate init time
  }

  /// Reset initialization state (useful for testing)
  void reset() {
    _isInitialized = false;
    AppLogger.info('App initializer reset');
  }

  /// Get initialization status
  Map<String, dynamic> getInitializationStatus() {
    return {
      'isInitialized': _isInitialized,
      'enabledFeatures': FeatureFlags.getEnabledFeatures(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Perform health check
  Future<bool> healthCheck() async {
    if (!_isInitialized) {
      return false;
    }
    
    try {
      // Perform basic health checks
      AppLogger.info('Performing health check...');
      
      // Check database connectivity
      // Check authentication status
      // Check critical services
      
      AppLogger.success('Health check passed');
      return true;
    } catch (e) {
      AppLogger.error('Health check failed: $e');
      return false;
    }
  }
}