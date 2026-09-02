// lib/services/account/data_export_service.dart

import 'package:clock/clock.dart';
import 'dart:convert';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/account/export/content_export_manager.dart';
import 'package:butlery/services/account/export/social_export_manager.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';
import 'package:butlery/services/account/export/compliance_export_manager.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';
import 'package:butlery/services/account/export/family_export_manager.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

/// GDPR Compliance - Right to Data Portability (Article 20) and Right of Access (Article 15)
/// Exports all user data including:
/// - Profile and authentication data
/// - Recipes, menus, shopping lists
/// - Social data (friends, messages)
/// - Comments, ratings, activity
/// - **Audit logs (Article 30)** - All permission checks and data processing activities
/// - **Consent records (Article 7)** - User consent history
/// - Notification data and preferences
/// - All shared content
///
/// Uses facade pattern with specialized export managers for each data category.
class DataExportService extends BaseService {
  @override
  String get serviceName => 'DataExportService';
  final auth_repo.AuthRepository _authRepository;
  final FirestoreRepository _firestoreRepository;
  static const String _logTag = 'DataExportService';

  // Export managers (facade pattern)
  late final ContentExportManager _contentManager;
  late final SocialExportManager _socialManager;
  late final ActivityExportManager _activityManager;
  late final ComplianceExportManager _complianceManager;
  late final PreferencesExportManager _preferencesManager;
  late final FamilyExportManager _familyManager;

  // BUT-501: residual-Firestore gateway used by every manager that still
  // touches collections without a typed repository. Held here so the
  // profile read can use it directly.
  late final FirebaseDataExportRepository _exportRepo;

  // BUT-1773: the Art. 30 record of the Art. 15 request itself. Held HERE and
  // deliberately not handed to [_exportRepo] — see [_logExportAudit].
  late final FirebaseAuditRepository _auditRepository;

  DataExportService({
    required auth_repo.AuthRepository authRepository,
    required FirestoreRepository firestoreRepository,
    // BUT-501: optional repo injections for tests; production resolves
    // via ServiceLocator on first use inside each manager.
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    FeedbackRepository? feedbackRepository,
    CookSnapRepository? cookSnapRepository,
    CookEventRepository? cookEventRepository,
    ActivityEventRepository? activityEventRepository,
    WeeklyMenuPlanRepository? weeklyMenuPlanRepository,
    GroupWeeklyMenuPlanRepository? groupWeeklyMenuPlanRepository,
    PantryRepository? pantryRepository,
    RecipeRepository? recipeRepository,
    FirebasePersonalTagRepository? personalTagRepository,
    FirebasePersonalTagGroupRepository? personalTagGroupRepository,
    FirebaseDataExportRepository? dataExportRepository,
    // Family (Phase 5 item 14) — optional seams; production resolves via
    // ServiceLocator inside FamilyExportManager.
    HouseholdRepository? householdRepository,
    DinerProfileRepository? dinerProfileRepository,
    FamilyRatingRepository? familyRatingRepository,
    // Test seam: ComplianceExportManager's default ctor calls
    // FirebaseFunctions.instanceFor() which requires Firebase.initializeApp.
    // Tests inject a pre-built manager with a mocked FirebaseFunctions
    // to bypass the Firebase.app dependency.
    ComplianceExportManager? complianceExportManager,
    // BUT-1773: test seam for the one-row-per-export audit trail.
    FirebaseAuditRepository? auditRepository,
  }) : _authRepository = authRepository,
       _firestoreRepository = firestoreRepository {
    _exportRepo =
        dataExportRepository ??
        FirebaseDataExportRepository(
          firestore: _firestoreRepository.firestore,
          authRepository: authRepository,
        );
    _auditRepository =
        auditRepository ??
        FirebaseAuditRepository(_firestoreRepository.firestore);
    _contentManager = ContentExportManager(
      cookSnapRepository: cookSnapRepository,
      cookEventRepository: cookEventRepository,
      activityEventRepository: activityEventRepository,
      weeklyMenuPlanRepository: weeklyMenuPlanRepository,
      groupWeeklyMenuPlanRepository: groupWeeklyMenuPlanRepository,
      pantryRepository: pantryRepository,
      recipeRepository: recipeRepository,
      personalTagRepository: personalTagRepository,
      personalTagGroupRepository: personalTagGroupRepository,
      dataExportRepository: _exportRepo,
    );
    _socialManager = SocialExportManager(dataExportRepository: _exportRepo);
    _activityManager = ActivityExportManager(
      commentsRepository: commentsRepository,
      ratingsRepository: ratingsRepository,
      feedbackRepository: feedbackRepository,
      // Increment 5: pooled-rating events read through the export gateway.
      dataExportRepository: _exportRepo,
    );
    _complianceManager =
        complianceExportManager ??
        ComplianceExportManager(
          dataExportRepository: _exportRepo,
        );
    _preferencesManager = PreferencesExportManager(
      dataExportRepository: _exportRepo,
    );
    _familyManager = FamilyExportManager(
      householdRepository: householdRepository,
      dinerProfileRepository: dinerProfileRepository,
      familyRatingRepository: familyRatingRepository,
    );
  }

