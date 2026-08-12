// lib/services/feature_flags/feature_flag_service.dart

import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';

/// Feature flag service using Firebase Remote Config.
/// Enables gradual rollouts, A/B testing, and kill switches without code deploys.
///
/// Usage:
/// ```dart
/// final flags = ServiceLocator.get<FeatureFlagService>();
/// if (flags.isEnabled(FeatureFlags.enableAlgoliaSearch)) {
///   // Use Algolia search
/// }
/// ```
class FeatureFlagService {
  final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;
  StreamSubscription<RemoteConfigUpdate>? _configUpdateSubscription;

  /// (flagName, variant) tuples already emitted as `feature_flag_evaluated`
  /// in the current session. A flag read inside a build method or stream
  /// listener can fire thousands of times; without dedup we'd blow through
  /// Firebase Analytics quotas with no extra signal. Reset by
  /// [resetSessionDedup] on session start (app foreground after >30 min
  /// background — wire from the lifecycle observer).
  final Set<String> _evaluatedTuples = <String>{};

  /// Soft cap on the dedup set to avoid unbounded growth if [resetSessionDedup]
  /// is never called. The realistic distinct (flag, variant) count is well
  /// under 100; this is a safety net, not a tuning knob.
  static const int _evaluatedTuplesMaxSize = 256;

