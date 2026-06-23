/// Butlery application entry point with modular DI system (5 domain modules + bootstrap stages).
///
/// The app shell ([ButleryApp]), the error fallback, and the auth-routing
/// subtree were extracted to `lib/app/` (BUT-530); this file keeps only the
/// bootstrap sequence. [ButleryApp] is re-exported so existing
/// `import 'package:butlery/main.dart'` consumers (e2e harnesses) keep working.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get_it/get_it.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Bootstrap system
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/firestore_bootstrap.dart';

// DI modules + bootstrap stages (shared with admin_main.dart)
import 'package:butlery/core/bootstrap/app_modules.dart';

import 'package:butlery/firebase_options.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/monitoring/web_error_reporter.dart';
import 'package:butlery/services/security/cert_pin_config.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/core/utils/logger.dart';

// App shell (extracted — BUT-530). Re-export ButleryApp so e2e harnesses that
// `import 'package:butlery/main.dart'` still resolve it.
import 'package:butlery/app/butlery_app.dart';
export 'package:butlery/app/butlery_app.dart' show ButleryApp;

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
        // BUT-769: fail-loud in release mode if any pinned host has an empty
        // fingerprint list. Cert pinning silently degrades to platform-trust
        // when pins are empty; a release build in that state is insecure
        // without an obvious error. The check is no-op in debug/profile so
        // daily dev work is unaffected. See docs/operations/cert-pin-rotation.md.
        CertPinConfig.assertReleaseModeSafety();

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

        // BUT-431: run the two deferred non-critical init side-effects
        // (perf-monitoring start + Firestore ingredient enrich) AFTER the first
        // frame rasterizes, so cold-start to first paint isn't blocked on them.
        // Registration stayed eager, so nothing depends on these synchronously.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(runDeferredBootstrap());
        });
      } catch (e, stackTrace) {
        runApp(
          ErrorApp(
            kDebugMode
                ? 'Application failed to initialize: $e\n\nStack trace:\n$stackTrace'
                : 'Application failed to initialize. Please restart.',
            onRestart: main,
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
  // BUT-431: defer the two non-critical init side-effects out of the
  // pre-runApp path. Must be set BEFORE bootstrap so the eager paths skip
  // them; main() re-runs them in a post-frame callback after runApp.
  enableDeferredBootstrap();

  // DI modules + bootstrap stages are built by the shared helper so the admin
  // entry point (lib/admin_main.dart) can reuse the exact same set.
  final modules = buildDiModules();
  final stages = buildBootstrapStages();

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
    final hasConsent = await hasAnalyticsConsent(
      GetIt.instance,
      logTag: 'EnableCollectionIfConsented',
    );

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
        FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          hasConsent && !kDebugMode,
        ),
        FirebasePerformance.instance.setPerformanceCollectionEnabled(
          hasConsent,
        ),
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
