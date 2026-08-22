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

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
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
  }) : _consentService = consentService,
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
    // Two scrubbers, deliberately. `scrubPii` knows free-text personal data —
    // email, personnummer, phone, address, relation names — and knows nothing
    // about identifiers; `maskIdentifiers` is the reverse. On web this is the
    // ONLY sink (Crashlytics is skipped entirely), so a uid or a
    // `direct_<uidA>_<uidB>` id reached Cloud Logging in clear text with only
    // the first scrubber applied (BUT-1897).
    //
    // Applied here rather than inside `scrubPii`: that function also scrubs LLM
    // prompts, and truncating identifiers there is a different decision about a
    // different payload.
    String scrub(String value) => LogSanitizer.maskIdentifiers(scrubPii(value));

    // Scrub BEFORE truncating, because a cut that lands inside an identifier is
    // worse than a lost tail: it drops a uid below the 20-char window so it
    // passes through RAW, and it makes a `direct_` id hash to a value that no
    // longer matches the same conversation elsewhere.
    //
    // Not because masking shortens the string — it does not always. `scrubPii`
    // replaces a 13-character personnummer with a 14-character token, and a
    // short `direct_a_b` grows into a 20-character hash.
    final message = _truncate(
      _scrubThrownHead(error.toString()),
      _kMaxMessageChars,
    );

    return {
      'message': message,
      if (stack != null)
        'stack': _truncate(_scrubStack(stack.toString()), _kMaxStackChars),
      if (context != null)
        'context': _truncate(scrub(context), _kMaxMessageChars),
      'fatal': fatal,
      'platform': 'web',
      'occurredAt': clock.now().toUtc().toIso8601String(),
    };
  }

  /// Scrubs a stack trace WITHOUT mangling its frames.
  ///
  /// The frames must stay readable: `maskIdentifiers` truncates any 20-28
  /// character alphanumeric run, and hundreds of class names in `lib/` are
  /// exactly that shape, so masking the whole thing turns
  /// `#0 AllergenPreferencesViewModel.build` into `#0 Alle***.build`. On web
  /// this reporter is the only sink there is, and unreadable frames make a
  /// crash report worthless.
  ///
  /// But the HEAD is not frames. Under dart2js a thrown Dart object is wrapped
  /// in a JS `Error` whose message is the object's own `toString()`, and the
  /// engine formats `.stack` as that message followed by the frames — so the
  /// first line of a web stack trace is a verbatim copy of the string the
  /// `message` field was just masked from. Masking one and not the other
  /// exports it anyway. Split at the first frame: mask above it, leave the
  /// frames to `scrubPii` alone.
  static String _scrubStack(String stack) {
    final firstFrame = stack.indexOf(_frameStart);
    if (firstFrame < 0) return LogSanitizer.maskIdentifiers(scrubPii(stack));
    if (firstFrame == 0) return scrubPii(stack);
    // The head is an exception string too, so it keeps its TYPE LABEL for the
    // same reason the message field does.
    return _scrubThrownHead(stack.substring(0, firstFrame)) +
        scrubPii(stack.substring(firstFrame));
  }

  /// A leading `SomeException: ` label, which must survive masking.
  ///
  /// Deliberately NOT bounded by length, and deliberately narrow in alphabet.
  ///
  /// Length cannot separate the two things here: `PermissionDeniedException` is
  /// 25 characters, the same window as a uid, so any bound tight enough to
  /// exclude an identifier also excludes the labels this exemption exists FOR —
  /// the ones inside the 20-28 window. Capping it at 19 was tried and did
  /// exactly that. (A shorter name like `ValidationException` survives such a
  /// cap, but it never needed the exemption: below 20 characters it is not a
  /// masking candidate at all.)
  ///
  /// What DOES separate them is shape. A public Dart exception name is
  /// UpperCamelCase: initial capital, no digits, no underscore. A Firebase uid
  /// is 28 random alphanumerics and a DM id is `direct_<a>_<b>`. Requiring that
  /// shape therefore exempts the label and never the secret.
  ///
  /// The rule wants a BARE `Name: `. Anything between the name and the colon
  /// fails it, and the name then falls inside the masked span — so
  /// `StorageUploadException($code): ` degrades to `Stor***(unauthorized): `,
  /// its 22-character name being inside the window. Private classes fail it
  /// too, on the underscore.
  ///
  /// Readability only, and the trade is the right way round: a name that cannot
  /// be told from an identifier should lose, not the identifier.
  ///
  /// Residual, stated rather than hidden: any 20-28 character token that is
  /// digit-free with a leading capital would pass — a uid drawn entirely from
  /// letters, but equally a long display name. Do not lean on how unlikely
  /// that is; the argument below rests on POSITION instead.
  ///
  /// What actually closes it is POSITION, not improbability: the token has to
  /// occupy one of the first two label slots — offset 0, or immediately after
  /// one accepted label such as V8's `Error: ` — and be followed by `": "`.
  /// Nothing mints a head of that shape, because a project exception prefixes
  /// its own class name, which puts any interpolated id at slot three or later.
  ///
  /// Two slots, not one, because the peel below runs twice. An earlier version
  /// of this sentence said "the very first thing in the string" and was
  /// falsified by its own neighbour.
  ///
  /// Note the exemption skips `scrubPii` too, so the kept span is unscrubbed
  /// either way. No free-text rule can match a lone token of this shape
  /// (`pii_scrubber`'s name rule needs a relation trigger), so this is not a
  /// regression against the behaviour before the label was preserved.
  ///
  /// No `^`: [RegExp.matchAsPrefix] does the anchoring, and `^` would pin the
  /// match to the start of the STRING rather than to the offset it is given —
  /// which silently defeats the second peel below.
  static final RegExp _leadingTypeLabel = RegExp(r'[A-Z][A-Za-z$]*: ');

  /// Masks an exception string while keeping its TYPE LABEL intact.
  ///
  /// `maskIdentifiers` truncates any 20-28 character alphanumeric run, which is
  /// the window `PermissionDeniedException` falls in — see the note on
  /// [_leadingTypeLabel] above. The exception classes split the label off
  /// outside their own masked span for that reason, and this sink was where
  /// that decision was being undone, on the one platform whose only crash
  /// report this is.
  static String _scrubThrownHead(String value) {
    String scrub(String v) => LogSanitizer.maskIdentifiers(scrubPii(v));

    // Peeled TWICE, because V8 nests them. A dart2js stack head reads
    // `Error: PermissionDeniedException: …` — the engine's own label wrapping
    // ours — so peeling one leaves the real type name inside the masked span,
    // where it is 25 characters and gets eaten. The message field never sees
    // this shape; a stack head on Chrome or Edge always does.
    var kept = 0;
    for (var i = 0; i < 2; i++) {
      final label = _leadingTypeLabel.matchAsPrefix(value, kept);
      if (label == null) break;
      kept = label.end;
    }
    if (kept == 0) return scrub(value);
    return value.substring(0, kept) + scrub(value.substring(kept));
  }

  /// Matches the start of a stack FRAME in the three spellings that reach this
  /// reporter: Dart's own `#0 `, V8's `    at fn (url)`, and the
  /// `fn@url:line:col` that SpiderMonkey and JSC emit.
  ///
  /// The third one is not decoration. A Firefox or Safari trace has NO header
  /// line at all, so a regex that knows only the first two matches nothing,
  /// the whole trace is treated as message head, and every frame is mangled —
  /// which is exactly the outcome this split exists to prevent. Failing that way is safe for privacy and useless
  /// for debugging.
  static final RegExp _frameStart = RegExp(
    r'^\s*(#\d+\s|at \S|[^\s@]*@\S+:\d+:\d+)',
    multiLine: true,
  );

  String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