  FeatureFlagService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  /// Default flag values - used when Remote Config is unavailable or flag not set
  static const Map<String, dynamic> _defaults = {
    // Phase 2 Scalability Flags
    'enable_algolia_search': false,
    'enable_subcollection_participants': true,
    'max_inline_participants': 10,
    'enable_reference_shared_content': true,

    // Phase 3 Scalability Flags
    'enable_server_rate_limiting': true,
    'enable_friend_category_subcollection': false,
    'max_inline_category_members': 50,
    'enable_activity_visibility_enum': true,
    'enable_permission_caching': false,
    'permission_cache_ttl_seconds': 300,
    'permission_cache_max_size': 1000,

    // Operational Flags
    // BUT-1560: `audit_log_retention_days` removed — it was a dead RC default (90)
    // that contradicted the BUT-665 tiered retention policy, which is enforced by
    // code constants in the Cloud Functions (consent audit 730d in
    // `purge-expired.ts`, general audit 180d in `request-account-deletion.ts`),
    // not by this flag. Nothing read it; a stale 90 here only risked misleading a
    // future operator into thinking it governed retention.
    'enable_performance_monitoring': true,

    // Pooled ratings "Butlery-betyget" — OFF until the full pipeline (incr 1–6)
    // ships and the backfill/legal gates clear. Same RC key the server reads.
    'enable_pooled_ratings': false,

    // Safety Flags (kill switches)
    'enable_social_features': true,
    'enable_sharing': true,
    'enable_messaging': true,
    // BUT-670: full-app maintenance kill switch + Swedish copy override
    'app_maintenance_mode': false,
    'app_maintenance_message_sv': '',
    // Ingredient sections (PR #211): kill switch for heading CAPTURE at
    // import (LLM bridge, text parser, schema.org heuristic). Display and
    // editing stay on — they're inert without data. Flip off remotely if
    // heading heuristics misfire broadly.
    'ingredient_section_capture': true,

    // Free on-device OCR as tier 0 before the paid provider chain. The code
    // default stays false so an unreachable Remote Config can never switch it
    // on.
    //
    // ON in production, and DELIBERATELY so despite losing its own gate. The
    // 2026-08-02 verdict rested on a harness that fed the recognizer RAW bytes
    // while production preprocesses first; that was fixed and re-run, and the
    // corrected eval scores on-device 96.1 against the paid chain's 96.6 over
    // 39 verified recipes — so the "at least as good" gate is NOT met. Malin
    // took the call on 2026-08-03: half a point is not worth paying per image
    // for, and the paid chain still runs behind the tier for anything read
    // poorly. **Do NOT flip this off citing the gate** — the gate was overridden
    // knowingly; see docs/architecture/ACCEPTED_DEVIATIONS.md. Flipping it off
    // restores the previous chain exactly.
    'enable_on_device_ocr': false,
    // BUT-1693: lets a household member share their own allergen list so menu
    // generation reads it instead of guessing a four-allergen floor. The
    // consent UI shipped 2026-08-12; what is still missing before this may be
    // flipped is (a) the firestore.rules block for `household_allergen_shares`,
    // (b) the atomic settings+share write, without which a shared list silently
    // lags its owner's edits (DPIA R4), and (c) the
    // consent_granted/consent_revoked audit pair (DPIA R5), and (d) the
    // erasure and access wiring — the account-deletion cascade step, its
    // probeResidualData leg, the reset-user-data entry and the GDPR export
    // section, none of which exist (`grep household_allergen functions/src` is
    // empty). This list is the launch checklist, so keep it exhaustive rather
    // than naming the interesting items. With the rules
    // absent, flipping this does not merely learn nothing: the denied query
    // makes every multi-member household report an incomplete roster, which
    // changes the menu and the opt-out dialog.
    'enable_household_allergen_sharing': false,
    // Decides WHICH of the on-device recognizer's two strings the parser sees —
    // the one built from its measured lines, or ML Kit's own assembly — AND
    // whether the page geometry travels with it. The page model is always
    // built; this flag decides whether it is attached and read.
    //
    // Since 2026-08-08 it is also the switch that makes the EDGE CROP reach an
    // import (`edge_crop.dart`): the sliver of the neighbouring cookbook page a
    // photo catches at the frame's edge is dropped from the layout string only,
    // so with this flag off the uncropped `providerText` ships and that text
    // still arrives in the recipe. Measured over 181 corpus pages: precision
    // 66.26 -> 66.64 %, and 66.65 -> 67.70 % on the 45 pages with a real
    // partial column, at a recall cost of 0.02 points. PROXY figures.
    //
    // THE SPLIT PATH IS LIVE behind this flag as of 248481c83 (2026-08-07):
    // `ocr_extraction_service` attaches the `PageLayout`, `photo_import_viewmodel`
    // carries it across pages, and `import_manager` runs `withoutOrphanTail`
    // and then hands the result to `MultiRecipeSplitter.split(input, layout:)`,
    // which opens a block per heading found by TYPE SIZE — where the text rules
    // need a title-shaped line with an ingredient cluster AFTER it. Measured on
    // 181 hand-verified corpus pages: multi-recipe spreads 19 % -> 33 % correct,
    // recipes never emitted 47 -> 39, single-recipe pages unchanged at 92 %.
    // PROXY figures — Windows offline OCR, not ML Kit.
    //
    // **This flag also switches on a rule that DELETES text from an import**
    // (`orphan_tail.dart`, 2026-08-08): a heading the camera frame separated
    // from its own recipe is cut off the end of the LAST page when under 120
    // characters follow it. Measured: 10 of 181 pages trimmed, precision
    // 66.64 -> 66.77 %, recall 91.54 -> 91.52 %, right block counts unchanged
    // (fixed 0, broke 0). All 10 trimmed pages were read against the PHOTOS on
    // 2026-08-09 and all 10 are correct cuts. The 120-200 band was designed and
    // then DECLINED by its own gate — every tail up there carries readable
    // content under the heading, in one case a whole small recipe. (An earlier
    // version of this line called those tails "subheadings inside a recipe",
    // read off the bare text and wrong on both examples it named.)
    //
    // **RE-MEASURED 2026-08-09 (BUT-1818): the trim's text cost is ZERO.** The
    // gold is not corrected — 14 entries were MARKED `frameCut`, and a default
    // run still scores every one of them as a complete recipe. What changed is
    // that the bias can now be excluded on request: `corpus_split_eval.dart
    // --trim --no-frame-cut` scores 15974 -> 15974 of 17441 gold tokens over the same
    // 181 pages — the `91.54 -> 91.52` above was the biased gold in full, and
    // is therefore an UPPER BOUND on the cost rather than the cost. The
    // paragraph below explains why.
    //
    // With the bias excluded the same blocks score 144 of 181 instead of 139.
    // **That is the GOLD moving, not the splitter** — the blocks are identical
    // in both runs, and the trim's own effect on right block counts is zero
    // under either gold (139 -> 139 and 144 -> 144, fixed 0 / broke 0 in each).
    // Nothing here is a benefit of turning this flag ON.
    //
    // **Why the figure above understates the trim.** The corpus gold records
    // frame-cut half recipes as complete ones. 14 of the 242 verified entries
    // were graded that way against their photographs, of which 11 bias recall
    // (`frameCut: fragment` — debris of the KIND this trim removes, though only one
    // of the 11 sits on a page it actually cuts); the other 3 are `tail`
    // and bias nothing. Both are floors rather than counts, and an unfound
    // FRAGMENT only makes the trim look worse (an unfound `tail` biases
    // nothing either way). So recall scores retained debris as a hit
    // and the trim is penalised for removing exactly what it was built to
    // remove: read `91.54 -> 91.52` as an upper bound on the cost, not the
    // cost.
    //
    // **OFF is the code default, and off means nothing is cut.** No geometry is
    // attached (`OCRExtractionService._layoutEnabled`), so `withoutOrphanTail`
    // no-ops on a null layout and the splitter never sees a layout either.
    //
    // **But turning it off does not undo what is already cached.** The FLAG
    // itself does propagate without a restart — `MaintenanceModeGate`
    // (`butlery_app.dart`, inside `MaterialApp.builder`, so app-wide) holds the
    // one `addOnConfigUpdatedListener` subscription, and the subscription's
    // handler IN THIS FILE calls `activate()`, which swaps the whole config.
    //
    // Where real-time updates are unsupported or unreachable, there is NO
    // mid-session fallback: nothing re-fetches on a timer or on foreground.
    // `fetchAndActivate` runs in exactly two places — `initialize()` at app
    // start, and `refresh()`, reachable only from the maintenance blocker's
    // retry button. `minimumFetchInterval` (1 h) THROTTLES those fetches; it
    // does not schedule one. So on that path the flag lands at the next app
    // start. (A draft of this paragraph said "the fallback is one hour", which
    // reads as a poll and is not what the constant does.)
    //
    // What survives either way is the OCR CACHE: it is keyed on the hash of the
    // preprocessed image, not on the flag, so a photo already read while the
    // flag was on keeps its stored geometry and keeps being trimmed. It leaves
    // that cache only on app restart, on the 24 h TTL, or by LRU eviction past
    // 100 distinct images. In memory only.
    //
    // So the honest instruction is the same either way: flip the flag, then
    // restart the app. Where real-time works the restart is for the cached
    // images; where it does not, it is for the flag as well. Say that to Malin
    // rather than "flip the flag and it's as before".
    // (An earlier version of this block said "there is no later step to wait
    // for", about column ordering. That was true of column ordering and went
    // false the moment this step landed behind the same flag.)
    //
    // **Keep the Remote Config description in step with this block** — the
    // console shows the key, not this comment, and Malin reads the description
    // at the moment she decides whether to enable it.
    //
    // Independent of enable_on_device_ocr on purpose: off, the free tier still
    // runs and stores byte-identical text to what it stored before the seam
    // widened, so a rollback never costs the free tier.
    'enable_layout_recipe_split': false,

    // Gradual Rollout Flags
    'new_search_rollout_percentage': 0,

    // Tagging Thresholds (BUT-353) — single source of truth in TaggingThresholds
    'tag_easy_max_ingredients': TaggingThresholds.easyMaxIngredients,
    'tag_easy_max_minutes': TaggingThresholds.easyMaxMinutes,
    'tag_advanced_min_ingredients': TaggingThresholds.advancedMinIngredients,
    'tag_advanced_min_minutes': TaggingThresholds.advancedMinMinutes,
    'tag_high_protein_ratio': TaggingThresholds.highProteinRatio,
    'tag_season_threshold': 2,
    'tag_spice_rich_count': TaggingThresholds.spiceRichCount,
    'tag_veggie_rich_count': TaggingThresholds.veggieRichCount,
  };

