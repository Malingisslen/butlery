import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';

/// Base class for analytics event trackers providing GDPR consent checking
/// and the shared once-per-user activation-milestone primitive.
abstract class BaseTracker {
  final AnalyticsRepository repository;
  ConsentService? _consentService;

  BaseTracker({required this.repository});

  /// Update consent service reference
  void setConsentService(ConsentService? service) {
    _consentService = service;
  }

  /// Check if user has granted analytics consent
  /// Returns false if consent not yet configured (privacy-by-default, GDPR Art.25)
  Future<bool> hasAnalyticsConsent() async {
    return ConsentService.checkSafely(_consentService, ConsentPurpose.analytics,
        logTag: 'BaseTracker');
  }

  /// Log generic event through repository
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    assert(
      _noStringifiedBooleans(parameters),
      'BaseTracker.logEvent: stringified booleans (\'true\'/\'false\') break '
      'BigQuery typed filters — emit native bool instead. (BUT-523)',
    );
    await repository.logEvent(name: name, parameters: parameters);
  }

  /// Asserts the BUT-523 invariant: no analytics param value is the string
  /// `'true'` or `'false'`. Stringified booleans break BigQuery typed
  /// filters (`WHERE enabled = true` fails when the column is STRING).
  /// Debug-only — `assert` strips in release.
  static bool _noStringifiedBooleans(Map<String, Object>? parameters) {
    if (parameters == null) return true;
    for (final value in parameters.values) {
      if (value is String && (value == 'true' || value == 'false')) {
        return false;
      }
    }
    return true;
  }

  /// BUT-1052: once-per-(install,user) primitive shared by every fire-once
  /// flow in the tracker package. Encapsulates the three things every such
  /// flow needs: consent check, SharedPreferences key check, and the dedupe
  /// write. [onFire] runs the domain-specific `repository.logEvent(...)`;
  /// [onFireUserProperty] is optional for flows that ALSO set a user
  /// property (activation-milestones do; funnel-entry events don't).
  ///
  /// Dedupe key: `'$prefsPrefix$userId'`. Persists across restarts; the uid
  /// suffix means household devices (where two users share one device) each
  /// get their own fire when each user signs in.
  ///
  /// Returns true if fired, false if skipped (no userId, no consent, prefs
  /// unavailable, or key already set).
  ///
  /// Subclasses-only — direct external callers use the typed wrappers
  /// (`fireOnceMilestone`, `logSocialOnboardingStartedIfFirstEntry`, etc.).
  @protected
  Future<bool> fireOnceWithKey({
    required String? userId,
    required String prefsPrefix,
    required Future<void> Function() onFire,
    Future<void> Function()? onFireUserProperty,
  }) async {
    if (userId == null || userId.isEmpty) return false;
    if (!await hasAnalyticsConsent()) return false;

    final prefs = await _tryGetPrefs();
    if (prefs == null) return false;

    final key = '$prefsPrefix$userId';
    if (prefs.getBool(key) == true) return false;

    await onFire();
    if (onFireUserProperty != null) {
      await onFireUserProperty();
    }
    await prefs.setBool(key, true);
    return true;
  }

  /// Once-per-user activation-milestone primitive. Mirrors the BUT-584 firstShare
  /// pattern; used by every `logFirst*IfMilestone` method across the trackers
  /// (firstShare/firstSearch on recipe; firstFriend/firstComment/firstGroup on
  /// social; firstMealPlan on menu).
  ///
  /// BUT-1052: now a thin wrapper around [fireOnceWithKey]. It supplies the
  /// milestone-shaped onFire/onFireUserProperty callbacks; the consent +
  /// prefs + dedupe-key machinery lives in fireOnceWithKey.
  ///
  /// `extraParams` lets callsites add their domain-specific payload
  /// (e.g. `share_method`, `recipe_count_at_time`). `minutes_since_signup` is
  /// auto-added when `joinedAt` is provided — never guessed when null.
  ///
  /// Returns true if the milestone fired, false if skipped.
  Future<bool> fireOnceMilestone({
    required String? userId,
    required String prefsPrefix,
    required String eventName,
    required String userPropertyName,
    DateTime? joinedAt,
    Map<String, Object> extraParams = const <String, Object>{},
  }) {
    return fireOnceWithKey(
      userId: userId,
      prefsPrefix: prefsPrefix,
      onFire: () async {
        final params = <String, Object>{...extraParams};
        if (joinedAt != null) {
          params['minutes_since_signup'] =
              clock.now().difference(joinedAt).inMinutes;
        }
        await repository.logEvent(name: eventName, parameters: params);
      },
      onFireUserProperty: () =>
          repository.setUserProperty(name: userPropertyName, value: 'true'),
    );
  }

  Future<SharedPreferences?> _tryGetPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning(
        'milestone tracker: SharedPreferences unavailable ($e); skipping',
      );
      return null;
    }
  }
}
