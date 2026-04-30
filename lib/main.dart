/// Butlery application entry point with modular DI system (5 domain modules + bootstrap stages).
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

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
import 'package:butlery/core/di/modules/search_module.dart';
import 'package:butlery/core/di/modules/tagging_module.dart';
import 'package:butlery/core/di/modules/pantry_module.dart';

// Application provider
import 'package:butlery/core/providers/application_provider.dart';

// Deep link handling
import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';

// Route observers
import 'package:butlery/core/observers/snackbar_route_observer.dart';
import 'package:butlery/core/observers/performance_navigator_observer.dart';
import 'package:butlery/core/observers/session_activity_observer.dart';
import 'package:butlery/core/observers/interaction_route_observer.dart';
import 'package:butlery/core/observers/consent_aware_analytics_observer.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';

// Session timeout
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/widgets/common/dialogs/session_timeout_warning_dialog.dart';

// Theme service
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/services/theme/seasonal_accent_service.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:clock/clock.dart';

// Material You dynamic color

// Memory pressure handling
import 'package:butlery/services/performance/intelligent_cache_manager.dart';

// Clipboard URL detection
import 'package:flutter/services.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/core/constants/routes.dart' as app_routes;

// Performance optimization - handled by modular system

// All services accessed through DI system - no direct imports needed

// Theme and routing
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// Localization
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';

// Analytics user-property bootstrap (BUT-636 / 637 / 639)
import 'package:butlery/services/analytics/user_property_bootstrap.dart';
import 'package:butlery/models/user_profile.dart';

// Views
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/auth/email_verification_view.dart';
import 'package:butlery/views/onboarding/onboarding_view.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

// Beta feedback
import 'package:butlery/widgets/common/feedback_fab.dart';

// Web error tracking (BUT-449)
import 'package:butlery/services/monitoring/web_error_reporter.dart';

// Keyboard shortcuts (BUT-521)
import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/observers/route_tracker.dart';

