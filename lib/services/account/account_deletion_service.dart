import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
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
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/crypto_utils.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';

/// GDPR-compliant account deletion orchestrator delegating to focused deletion modules.
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
  final SearchRepository? _searchRepository;
  static const String _logTag = 'AccountDeletionService';

  /// GDPR Art.5(1)(e) — audit log retention period.
  /// Must align with cleanup-audit-logs.ts expireAt TTL query.
  static const int _auditLogRetentionDays = 180;
  static const int _searchIndexDeleteChunkSize = 50;

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
    SearchRepository? searchRepository,
  })  : _authRepository = authRepository,
        _firestoreRepository = firestoreRepository,
        _analyticsService = analyticsService,
        _searchRepository = searchRepository {
    // Initialize deletion operations with Firestore instance from repository
    final firestore = _firestoreRepository.firestore;
    _contentOps = ContentDeletionOperations(firestore);
    _socialOps = SocialDeletionOperations(firestore);
    _profileOps = ProfileDeletionOperations(firestore);
    _storageOps = StorageDeletionOperations(
      firestore: firestore,
      offlineService: offlineService,
      authRepository: authRepository,
      // Note: audit repository could be injected here for GDPR Article 30 compliance
    );
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

      // Search index cleanup must complete before Firestore deletion (needs IDs)
      if (_searchRepository != null) {
        await _runDeletionStep(
            'search_index_user', result, () => _deleteSearchIndexUser(userId));
        await _runDeletionStep('search_index_recipes', result,
            () => _deleteSearchIndexRecipes(userId));
      }

      // Delete auth entry FIRST — if reauth is required, abort before
      // touching any Firestore data. Orphaned Firestore data can be cleaned
      // by scheduled Cloud Functions, but a zombie auth entry cannot.
      try {
        await user.delete();
      } catch (authError) {
        app_logger.AppLogger.error(
          '[$_logTag] Failed to delete auth entry',
          authError,
        );
        result['errors'].add('auth_deletion: ${authError.toString()}');
        if (authError is FirebaseAuthException &&
            authError.code == 'requires-recent-login') {
          result['requiresReauth'] = true;
        }
        // Auth deletion failed — abort entire operation
        return result;
      }

      // Auth deleted — now clean up Firestore data in parallel tiers.
      // Tier 1: All independent content, social, notification, and storage deletions.
      final tier1 = <String, Future<bool> Function()>{
        'recipes': () => _contentOps.deleteRecipes(userId),
        'menus': () => _contentOps.deleteMenus(userId),
        'shopping_lists': () => _contentOps.deleteShoppingLists(userId),
        'personal_tags': () => _contentOps.deletePersonalTags(userId),
        'personal_tag_groups': () =>
            _contentOps.deletePersonalTagGroups(userId),
        'cook_snaps': () => _contentOps.deleteCookSnaps(userId),
        'friend_connections': () => _socialOps.removeFriendConnections(userId),
        'messages': () => _socialOps.deleteMessages(userId),
        'shared_content': () => _socialOps.removeFromSharedContent(userId),
        'comments_ratings': () => _socialOps.deleteCommentsAndRatings(userId),
        // shared_menus + shared_shopping_lists deleted via removeFromSharedContent (unified shared_content collection)
        'reports': () => _socialOps.deleteUserReports(userId),
        'block_records': () => _deleteBlockRecords(userId),
        'preferences': () => _profileOps.deleteUserPreferences(userId),
        'fcm_tokens': () => _profileOps.deleteFcmTokens(userId),
        'notification_preferences': () =>
            _profileOps.deleteNotificationPreferences(userId),
        'notifications': () => _profileOps.deleteNotifications(userId),
        'notification_analytics': () =>
            _profileOps.deleteNotificationAnalytics(userId),
        'offline_cache': () => _storageOps.clearOfflineData(userId),
        'public_profile': () => _profileOps.deletePublicProfile(userId),
        'realtime_recipes': () => _storageOps.deleteRealtimeRecipes(userId),
        'presence': () => _storageOps.deletePresence(userId),
        'storage_files': () => _storageOps.deleteUserStorageFiles(userId),
      };

      // Tier 2: Subcollections under users/{uid} (must complete before doc deletion).
      final tier2 = <String, Future<bool> Function()>{
        'consent_records': () => _profileOps.deleteConsentRecords(userId),
        'user_subcollections': () =>
            _profileOps.deleteUserSubcollections(userId),
      };

      // Tier 3: The user document itself (must be last).
      final tier3 = <String, Future<bool> Function()>{
        'profile': () => _profileOps.deleteUserProfile(userId),
      };

      // Execute each tier in parallel, tiers sequentially
      for (final tier in [tier1, tier2, tier3]) {
        await Future.wait(
          tier.entries.map((e) => _runDeletionStep(e.key, result, e.value)),
        );
      }

      // Audit log AFTER auth deletion succeeds — no lying audit on failure
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

      // Invalidate FCM token at SDK level via NotificationService
      try {
        await ServiceLocator.get<notif.NotificationService>().resetForLogout();
      } catch (e) {
        app_logger.AppLogger.warning(
          '[$_logTag] Failed to reset notification service: $e',
        );
      }

      result['success'] = true;
      if (result['failedCollections'].isNotEmpty) {
        app_logger.AppLogger.warning(
          '[$_logTag] Auth deleted but some Firestore collections failed: '
          '${result['failedCollections']}',
        );
      } else {
        app_logger.AppLogger.info(
          '[$_logTag] Account deletion completed successfully for user: $userId',
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

  Future<void> _runDeletionStep(
    String name,
    Map<String, dynamic> result,
    Future<bool> Function() task,
  ) async {
    try {
      final success = await task();
      if (success) {
        result['deletedCollections'].add(name);
      } else {
        result['failedCollections'].add(name);
      }
    } catch (e) {
      result['failedCollections'].add(name);
      result['errors'].add('$name: ${e.toString()}');
      app_logger.AppLogger.error('[$_logTag] Failed to delete $name', e);
    }
  }

  Future<bool> _deleteBlockRecords(String userId) async {
    try {
      final blockRepo = ServiceLocator.get<FirebaseBlockRepository>();
      await blockRepo.deleteAllBlocksForUser(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete block records', e);
      return false;
    }
  }

  Future<bool> _deleteSearchIndexUser(String userId) async {
    try {
      await _searchRepository!.removeUser(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to remove user from search index',
        e,
      );
      return false;
    }
  }

  Future<bool> _deleteSearchIndexRecipes(String userId) async {
    try {
      final recipesSnapshot = await _firestore
          .collection(FirestoreCollections.recipes)
          .where('userId', isEqualTo: userId)
          .limit(10000)
          .get();

      final recipeIds = recipesSnapshot.docs.map((d) => d.id).toList();
      for (var i = 0; i < recipeIds.length; i += _searchIndexDeleteChunkSize) {
        final chunk = recipeIds.sublist(
          i,
          (i + _searchIndexDeleteChunkSize).clamp(0, recipeIds.length),
        );
        await Future.wait(
          chunk.map((id) => _searchRepository!.removeRecipe(id)),
        );
      }
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to remove recipes from search index',
        e,
      );
      return false;
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
            final emailHash = CryptoUtils.sha256Hash(email);
            final auditDoc = await _firestore
                .collection(FirestoreCollections.deletionAuditLogs)
                .add({
              'userId': userId,
              'emailHash': emailHash,
              'reason': reason,
              'deletedCollections': deletedCollections,
              'failedCollections': failedCollections,
              'deletionTimestamp': FieldValue.serverTimestamp(),
              'expireAt': Timestamp.fromDate(
                DateTime.now()
                    .add(const Duration(days: _auditLogRetentionDays)),
              ),
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
