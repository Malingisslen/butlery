/// Navigator observer that only forwards lifecycle callbacks to the wrapped
/// [FirebaseAnalyticsObserver] while analytics consent is granted.
///
/// **GDPR Art. 7 (BUT-570):** `FirebaseAnalyticsObserver` emits `screen_view`
/// events unconditionally. Attaching it at bootstrap — before the user has
/// answered the consent dialog — leaks screen-navigation telemetry. This
/// wrapper checks [ConsentService] on every callback and no-ops when denied.
///
/// The consent check is synchronous from the caller's perspective: we cache
/// the last known result and refresh it opportunistically. Until the first
/// async refresh completes we fail **closed** (deny), so the very first
/// pre-consent screen never fires an event.
library;

import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';

class ConsentAwareAnalyticsObserver extends NavigatorObserver {
  final FirebaseAnalyticsObserver _inner;
  final ConsentService? Function() _consentServiceResolver;

  /// Last-known consent state. Defaults to `false` (deny) so we never leak
  /// events before the first async consent lookup resolves.
  bool _hasConsent = false;

  /// Guards re-entrant async refreshes.
  bool _refreshInFlight = false;

  ConsentAwareAnalyticsObserver({
    required FirebaseAnalyticsObserver inner,
    required ConsentService? Function() consentServiceResolver,
  })  : _inner = inner,
        _consentServiceResolver = consentServiceResolver;

  /// Refresh the cached consent flag from [ConsentService]. Called lazily
  /// from each lifecycle callback — on most frames this hits an in-memory
  /// cache inside ConsentService.
  void _scheduleConsentRefresh() {
    if (_refreshInFlight) return;
    final service = _consentServiceResolver();
    if (service == null) {
      // Bootstrap race: DI container not ready yet OR test harness not
      // wiring a consent service. Leave the cached flag untouched so a prior
      // grant (or a test-only debugSetConsent) isn't clobbered.
      return;
    }
    _refreshInFlight = true;
    // Fire-and-forget — the current callback deliberately uses the stale flag.
    // This makes the observer cheap and non-blocking; the trade-off is that a
    // consent-granted decision takes effect on the next navigation event, not
    // the current one. Acceptable because the first post-grant navigation
    // will still be logged.
    ConsentService.checkSafely(
      service,
      ConsentPurpose.analytics,
      logTag: 'ConsentAwareAnalyticsObserver',
    ).then((granted) {
      _hasConsent = granted;
    }).whenComplete(() {
      _refreshInFlight = false;
    });
  }

  bool get _shouldForward => _hasConsent;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleConsentRefresh();
    if (_shouldForward) _inner.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleConsentRefresh();
    if (_shouldForward) _inner.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _scheduleConsentRefresh();
    if (_shouldForward) {
      _inner.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleConsentRefresh();
    if (_shouldForward) _inner.didRemove(route, previousRoute);
  }

  /// Test hook — lets specs bypass the async refresh and assert the pure
  /// gating behaviour.
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void debugSetConsent(bool granted) {
    _hasConsent = granted;
  }
}
