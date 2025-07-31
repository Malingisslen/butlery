/// New modular main entry point for the Butlery application.
///
/// This file demonstrates the new modular dependency injection and bootstrap
/// system. It replaces the monolithic main.dart with a clean, maintainable
/// architecture that separates concerns and improves testability.
///
/// Key improvements:
/// - Modular dependency injection with domain-specific modules
/// - Staged bootstrap process with proper error handling
/// - Clean separation between initialization and UI concerns
/// - Feature flag support for gradual rollout
/// - Comprehensive health monitoring and validation
///
/// Architecture:
/// ```
/// main() -> ApplicationBootstrap.initialize() -> runApp()
///   └─> DIContainer + Modules -> Bootstrap Stages -> ButleryApp
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

// Core configuration
import 'package:butlery/core/config/feature_flags.dart';

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

// Application provider
import 'package:butlery/core/providers/application_provider.dart';

// Deep link handling
import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';

// Legacy fallback
import 'package:butlery/core/startup/app_initializer.dart';
import 'package:butlery/core/injection.dart' as legacy_injection;

// Services
import 'package:butlery/services/offline_service.dart';

// Theme and routing
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/router/app_router.dart';

// Views
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/mina_recept_view.dart';

// Firebase
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';

/// Application entry point with modular architecture.
///
/// Determines whether to use the new modular system or fall back to
/// the legacy system based on feature flags. Provides a safe migration
/// path with comprehensive error handling.
Future<void> main() async {
  try {
    // Check feature flags to determine initialization approach
    final useModularDI = FeatureFlags.useModularDI;

    if (kDebugMode) {
      debugPrint('🚀 Starting Butlery with ${useModularDI ? 'modular' : 'legacy'} system');
    }

    if (useModularDI) {
      // Use new modular system
      await _initializeModularSystem();
    } else {
      // Use legacy system
      await _initializeLegacySystem();
    }

    // Start the application
    runApp(ButleryApp(useModularSystem: useModularDI));
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Application startup failed: $e');
    }

    // Try fallback to legacy system if enabled
    if (FeatureFlags.enableLegacyFallback && FeatureFlags.useModularDI) {
      if (kDebugMode) {
        debugPrint('🔄 Falling back to legacy system...');
      }
      
      try {
        await _initializeLegacySystem();
        runApp(const ButleryApp(useModularSystem: false));
      } catch (fallbackError) {
        if (kDebugMode) {
          debugPrint('❌ Legacy fallback also failed: $fallbackError');
        }
        
        // Last resort - run minimal app
        runApp(const _ErrorApp('Application failed to initialize'));
      }
    } else {
      // No fallback - show error
      runApp(const _ErrorApp('Application failed to initialize'));
    }
  }
}

/// Initialize the new modular dependency injection system.
Future<void> _initializeModularSystem() async {
  if (kDebugMode) {
    debugPrint('🔧 Initializing modular DI system...');
  }

  // Create DI modules in dependency order
  final modules = [
    CoreModule(),
    ContentModule(),
    SocialModule(),
    MessagingModule(),
    CollaborationModule(),
  ];

  // Create bootstrap stages
  final stages = [
    PlatformStage(),
    CoreStage(),
    ContentStage(),
    SocialStage(),
    UIStage(),
  ];

  // Initialize with modules and stages
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );

  // Initialize global service locator
  ServiceLocator.initialize(ApplicationBootstrap().container);

  if (kDebugMode) {
    debugPrint('✅ Modular system initialized successfully');
  }
}

/// Initialize the legacy dependency injection system.
Future<void> _initializeLegacySystem() async {
  if (kDebugMode) {
    debugPrint('🔧 Initializing legacy system...');
  }

  // Use existing initialization
  await AppInitializer.initializeCritical();
  AppInitializer.initializeBackground();

  if (kDebugMode) {
    debugPrint('✅ Legacy system initialized');
  }
}

/// Error app widget for when initialization fails completely.
class _ErrorApp extends StatelessWidget {
  final String message;
  
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery - Error',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.backgroundBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              const Text(
                'Application Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: () {
                  // Restart the application
                  main();
                },
                child: const Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Root application widget with modular architecture support.
///
/// Handles both modular and legacy systems gracefully, providing
/// appropriate providers and initialization logic for each approach.
class ButleryApp extends StatefulWidget {
  final bool useModularSystem;

