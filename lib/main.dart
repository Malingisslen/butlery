/// Butlery application entry point with modular DI system (5 domain modules + bootstrap stages).
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:get_it/get_it.dart';

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
// Win-back attribution session-start hook (BUT-691)
import 'package:butlery/services/analytics/winback_attribution_service.dart';
import 'package:butlery/models/user_profile.dart';

// Views
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/auth/email_verification_view.dart';
import 'package:butlery/views/onboarding/onboarding_view.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

// Beta feedback
import 'package:butlery/widgets/common/feedback_fab.dart';
import 'package:butlery/widgets/maintenance_mode_gate.dart';

// Web error tracking (BUT-449)
import 'package:butlery/services/monitoring/web_error_reporter.dart';

// Keyboard shortcuts (BUT-521)
import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/observers/route_tracker.dart';

// Services for auth wrapper
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_deep_link_router.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:butlery/core/bootstrap/firestore_bootstrap.dart';
import 'package:butlery/firebase_options.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/widgets/consent/consent_renewal_dialog.dart';
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

        // Must run before any DI module instantiates FirestoreRepository.
        await FirestoreBootstrap.configure();

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
                : const AppleAppAttestWithDeviceCheckFallbackProvider(),
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

        // BUT-468: pre-read cached theme so the first MaterialApp paint
        // matches the user's saved preference. Without this, the app paints
        // through `ThemeMode.system` until the async DI-bootstrapped
        // ThemeService resolves, producing a visible theme flash.
        final initialThemeMode = await ThemeService.readCachedThemeMode();

        runApp(ButleryApp(initialThemeMode: initialThemeMode));
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

    // BUT-751: shared fail-closed gate; denies on missing service or error.
    // `bootstrap.container` is a `DIContainer` wrapping the global GetIt
    // singleton (`GetIt.instance`); the helper takes the raw GetIt.
    final hasConsent = await hasAnalyticsConsent(GetIt.instance,
        logTag: 'EnableCollectionIfConsented');

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
        final consentService = bootstrap.container.get<ConsentService>();
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
                        textAlign: TextAlign.start,
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
  const ButleryApp({super.key, this.initialThemeMode = ThemeMode.system});

  /// BUT-468: theme mode pre-read from SharedPreferences in `main()` before
  /// `runApp`. Used as the MaterialApp's `themeMode` until the async-resolved
  /// `ThemeService` instance lands, eliminating the visible theme-flash on
  /// startup that occurred when the first paint defaulted to system mode.
  final ThemeMode initialThemeMode;

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
    _initializeConsentRenewalCheck();
  }

  /// BUT-465: prompt the user to re-consent when the consent version has
  /// rolled forward. Awaits bootstrap so [ConsentService] is registered;
  /// schedules the dialog via a post-frame callback so the MaterialApp's
  /// navigator is ready. Failures are non-fatal — a missing consent
  /// service or network blip shouldn't block app start.
  Future<void> _initializeConsentRenewalCheck() async {
    try {
      final bootstrap = ApplicationBootstrap();
      await bootstrap.initialized;
      if (!bootstrap.isInitialized) return;

      final userService = bootstrap.container.get<UserService>();
      final userId = userService.currentUserId;
      if (userId == null || userId.isEmpty) return;

      final consentService = bootstrap.container.get<ConsentService>();
      final shouldRenew = await consentService.needsConsentRenewal();
      if (!shouldRenew) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Re-check auth in case the user signed out between
        // needsConsentRenewal() resolving and this callback firing —
        // avoids a renewal-dialog flash for a logged-out user.
        if (userService.currentUserId == null) return;
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null) return;
        ConsentRenewalDialog.show(ctx);
      });
    } catch (e) {
      AppLogger.warning('Consent renewal check failed: $e');
    }
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

  /// Initialize theme service.
  ///
  /// BUT-468: the MaterialApp paints with `widget.initialThemeMode` (pre-read
  /// from SharedPreferences in `main()`) until this resolves. The listener
  /// attached below handles all *subsequent* theme changes (the common
  /// `setThemeMode()` flow). The `setState` skip is purely a one-frame
  /// paint optimization for the steady-state startup case where the
  /// prewarmed value already matches what the service resolved to —
  /// avoids a redundant initial rebuild.
  Future<void> _initializeTheme() async {
    try {
      final bootstrap = ApplicationBootstrap();
      await bootstrap.initialized;

      if (bootstrap.isInitialized) {
        _themeService = bootstrap.container.get<ThemeService>();
        await _themeService?.initialize();
        _themeService?.addListener(_onThemeChanged);
        if (mounted && _themeService?.themeMode != widget.initialThemeMode) {
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
      if (kDebugMode) {
        AppLogger.warning('cacheManager dispose failed: $e');
      }
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

      _sessionStartTime = clock.now();

      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized) {
        final analyticsService = bootstrap.container.get<AnalyticsService>();
        await analyticsService.logEvent(
          name: AnalyticsEvents.appOpened,
          parameters: {
            'session_count': sessionCount,
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
            clock.now().difference(_sessionStartTime!).inSeconds;

        final analyticsService = bootstrap.container.get<AnalyticsService>();
        await analyticsService.logEvent(
          name: AnalyticsEvents.appBackgrounded,
          parameters: {
            'session_duration_seconds': sessionDuration,
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

        // BUT-691: bootstrap win-back conversion attribution. Reads the
        // four `lastWinBack*` bridge fields written server-side by the
        // win-back push CF; if a recent send is detected, slices the FA
        // session via ExperimentAssignment and arms the next-meaningful-
        // action probe in AnalyticsService.logEvent. Fire-and-forget so
        // the cold-start critical path isn't blocked on a Firestore
        // round-trip — events emitted before bootstrap completes simply
        // miss attribution (acceptable: 99% of users never received a
        // win-back; the read returns "no context" anyway).
        try {
          final userId = bootstrap.container.get<UserService>().currentUserId;
          if (userId != null && userId.isNotEmpty) {
            unawaited(bootstrap.container
                .get<WinbackAttributionService>()
                .bootstrap(userId: userId));
          }
        } catch (_) {
          // Non-critical.
        }
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
        themeMode: _themeService?.themeMode ?? widget.initialThemeMode,
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
          return MaintenanceModeGate(
            child: Shortcuts(
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
        // BUT-745: Skip the resume Firestore round-trip for users who just
        // signed up — there can't be a progress doc yet, so the gate's
        // FutureBuilder spinner is pure flicker. Heuristic: auth-account is
        // fresh (creationTime within ~5s of now). Falls through to the gate
        // when creationTime is null/unknown so returning users still resume
        // correctly.
        final createdAt = user.metadata.creationTime;
        final isFreshSignup = createdAt != null &&
            clock.now().difference(createdAt) < const Duration(seconds: 5);
        if (isFreshSignup) {
          return KeyedSubtree(
            key: ValueKey('onboarding_${user.uid}'),
            child: const OnboardingView(initialPage: 0),
          );
        }
        return _OnboardingResumeGate(
          key: ValueKey('onboarding_${user.uid}'),
          userId: user.uid,
        );
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

/// BUT-675: One-shot Firestore lookup to resolve the next-incomplete onboarding
/// step for resume support. Fires the `onboarding_resumed` analytics event when
/// the user re-enters mid-flow, and the `onboarding_abandoned` event + a
/// bottom-sheet nudge when the last step is older than 24h.
class _OnboardingResumeGate extends StatefulWidget {
  final String userId;

  const _OnboardingResumeGate({super.key, required this.userId});

  @override
  State<_OnboardingResumeGate> createState() => _OnboardingResumeGateState();
}

class _OnboardingResumeGateState extends State<_OnboardingResumeGate> {
  late final Future<_ResumeResolution> _future;
  bool _nudgeShown = false;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<_ResumeResolution> _resolve() async {
    // BUT-743: resolved via DI; no FirebaseFirestore.instance here.
    final svc = ServiceLocator.get<OnboardingProgressService>();
    final progress = await svc.readProgress(widget.userId);
    final pageIndex = svc.resolveResumePageIndex(progress);
    final showNudge = svc.shouldShowAbandonedNudge(progress, clock.now());
    // Fire-and-forget analytics — never block UI.
    if (progress.hasProgress && (pageIndex ?? 0) > 0) {
      unawaited(svc.logResumed(lastStep: progress.lastCompletedStep));
    }
    if (showNudge) {
      unawaited(svc.logAbandoned(lastStep: progress.lastCompletedStep));
    }
    return _ResumeResolution(
      pageIndex: pageIndex ?? 0,
      showNudge: showNudge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResumeResolution>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final resolution = snap.data!;
        // Schedule nudge for after first frame so we have a Scaffold context.
        if (resolution.showNudge && !_nudgeShown) {
          _nudgeShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showResumeNudge(context);
          });
        }
        return OnboardingView(initialPage: resolution.pageIndex);
      },
    );
  }

  Future<void> _showResumeNudge(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingResumeTitle,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  l10n.onboardingResumeBody,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(l10n.onboardingResumeCta),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResumeResolution {
  final int pageIndex;
  final bool showNudge;
  const _ResumeResolution({required this.pageIndex, required this.showNudge});
}
