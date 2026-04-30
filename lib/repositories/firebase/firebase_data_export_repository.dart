// lib/repositories/firebase/firebase_data_export_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Single repository that owns the residual user-scoped Firestore reads
/// needed by the GDPR data-export pipeline.
///
/// **Why this exists:** Several export-only collections (menus, shopping
/// lists, settings, notification preferences, friend categories,
/// conversation memberships, friends subcollection, social_requests,
/// blocks, conversations + messages, FCM tokens, category preferences,
/// list category orders, public profile, private profile, consent
/// subcollection) don't have typed interface-level repositories yet.
///
/// Rather than scatter `FirebaseFirestore.instance` calls across the
/// export-manager facade, every direct read funnels through this one
/// repository. Each method:
///   - Calls `validateOwnership` to confirm the authenticated caller is
///     the user being exported (defence-in-depth on top of Firestore rules).
///   - Returns raw `{id, data}` shapes (or single `data` for doc reads)
///     so the export pipeline can sanitize timestamps without a model.
///
/// **Future direction:** As real typed repositories grow `exportXxxByUser`
/// methods (the BUT-498 / BUT-501 pattern), the corresponding methods on
/// this gateway can be removed. This is a transitional layer, not a
/// permanent home.
///
/// This class deliberately does NOT implement
/// [butlery_repositories_interfaces_repository.Repository] — it has no
/// single entity model; it's a query gateway.
class FirebaseDataExportRepository extends BaseFirebaseRepository<Object> {
  FirebaseDataExportRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'users';

  // The Repository<Object> abstractions below are unused — this gateway
  // doesn't expose CRUD on a single model. They throw to make accidental
  // use loud.
  @override
  Object fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');

  @override
  Map<String, dynamic> toFirestore(Object entity) =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');

  @override
  String getId(Object entity) =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');

  // Gateway is read-only via the export* methods; the four CRUD permission
  // hooks would bypass `_guardSelfExport`'s per-resource ownership check if
  // ever invoked. Throw so a stray call surfaces immediately rather than
  // silently returning a misleading allow/deny.
  @override
  Future<bool> validateCreatePermission(String userId, Object entity) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');
  @override
  Future<bool> validateReadPermission(
          String userId, String resourceId, Object? entity) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');
  @override
  Future<bool> validateUpdatePermission(
          String userId, String resourceId, Object entity) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');
  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');

