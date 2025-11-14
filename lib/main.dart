/// Butlery application entry point with modular DI system (5 domain modules + bootstrap stages).
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

// Route observers
import 'package:butlery/core/observers/snackbar_route_observer.dart';
import 'package:butlery/core/observers/performance_navigator_observer.dart';

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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/firebase_options.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Initialize Firebase with configuration from .env
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode) {
      debugPrint('✅ Firebase initialized successfully');
    }

    // Initialize Firebase Crashlytics for production error tracking
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Pass all Flutter errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      // Also log to console in debug mode
      if (kDebugMode) {
        FlutterError.presentError(errorDetails);
      }
    };

    // Pass all platform dispatcher errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    if (kDebugMode) {
      debugPrint('✅ Crashlytics initialized (collection: ${!kDebugMode})');
    }

    // Initialize Firebase App Check
    // Skip App Check in debug mode to avoid rate limiting during development
    if (!kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY'),
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
    }
    // Firebase App Check configuration complete (production mode uses App Check, debug mode skips it)

    // Initialize modular system FIRST - this sets up the DI container and ServiceLocator
    await _initializeModularSystem();

    // Skip startup optimization manager - it conflicts with the modular bootstrap system
    // The modular system already handles all initialization properly

    // Start the application with zone error handling for async errors
    runZonedGuarded(
      () => runApp(const ButleryApp()),
      (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        if (kDebugMode) {
          debugPrint('❌ Uncaught async error: $error');
          debugPrint('Stack trace: $stack');
        }
      },
    );
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ Application startup failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    // Show error app with more details
    runApp(_ErrorApp(
        'Application failed to initialize: $e\n\nStack trace:\n$stackTrace'));
  }
}

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

  // Start Firebase Performance trace for app startup
  final startupTrace = FirebasePerformance.instance.newTrace('app_startup');
  await startupTrace.start();

  if (kDebugMode) {
    debugPrint('📊 Performance: Started app startup trace');
  }

  // Initialize with modules and stages
  // This also initializes the ServiceLocator internally
  await ApplicationBootstrap.initialize(
    modules: modules,
    stages: stages,
  );

  // Stop startup trace after initialization complete
  await startupTrace.stop();

  if (kDebugMode) {
    debugPrint('📊 Performance: Stopped app startup trace');
  }

  // ServiceLocator is now initialized by ApplicationBootstrap
  // Performance services are handled by the PerformanceModule if registered

  if (kDebugMode) {
    debugPrint('✅ Modular system initialized successfully');
  }
}

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
                  size: AppDimensions.iconSizeXxl,
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
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
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

class ButleryApp extends StatefulWidget {
  const ButleryApp({super.key});

  @override
  State<ButleryApp> createState() => _ButleryAppState();
}

class _ButleryAppState extends State<ButleryApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  FirebaseAnalyticsObserver? _analyticsObserver;
  final SnackbarRouteObserver _snackbarObserver = SnackbarRouteObserver();
  final PerformanceNavigatorObserver _performanceObserver =
      PerformanceNavigatorObserver();
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUI();
    _trackAppOpened();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _trackAppOpened();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _trackAppBackgrounded();
    }
  }

  /// Track app opened event with session count
  Future<void> _trackAppOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCount = (prefs.getInt('session_count') ?? 0) + 1;
      await prefs.setInt('session_count', sessionCount);

      _sessionStartTime = DateTime.now();

      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final analyticsService = bootstrap.container.get<AnalyticsService>();
        await analyticsService.logEvent(
          name: 'app_opened',
          parameters: {
            'session_count': sessionCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      AppLogger.error('Failed to track app_opened', e);
    }
  }

  /// Track app backgrounded event with session duration
  Future<void> _trackAppBackgrounded() async {
    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized && _sessionStartTime != null) {
        final sessionDuration =
            DateTime.now().difference(_sessionStartTime!).inSeconds;

        final analyticsService = bootstrap.container.get<AnalyticsService>();
        await analyticsService.logEvent(
          name: 'app_backgrounded',
          parameters: {
            'session_duration_seconds': sessionDuration,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      AppLogger.error('Failed to track app_backgrounded', e);
    }
  }

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
        debugPrint(
            '💡 Note: Deep links may not work on all platforms (e.g., web)');
      }
    }
  }

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
        _analyticsObserver =
            analyticsService.observer as FirebaseAnalyticsObserver?;

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

  @override
  Widget build(BuildContext context) {
    return _buildModularApp();
  }

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

  Widget _buildMainApp() {
    // Build navigator observers list with performance, snackbar, and optional analytics observers
    final observers = <NavigatorObserver>[
      _performanceObserver, // Track screen performance with Firebase Performance
      _snackbarObserver,
      if (_analyticsObserver != null) _analyticsObserver!,
    ];

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: observers,
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const InitializationWrapper(),
      onUnknownRoute: AppRouter.handleUnknownRoute,
      onGenerateRoute: AppRouter.generateRoute,
      // Universal fix for Android nav bar overlay
      // Wraps ALL views with SafeArea to prevent content from being hidden
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return SafeArea(
          top: false, // Let AppBar handle top
          bottom: true, // Always protect bottom from system nav bar
          left: false,
          right: false,
          child: child,
        );
      },
    );
  }

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
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusL),
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

class InitializationWrapper extends StatelessWidget {
  // CRITICAL: Use GlobalKey to prevent AuthWrapper recreation
  static final GlobalKey<_AuthWrapperState> _authWrapperKey =
      GlobalKey<_AuthWrapperState>();

  const InitializationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(key: _authWrapperKey);
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Get initial Firebase auth state
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      AppLogger.debug(
          'AuthWrapper: User logged in at startup: ${_currentUser!.email}');
    }

    // Single clean auth listener - no redundancy, no battery drain
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });

        if (user != null) {
          AppLogger.debug('AuthWrapper: User authenticated: ${user.email}');
        } else {
          AppLogger.debug('AuthWrapper: User signed out');
        }
      }
    });
  }

  @override
  void dispose() {
    AppLogger.debug(
        'AuthWrapper: Disposing wrapper for user: ${_currentUser?.email ?? 'NULL'}');
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 ULTRATHINK: AGGRESSIVE LOGIN NAVIGATION - Always sync with Firebase on every build
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null &&
        (_currentUser == null || _currentUser!.uid != firebaseUser.uid)) {
      _currentUser = firebaseUser;

      // ULTRA-AGGRESSIVE: Force multiple rebuilds with different mechanisms
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});

          // Second rebuild with delay
          Future.delayed(const Duration(milliseconds: 16), () {
            if (mounted) setState(() {});
          });

          // Third rebuild with longer delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      });
    }

    // 🔧 DIRECT STATE-BASED RENDERING (No StreamBuilder)
    final user = _currentUser;

    if (user != null) {
      AppLogger.debug(
          'AuthWrapper: NAVIGATION SUCCESS - User logged in: ${user.email}');
      return MinaReceptView(key: ValueKey(user.uid));
    }

    AppLogger.debug('AuthWrapper: No user logged in, showing auth view');
    return const AuthView();
  }
}
