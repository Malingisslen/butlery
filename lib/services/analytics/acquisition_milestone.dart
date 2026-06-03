/// First-UTM-arrival milestone (BUT-612).
///
/// Mirrors the [FirstRecipeSourceMilestone] / `first_share` dedupe pattern:
/// SharedPreferences-flag keyed by uid for fast first-write-wins on Firebase
/// user properties, plus a Firestore mirror at users/{uid}/acquisition/current
/// for server-side cohort/retention queries.
///
/// Anonymous users (no uid yet): user properties still set on the device
/// (Firebase Analytics tolerates pre-auth), Firestore write deferred until
/// the next UTM arrival when a uid exists.
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
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
  /// [utmSource], [utmMedium], [utmCampaign] are taken verbatim from deep
  /// link query params. Empty/missing source short-circuits the whole call.
  static Future<void> recordIfFirst({
    required AnalyticsService? analytics,
    required AcquisitionRepository? repository,
    required String? userId,
    required String? utmSource,
    String? utmMedium,
    String? utmCampaign,
  }) async {
    // Empty source = no signal worth attributing.
    if (utmSource == null || utmSource.isEmpty) return;
    final medium = utmMedium.orEmpty();
    final campaign = utmCampaign.orEmpty();

    final prefs = await tryGetSharedPreferences(logTag: 'AcquisitionMilestone');

    // 1. Firebase user properties — fire-and-forget per-user dedupe.
    final propsKey = userId != null && userId.isNotEmpty
        ? '$_userPropsPrefsPrefix$userId'
        : '$_userPropsPrefsPrefix$_anonSuffix';
    if (prefs == null || prefs.getBool(propsKey) != true) {
      if (analytics != null) {
        await Future.wait<void>([
          analytics.setUserProperty(
            name: AnalyticsUserProperties.acquisitionSource,
            value: utmSource,
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
    if (userId == null || userId.isEmpty || repository == null) return;
    final fsKey = '$_firestorePrefsPrefix$userId';
    if (prefs != null && prefs.getBool(fsKey) == true) return;

    final wrote = await repository.setAcquisitionIfAbsent(
      userId,
      AcquisitionAttribution(
        source: utmSource,
        medium: medium,
        campaign: campaign,
      ),
    );
    // Set the flag whether or not the write happened — if a doc already
    // existed, dedupe is satisfied either way and we don't want to keep
    // probing Firestore on every UTM click.
    await prefs?.setBool(fsKey, true);

    if (wrote) {
      AppLogger.debug(
        'AcquisitionMilestone: recorded first UTM for user (source=$utmSource)',
      );
    }
  }
}
