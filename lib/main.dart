/// Butlery application with clean modular architecture.
///
/// This main entry point uses a modular dependency injection system that
/// provides excellent separation of concerns, testability, and maintainability.
///
/// Architecture:
/// - 5 domain modules: Core, Content, Social, Messaging, Collaboration
/// - Bootstrap stages for organized initialization
/// - Health monitoring and comprehensive error handling
/// - Clean provider-based service access
///
/// Bootstrap flow:
/// ```
/// main() -> ApplicationBootstrap.initialize() -> runApp()
///   └─> DIContainer + 5 Modules -> 5 Bootstrap Stages -> ButleryApp
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

// Application provider
import 'package:butlery/core/providers/application_provider.dart';

// Deep link handling
import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';

// Performance optimization - handled by modular system

// All services accessed through DI system - no direct imports needed

// Theme and routing
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/router/app_router.dart';

// Views
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/mina_recept_view.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/firebase_options_real.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Application entry point with clean modular architecture.
///
/// Uses the new modular dependency injection system exclusively.
/// Provides comprehensive error handling and graceful failure modes.
Future<void> main() async {
  // CRITICAL: Initialize Flutter bindings first - required for any Flutter services
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (kDebugMode) {
      debugPrint('🚀 Starting Butlery with modular system');
    }

    // Load environment variables first - required for Firebase configuration
    await dotenv.load(fileName: '.env');
    
    if (kDebugMode) {
      debugPrint('✅ Environment variables loaded');
    }

    // Initialize Firebase with real configuration
    await Firebase.initializeApp(
      options: RealFirebaseOptions.currentPlatform,
    );
    
    if (kDebugMode) {
      debugPrint('✅ Firebase initialized successfully');
    }

    // Initialize Firebase App Check
    // Skip App Check in debug mode to avoid rate limiting during development
    if (!kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY'),
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      
      debugPrint('✅ Firebase App Check activated for production');
    } else {
      // In debug mode, optionally use debug provider with proper token
      // For now, skip to avoid "Too many attempts" errors
      debugPrint('⚠️ Firebase App Check skipped in debug mode to avoid rate limiting');
    }

    // Initialize modular system FIRST - this sets up the DI container and ServiceLocator
    await _initializeModularSystem();

    // Skip startup optimization manager - it conflicts with the modular bootstrap system
    // The modular system already handles all initialization properly

    // Start the application
    runApp(const ButleryApp());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ Application startup failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    // Show error app with more details
    runApp(_ErrorApp('Application failed to initialize: $e\n\nStack trace:\n$stackTrace'));
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
    PerformanceModule(),
    UIModule(), // ViewModels and UI services
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
  // This also initializes the ServiceLocator internally
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );
  
  // ServiceLocator is now initialized by ApplicationBootstrap
  // Performance services are handled by the PerformanceModule if registered

  if (kDebugMode) {
    debugPrint('✅ Modular system initialized successfully');
  }
}

// Legacy initialization removed - modular system only

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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
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
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      textAlign: TextAlign.left,
                    ),
                  ),
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
      ),
    );
  }
}

/// Root application widget with clean modular architecture.
///
/// Uses the modular dependency injection system exclusively,
/// providing clean separation of concerns and excellent testability.
class ButleryApp extends StatefulWidget {
  const ButleryApp({super.key});

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
      // Initialize deep link handling (platform-aware)
      await DeepLinkHandler().initialize();

      // Setup analytics observer
      await _setupModularAnalytics();

      if (mounted) {
        setState(() {}); // Trigger rebuild with analytics
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ UI initialization error (non-critical): $e');
        debugPrint('💡 Note: Deep links may not work on all platforms (e.g., web)');
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
        _analyticsObserver = analyticsService.observer as FirebaseAnalyticsObserver?;
        
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

  // Legacy analytics removed - modular system only

  @override
  Widget build(BuildContext context) {
    return _buildModularApp();
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

  // Legacy app builder removed - modular system only

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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen('Checking authentication...');
        }

        if (snapshot.hasError) {
          return _buildErrorScreen('Authentication error', snapshot.error.toString());
        }

        final user = snapshot.data;
        if (user != null) {
          AppLogger.debug('AuthWrapper: User logged in - ${user.email}');
          // Use key to force widget rebuild when user changes
          return MinaReceptView(key: ValueKey(user.uid));
        }

        AppLogger.debug('AuthWrapper: No user logged in, showing auth view');
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