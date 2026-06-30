// lib/services/account/data_export_service.dart

import 'package:clock/clock.dart';
import 'dart:convert';
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
  }) : _authRepository = authRepository,
       _firestoreRepository = firestoreRepository {
    _exportRepo =
        dataExportRepository ??
        FirebaseDataExportRepository(
          firestore: _firestoreRepository.firestore,
          authRepository: authRepository,
        );
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
      throw Exception('No authenticated user found');
    }

    final userId = user.uid;
    app_logger.AppLogger.info(
      '[$_logTag] Starting data export for user: ${userId.maskedUserId}',
    );

    // Fan out all collection reads in parallel — wall time becomes max(t)
    // instead of sum(t). Each manager method is read-only, stateless, takes
    // only userId, and returns Map<String, dynamic>. Mirrors the pattern in
    // account_deletion_service.dart's tier-parallel deletion.
    final futures = <String, Future<Map<String, dynamic>>>{
      'profile': _exportUserProfile(userId),
      'recipes': _contentManager.exportRecipes(userId),
      'menus': _contentManager.exportMenus(userId),
      'shopping_lists': _contentManager.exportShoppingLists(userId),
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
      if (value['truncated'] == true) {
        truncatedCollections.add(entry.key);
      }
      // BUT-864: surface BUT-842 transient-error markers as top-level
      // warnings so the consuming UI flags partial bundles prominently
      // (vs. requiring the user to scan every section for an `error_code`).
      if (value is Map && value['error_code'] != null) {
        warnings.add({
          'section': entry.key,
          'error_code': value['error_code'],
          'message': value['error'] ?? value['note'] ?? 'Unknown error',
        });
      }
      // Check nested maps (e.g., messages with per-conversation truncation)
      for (final nested in value.values) {
        if (nested is Map && nested['messages_truncated'] == true) {
          if (!truncatedCollections.contains(entry.key)) {
            truncatedCollections.add(entry.key);
          }
        }
      }
    }
    if (truncatedCollections.isNotEmpty) {
      (exportData['export_metadata']
              as Map<String, dynamic>)['truncated_collections'] =
          truncatedCollections;
      (exportData['export_metadata']
              as Map<String, dynamic>)['data_completeness'] =
          'Some collections were truncated due to size limits: ${truncatedCollections.join(', ')}';
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