  /// Initialize the feature flag service.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set defaults for when Remote Config hasn't fetched values yet
      await _remoteConfig.setDefaults(
        _defaults.map(
          (key, value) => MapEntry(key, value),
        ),
      );

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Fetch and activate latest values
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      AppLogger.info('FeatureFlagService initialized successfully');
    } catch (e) {
      // Don't fail startup if Remote Config fails - use defaults
      AppLogger.warning(
        'Failed to initialize Remote Config, using defaults: $e',
      );
      _initialized = true;
    }
  }

  /// Check if a boolean feature flag is enabled.
  ///
  /// BUT-803 (PA8): emits `feature_flag_evaluated` once per (flag, variant)
  /// per session, matching the `isInRollout` path. Without this, flags read
  /// via `isEnabled` were dark in BigQuery.
  bool isEnabled(String flag) {
    bool result;
    try {
      result = _remoteConfig.getBool(flag);
    } catch (e) {
      AppLogger.warning('Failed to get flag "$flag", using default');
      final defaultValue = _defaults[flag];
      result = defaultValue is bool ? defaultValue : false;
    }
    _maybeLogFlagEvaluated(flag, result);
    return result;
  }

  /// Get an integer feature flag value.
  int getInt(String flag) {
    try {
      return _remoteConfig.getInt(flag);
    } catch (e) {
      AppLogger.warning('Failed to get int flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is int ? defaultValue : 0;
    }
  }

  /// Get a string feature flag value.
  String getString(String flag) {
    try {
      return _remoteConfig.getString(flag);
    } catch (e) {
      AppLogger.warning('Failed to get string flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is String ? defaultValue : '';
    }
  }

  /// Get a double feature flag value.
  double getDouble(String flag) {
    try {
      return _remoteConfig.getDouble(flag);
    } catch (e) {
      AppLogger.warning('Failed to get double flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is double ? defaultValue : 0.0;
    }
  }

  /// Force refresh flags from Remote Config.
  /// Use sparingly - respects minimum fetch interval.
  Future<bool> refresh() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        AppLogger.info('Feature flags refreshed with new values');
      }
      return updated;
    } catch (e) {
      AppLogger.warning('Failed to refresh feature flags: $e');
      return false;
    }
  }

  /// Check if user is in rollout percentage for gradual feature releases.
  /// Uses stable hashing so user always gets same result.
  bool isInRollout(String flag, String userId) {
    final percentage = getInt(flag);
    if (percentage <= 0) return false;
    if (percentage >= 100) return true;

    // Deterministic FNV-1a hash — stable across platforms and VM runs
    final key = '${flag}_$userId';
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final result = (hash % 100) < percentage;

    _maybeLogFlagEvaluated(flag, result);

    return result;
  }

  /// Emit `feature_flag_evaluated` once per (flag, variant) per session.
  /// Repeat calls with the same tuple are dropped silently. (BUT-663)
  /// `enabled` is emitted as a real `bool` — BigQuery typed filters depend
  /// on this (BUT-523). Stringified booleans broke `WHERE enabled = true`.
  void _maybeLogFlagEvaluated(String flag, bool variant) {
    final tuple = '$flag:$variant';
    if (_evaluatedTuples.contains(tuple)) return;

    if (_evaluatedTuples.length >= _evaluatedTuplesMaxSize) {
      // Defensive: skip emit if we somehow accumulated more variants than
      // the cap (extreme bug or pathological flag churn). Better silence
      // than runaway growth.
      return;
    }
    _evaluatedTuples.add(tuple);

    // BUT-766: tryLog swallows internal failures, matching the prior
    // behavior — a thrown logEvent leaves the tuple in the dedup set so we
    // don't retry-spam. Side-effect: still "silently lose this one event."
    AnalyticsService.tryLog(
      AnalyticsEvents.featureFlagEvaluated,
      parameters: {'flag': flag, 'enabled': variant},
    );
  }

  /// Clear the per-session dedup so subsequent flag reads emit again.
  /// Call from the app-lifecycle hook on foreground after >30 min idle.
  void resetSessionDedup() {
    _evaluatedTuples.clear();
  }

  /// Test seam: number of distinct (flag, variant) tuples captured this
  /// session. Lets unit tests verify dedup without mocking AnalyticsService.
  @visibleForTesting
  int get evaluatedTupleCount => _evaluatedTuples.length;

  /// Get all current flag values for debugging.
  Map<String, dynamic> getAllFlags() {
    final result = <String, dynamic>{};
    for (final key in _defaults.keys) {
      final value = _defaults[key];
      if (value is bool) {
        result[key] = isEnabled(key);
      } else if (value is int) {
        result[key] = getInt(key);
      } else if (value is double) {
        result[key] = getDouble(key);
      } else if (value is String) {
        result[key] = getString(key);
      }
    }
    return result;
  }

  /// Listen for real-time config updates.
  /// Only supported on some platforms.
  void addOnConfigUpdatedListener(void Function() onUpdated) {
    try {
      _configUpdateSubscription?.cancel();
      _configUpdateSubscription = _remoteConfig.onConfigUpdated.listen((_) {
        _remoteConfig.activate().then((_) {
          AppLogger.info('Feature flags updated in real-time');
          onUpdated();
        });
      });
    } catch (e) {
      // Real-time updates not supported on this platform
      AppLogger.debug('Real-time config updates not available: $e');
    }
  }

  /// Cancel active subscriptions.
  void dispose() {
    _configUpdateSubscription?.cancel();
  }
}

