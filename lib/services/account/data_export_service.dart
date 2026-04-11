// lib/services/account/data_export_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/content_export_manager.dart';
import 'package:butlery/services/account/export/social_export_manager.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';
import 'package:butlery/services/account/export/compliance_export_manager.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;
import 'package:butlery/core/constants/firestore_collections.dart';

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

  DataExportService({
    required auth_repo.AuthRepository authRepository,
    required FirestoreRepository firestoreRepository,
  })  : _authRepository = authRepository,
        _firestoreRepository = firestoreRepository {
    final firestore = _firestoreRepository.firestore;
    _contentManager = ContentExportManager(firestore: firestore);
    _socialManager = SocialExportManager(firestore: firestore);
    _activityManager = ActivityExportManager(firestore: firestore);
    _complianceManager = ComplianceExportManager(firestore: firestore);
    _preferencesManager = PreferencesExportManager(firestore: firestore);
  }

  /// Access Firestore instance from repository
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

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
        '[$_logTag] Starting data export for user: $userId');

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
      'activity_events': _contentManager.exportActivityEvents(userId),
      'weekly_menu_plans': _contentManager.exportWeeklyMenuPlans(userId),
      'friends': _socialManager.exportFriends(userId),
      'messages': _socialManager.exportMessages(userId),
      'shared_content': _socialManager.exportSharedContent(userId),
      'comments_and_ratings': _activityManager.exportCommentsAndRatings(userId),
      'audit_logs': _complianceManager.exportAuditLogs(userId),
      'consent_records': _complianceManager.exportConsentRecords(userId),
      'preferences': _preferencesManager.exportPreferences(userId),
      'notifications': _preferencesManager.exportNotifications(userId),
      'notification_preferences':
          _preferencesManager.exportNotificationPreferences(userId),
      'blocks': _socialManager.exportBlocks(userId),
      'conversation_memberships':
          _socialManager.exportConversationMemberships(userId),
      'feedback': _activityManager.exportFeedback(userId),
      'fcm_tokens': _preferencesManager.exportFcmTokens(userId),
      'category_preferences':
          _preferencesManager.exportCategoryPreferences(userId),
    };

    final keys = futures.keys.toList();
    final results = await Future.wait(futures.values, eagerError: true);

    final exportData = <String, dynamic>{
      'export_metadata': {
        'export_date': DateTime.now().toIso8601String(),
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
    for (final entry in exportData.entries) {
      if (entry.key == 'export_metadata') continue;
      final value = entry.value;
      if (value['truncated'] == true) {
        truncatedCollections.add(entry.key);
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

    // Convert to pretty-printed JSON
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    app_logger.AppLogger.success(
        '[$_logTag] Data export completed successfully');
    return jsonString;
  }

  /// Export user profile (kept in main service as it requires auth repository)
  Future<Map<String, dynamic>> _exportUserProfile(String userId) async {
    return await safeExecute(
          () async {
            // Get private profile
            final userDoc = await _firestore
                .collection(FirestoreCollections.users)
                .doc(userId)
                .get();

            // Get public profile
            final publicProfileDoc = await _firestore
                .collection(FirestoreCollections.publicProfiles)
                .doc(userId)
                .get();

            final currentUser = _authRepository.currentUser;
            return {
              'private_profile': sanitizeForJson(userDoc.data() ?? {}),
              'public_profile': sanitizeForJson(publicProfileDoc.data() ?? {}),
              'firebase_auth': {
                'uid': userId,
                'email': currentUser?.email,
                'email_verified': currentUser?.emailVerified,
                'creation_time':
                    currentUser?.metadata.creationTime?.toIso8601String(),
                'last_sign_in':
                    currentUser?.metadata.lastSignInTime?.toIso8601String(),
              },
            };
          },
          operationName: 'Export user profile',
          defaultValue: {'error': 'Failed to export user profile'},
        ) ??
        {'error': 'Failed to export user profile'};
  }
}