// Services for auth wrapper
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_deep_link_router.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:butlery/firebase_options.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Wrap everything in runZonedGuarded so the binding and runApp share the
  // same zone. Splitting them (binding in root, runApp in child) causes a
  // "Zone mismatch" assertion on Flutter web in debug mode.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Web: use path-based URLs (no `#` fragment). Without this, the debug
      // Chrome opens `http://host:port/` and the router fails to match the
      // root route — the navigation shell never renders.
      if (kIsWeb) {
        usePathUrlStrategy();

        // Build semantics from the first frame. Otherwise Flutter waits for
        // the user to click the "Enable accessibility" placeholder, which
        // silently breaks Chrome-MCP / smoke-test CTA lookup via
        // `[aria-label="btn-..."]`. Escape hatch for profiling:
        // --dart-define=DISABLE_FORCE_SEMANTICS=true.
        if (!const bool.fromEnvironment('DISABLE_FORCE_SEMANTICS')) {
          SemanticsBinding.instance.ensureSemantics();
        }
      }

      // Limit image cache to prevent unbounded memory growth
      // BUT-470: bumped from 100 to reduce grid thrash on tablets/desktop. 50MB byte cap stays.
      PaintingBinding.instance.imageCache.maximumSize = 300;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          50 * 1024 * 1024; // 50 MB

      // Set up error handlers early (before any async work)
      if (kIsWeb) {
        FlutterError.onError = (errorDetails) {
          FlutterError.presentError(errorDetails);
        };
      }

      try {
        // Initialize Firebase with configuration from compile-time --dart-define
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Configure Firestore settings early, before any DI module can
        // instantiate FirestoreRepository and trigger Firestore operations.
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
          );

          // On web, detect and recover from corrupted IndexedDB persistence.
          // Firestore JS SDK 12.x has a known bug where IndexedDB state machine
          // gets stuck after unclean shutdown, causing INTERNAL ASSERTION FAILED.
          if (kIsWeb) {
            try {
              await FirebaseFirestore.instance
                  .collection('_health')
                  .doc('_')
                  .get()
                  .timeout(const Duration(seconds: 5));
            } catch (healthError) {
              final msg = healthError.toString();
              if (msg.contains('INTERNAL ASSERTION') ||
                  msg.contains('Unexpected state')) {
                AppLogger.warning(
                  'Firestore web persistence corrupted — clearing IndexedDB',
                );
                await FirebaseFirestore.instance.terminate();
                await FirebaseFirestore.instance.clearPersistence();
                FirebaseFirestore.instance.settings = const Settings(
                  persistenceEnabled: true,
                  cacheSizeBytes: 100 * 1024 * 1024,
                );
              }
              // permission-denied on non-existent doc is expected — ignore
            }
          }
        } catch (e) {
          // Settings already applied (e.g. hot restart)
        }

        // Default Crashlytics to disabled until consent is verified (GDPR)
        // App Check can proceed immediately (security, not analytics)
        await Future.wait([
          if (!kIsWeb)
            FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false),
          FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(
              '6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo',
            ),
            providerAndroid: kDebugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode
                ? const AppleDebugProvider()
                : const AppleDeviceCheckProvider(),
          ),
        ]);

        // Set up native error handlers (after Crashlytics available)
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

        runApp(const ButleryApp());
      } catch (e, stackTrace) {
        runApp(
          _ErrorApp(
            kDebugMode
                ? 'Application failed to initialize: $e\n\nStack trace:\n$stackTrace'
                : 'Application failed to initialize. Please restart.',
          ),
        );
      }
    },
    (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

Future<void> _initializeModularSystem() async {
  // Create DI modules in dependency order
  final modules = [
    CoreModule(),
    SearchModule(), // Search provider (Algolia/Firestore fallback)
    TaggingModule(), // Automatic recipe tagging system
    PantryModule(), // Skafferiet — user's pantry inventory
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

  // Default Performance collection to disabled until consent (GDPR)
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(false);

  // Initialize with modules and stages
  // This also initializes the ServiceLocator internally
  await ApplicationBootstrap.initialize(modules: modules, stages: stages);

  // Enable Crashlytics and Performance only if user has analytics consent
  await _enableCollectionIfConsented();
}

/// Enable Analytics, Crashlytics, and Performance collection only when the
/// user has granted analytics consent. Safe default: disabled.
///
/// GDPR Art. 7: the repository's `initialize()` starts collection DENIED;
/// this function re-enables only after the consent check passes. Analytics
/// is additionally disabled in debug builds to keep dev traffic out of
/// production metrics.
Future<void> _enableCollectionIfConsented() async {
  try {
    final bootstrap = ApplicationBootstrap();
    if (!bootstrap.isInitialized) return;

    final consentService = bootstrap.container.get<ConsentService>();
    final hasConsent =
        await consentService.hasConsent(ConsentPurpose.analytics);

    final analyticsEnabled = hasConsent && !kDebugMode;

    // Analytics (all platforms — Firebase Analytics supports web + mobile)
    try {
      final analyticsService = bootstrap.container.get<AnalyticsService>();
      await analyticsService.setAnalyticsCollectionEnabled(analyticsEnabled);
    } catch (e) {
      AppLogger.warning('Failed to toggle Analytics collection: $e');
    }

    // Crashlytics + Performance are mobile-only
    if (!kIsWeb) {
      await Future.wait([
        FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(hasConsent && !kDebugMode),
        FirebasePerformance.instance
            .setPerformanceCollectionEnabled(hasConsent),
      ]);
    }

    // Web error tracking (BUT-449): Crashlytics has no web SDK, so we
    // route web errors through the `logWebError` callable instead.
    // Same consent gate as native — install only after consent is
    // confirmed and skip in debug to avoid noise in dev.
    if (kIsWeb && hasConsent && !kDebugMode) {
      try {
        WebErrorReporter(consentService: consentService).install();
        AppLogger.info('Web error reporter installed');
      } catch (e) {
        AppLogger.warning('Failed to install web error reporter: $e');
      }
    }

    AppLogger.info(
      'Collection consent: analytics=$hasConsent → '
      'Analytics=$analyticsEnabled, '
      'Crashlytics=${hasConsent && !kDebugMode}, Performance=$hasConsent',
    );
  } catch (e) {
    // Consent check failed — leave collection disabled (safe default)
    AppLogger.warning('Failed to check analytics consent: $e');
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
      home: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: cs.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppDimensions.iconSizeXxl,
                    color: cs.error,
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
        );
      }),
    );
  }
}

