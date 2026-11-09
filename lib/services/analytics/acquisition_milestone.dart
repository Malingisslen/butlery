/// First-UTM-arrival milestone (BUT-612).
///
/// Mirrors the [FirstRecipeSourceMilestone] / `first_share` dedupe pattern:
/// SharedPreferences-flag keyed by uid for fast first-write-wins on Firebase
/// user properties, plus a Firestore mirror at users/{uid}/acquisition/current.
///
/// Anonymous users (no uid yet): user properties still set on the device
/// (Firebase Analytics tolerates pre-auth), Firestore write deferred until
/// the next UTM arrival when a uid exists.
library;

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/pending_acquisition.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';

class AcquisitionMilestone {
  /// SharedPreferences flag prefix; suffixed by uid for per-user dedupe, or
  /// by `__anon__` for anonymous-only writes (so the first authed write
  /// still goes through and lands the Firestore mirror).
  static const String _userPropsPrefsPrefix = 'acquisition_user_props_v1_';
  static const String _firestorePrefsPrefix = 'acquisition_firestore_v1_';
  static const String _anonSuffix = '__anon__';

  /// Records UTM attribution on the first arrival per user.
  ///
  /// First-write-wins applies independently to:
  /// - Firebase user properties (deduped via [_userPropsPrefsPrefix] flag)
  /// - Firestore mirror (deduped via [_firestorePrefsPrefix] flag and a
  ///   read-before-write check at the repository layer)
  ///
  /// An empty or missing source short-circuits the whole call.
  ///
  /// BUT-1997: the Firestore mirror is written only when [consentService]
  /// positively reports analytics consent. A missing service, no consent
  /// record, a refusal or a failed lookup all skip it, and a skipped write
  /// leaves the dedupe flag unset, so a later arrival with consent is still
  /// written.
  static Future<void> recordIfFirst({
    required AnalyticsService? analytics,
    required AcquisitionRepository? repository,
    required ConsentService? consentService,
    required String? userId,
    bool isGuest = false,
    required String? utmSource,
    String? utmMedium,
    String? utmCampaign,
  }) async {
    // Empty source = no signal worth attributing.
    final channel = AcquisitionChannel.from(utmSource, utmMedium);
    if (channel == null) return;
    // Only allowlisted values go on, so no free text from a link reaches the
    // account or the analytics properties, and the campaign name is not kept.
    final medium = channel.medium;
    const campaign = '';

    final prefs = await tryGetSharedPreferences(logTag: 'AcquisitionMilestone');

    final hasUid = userId != null && userId.isNotEmpty;
    final consented =
        hasUid &&
        await ConsentService.checkSafely(
          consentService,
          ConsentPurpose.analytics,
          logTag: 'AcquisitionMilestone',
        );

    // 1. Firebase user properties — fire-and-forget per-user dedupe.
    final propsKey = userId != null && userId.isNotEmpty
        ? '$_userPropsPrefsPrefix$userId'
        : '$_userPropsPrefsPrefix$_anonSuffix';
    // A signed-in user's flag is set only after a positive consent check, so
    // a later yes still sets the properties.
    if ((!hasUid || consented) &&
        (prefs == null || prefs.getBool(propsKey) != true)) {
      if (analytics != null) {
        await Future.wait<void>([
          analytics.setUserProperty(
            name: AnalyticsUserProperties.acquisitionSource,
            value: channel.source,
          ),
          analytics.setUserProperty(
            name: AnalyticsUserProperties.acquisitionMedium,
            value: medium.isEmpty ? null : medium,
          ),
          analytics.setUserProperty(
            name: AnalyticsUserProperties.acquisitionCampaign,
            value: campaign.isEmpty ? null : campaign,
          ),
        ]);
      }
      await prefs?.setBool(propsKey, true);
    }

    // 2. Firestore mirror — requires an authenticated uid. The
    // SharedPreferences flag short-circuits cheap; the repo additionally
    // checks the doc to defend against a wiped-prefs reinstall.
    if (userId == null || userId.isEmpty || repository == null || isGuest) {
      return;
    }
    final fsKey = '$_firestorePrefsPrefix$userId';
    if (prefs != null && prefs.getBool(fsKey) == true) return;

    if (!consented) return;

    final wrote = await repository.setAcquisitionIfAbsent(
      userId,
      AcquisitionAttribution(
        source: channel.source,
        medium: medium,
        // The campaign name stays out of the account: newsletter tools can
        // put a subscriber id in it, and the tally never reads it.
        campaign: '',
      ),
    );
    // Set the flag whether or not the write happened — if a doc already
    // existed, dedupe is satisfied either way and we don't want to keep
    // probing Firestore on every UTM click.
    await prefs?.setBool(fsKey, true);

    if (wrote) {
      AppLogger.debug(
        'AcquisitionMilestone: recorded first UTM for user (source=${channel.source})',
      );
    }
  }
}
