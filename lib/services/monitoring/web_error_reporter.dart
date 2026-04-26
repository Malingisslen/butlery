/// Web-only error reporting (BUT-449).
///
/// Flutter Crashlytics has no web SDK — its package only ships
/// android/, ios/, and macos/. To still capture web crashes in the same
/// GCP project as native, this module ships error events through the
/// `logWebError` Cloud Function. They land in Cloud Logging filtered by
/// label `event=web_error`; alert on rate via existing Cloud Monitoring.
///
/// Pipeline:
///   FlutterError.onError + PlatformDispatcher.onError (kIsWeb only)
///     → consent gate (analytics) → PII scrub → callable.
///
/// PII scrubbing reuses the BUT-421/422/423 client-side scrubber in
/// `lib/services/llm/pii_scrubber.dart`. Stack traces and error messages
/// can carry email/phone/personnummer fragments (e.g. an exception
/// message that interpolates user input), so every text field passed to
/// the function is scrubbed.
///
/// GDPR: web error reports are gated on `ConsentPurpose.analytics`.
/// Without consent we silently drop the event — same contract as the
/// native Crashlytics path in `main.dart`.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/llm/pii_scrubber.dart';

/// Region must match the LLM region — `europe-west1` keeps egress in EU.
const String _kRegion = 'europe-west1';

/// Server-side cap; stay well under it client-side too.
const int _kMaxStackChars = 8000;
const int _kMaxMessageChars = 2000;

/// Coordinates web-only error capture, scrubbing, and dispatch.
///
/// Lifetime: created once during app bootstrap when `kIsWeb` is true and
/// `ConsentService` is registered. The instance owns no state worth
/// disposing — it's safe to discard on hot-restart.
class WebErrorReporter {
  WebErrorReporter({
    required ConsentService consentService,
    FirebaseFunctions? functions,
  })  : _consentService = consentService,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _kRegion);

  final ConsentService _consentService;
  final FirebaseFunctions _functions;

  /// Install error handlers. Must run on web only — caller asserts
  /// `kIsWeb` so the native Crashlytics path is unaffected.
  void install() {
    assert(kIsWeb, 'WebErrorReporter is web-only');

    // Preserve any prior handler (e.g. the early-bootstrap presenter that
    // ran before Firebase was initialized). We chain to it after our
    // dispatch so dev still sees the red error screen.
    final priorFlutterHandler = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      // Always call the upstream handler synchronously so debug overlay
      // / DevTools observer continue to function.
      if (priorFlutterHandler != null) {
        priorFlutterHandler(errorDetails);
      } else {
        FlutterError.presentError(errorDetails);
      }
      // Fire-and-forget — the dispatch is gated, scrubbed, and async.
      unawaited(reportFlutterError(errorDetails));
    };

    final priorPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      // Mirror native behavior: return true to mark as "handled" so the
      // zone doesn't crash the runtime.
      unawaited(reportError(error, stack, fatal: true));
      // If a prior handler was set, defer to its return value.
      return priorPlatformHandler?.call(error, stack) ?? true;
    };
  }

  /// Report a Flutter framework error.
  Future<void> reportFlutterError(FlutterErrorDetails details) {
    return reportError(
      details.exceptionAsString(),
      details.stack,
      fatal: false,
      context: details.context?.toDescription(),
    );
  }

  /// Report an arbitrary error/stack pair.
  ///
  /// `fatal=true` is used for `PlatformDispatcher.onError` (uncaught
  /// async errors that crashed the zone). Framework errors caught by
  /// `FlutterError.onError` are non-fatal.
  Future<void> reportError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    if (!kIsWeb) return;

    // GDPR: skip silently when analytics consent missing. Note: we use
    // analytics consent here (not a dedicated diagnostics purpose) to
    // mirror native Crashlytics' policy in `main.dart` — flipping the
    // "diagnostics" toggle would create a parallel consent surface for
    // no UX gain. Document in privacy policy under "Analytics &
    // diagnostics".
    final hasConsent = await ConsentService.checkSafely(
      _consentService,
      ConsentPurpose.analytics,
      logTag: 'WebErrorReporter',
    );
    if (!hasConsent) return;

    try {
      final scrubbed = _scrubPayload(
        error: error,
        stack: stack,
        fatal: fatal,
        context: context,
      );
      final callable = _functions.httpsCallable(
        'logWebError',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 10),
        ),
      );
      await callable.call<void>(scrubbed);
    } catch (e) {
      // Never let an error reporter crash the app. Failure here means
      // we lose visibility on this one event; the user-facing surface
      // is unaffected.
      AppLogger.warning('WebErrorReporter dispatch failed: $e');
    }
  }

  /// Build the request payload. Public for unit testing — callers
  /// outside this file should use `reportError`.
  @visibleForTesting
  Map<String, dynamic> buildPayload({
    required Object error,
    StackTrace? stack,
    bool fatal = false,
    String? context,
  }) {
    return _scrubPayload(
      error: error,
      stack: stack,
      fatal: fatal,
      context: context,
    );
  }

  Map<String, dynamic> _scrubPayload({
    required Object error,
    StackTrace? stack,
    bool fatal = false,
    String? context,
  }) {
    final rawMessage = _truncate(error.toString(), _kMaxMessageChars);
    final rawStack =
        stack == null ? null : _truncate(stack.toString(), _kMaxStackChars);

    return {
      'message': scrubPii(rawMessage),
      if (rawStack != null) 'stack': scrubPii(rawStack),
      if (context != null) 'context': scrubPii(context),
      'fatal': fatal,
      'platform': 'web',
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