/// Feature flag constants for type-safe access.
/// Use these instead of string literals.
abstract final class FeatureFlags {
  // Phase 2 Scalability Flags
  static const enableAlgoliaSearch = 'enable_algolia_search';
  static const enableSubcollectionParticipants =
      'enable_subcollection_participants';
  static const maxInlineParticipants = 'max_inline_participants';
  static const enableReferenceSharedContent = 'enable_reference_shared_content';

  // Phase 3 Scalability Flags
  static const enableServerRateLimiting = 'enable_server_rate_limiting';
  static const enableFriendCategorySubcollection =
      'enable_friend_category_subcollection';
  static const maxInlineCategoryMembers = 'max_inline_category_members';
  static const enableActivityVisibilityEnum = 'enable_activity_visibility_enum';
  static const enablePermissionCaching = 'enable_permission_caching';
  static const permissionCacheTtlSeconds = 'permission_cache_ttl_seconds';
  static const permissionCacheMaxSize = 'permission_cache_max_size';

  // Operational Flags
  // BUT-1560: `auditLogRetentionDays` removed — see the defaults map above. Audit
  // retention is code-constant in the Cloud Functions, not an RC flag.
  static const enablePerformanceMonitoring = 'enable_performance_monitoring';

  // Pooled ratings "Butlery-betyget" display + contribution kill switch.
  // Must equal the server key in functions/src/ratings/pooled-ratings-flag.ts.
  static const enablePooledRatings = 'enable_pooled_ratings';