  const ButleryApp({
    super.key,
    required this.useModularSystem,
  });

  @override
  State<ButleryApp> createState() => _ButleryAppState();
}

class _ButleryAppState extends State<ButleryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  FirebaseAnalyticsObserver? _analyticsObserver;

  @override
  void initState() {
    super.initState();
    _initializeUI();
  }

  /// Initialize UI-specific components.
  Future<void> _initializeUI() async {
    try {
      // Initialize deep link handling
      await DeepLinkHandler().initialize();

      // Setup analytics observer
      if (widget.useModularSystem) {
        await _setupModularAnalytics();
      } else {
        await _setupLegacyAnalytics();
      }

      if (mounted) {
        setState(() {}); // Trigger rebuild with analytics
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ UI initialization failed: $e');
      }
    }
  }

  /// Setup analytics for modular system.
  Future<void> _setupModularAnalytics() async {
    try {
      // Wait for application to be ready
      final bootstrap = ApplicationBootstrap();
      if (!bootstrap.isInitialized) {
        if (kDebugMode) {
          debugPrint('⏳ Waiting for modular system to initialize...');
        }
        
        // Wait for initialization with timeout
        var attempts = 0;
        while (!bootstrap.isInitialized && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      if (bootstrap.isInitialized) {
        final analyticsService = bootstrap.container.get<AnalyticsService>();
        _analyticsObserver = FirebaseAnalyticsObserver(
          analytics: analyticsService.analytics,
        );
        
        if (kDebugMode) {
          debugPrint('✅ Modular analytics observer setup');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Modular analytics setup failed: $e');
      }
    }
  }

  /// Setup analytics for legacy system.  
  Future<void> _setupLegacyAnalytics() async {
    try {
      // Wait for legacy background initialization
      while (!AppInitializer.isBackgroundInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final analyticsService = legacy_injection.sl<AnalyticsService>();
      _analyticsObserver = FirebaseAnalyticsObserver(
        analytics: analyticsService.analytics,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Legacy analytics observer setup');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Legacy analytics setup failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useModularSystem) {
      return _buildModularApp();
    } else {
      return _buildLegacyApp();
    }
  }

  /// Build app with modular system.
  Widget _buildModularApp() {
    final bootstrap = ApplicationBootstrap();
    
    if (!bootstrap.isInitialized) {
      return _buildLoadingApp('Initializing modular system...');
    }

    return ApplicationProvider(
      container: bootstrap.container,
      bootstrap: bootstrap,
      child: ApplicationReadyBuilder(
        onReady: _onApplicationReady,
        child: _buildMainApp(),
      ),
    );
  }

  /// Build app with legacy system.
  Widget _buildLegacyApp() {
    if (!AppInitializer.isBackgroundInitialized) {
      return _buildLoadingApp('Initializing services...');
    }

    return ChangeNotifierProvider<OfflineService>.value(
      value: legacy_injection.sl<OfflineService>(),
      child: _buildMainApp(),
    );
  }

  /// Build the main application UI.
  Widget _buildMainApp() {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: _analyticsObserver != null ? [_analyticsObserver!] : [],
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const InitializationWrapper(),
      onUnknownRoute: AppRouter.handleUnknownRoute,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }

  /// Build loading screen.
  Widget _buildLoadingApp(String message) {
    return MaterialApp(
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.backgroundBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppDimensions.iconSizeHero,
                height: AppDimensions.iconSizeHero,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: AppDimensions.iconSizeHero,
                  color: AppColors.neutralLight,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXxxl),
              const CircularProgressIndicator(),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Called when the application becomes ready.
  void _onApplicationReady() {
    if (kDebugMode) {
      debugPrint('✅ Application is ready for user interaction');
    }

    // Process any pending deep links
    if (mounted) {
      DeepLinkHandler().processPendingDeepLink(context);
    }
  }
}

/// Initialization wrapper that shows loading or auth based on state.
class InitializationWrapper extends StatelessWidget {
  const InitializationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

/// Authentication wrapper that manages auth state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthRepository().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen('Checking authentication...');
        }

        if (snapshot.hasError) {
          return _buildErrorScreen('Authentication error', snapshot.error.toString());
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MinaReceptView();
        }

        return const AuthView();
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBeige,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String title, String message) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBeige,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              color: AppColors.error,
              size: AppDimensions.iconSizeXl,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}