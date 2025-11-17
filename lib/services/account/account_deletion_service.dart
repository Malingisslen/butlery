import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart' as user_svc;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/account/account_deletion/content_deletion_operations.dart';
import 'package:butlery/services/account/account_deletion/social_deletion_operations.dart';
import 'package:butlery/services/account/account_deletion/profile_deletion_operations.dart';
import 'package:butlery/services/account/account_deletion/storage_deletion_operations.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// GDPR-compliant account deletion orchestrator delegating to focused deletion modules.
///
/// Uses repository pattern for database access to improve testability and maintain
/// architectural consistency. Delegates to focused deletion operation modules for
/// different data categories (content, social, profile, storage).
class AccountDeletionService extends BaseService {
  @override
  String get serviceName => 'AccountDeletionService';
  final auth_repo.AuthRepository _authRepository;
  final FirestoreRepository _firestoreRepository;
  final AnalyticsService?
      _analyticsService; // Optional - may not be available on web
  static const String _logTag = 'AccountDeletionService';

  late final ContentDeletionOperations _contentOps;
  late final SocialDeletionOperations _socialOps;
  late final ProfileDeletionOperations _profileOps;
  late final StorageDeletionOperations _storageOps;

  AccountDeletionService({
    required auth_repo.AuthRepository authRepository,
    required FirestoreRepository firestoreRepository,
    required AuthService authService,
    required user_svc.UserService userService,
    required UnifiedRecipeService recipeService,
    required OfflineService offlineService,
    AnalyticsService?
        analyticsService, // Optional - may not be available on web
  })  : _authRepository = authRepository,
        _firestoreRepository = firestoreRepository,
        _analyticsService = analyticsService {
    // Initialize deletion operations with Firestore instance from repository
    final firestore = _firestoreRepository.firestore;
    _contentOps = ContentDeletionOperations(firestore);
    _socialOps = SocialDeletionOperations(firestore);
    _profileOps = ProfileDeletionOperations(firestore);
    _storageOps = StorageDeletionOperations(firestore, offlineService);
  }

  /// Access Firestore instance from repository
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  Future<Map<String, dynamic>> deleteUserAccount({
    required String reason,
    bool createAuditLog = true,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'deletedCollections': [],
      'failedCollections': [],
      'errors': [],
      'auditLogId': null,
    };

    try {
      final user = _authRepository.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final userId = user.uid;
      final userEmail = user.email ?? 'unknown';

      app_logger.AppLogger.info(
        '[$_logTag] Starting account deletion for user: $userId',
      );

      final deletionTasks = <String, Future<bool>>{
        'recipes': _contentOps.deleteRecipes(userId),
        'menus': _contentOps.deleteMenus(userId),
        'shopping_lists': _contentOps.deleteShoppingLists(userId),
        'friend_connections': _socialOps.removeFriendConnections(userId),
        'messages': _socialOps.deleteMessages(userId),
        'shared_content': _socialOps.removeFromSharedContent(userId),
        'comments_ratings': _socialOps.deleteCommentsAndRatings(userId),
        'preferences': _profileOps.deleteUserPreferences(userId),
        'offline_cache': _storageOps.clearOfflineData(userId),
        'public_profile': _profileOps.deletePublicProfile(userId),
        'realtime_recipes': _storageOps.deleteRealtimeRecipes(userId),
        'activity_feed': _profileOps.deleteActivityFeed(userId),
        'storage_files': _storageOps.deleteUserStorageFiles(userId),
        'profile': _profileOps.deleteUserProfile(userId),
      };

      for (final entry in deletionTasks.entries) {
        try {
          final success = await entry.value;
          if (success) {
            result['deletedCollections'].add(entry.key);
          } else {
            result['failedCollections'].add(entry.key);
          }
        } catch (e) {
          result['failedCollections'].add(entry.key);
          result['errors'].add('${entry.key}: ${e.toString()}');
          app_logger.AppLogger.error(
            '[$_logTag] Failed to delete ${entry.key}',
            e,
          );
        }
      }

      if (createAuditLog) {
        result['auditLogId'] = await _createDeletionAuditLog(
          userId: userId,
          email: userEmail,
          reason: reason,
          deletedCollections: result['deletedCollections'],
          failedCollections: result['failedCollections'],
        );
      }

      // Log analytics if available (may not be on web)
      await _analyticsService?.logAccountDeleted({
        'reason': reason,
        'collections_deleted': result['deletedCollections'].length,
        'collections_failed': result['failedCollections'].length,
      });

      if (result['failedCollections'].isEmpty) {
        await user.delete();
        result['success'] = true;
        app_logger.AppLogger.info(
          '[$_logTag] Account deletion completed successfully for user: $userId',
        );
      } else {
        app_logger.AppLogger.warning(
          '[$_logTag] Account deletion incomplete - some collections failed',
        );
      }

      return result;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Account deletion failed', e);
      result['errors'].add('Main process: ${e.toString()}');

      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        result['requiresReauth'] = true;
      }

      return result;
    }
  }

  Future<String> _createDeletionAuditLog({
    required String userId,
    required String email,
    required String reason,
    required List<dynamic> deletedCollections,
    required List<dynamic> failedCollections,
  }) async {
    return await safeExecute(
          () async {
            final auditDoc =
                await _firestore.collection('deletion_audit_logs').add({
              'userId': userId,
              'email': email,
              'reason': reason,
              'deletedCollections': deletedCollections,
              'failedCollections': failedCollections,
              'deletionTimestamp': FieldValue.serverTimestamp(),
              'gdprCompliant': failedCollections.isEmpty,
            });
            return auditDoc.id;
          },
          operationName: 'Create deletion audit log',
          defaultValue: 'error',
        ) ??
        'error';
  }
}