  // Safety Flags (kill switches)
  static const enableSocialFeatures = 'enable_social_features';
  static const enableSharing = 'enable_sharing';
  static const enableMessaging = 'enable_messaging';
  // BUT-670: maintenance-mode kill switch
  static const appMaintenanceMode = 'app_maintenance_mode';
  static const appMaintenanceMessageSv = 'app_maintenance_message_sv';
  // Ingredient sections (PR #211): import-capture kill switch
  static const ingredientSectionCapture = 'ingredient_section_capture';
  // Free on-device OCR tier 0 — ON in prod. It LOST its own measured gate and
  // ships anyway on Malin's 2026-08-03 call; read the defaults map above and
  // ACCEPTED_DEVIATIONS.md before changing it.
  static const enableOnDeviceOcr = 'enable_on_device_ocr';
  // Household allergen sharing (BUT-1693). OFF: the collection is default-denied
  // until the rules block lands. The settings row that writes a share and the
  // menu aggregate that reads one both sit behind this flag.
  static const enableHouseholdAllergenSharing =
      'enable_household_allergen_sharing';
  // Layout-aware recipe splitting — the split path is LIVE behind this flag;
  // see the defaults map above for the chain and the measured result.
  static const enableLayoutRecipeSplit = 'enable_layout_recipe_split';

  // Gradual Rollout Flags
  static const newSearchRolloutPercentage = 'new_search_rollout_percentage';

  // Tagging Thresholds
  static const tagEasyMaxIngredients = 'tag_easy_max_ingredients';
  static const tagEasyMaxMinutes = 'tag_easy_max_minutes';
  static const tagAdvancedMinIngredients = 'tag_advanced_min_ingredients';
  static const tagAdvancedMinMinutes = 'tag_advanced_min_minutes';
  static const tagHighProteinRatio = 'tag_high_protein_ratio';
  static const tagSeasonThreshold = 'tag_season_threshold';
  static const tagSpiceRichCount = 'tag_spice_rich_count';
  static const tagVeggieRichCount = 'tag_veggie_rich_count';
}
