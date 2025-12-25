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
import 'package:butlery/core/observers/session_activity_observer.dart';

// Session timeout
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/widgets/common/dialogs/session_timeout_warning_dialog.dart';

// Memory pressure handling
import 'package:butlery/services/performance/intelligent_cache_manager.dart';

// Performance optimization - handled by modular system

// All services accessed through DI system - no direct imports needed

// Theme and routing
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/router/app_router.dart';

// Localization
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/providers/locale_provider.dart';

// Views
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/mina_recept_view.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/firebase_options.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // CRITICAL: Initialize Flutter bindings first - required for any Flutter services
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables first - required for Firebase configuration
    await dotenv.load(fileName: '.env');

    // Initialize Firebase with configuration from .env
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Crashlytics and App Check in parallel for faster startup
    await Future.wait([
      if (!kIsWeb)
        FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode),
      if (!kDebugMode)
        FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY'),
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleDeviceCheckProvider(),
        ),
    ]);

    // Set up Crashlytics error handlers (sync, after Crashlytics enabled)
    if (!kIsWeb) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        if (kDebugMode) {
          FlutterError.presentError(errorDetails);
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Initialize modular system FIRST - this sets up the DI container and ServiceLocator
    await _initializeModularSystem();

    // Skip startup optimization manager - it conflicts with the modular bootstrap system
    // The modular system already handles all initialization properly

    // Setup zone error handling for async errors
    runZonedGuarded(
      () async {
        // This zone will catch async errors but app is started outside
      },
      (error, stack) {
        // Log to Crashlytics (mobile only)
        if (!kIsWeb) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
      },
    );

    // Start the application (must be in same zone as ensureInitialized)
    runApp(const ButleryApp());
  } catch (e, stackTrace) {
    // Show error app with more details
    runApp(
      _ErrorApp(
        'Application failed to initialize: $e\n\nStack trace:\n$stackTrace',
      ),
    );
  }
}