  /// Export all user data in GDPR-compliant JSON format
  /// Returns a comprehensive JSON string containing all user personal data.
  /// This can be saved to a file or shared with the user.
  /// Throws an exception if user is not authenticated or export fails.
  Future<String> exportUserData() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      // A refused request is a processing activity too — Art. 30 records the
      // attempt, not just the successes, and a bundle that was never produced
      // is exactly the case a data subject later disputes.
      await _logExportAudit(
        userId: _unauthenticatedActor,
        granted: false,
        outcome: 'denied_unauthenticated',
      );
      throw Exception('No authenticated user found');
    }

    final userId = user.uid;
    app_logger.AppLogger.info(
      '[$_logTag] Starting data export for user: ${userId.maskedUserId}',
    );
    try {
      final jsonString = await _buildExportBundle(userId);
      await _logExportAudit(
        userId: userId,
        granted: true,
        outcome: 'granted',
        bytes: jsonString.length,
      );
      return jsonString;
    } catch (e) {
      await _logExportAudit(
        userId: userId,
        granted: false,
        outcome: 'failed',
      );
      rethrow;
    }
  }

  /// Placeholder actor id for a request with no authenticated user. The
  /// `audit_logs` rule binds `userId` to `request.auth.uid`, so this row cannot
  /// land server-side — the write is best-effort by design and the local log
  /// still carries the refusal.
  static const String _unauthenticatedActor = 'unauthenticated';

  /// Exactly ONE audit row per export request, written HERE rather than in
  /// [FirebaseDataExportRepository].
  ///
  /// The gateway would be the obvious home — it already guards every read with
  /// `validateOwnership` — but a bundle makes ~30 of those calls, so wiring an
  /// audit repository into it would write ~30 near-identical rows per export.
  /// That is both noise in the one collection an auditor reads and a fight with
  /// `firestore.rules`, which caps `audit_logs` creates at
  /// `rateLimitWrite('audit_logs', 2)` per minute: rows 3..30 would be rejected
  /// and the trail would be arbitrarily partial. One row per REQUEST is what
  /// Art. 30 asks for anyway — the processing activity is "the user exported
  /// their data", not "the export read `friend_categories`".
  ///
  /// Fire-and-forget by contract ([FirebaseAuditRepository.logPermissionCheck]
  /// swallows its own failures): a failed audit write must never turn a
  /// successful Art. 15 export into an error the data subject sees.
  Future<void> _logExportAudit({
    required String userId,
    required bool granted,
    required String outcome,
    int? bytes,
  }) async {
    await _auditRepository.logPermissionCheck(
      userId: userId,
      operation: 'gdpr_export',
      resourceType: 'data_export',
      granted: granted,
      metadata: <String, dynamic>{
        'outcome': outcome,
        'article': '15',
        'bundle_bytes': ?bytes,
      },
    );
  }

  Future<String> _buildExportBundle(String userId) async {
    // Fan out all collection reads in parallel — wall time becomes max(t)
    // instead of sum(t). Each manager method is read-only, stateless, takes
    // only userId, and returns Map<String, dynamic>. Mirrors the pattern in
    // account_deletion_service.dart's tier-parallel deletion.
    final futures = <String, Future<Map<String, dynamic>>>{
      'profile': _exportUserProfile(userId),
      'recipes': _contentManager.exportRecipes(userId),
      'menus': _contentManager.exportMenus(userId),
      'shopping_lists': _contentManager.exportShoppingLists(userId),
      // BUT-1732: `shopping_lists` is the PERSONAL subcollection only. A
      // household that shops from a shared list had its whole shopping history
      // missing from the Art. 15 bundle while Art. 17 erased it.
      'shared_shopping_lists': _contentManager.exportSharedShoppingLists(
        userId,
      ),
      'personal_tags': _contentManager.exportPersonalTags(userId),
      'personal_tag_groups': _contentManager.exportPersonalTagGroups(userId),
      'cook_snaps': _contentManager.exportCookSnaps(userId),
      'recipe_cook_events': _contentManager.exportCookEvents(userId),
      'activity_events': _contentManager.exportActivityEvents(userId),
      'weekly_menu_plans': _contentManager.exportWeeklyMenuPlans(userId),
      'pantry_items': _contentManager.exportPantryItems(userId),
      'friends': _socialManager.exportFriends(userId),
      'messages': _socialManager.exportMessages(userId),
      'shared_content': _socialManager.exportSharedContent(userId),
      'comments_and_ratings': _activityManager.exportCommentsAndRatings(userId),
      'audit_logs': _complianceManager.exportAuditLogs(userId),
      'consent_records': _complianceManager.exportConsentRecords(userId),
      'preferences': _preferencesManager.exportPreferences(userId),
      'notifications': _preferencesManager.exportNotifications(userId),
      // BUT-1957: `users/{uid}/notifications`, the subcollection. NOT the same
      // rows as `notifications` above, which is the top-level
      // `user_notifications`. Added in the commit that first made the cascade
      // erase them — the export must reach anything the erasure does.
      'delivered_notifications': _preferencesManager
          .exportDeliveredNotifications(userId),
      'notification_preferences': _preferencesManager
          .exportNotificationPreferences(userId),
      'blocks': _socialManager.exportBlocks(userId),
      'conversation_memberships': _socialManager.exportConversationMemberships(
        userId,
      ),
      'feedback': _activityManager.exportFeedback(userId),
      'fcm_tokens': _preferencesManager.exportFcmTokens(userId),
      'category_preferences': _preferencesManager.exportCategoryPreferences(
        userId,
      ),
      'family': _familyManager.exportFamily(userId),
      // BUT-1396: PII the deletion cascade erases but the export previously
      // omitted (Art. 15 right-of-access). `group_weekly_menu_plans` wires in
      // the already-implemented-but-orphaned ContentExportManager method.
      'reports': _socialManager.exportReports(userId),
      'pings': _socialManager.exportPings(userId),
      'realtime_recipes': _contentManager.exportRealtimeRecipes(userId),
      'group_weekly_menu_plans': _contentManager.exportGroupWeeklyMenuPlans(
        userId,
      ),
      // BUT-1450: notification analytics the deletion cascade erases (Art. 15).
      'notification_history': _preferencesManager.exportNotificationHistory(
        userId,
      ),
      'notification_batches': _preferencesManager.exportNotificationBatches(
        userId,
      ),
      'notification_engagement': _preferencesManager
          .exportNotificationEngagement(userId),
      'notification_delivery': _preferencesManager.exportNotificationDelivery(
        userId,
      ),
      // Increment 5 (decision 12): pooled-rating events the deletion cascade
      // erases must be present in the export (Art. 15 ⊇ Art. 17). Pseudonymous.
      'pooled_rating_events': _activityManager.exportPooledRatingEvents(userId),
    };

    final keys = futures.keys.toList();
    final results = await Future.wait(futures.values, eagerError: true);

    final exportData = <String, dynamic>{
      'export_metadata': {
        'export_date': clock.now().toIso8601String(),
        'export_version': '2.0',
        'gdpr_compliance': {
          'article_15': 'Right of Access',
          'article_20': 'Right to Data Portability',
          'article_30': 'Records of Processing Activities (Audit Logs)',
          'article_7': 'Consent Records',
        },
        'user_id': userId,
        'format': 'JSON',
        'includes_audit_logs': true,
        'includes_consent_history': true,
      },
      for (var i = 0; i < keys.length; i++) keys[i]: results[i],
    };

    // Aggregate truncation flags into metadata
    final truncatedCollections = <String>[];
    final warnings = <Map<String, dynamic>>[];
    for (final entry in exportData.entries) {
      if (entry.key == 'export_metadata') continue;
      final value = entry.value;
      // BUT-1721: ONE depth-bounded walk, replacing a section-root check plus a
      // one-level `messages_truncated` special case. The per-conversation flag
      // sits inside a LIST of maps (`messages.conversations[i]`), and
      // `value.values` hands that list over as a single non-Map value — so the
      // old nested check could never see it, and a bundle that had dropped a
      // conversation's messages still reported itself complete.
      if (_declaresTruncation(value)) {
        truncatedCollections.add(entry.key);
      }
      // BUT-864 / BUT-1721: surface a failed section as a top-level warning so
      // the consuming UI flags a partial bundle instead of making the user scan
      // every section. Keyed on `error` as well as `error_code`: only a few of
      // the export managers' catch blocks set the second key, so a bundle whose
      // friends / recipes / preferences section had failed outright still
      // claimed to be complete. A manager's own token wins when it set one;
      // otherwise the section name derives a stable one, so a NEW manager
      // cannot go silent at bundle level by forgetting the second key.
      if (value is Map &&
          (value['error'] != null || value['error_code'] != null)) {
        final code = value['error_code'] ?? '${entry.key}-export-failed';
        // BUT-1732: the message is DERIVED here, never `value['error']` copied
        // through. Lifting a section field to bundle level changes its blast
        // radius: this string sits at the ROOT of an Art. 15 bundle the data
        // subject downloads and may forward to a supervisory authority, and
        // several managers still put a raw `e.toString()` in their section's
        // `error` — which can carry ANOTHER user's uid (composite doc ids like
        // `blocks/<uid>_<otherUid>`), a `create_composite` index URL embedding
        // `memberPermissions.<uid>` and the project id, or internal collection
        // paths. This chokepoint cannot tell an authored sentence from an
        // exception string, so it does not gamble on one: `error_code` already
        // names WHICH read failed, and the exception itself is in the logs.
        //
        // The two shapes are NOT the same claim, and asserting the stronger one
        // for both would re-introduce this ticket's defect with the sign
        // flipped. `error` means the section failed outright. `error_code`
        // WITHOUT `error` is a partial: `shared_shopping_list_export.dart` sets
        // it when one of three probes failed while the other two returned, so
        // the section body still ships its lists and its own accurate note. A
        // flat "could not be exported" would tell the data subject an exported
        // section is missing — at the root of an Art. 15 artifact they may
        // forward to a supervisory authority.
        final failedOutright = value['error'] != null;
        warnings.add({
          'section': entry.key,
          'error_code': code,
          'message': failedOutright
              ? 'The "${entry.key}" section could not be exported '
                    '(error_code: $code).'
              : 'The "${entry.key}" section may be incomplete — one of its '
                    'lookups did not complete (error_code: $code). See that '
                    'section for details.',
        });
      }
    }
    if (truncatedCollections.isNotEmpty) {
      (exportData['export_metadata']
              as Map<String, dynamic>)['truncated_collections'] =
          truncatedCollections;
    }
    // `data_completeness` is the one field literally named "is this complete?",
    // and it must answer for BOTH ways a bundle can be incomplete. Keyed on
    // truncation alone it stayed ABSENT when three sections failed and nothing
    // was clipped — byte-identical in that field to a fully successful export —
    // and when both happened it named size limits as the only cause. Nothing
    // reads these fields; the audience is a human, possibly a supervisory
    // authority.
    final truncationSentence =
        'Some collections were truncated due to size limits: '
        '${truncatedCollections.join(', ')}.';
    final warningSentence =
        'Some sections could not be exported or are incomplete: '
        '${warnings.map((w) => w['section']).join(', ')}. See warnings below.';
    final completeness = <String>[
      if (truncatedCollections.isNotEmpty) truncationSentence,
      if (warnings.isNotEmpty) warningSentence,
    ];
    if (completeness.isNotEmpty) {
      (exportData['export_metadata']
          as Map<String, dynamic>)['data_completeness'] = completeness.join(
        ' ',
      );
    }
    if (warnings.isNotEmpty) {
      (exportData['export_metadata'] as Map<String, dynamic>)['warnings'] =
          warnings;
    }

    // Convert to pretty-printed JSON
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    app_logger.AppLogger.success(
      '[$_logTag] Data export completed successfully',
    );
    return jsonString;
  }

  /// Whether [node] — or anything nested inside it — declares that rows were
  /// clipped, i.e. carries `truncated` or a `*_truncated` flag set to true.
  ///
  /// A section states its own incompleteness in more than one shape: at its root
  /// (`shopping_lists.truncated`) and per child (`messages.conversations[i]
  /// .messages_truncated`). Only the first ever reached `truncated_collections`,
  /// because the walk it replaced iterated `value.values` and required each one
  /// to be a Map — a List of conversation maps failed that test silently. A GDPR
  /// bundle that admits nothing is a bundle claiming completeness it does not
  /// have, which is the whole defect (BUT-1721).
  ///
  /// Depth-bounded: the deepest real flag sits two levels in, and a section also
  /// carries whole Firestore documents whose contents are none of this walk's
  /// business.
  static bool _declaresTruncation(Object? node, [int depth = 0]) {
    if (depth > 4) return false;
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key;
        if (key is String &&
            (key == 'truncated' || key.endsWith('_truncated')) &&
            entry.value == true) {
          return true;
        }
        if (_declaresTruncation(entry.value, depth + 1)) return true;
      }
      return false;
    }
    if (node is List) {
      for (final item in node) {
        if (_declaresTruncation(item, depth + 1)) return true;
      }
      return false;
    }
    return false;
  }

  /// Export user profile (kept in main service as it requires auth repository)
  Future<Map<String, dynamic>> _exportUserProfile(String userId) async {
    return await safeExecute(
          () async {
            // BUT-501: profile reads route through FirebaseDataExportRepository
            // which validates ownership before each fetch.
            final privateProfile = await _exportRepo.exportPrivateProfile(
              userId,
            );
            final publicProfile = await _exportRepo.exportPublicProfile(userId);

            final currentUser = _authRepository.currentUser;
            return {
              'private_profile': sanitizeForJson(privateProfile ?? {}),
              'public_profile': sanitizeForJson(publicProfile ?? {}),
              'firebase_auth': {
                'uid': userId,
                'email': currentUser?.email,
                'email_verified': currentUser?.emailVerified,
                'creation_time': currentUser?.metadata.creationTime
                    ?.toIso8601String(),
                'last_sign_in': currentUser?.metadata.lastSignInTime
                    ?.toIso8601String(),
              },
            };
          },
          operationName: 'Export user profile',
          defaultValue: {'error': 'Failed to export user profile'},
        ) ??
        {'error': 'Failed to export user profile'};
  }
}
