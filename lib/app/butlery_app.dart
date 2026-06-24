/// Butlery application shell — the root [ButleryApp] widget and its state,
/// plus the [ErrorApp] fallback. Extracted from `main.dart` (BUT-530); `main()`
/// and the bootstrap helpers stay in `main.dart`, which re-exports
/// [ButleryApp].
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/app/auth/auth_wrapper.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/constants/routes.dart' as app_routes;
import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/observers/consent_aware_analytics_observer.dart';
import 'package:butlery/core/observers/interaction_route_observer.dart';
import 'package:butlery/core/observers/performance_navigator_observer.dart';
import 'package:butlery/core/observers/route_tracker.dart';
import 'package:butlery/core/observers/session_activity_observer.dart';
import 'package:butlery/core/observers/snackbar_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/user_property_bootstrap.dart';
import 'package:butlery/services/analytics/winback_attribution_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/services/notifications/notification_deep_link_router.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/performance/intelligent_cache_manager.dart';
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/services/theme/seasonal_accent_service.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/dialogs/session_timeout_warning_dialog.dart';
import 'package:butlery/widgets/common/feedback_fab.dart';
import 'package:butlery/widgets/consent/consent_renewal_dialog.dart';
import 'package:butlery/widgets/maintenance_mode_gate.dart';

/// Fallback shown when bootstrap throws before [ButleryApp] can start. The
/// "Restart App" button calls [onRestart] (wired to `main` in `main.dart`) so
/// this widget doesn't have to import the entry point.
class ErrorApp extends StatelessWidget {
  final String message;
  final VoidCallback onRestart;

  const ErrorApp(this.message, {super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery - Error',
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
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
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                    ElevatedButton(
                      onPressed: onRestart,
                      child: const Text('Restart App'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
  // BUT-786: tracks when we last paused so resume-after-long-background can
  // mint a fresh `session_id` (analytics convention: 30 min idle = new session).
  DateTime? _lastBackgroundedAt;
  static const Duration _sessionIdleResetThreshold = Duration(minutes: 30);
  static const Uuid _sessionIdGen = Uuid();
  // Resolved from DI in initState — same instance that views/services
  // access via ServiceLocator. BUT-801: previously a local field, which
  // meant the settings hub's locale switcher (via ServiceLocator) wrote
  // to a different LocaleProvider than the one MaterialApp listened to.
  late final LocaleProvider _localeProvider;
  ThemeService? _themeService;
  UserPropertyBootstrap? _userPropertyBootstrap;
  String? _lastPromptedClipboardUrl;
  static final _inputDetector = InputDetector();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ApplicationBootstrap completed before runApp(), so DI is ready here.
    _localeProvider = ApplicationBootstrap().container.get<LocaleProvider>();
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
        _sessionTimeoutService = bootstrap.container
            .get<SessionTimeoutService>();

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
      // BUT-786 (review C1): defensively await bootstrap before doing any
      // analytics work. Cold start already awaits this in `main()` before
      // `runApp`, so this is a no-op for the cold-start case. But on a
      // fast resume during a still-initializing bootstrap this prevents
      // the SharedPreferences write + session-id mint from running while
      // the analytics chokepoint is missing — keeps `session_count`,
      // `_sessionStartTime`, and `session_id` in lockstep.
      final bootstrap = ApplicationBootstrap();
      await bootstrap.initialized;
      if (!bootstrap.isInitialized) return;

      final prefs = await SharedPreferences.getInstance();
      final sessionCount = (prefs.getInt('session_count') ?? 0) + 1;
      await prefs.setInt('session_count', sessionCount);

      _sessionStartTime = clock.now();

      // BUT-786: install / refresh the analytics session id BEFORE the first
      // event of this resume cycle fires so `app_opened` itself carries it.
      _ensureAnalyticsSessionId();

      final analyticsService = bootstrap.container.get<AnalyticsService>();
      await analyticsService.logEvent(
        name: AnalyticsEvents.appOpened,
        parameters: {
          'session_count': sessionCount,
        },
      );
    } catch (e) {
      AppLogger.error('Failed to track app_opened', e);
    }
  }

  /// Track app backgrounded event with session duration
  Future<void> _trackAppBackgrounded() async {
    // BUT-786: timestamp the pause so the next resume can decide whether to
    // mint a new session id. Recorded outside the try-block so a logging
    // failure can't break the timer.
    _lastBackgroundedAt = clock.now();

    try {
      final bootstrap = ApplicationBootstrap();
      if (bootstrap.isInitialized && _sessionStartTime != null) {
        final sessionDuration = clock
            .now()
            .difference(_sessionStartTime!)
            .inSeconds;

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

  /// BUT-786: install/refresh the analytics `session_id` on cold start and
  /// resume. A new id is minted when (a) we don't have one yet, or
  /// (b) the app sat in background for >30min — analytics convention for
  /// "this is effectively a new session". Cheap enough to call on every
  /// resume; the no-op path runs in O(1) without touching DI.
  void _ensureAnalyticsSessionId() {
    try {
      final bootstrap = ApplicationBootstrap();
      if (!bootstrap.isInitialized) return;

      final analytics = bootstrap.container.get<AnalyticsService>();
      final existing = analytics.currentSessionId;
      final pausedAt = _lastBackgroundedAt;
      final now = clock.now();

      final needsNew =
          existing == null ||
          (pausedAt != null &&
              now.difference(pausedAt) >= _sessionIdleResetThreshold);

      if (needsNew) {
        analytics.setSessionId(_sessionIdGen.v4());
      }
      _lastBackgroundedAt = null;
    } catch (e) {
      // Best-effort — analytics shouldn't break the resume path.
      AppLogger.warning('Failed to ensure analytics session id: $e');
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
        _userPropertyBootstrap = bootstrap.container
            .get<UserPropertyBootstrap>();
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
            unawaited(
              bootstrap.container.get<WinbackAttributionService>().bootstrap(
                userId: userId,
              ),
            );
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
    _interactionObserver ??= InteractionRouteObserver(
      ServiceLocator.get<InteractionLogger>(),
    );

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
      ?_sessionActivityObserver,
      ?_analyticsObserver,
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
          // BUT-800: clamp `textScaler` once at the MaterialApp root so every
          // descendant widget inherits the clamped MediaQuery automatically.
          // Without this, users with extreme accessibility text-scale settings
          // (200%+) clip fixed-height surfaces. 1.4× preserves readability
          // gains while keeping our layouts intact.
          //
          // Per-scaffold `AccessibilityUtils.clampTextScaling` wrappers in
          // `base_scaffold.dart`, `adaptive_navigation.dart`, and
          // `unified_badge.dart` become redundant but harmless — a clamp
          // applied twice still resolves to the tighter bound.
          final mq = MediaQuery.of(context);
          final clampedChild = MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4),
            ),
            child: child,
          );
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
                          child: clampedChild,
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
      home: Builder(
        builder: (context) {
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
        },
      ),
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
