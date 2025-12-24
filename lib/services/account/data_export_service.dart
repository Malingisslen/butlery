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

    // Create comprehensive export data structure
    final exportData = {
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
      'profile': await _exportUserProfile(userId),
      // Content exports
      'recipes': await _contentManager.exportRecipes(userId),
      'menus': await _contentManager.exportMenus(userId),
      'shopping_lists': await _contentManager.exportShoppingLists(userId),
      // Social exports
      'friends': await _socialManager.exportFriends(userId),
      'messages': await _socialManager.exportMessages(userId),
      'shared_content': await _socialManager.exportSharedContent(userId),
      // Activity exports
      'comments_and_ratings':
          await _activityManager.exportCommentsAndRatings(userId),
      'activity_history': await _activityManager.exportActivityHistory(userId),
      // Compliance exports (GDPR-critical)
      'audit_logs': await _complianceManager.exportAuditLogs(userId),
      'consent_records': await _complianceManager.exportConsentRecords(userId),
      // Preferences exports
      'preferences': await _preferencesManager.exportPreferences(userId),
      'notifications': await _preferencesManager.exportNotifications(userId),
      'notification_preferences':
          await _preferencesManager.exportNotificationPreferences(userId),
    };

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
            final userDoc =
                await _firestore.collection('users').doc(userId).get();

            // Get public profile
            final publicProfileDoc = await _firestore
                .collection('public_profiles')
                .doc(userId)
                .get();

            final currentUser = _authRepository.currentUser;
            return {
              'private_profile': userDoc.data() ?? {},
              'public_profile': publicProfileDoc.data() ?? {},
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