Future<void> _initializeModularSystem() async {
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

  // Initialize with modules and stages
  // This also initializes the ServiceLocator internally
  await ApplicationBootstrap.initialize(modules: modules, stages: stages);

  // Stop startup trace after initialization complete
  await startupTrace.stop();
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spacingM),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
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
  SessionTimeoutService? _sessionTimeoutService;
  SessionActivityObserver? _sessionActivityObserver;
  DateTime? _sessionStartTime;
  final LocaleProvider _localeProvider = LocaleProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUI();
    _trackAppOpened();
    _initializeSessionTimeout();
    _initializeLocale();
  }

  /// Initialize locale provider
  Future<void> _initializeLocale() async {
    await _localeProvider.initialize();
    _localeProvider.addListener(_onLocaleChanged);
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle locale change
  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Initialize session timeout service for automatic logout on inactivity
  Future<void> _initializeSessionTimeout() async {
    try {
      final bootstrap = ApplicationBootstrap();

      // Wait for bootstrap to be ready using Completer pattern (no polling)
      await bootstrap.initialized;

      if (bootstrap.isInitialized) {
        _sessionTimeoutService =
            bootstrap.container.get<SessionTimeoutService>();

        // Register warning dialog callback
        _sessionTimeoutService?.registerWarningCallback(() {
          _showSessionTimeoutWarning();
        });

        // Initialize the service
        await _sessionTimeoutService?.initialize();

        // Create session activity observer
        if (_sessionTimeoutService != null) {
          _sessionActivityObserver = SessionActivityObserver(
            _sessionTimeoutService!,
          );
        }
      }
    } catch (e) {
      // Session timeout initialization failed - non-critical
    }
  }

  /// Show session timeout warning dialog
  void _showSessionTimeoutWarning() {
    if (!mounted || _navigatorKey.currentContext == null) return;

    final remainingSeconds =
        (_sessionTimeoutService?.timeRemaining?.inSeconds ?? 300);

    SessionTimeoutWarningDialog.show(
      context: _navigatorKey.currentContext!,
      remainingSeconds: remainingSeconds,
      onExtendSession: () {
        _sessionTimeoutService?.recordActivity();
      },
      onLogoutNow: () {
        _sessionTimeoutService?.forceLogout();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localeProvider.removeListener(_onLocaleChanged);
    _sessionTimeoutService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _trackAppOpened();
      _sessionTimeoutService?.onAppResumed();
      _resumeCacheManager();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _trackAppBackgrounded();
      _sessionTimeoutService?.onAppPaused();
      _pauseCacheManager();
    }
  }

  /// Pause cache manager background operations when app backgrounds
  void _pauseCacheManager() {
    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final cacheManager = bootstrap.container.get<IntelligentCacheManager>();
        cacheManager.onAppPaused();
      }
    } catch (e) {
      // Silently ignore - cache manager may not be available
    }
  }

  /// Resume cache manager background operations when app resumes
  void _resumeCacheManager() {
    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final cacheManager = bootstrap.container.get<IntelligentCacheManager>();
        cacheManager.onAppResumed();
      }
    } catch (e) {
      // Silently ignore - cache manager may not be available
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    _handleMemoryPressure();
  }

  /// Handle system memory pressure by clearing caches.
  void _handleMemoryPressure() {
    AppLogger.warning('System memory pressure detected - clearing caches');

    // Clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Clear app-level caches
    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final cacheManager = bootstrap.container.get<IntelligentCacheManager>();
        cacheManager.handleMemoryPressure();
      }
    } catch (e) {
      AppLogger.error('Failed to handle memory pressure in cache manager', e);
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
      // UI initialization error - non-critical, deep links may not work on all platforms
    }
  }

  Future<void> _setupModularAnalytics() async {
    try {
      // Wait for application to be ready using Completer pattern (no polling)
      final bootstrap = ApplicationBootstrap();
      await bootstrap.initialized;

      if (bootstrap.isInitialized) {
        final analyticsService = bootstrap.container.get<AnalyticsService>();
        _analyticsObserver =
            analyticsService.observer as FirebaseAnalyticsObserver?;
      }
    } catch (e) {
      // Analytics setup failed - non-critical
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
    // Build navigator observers list with performance, snackbar, session activity, and optional analytics observers
    final observers = <NavigatorObserver>[
      _performanceObserver, // Track screen performance with Firebase Performance
      _snackbarObserver,
      if (_sessionActivityObserver != null) _sessionActivityObserver!,
      if (_analyticsObserver != null) _analyticsObserver!,
    ];

    // Wrap MaterialApp with GestureDetector for universal activity tracking (session timeout)
    return GestureDetector(
      onTap: () => _sessionTimeoutService?.recordActivity(),
      onPanDown: (_) => _sessionTimeoutService?.recordActivity(),
      onScaleStart: (_) => _sessionTimeoutService?.recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: observers,
        title: 'Butlery',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // Localization configuration
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _localeProvider.locale,
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
      ),
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
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusL,
                  ),
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
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.get<AuthService>();

    // Log initial state
    if (_authService.currentUser != null) {
      AppLogger.debug(
        'AuthWrapper: User logged in at startup: ${_authService.currentUser!.uid}',
      );
    }

    // Listen to AuthService ChangeNotifier for auth state changes
    _authService.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});

      final user = _authService.currentUser;
      if (user != null) {
        AppLogger.debug('AuthWrapper: User authenticated: ${user.uid}');
      } else {
        AppLogger.debug('AuthWrapper: User signed out');
      }
    }
  }

  @override
  void dispose() {
    AppLogger.debug(
      'AuthWrapper: Disposing wrapper for user: ${_authService.currentUser?.uid ?? 'NULL'}',
    );
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // State-based rendering - AuthService ChangeNotifier triggers rebuilds
    final user = _authService.currentUser;

    if (user != null) {
      AppLogger.debug(
        'AuthWrapper: NAVIGATION SUCCESS - User logged in: ${user.uid}',
      );
      return MinaReceptView(key: ValueKey(user.uid));
    }

    AppLogger.debug('AuthWrapper: No user logged in, showing auth view');
    return const AuthView();
  }
}