class ButleryApp extends StatefulWidget {
  const ButleryApp({super.key});

  @override
  State<ButleryApp> createState() => _ButleryAppState();
}

class _ButleryAppState extends State<ButleryApp> with WidgetsBindingObserver {
  ConsentAwareAnalyticsObserver? _analyticsObserver;
  final SnackbarRouteObserver _snackbarObserver = SnackbarRouteObserver();
  final PerformanceNavigatorObserver _performanceObserver =
      PerformanceNavigatorObserver();
  InteractionRouteObserver? _interactionObserver;
  SessionTimeoutService? _sessionTimeoutService;
  SessionActivityObserver? _sessionActivityObserver;
  DateTime? _sessionStartTime;
  final LocaleProvider _localeProvider = LocaleProvider();
  ThemeService? _themeService;
  UserPropertyBootstrap? _userPropertyBootstrap;
  String? _lastPromptedClipboardUrl;
  static final _inputDetector = InputDetector();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUI();
    _trackAppOpened();
    _initializeSessionTimeout();
    _initializeLocale();
    _initializeTheme();
  }

  /// Initialize locale provider
  Future<void> _initializeLocale() async {
    await _localeProvider.initialize();
    AppLocale.initialize(_localeProvider.locale);
    _localeProvider.addListener(_onLocaleChanged);
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle locale change
  void _onLocaleChanged() {
    AppLocale.updateLocale(_localeProvider.locale);
    // Re-fire `language` user property (BUT-636) so segmentation reflects
    // the user's new locale immediately — fire-and-forget; failures logged.
    _userPropertyBootstrap?.emitLanguage(_localeProvider.locale);
    if (mounted) {
      setState(() {});
    }
  }

  /// Initialize theme service
  Future<void> _initializeTheme() async {
    try {
      final bootstrap = ApplicationBootstrap();
      await bootstrap.initialized;

      if (bootstrap.isInitialized) {
        _themeService = bootstrap.container.get<ThemeService>();
        await _themeService?.initialize();
        _themeService?.addListener(_onThemeChanged);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Theme initialization failed - use default light theme
    }
  }

  /// Handle theme change
  void _onThemeChanged() {
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
    if (!mounted || appNavigatorKey.currentContext == null) return;

    final remainingSeconds =
        (_sessionTimeoutService?.timeRemaining?.inSeconds ?? 300);

    SessionTimeoutWarningDialog.show(
      context: appNavigatorKey.currentContext!,
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
    _themeService?.removeListener(_onThemeChanged);
    _sessionTimeoutService?.dispose();
    _disposeCacheManager();
    super.dispose();
  }

  void _disposeCacheManager() {
    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final cacheManager = bootstrap.container.get<IntelligentCacheManager>();
        cacheManager.dispose();
      }
    } catch (e) {
      // Silently ignore - cache manager may not be available
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _trackAppOpened();
      _sessionTimeoutService?.onAppResumed();
      _resumeCacheManager();
      _checkClipboardForRecipeUrl();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _trackAppBackgrounded();
      _sessionTimeoutService?.onAppPaused();
      _pauseCacheManager();
    }
  }

  /// Check clipboard for recipe URLs on app resume.
  /// Shows a non-intrusive MaterialBanner if a URL is detected.
  Future<void> _checkClipboardForRecipeUrl() async {
    try {
      // Only check if clipboard has strings (avoids iOS permission banner)
      if (!await Clipboard.hasStrings()) return;

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();
      if (text == null || text.isEmpty) return;

      // Skip if already prompted for this URL
      if (text == _lastPromptedClipboardUrl) return;

      final detection = _inputDetector.detect(text);
      if (!detection.isUrl) return;

      _lastPromptedClipboardUrl = text;

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.showMaterialBanner(
        MaterialBanner(
          content: Text(l10n.importClipboardUrlDetected),
          leading: const Icon(Icons.link),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                if (!mounted) return;
                Navigator.of(context).pushNamed(
                  app_routes.Routes.smartImport,
                  arguments: {'url': text},
                );
              },
              child: Text(l10n.importClipboardUseUrl),
            ),
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      );
      // Auto-dismiss after 8 seconds to prevent stale banners
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) messenger.hideCurrentMaterialBanner();
      });
    } catch (_) {
      // Clipboard access failed silently
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
        final inner = analyticsService.observer as FirebaseAnalyticsObserver?;
        if (inner != null) {
          // Gate screen_view events on analytics consent. The resolver
          // closure keeps us resilient if DI hasn't populated ConsentService
          // yet on the very first navigation.
          _analyticsObserver = ConsentAwareAnalyticsObserver(
            inner: inner,
            consentServiceResolver: () {
              try {
                return bootstrap.container.get<ConsentService>();
              } catch (_) {
                return null;
              }
            },
          );
        }

        // Session-start user properties (BUT-636 / 637 / 639). Routed via
        // AnalyticsService so the existing GDPR consent gate applies — when
        // consent is denied these calls silently no-op. lifecycle_stage uses
        // whatever profile data is loaded; if no UserService session yet
        // (cold start before login), classifier falls back to `new_`.
        _userPropertyBootstrap = UserPropertyBootstrap(analyticsService);
        UserProfile? profile;
        try {
          profile = bootstrap.container.get<UserService>().currentUserProfile;
        } catch (_) {
          // UserService unavailable at this point — fine, classifier handles null.
        }
        await _userPropertyBootstrap!.emitAtSessionStart(
          locale: _localeProvider.locale,
          profile: profile,
          lastCookAt: null,
          cooksLast14Days: 0,
        );
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
    // Lazily create once so rebuilds don't allocate a new observer each time
    _interactionObserver ??=
        InteractionRouteObserver(ServiceLocator.get<InteractionLogger>());

    // Seasonal accent: resolved once per rebuild via package:clock so tests
    // can override it. Service returns the base palette unmodified in summer.
    final seasonal = ServiceLocator.get<SeasonalAccentService>();
    final now = clock.now();
    final lightAccent = seasonal.getAccentsFor(now, base: ButleryColors.light);
    final darkAccent = seasonal.getAccentsFor(now, base: ButleryColors.dark);

    // Build navigator observers list with performance, snackbar, session activity, and optional analytics observers
    final observers = <NavigatorObserver>[
      _performanceObserver, // Track screen performance with Firebase Performance
      _snackbarObserver,
      _interactionObserver!,
      // BUT-521 follow-up: feeds `appRouteTracker.currentRouteName` so the
      // keyboard layer can dedupe shortcut-driven navigation (e.g. Cmd+K).
      appRouteTracker,
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
        navigatorKey: appNavigatorKey,
        navigatorObservers: observers,
        title: 'Butlery',
        theme: AppTheme.lightThemeWith(lightAccent),
        darkTheme: AppTheme.darkThemeWith(darkAccent),
        themeMode: _themeService?.themeMode ?? ThemeMode.system,
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
        // Universal fix for Android nav bar overlay + beta feedback FAB overlay
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          // Keyboard layer (BUT-521): Shortcuts + Actions wrap the entire
          // navigator subtree so Esc / Cmd+K / Cmd+1-3 etc. work on every
          // route. `Focus(autofocus)` is required so the Shortcuts widget
          // is the focus root that receives unhandled key events.
          return Shortcuts(
            shortcuts: AppShortcuts.bindings,
            child: Actions(
              actions: AppActions.dispatch(),
              child: Focus(
                autofocus: true,
                child: SafeArea(
                  top: false, // Let AppBar handle top
                  bottom: true, // Always protect bottom from system nav bar
                  left: false,
                  right: false,
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        key: feedbackRepaintBoundaryKey,
                        child: child,
                      ),
                      const FeedbackFAB(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingApp(String message) {
    return MaterialApp(
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      home: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: cs.surface,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: AppDimensions.iconSizeHero,
                  height: AppDimensions.iconSizeHero,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusL,
                    ),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    size: AppDimensions.iconSizeHero,
                    color: cs.outlineVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxxl),
                const CircularProgressIndicator(),
                const SizedBox(height: AppDimensions.spacingXl),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _onApplicationReady() async {
    if (!mounted) return;

    // Ensure deep link handler is initialized before processing
    // (_initializeUI is not awaited, so it may still be in progress)
    final handler = DeepLinkHandler();
    if (!handler.isInitialized) {
      await handler.initialize();
    }
    if (mounted) {
      handler.processPendingDeepLink(context);
    }

    // BUT-641: wire notification tap → deep-link router so taps land on
    // the right screen (recipe / friend request / comment / cooking / menu /
    // winback) and `notification_opened` analytics fires for CTR
    // attribution. Replaces the previous inline lambda which had no
    // analytics and crashed on legacy in-flight payloads without `route`.
    final notificationRouter = NotificationDeepLinkRouter(
      navigatorResolver: () => appNavigatorKey.currentState,
      analyticsResolver: () => ServiceLocator.tryGet<AnalyticsService>(),
    );
    NotificationService.onNotificationTapped = notificationRouter.handle;
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
  late final UserService _userService;
  bool _verificationDismissed = false;
  bool _wasAuthenticated = false;

  /// Only gate users created after this date (grandfather existing users).
  static final DateTime _verificationGateDate = DateTime(2026, 3, 20);

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.get<AuthService>();
    _userService = ServiceLocator.get<UserService>();

    // Log initial state
    if (_authService.currentUser != null) {
      AppLogger.debug(
        'AuthWrapper: User logged in at startup: ${_authService.currentUser!.uid}',
      );
    }

    // Listen to AuthService ChangeNotifier for auth state changes
    _authService.addListener(_onAuthStateChanged);
    // Listen to UserService to react when profile loads
    _userService.addListener(_onUserProfileChanged);

    // Handle race: if UserService loaded the profile before our listener
    // was attached, we'd never get notified. Re-read state after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _userService.currentUserProfile != null) {
        setState(() {});
      }
    });
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});

      final user = _authService.currentUser;
      if (user != null) {
        AppLogger.debug(
            'AuthWrapper: User authenticated: ${user.uid.maskedUserId}');
        // Re-process pending deep link when transitioning to authenticated
        if (!_wasAuthenticated) {
          DeepLinkHandler().processPendingDeepLink(context);
        }
      } else {
        AppLogger.debug('AuthWrapper: User signed out');
      }
      _wasAuthenticated = user != null;
    }
  }

  void _onUserProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppLogger.debug(
      'AuthWrapper: Disposing wrapper for user: ${_authService.currentUser?.uid.maskedUserId ?? 'NULL'}',
    );
    _authService.removeListener(_onAuthStateChanged);
    _userService.removeListener(_onUserProfileChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // State-based rendering - AuthService ChangeNotifier triggers rebuilds
    final user = _authService.currentUser;

    if (user != null) {
      // Email verification gate for new users (soft — dismissable)
      if (!_verificationDismissed) {
        final createdAfterGate = user.metadata.creationTime?.isAfter(
              _verificationGateDate,
            ) ??
            false;

        if (createdAfterGate && !user.emailVerified) {
          return EmailVerificationView(
            email: user.email ?? '',
            key: ValueKey('verify_${user.uid}'),
            onDismiss: () {
              setState(() => _verificationDismissed = true);
            },
          );
        }
      }

      // Check if user has completed onboarding
      final profile = _userService.currentUserProfile;
      if (profile == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!profile.hasCompletedOnboarding) {
        AppLogger.debug('AuthWrapper: User needs onboarding');
        return OnboardingView(key: ValueKey('onboarding_${user.uid}'));
      }

      AppLogger.debug(
        'AuthWrapper: NAVIGATION SUCCESS - User logged in: ${user.uid}',
      );
      return KeyedSubtree(
        key: ValueKey(user.uid),
        child: LayoutScaffolds.mainMenu(),
      );
    }

    AppLogger.debug('AuthWrapper: No user logged in, showing auth view');
    return const AuthView();
  }
}