  /// Guard helper: confirm the authenticated caller is exporting their
  /// own data. Every public method funnels through this.
  Future<void> _guardSelfExport(String userId, String resourceType) async {
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: resourceType,
    );
  }

  // ── content_export_manager residuals ──

  /// `users/{uid}/menus` subcollection — personal menus.
  Future<List<Map<String, dynamic>>> exportPersonalMenus(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await _guardSelfExport(userId, 'menus');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.menus)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// Top-level `menus` where `sharedByUserId == userId` — menus the user
  /// has shared with others.
  Future<List<Map<String, dynamic>>> exportSharedMenusByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await _guardSelfExport(userId, 'menus');
    final snapshot = await firestore
        .collection(FirestoreCollections.menus)
        .where('sharedByUserId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// `users/{uid}/shopping_lists` with each list's nested `items` subcoll.
  /// Returns `{id, data, items: [{id, data}]}` shapes.
  Future<List<Map<String, dynamic>>> exportPersonalShoppingLists(
    String userId, {
    int maxLists = 1000,
    int maxItemsPerList = 500,
  }) async {
    await _guardSelfExport(userId, 'shopping_lists');
    final listsSnapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userShoppingLists)
        .limit(maxLists)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final listDoc in listsSnapshot.docs) {
      final items = <Map<String, dynamic>>[];
      try {
        final itemsSnapshot = await listDoc.reference
            .collection(FirestoreCollections.items)
            .limit(maxItemsPerList)
            .get();
        for (final itemDoc in itemsSnapshot.docs) {
          items.add(<String, dynamic>{
            'id': itemDoc.id,
            'data': itemDoc.data(),
          });
        }
      } catch (e) {
        // Items may be embedded in the list doc itself; not every list
        // has an items subcollection. Logged at debug only.
        AppLogger.debug(
          '[DataExportRepo] no items subcollection for list ${listDoc.id}',
        );
      }
      results.add(<String, dynamic>{
        'id': listDoc.id,
        'data': listDoc.data(),
        'items': items,
      });
    }
    return results;
  }

  // ── social_export_manager residuals ──

  /// `users/{uid}/friends` subcollection.
  Future<List<Map<String, dynamic>>> exportFriendsSubcollection(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await _guardSelfExport(userId, 'friends');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userFriends)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// `users/{uid}/friend_categories` subcollection.
  Future<List<Map<String, dynamic>>> exportFriendCategories(
    String userId, {
    int maxDocuments = 100,
  }) async {
    await _guardSelfExport(userId, 'friend_categories');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userFriendCategories)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// Top-level `social_requests` where `fromUserId == userId`
  /// (sent friend / group requests).
  Future<List<Map<String, dynamic>>> exportSocialRequestsSent(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'social_requests');
    final snapshot = await firestore
        .collection(FirestoreCollections.socialRequests)
        .where('fromUserId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// Top-level `social_requests` where `toUserId == userId`
  /// (received friend / group requests).
  Future<List<Map<String, dynamic>>> exportSocialRequestsReceived(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'social_requests');
    final snapshot = await firestore
        .collection(FirestoreCollections.socialRequests)
        .where('toUserId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// `conversations` where `participantIds arrayContains userId`,
  /// each carrying its `messages` subcollection (limited).
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = 100,
    int maxMessagesPerConversation = 500,
  }) async {
    await _guardSelfExport(userId, 'conversations');
    final convoSnapshot = await firestore
        .collection(FirestoreCollections.conversations)
        .where('participantIds', arrayContains: userId)
        .limit(maxConversations)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final convoDoc in convoSnapshot.docs) {
      final messages = <Map<String, dynamic>>[];
      final messagesSnapshot = await convoDoc.reference
          .collection(FirestoreCollections.messages)
          .orderBy('timestamp', descending: false)
          .limit(maxMessagesPerConversation)
          .get();

      for (final msgDoc in messagesSnapshot.docs) {
        messages.add(<String, dynamic>{
          'id': msgDoc.id,
          'data': msgDoc.data(),
        });
      }
      results.add(<String, dynamic>{
        'id': convoDoc.id,
        'data': convoDoc.data(),
        'messages': messages,
        'messages_truncated':
            messagesSnapshot.docs.length >= maxMessagesPerConversation,
      });
    }
    return results;
  }

  /// Top-level `shared_content` where contentType == recipe AND
  /// `sharedWithUserIds arrayContains userId` — recipes shared TO the user.
  Future<List<Map<String, dynamic>>> exportSharedRecipesReceived(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await _guardSelfExport(userId, 'shared_content');
    final snapshot = await firestore
        .collection(FirestoreCollections.sharedContent)
        .where('contentType', isEqualTo: 'recipe')
        .where('sharedWithUserIds', arrayContains: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// Top-level `menus` where `sharedToUserIds arrayContains userId` —
  /// menus shared TO the user.
  Future<List<Map<String, dynamic>>> exportSharedMenusReceived(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'menus');
    final snapshot = await firestore
        .collection(FirestoreCollections.menus)
        .where('sharedToUserIds', arrayContains: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// Outgoing blocks (`blocks` where `blockerId == userId`).
  Future<List<Map<String, dynamic>>> exportOutgoingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'blocks');
    final snapshot = await firestore
        .collection(FirestoreCollections.blocks)
        .where('blockerId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Incoming blocks (`blocks` where `blockedUserId == userId`).
  Future<List<Map<String, dynamic>>> exportIncomingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'blocks');
    final snapshot = await firestore
        .collection(FirestoreCollections.blocks)
        .where('blockedUserId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// `users/{uid}/conversation_memberships` subcollection.
  Future<List<Map<String, dynamic>>> exportConversationMemberships(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'conversation_memberships');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConversationMemberships)
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ── compliance_export_manager residuals ──

  /// `users/{uid}/consent` subcollection (history) ordered by timestamp desc.
  Future<List<Map<String, dynamic>>> exportConsentHistory(
    String userId, {
    int maxDocuments = 100,
  }) async {
    await _guardSelfExport(userId, 'user_consent');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConsent)
        .orderBy('timestamp', descending: true)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// `users/{uid}/consent/current` single-doc fetch.
  Future<Map<String, dynamic>?> exportCurrentConsent(String userId) async {
    await _guardSelfExport(userId, 'user_consent');
    final doc = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConsent)
        .doc('current')
        .get();
    return doc.exists ? doc.data() : null;
  }

  // ── preferences_export_manager residuals ──

  /// `users/{uid}/settings/preferences` single-doc fetch.
  Future<Map<String, dynamic>?> exportSettingsPreferences(
    String userId,
  ) async {
    await _guardSelfExport(userId, 'user_settings');
    final doc = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userSettings)
        .doc('preferences')
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// `user_notifications` where `userId == userId`.
  Future<List<Map<String, dynamic>>> exportUserNotifications(
    String userId, {
    int maxDocuments = 500,
  }) async {
    await _guardSelfExport(userId, 'user_notifications');
    final snapshot = await firestore
        .collection(FirestoreCollections.userNotifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  /// `user_notification_preferences/{userId}` single-doc fetch.
  Future<Map<String, dynamic>?> exportNotificationPreferences(
    String userId,
  ) async {
    await _guardSelfExport(userId, 'user_notification_preferences');
    final doc = await firestore
        .collection(FirestoreCollections.userNotificationPreferences)
        .doc(userId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// `user_fcm_tokens/{userId}` single-doc fetch (top-level shape).
  Future<Map<String, dynamic>?> exportFcmTokensTopLevel(
    String userId,
  ) async {
    await _guardSelfExport(userId, 'user_fcm_tokens');
    final doc = await firestore
        .collection(FirestoreCollections.userFcmTokens)
        .doc(userId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// `users/{uid}/fcm_tokens` subcollection (multi-device shape).
  Future<List<Map<String, dynamic>>> exportFcmTokensSubcollection(
    String userId, {
    int maxDocuments = 50,
  }) async {
    await _guardSelfExport(userId, 'user_fcm_tokens');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection('fcm_tokens')
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// `users/{uid}/category_preferences` subcollection.
  Future<List<Map<String, dynamic>>> exportCategoryPreferences(
    String userId, {
    int maxDocuments = 200,
  }) async {
    await _guardSelfExport(userId, 'category_preferences');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.categoryPreferences)
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// `users/{uid}/list_category_orders` subcollection.
  Future<List<Map<String, dynamic>>> exportListCategoryOrders(
    String userId, {
    int maxDocuments = 200,
  }) async {
    await _guardSelfExport(userId, 'list_category_orders');
    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.listCategoryOrders)
        .limit(maxDocuments)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ── data_export_service profile residuals ──

  /// `users/{uid}` private profile single-doc fetch.
  Future<Map<String, dynamic>?> exportPrivateProfile(String userId) async {
    await _guardSelfExport(userId, 'users');
    final doc = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();
    return doc.data();
  }

  /// `public_profiles/{uid}` single-doc fetch.
  Future<Map<String, dynamic>?> exportPublicProfile(String userId) async {
    await _guardSelfExport(userId, 'public_profiles');
    final doc = await firestore
        .collection(FirestoreCollections.publicProfiles)
        .doc(userId)
        .get();
    return doc.data();
  }
}
