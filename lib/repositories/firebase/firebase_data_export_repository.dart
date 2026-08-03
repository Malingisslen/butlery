// lib/repositories/firebase/firebase_data_export_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Resource-type tag passed to [validateOwnership] for log/exception
/// breadcrumbs. Replaces the 16+ stringly-typed `resourceType` literals
/// that were previously copy-pasted across every export method.
///
/// BUT-740: two distinct top-level collections previously both passed
/// `'menus'` (personal subcollection vs shared top-level). They keep the
/// same tag because [validateOwnership] only uses it for log strings, not
/// authorization decisions — but the enum makes the collision explicit
/// and easy to split later if needed.
enum ExportResourceType {
  menus('menus'),
  shoppingLists('shopping_lists'),
  friends('friends'),
  friendCategories('friend_categories'),
  socialRequests('social_requests'),
  conversations('conversations'),
  sharedContent('shared_content'),
  blocks('blocks'),
  conversationMemberships('conversation_memberships'),
  userConsent('user_consent'),
  userSettings('user_settings'),
  userNotifications('user_notifications'),
  userNotificationPreferences('user_notification_preferences'),
  userFcmTokens('user_fcm_tokens'),
  categoryPreferences('category_preferences'),
  listCategoryOrders('list_category_orders'),
  users('users'),
  publicProfiles('public_profiles'),
  // BUT-1396: PII collections the deletion cascade erases but the export
  // previously omitted — a right-of-access gap (Art. 15).
  reports('reports'),
  pings('pings'),
  realtimeRecipes('realtime_recipes'),
  // BUT-1450: notification analytics the deletion cascade erases but the
  // export previously omitted (Art. 15 ⊇ Art. 17).
  notificationHistory('notification_history'),
  notificationBatches('notification_batches'),
  notificationEngagement('notification_engagement'),
  notificationDelivery('notification_delivery'),
  // Increment 5 (decision 12): pooled-rating events the deletion cascade
  // erases but the export previously omitted (Art. 15 ⊇ Art. 17).
  canonicalRatingEvents('canonical_rating_events'),
  // BUT-1732: shared shopping lists the deletion cascade scrubs but the
  // export omitted entirely (Art. 15 ⊇ Art. 17).
  sharedShoppingLists('shared_shopping_lists')
  ;

  const ExportResourceType(this.tag);
  final String tag;
}

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
    String userId,
    String resourceId,
    Object? entity,
  ) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');
  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    Object entity,
  ) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');
  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async =>
      throw UnsupportedError('FirebaseDataExportRepository is read-only');

  /// Guard helper: confirm the authenticated caller is exporting their
  /// own data. Every public method funnels through this.
  ///
  /// BUT-1773: this gateway is constructed WITHOUT a `FirebaseAuditRepository`
  /// on purpose, so [validateOwnership]'s `logPermissionCheck` stays a local
  /// log line here. One bundle makes ~30 guarded reads; persisting each would
  /// write ~30 near-identical Art. 30 rows per export, and `firestore.rules`
  /// caps `audit_logs` creates at `rateLimitWrite('audit_logs', 2)` — rows
  /// 3..30 would be rejected, leaving an arbitrarily partial trail. The single
  /// row per REQUEST is written one layer up, in
  /// [DataExportService._logExportAudit]. Do not pass an audit repository in.
  Future<void> _guardSelfExport(
    String userId,
    ExportResourceType resource,
  ) async {
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: resource.tag,
    );
  }

  /// BUT-740: list-shape helper. Runs [query] after self-export guard,
  /// returns either `[{id, data}]` (when [includeIds] is true) or `[data]`
  /// (when false). Replaces the ~16 near-identical
  /// `_guardSelfExport → query.limit(n).get() → map → toList` blocks.
  Future<List<Map<String, dynamic>>> _queryList(
    Query<Map<String, dynamic>> query,
    String userId,
    ExportResourceType resource, {
    int limit = 500,
    bool includeIds = true,
  }) async {
    await _guardSelfExport(userId, resource);
    final snapshot = await query.limit(limit).get();
    if (includeIds) {
      return snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
          .toList();
    }
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// BUT-740: single-doc-shape helper. Runs `[ref].get()` after self-export
  /// guard, returns the data map or null. Replaces the 6 single-doc
  /// `_guardSelfExport → ref.get() → exists ? data : null` blocks.
  Future<Map<String, dynamic>?> _readDoc(
    DocumentReference<Map<String, dynamic>> ref,
    String userId,
    ExportResourceType resource,
  ) async {
    await _guardSelfExport(userId, resource);
    final doc = await ref.get();
    return doc.exists ? doc.data() : null;
  }

  // ── content_export_manager residuals ──

  /// `users/{uid}/menus` subcollection — personal menus.
  Future<List<Map<String, dynamic>>> exportPersonalMenus(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.menus),
    userId,
    ExportResourceType.menus,
    limit: maxDocuments,
  );

  /// Top-level `menus` where `sharedByUserId == userId` — menus the user
  /// has shared with others.
  Future<List<Map<String, dynamic>>> exportSharedMenusByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.menus)
        .where('sharedByUserId', isEqualTo: userId),
    userId,
    ExportResourceType.menus,
    limit: maxDocuments,
  );

  /// `users/{uid}/unified_shopping_lists` with each list's nested `items`
  /// subcollection. Returns `{id, data, items: [{id, data}]}` shapes.
  ///
  /// BUT-1697: this must stay on the same constant as
  /// [FirebaseShoppingRepository.collectionName]. It previously read the
  /// pre-rename `shopping_lists` name, which nothing writes and which
  /// `firestore.rules` does not even grant — so the Article 15/20 export of
  /// personal shopping lists returned an empty list for every user.
  Future<List<Map<String, dynamic>>> exportPersonalShoppingLists(
    String userId, {
    int maxLists = 1000,
    int maxItemsPerList = 500,
  }) async {
    await _guardSelfExport(userId, ExportResourceType.shoppingLists);
    final listsSnapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.unifiedShoppingLists)
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
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userFriends),
    userId,
    ExportResourceType.friends,
    limit: maxDocuments,
  );

  /// `users/{uid}/friend_categories` subcollection.
  Future<List<Map<String, dynamic>>> exportFriendCategories(
    String userId, {
    int maxDocuments = 100,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userFriendCategories),
    userId,
    ExportResourceType.friendCategories,
    limit: maxDocuments,
  );

  /// Top-level `social_requests` where `fromUserId == userId`
  /// (sent friend / group requests).
  Future<List<Map<String, dynamic>>> exportSocialRequestsSent(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.socialRequests)
        .where('fromUserId', isEqualTo: userId),
    userId,
    ExportResourceType.socialRequests,
    limit: maxDocuments,
  );

  /// Top-level `social_requests` where `toUserId == userId`
  /// (received friend / group requests).
  Future<List<Map<String, dynamic>>> exportSocialRequestsReceived(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.socialRequests)
        .where('toUserId', isEqualTo: userId),
    userId,
    ExportResourceType.socialRequests,
    limit: maxDocuments,
  );

  /// `conversations` where `participantIds arrayContains userId`, each carrying
  /// the top-level `messages` written against that conversation (limited).
  ///
  /// BUT-1767: this read had three independent faults, each of which alone
  /// returned an empty message list, so the Art. 15 export has never contained
  /// a single message. The collection was the `conversations/{id}/messages`
  /// SUBCOLLECTION — a path with no `match` block in `firestore.rules`, i.e.
  /// denied rather than merely empty, which is what surfaced the whole section
  /// as `messages-export-failed`. The sort field was `timestamp`, which no
  /// message document carries (`MessageDto.toFirestore` writes `sentAt`), so
  /// even against the right collection the query would have matched nothing.
  /// Messages are top-level, keyed by a `conversationId` FIELD, exactly as
  /// [MessageQueryModule] reads them for the chat UI.
  ///
  /// The `conversationId ASC + sentAt ASC` composite is declared in
  /// `firestore.indexes.json`; the existing entry is `sentAt DESCENDING` (the
  /// chat UI's newest-first order) and does not serve this ascending read.
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = 100,
    int maxMessagesPerConversation = 500,
  }) async {
    await _guardSelfExport(userId, ExportResourceType.conversations);
    final convoSnapshot = await firestore
        .collection(FirestoreCollections.conversations)
        .where('participantIds', arrayContains: userId)
        .limit(maxConversations)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final convoDoc in convoSnapshot.docs) {
      // BUT-1721: read ONE past the cap so a full page can be told apart from a
      // clipped one. `docs.length >= cap` cannot: a conversation holding exactly
      // `maxMessagesPerConversation` messages loses nothing yet reports itself
      // truncated, and BUT-1721's new aggregator lifts that flag to the whole
      // `messages` section — so the false positive now mislabels a complete
      // Art. 15 bundle. Same probe-one-extra shape as
      // [ExportPaginationHelper.fetchCapped].
      final messagesSnapshot = await firestore
          .collection(FirestoreCollections.messages)
          .where('conversationId', isEqualTo: convoDoc.id)
          .orderBy('sentAt')
          .limit(maxMessagesPerConversation + 1)
          .get();

      final truncated =
          messagesSnapshot.docs.length > maxMessagesPerConversation;
      final kept = truncated
          ? messagesSnapshot.docs.sublist(0, maxMessagesPerConversation)
          : messagesSnapshot.docs;

      final messages = <Map<String, dynamic>>[];
      for (final msgDoc in kept) {
        messages.add(<String, dynamic>{
          'id': msgDoc.id,
          'data': msgDoc.data(),
        });
      }
      results.add(<String, dynamic>{
        'id': convoDoc.id,
        'data': convoDoc.data(),
        'messages': messages,
        'messages_truncated': truncated,
      });
    }
    return results;
  }

  /// One `shared_content` leg: `contentType == [contentType]` AND the caller is
  /// a recipient.
  ///
  /// BUT-1775 follow-up. Membership was written under TWO spellings inside this
  /// one collection — `sharedToUserIds` (BaseSharedContentRepository, and the
  /// only one `firestore.rules`' `allow list` recognises, :722) and
  /// `sharedWithUserIds` (the direct writers in recipe_sharing_manager /
  /// social_menu_operations / shopping_social_share_module). Those writers now
  /// emit BOTH, and this query stays on the rules-sanctioned one: a query
  /// filtered on `sharedWithUserIds` is refused by the list rule for every
  /// recipient, which would fail the whole section rather than return the rows.
  ///
  /// Documents shared BEFORE that writer fix carry only `sharedWithUserIds` and
  /// are invisible here — they are equally invisible to the rules, so no client
  /// query can reach them; a backfill is the only remedy and is not this call's
  /// job.
  Query<Map<String, dynamic>> _sharedContentReceivedQuery(
    String userId,
    String contentType,
  ) => firestore
      .collection(FirestoreCollections.sharedContent)
      .where('contentType', isEqualTo: contentType)
      .where('sharedToUserIds', arrayContains: userId);

  /// `shared_content` where contentType == recipe and the user is a recipient.
  Future<List<Map<String, dynamic>>> exportSharedRecipesReceived(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    _sharedContentReceivedQuery(userId, 'recipe'),
    userId,
    ExportResourceType.sharedContent,
    limit: maxDocuments,
  );

  /// `shared_content` where contentType == menu and the user is a recipient.
  ///
  /// NOT the top-level `menus` collection, which this read used to target:
  /// `SharedMenu.toFirestore()` emits neither `sharedToUserIds` nor
  /// `sharedByAvatarUrl`, and its only two writers (`menu_storage.saveMenu`,
  /// `UnifiedMenuService.saveMenu`) pass `sharedToUserIds: []` into a factory
  /// that never serialises it. So the old query matched zero documents and
  /// `shared_menus_received` had never once carried a row — an Art. 15 gap
  /// dressed as an empty section. Menus actually shared land in
  /// `shared_content` with `contentType: 'menu'` (BUT-1775).
  Future<List<Map<String, dynamic>>> exportSharedMenusReceived(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    _sharedContentReceivedQuery(userId, 'menu'),
    userId,
    ExportResourceType.sharedContent,
    limit: maxDocuments,
  );

  /// `shared_content` where contentType == shopping_list and the user is a
  /// recipient.
  ///
  /// BUT-1798. `shopping_social_share_module` has always written this third
  /// `contentType`, readable by the recipient under `firestore.rules` :720-728,
  /// and nothing exported it. `exportSharedShoppingLists*` is NOT coverage —
  /// those read `unified_shared_shopping_lists`, a different collection with a
  /// different provenance (a list you were made a MEMBER of, rather than one a
  /// friend sent you a copy of). Both sections ship, under distinct keys, so
  /// the bundle stays intelligible under Art. 12(1).
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsReceived(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    _sharedContentReceivedQuery(userId, 'shopping_list'),
    userId,
    ExportResourceType.sharedContent,
    limit: maxDocuments,
  );

  /// Outgoing blocks (`blocks` where `blockerId == userId`).
  Future<List<Map<String, dynamic>>> exportOutgoingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.blocks)
        .where('blockerId', isEqualTo: userId),
    userId,
    ExportResourceType.blocks,
    limit: maxDocuments,
    includeIds: false,
  );

  /// Incoming blocks (`blocks` where `blockedId == userId`).
  ///
  /// BUT-748: Field name canonicalised to `blockedId` to match
  /// [FirebaseBlockRepository] (which writes/queries `blockedId`). Earlier
  /// code queried `blockedUserId` here, returning zero rows in production.
  /// No data migration is needed because no production write path ever
  /// emitted `blockedUserId` — `FirebaseBlockRepository.blockUser` has
  /// always written `blockedId` via `BlockRecord.toFirestore()`.
  Future<List<Map<String, dynamic>>> exportIncomingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.blocks)
        .where('blockedId', isEqualTo: userId),
    userId,
    ExportResourceType.blocks,
    limit: maxDocuments,
    includeIds: false,
  );

  /// `users/{uid}/conversation_memberships` subcollection.
  Future<List<Map<String, dynamic>>> exportConversationMemberships(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConversationMemberships),
    userId,
    ExportResourceType.conversationMemberships,
    limit: maxDocuments,
    includeIds: false,
  );

  // ── compliance_export_manager residuals ──

  /// `users/{uid}/consent` subcollection (history) ordered by timestamp desc.
  Future<List<Map<String, dynamic>>> exportConsentHistory(
    String userId, {
    int maxDocuments = 100,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConsent)
        .orderBy('timestamp', descending: true),
    userId,
    ExportResourceType.userConsent,
    limit: maxDocuments,
  );

  /// `users/{uid}/consent/current` single-doc fetch.
  Future<Map<String, dynamic>?> exportCurrentConsent(String userId) => _readDoc(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConsent)
        .doc('current'),
    userId,
    ExportResourceType.userConsent,
  );

  // ── preferences_export_manager residuals ──

  /// `users/{uid}/settings/preferences` single-doc fetch.
  Future<Map<String, dynamic>?> exportSettingsPreferences(String userId) =>
      _readDoc(
        firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userSettings)
            .doc('preferences'),
        userId,
        ExportResourceType.userSettings,
      );

  /// `user_notifications` where `userId == userId`.
  Future<List<Map<String, dynamic>>> exportUserNotifications(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.userNotifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true),
    userId,
    ExportResourceType.userNotifications,
    limit: maxDocuments,
  );

  /// `user_notification_preferences/{userId}` single-doc fetch.
  Future<Map<String, dynamic>?> exportNotificationPreferences(String userId) =>
      _readDoc(
        firestore
            .collection(FirestoreCollections.userNotificationPreferences)
            .doc(userId),
        userId,
        ExportResourceType.userNotificationPreferences,
      );

  /// `user_fcm_tokens/{userId}` single-doc fetch (top-level shape).
  Future<Map<String, dynamic>?> exportFcmTokensTopLevel(String userId) =>
      _readDoc(
        firestore.collection(FirestoreCollections.userFcmTokens).doc(userId),
        userId,
        ExportResourceType.userFcmTokens,
      );

  /// `users/{uid}/fcm_tokens` subcollection (multi-device shape).
  Future<List<Map<String, dynamic>>> exportFcmTokensSubcollection(
    String userId, {
    int maxDocuments = 50,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection('fcm_tokens'),
    userId,
    ExportResourceType.userFcmTokens,
    limit: maxDocuments,
    includeIds: false,
  );

  /// `users/{uid}/category_preferences` subcollection.
  Future<List<Map<String, dynamic>>> exportCategoryPreferences(
    String userId, {
    int maxDocuments = 200,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.categoryPreferences),
    userId,
    ExportResourceType.categoryPreferences,
    limit: maxDocuments,
    includeIds: false,
  );

  /// `users/{uid}/list_category_orders` subcollection.
  Future<List<Map<String, dynamic>>> exportListCategoryOrders(
    String userId, {
    int maxDocuments = 200,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.listCategoryOrders),
    userId,
    ExportResourceType.listCategoryOrders,
    limit: maxDocuments,
    includeIds: false,
  );

  // ── data_export_service profile residuals ──

  /// `users/{uid}` private profile single-doc fetch. Returns null when the
  /// doc is missing (via [_readDoc]'s `doc.exists` short-circuit).
  Future<Map<String, dynamic>?> exportPrivateProfile(String userId) => _readDoc(
    firestore.collection(FirestoreCollections.users).doc(userId),
    userId,
    ExportResourceType.users,
  );

  /// `public_profiles/{uid}` single-doc fetch.
  Future<Map<String, dynamic>?> exportPublicProfile(String userId) => _readDoc(
    firestore.collection(FirestoreCollections.publicProfiles).doc(userId),
    userId,
    ExportResourceType.publicProfiles,
  );

  // ── BUT-1396: erased-but-unexported PII collections (Art. 15) ──

  /// Top-level `reports` where `reporterId == userId` — moderation reports
  /// the user filed, including their free-text reason. Mirrors the deletion
  /// cascade's `deleteUserReports` scoping so export ⊇ erased.
  Future<List<Map<String, dynamic>>> exportReportsByReporter(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.reports)
        .where('reporterId', isEqualTo: userId),
    userId,
    ExportResourceType.reports,
    limit: maxDocuments,
  );

  /// `pings` collection-group where `fromUserId == userId` — group pings the
  /// user sent (pings nest under `pings/{groupId}/pings`). Mirrors the
  /// cascade's `deletePingsByUser` collection-group scoping.
  Future<List<Map<String, dynamic>>> exportPingsSent(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collectionGroup(FirestoreCollections.pings)
        .where('fromUserId', isEqualTo: userId),
    userId,
    ExportResourceType.pings,
    limit: maxDocuments,
  );

  /// Top-level `realtime_recipes` where `ownerId == userId` — collaborative
  /// recipes the user owns. `ownerId` is the model's authoritative field
  /// (`RealtimeRecipe.fromFirestore` reads `ownerId`; the cascade CF's
  /// `userId` filter is a known no-op), so the export queries `ownerId`.
  Future<List<Map<String, dynamic>>> exportRealtimeRecipesByOwner(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.realtimeRecipes)
        .where('ownerId', isEqualTo: userId),
    userId,
    ExportResourceType.realtimeRecipes,
    limit: maxDocuments,
  );

  // ── BUT-1732: shared shopping lists (Art. 15 ⊇ erased) ──

  /// Top-level `unified_shared_shopping_lists` where `ownerId == userId`.
  ///
  /// The three probes below mirror the ones
  /// `functions/src/account/account-deletion-cascade.ts` runs to FIND a user's
  /// shared lists, because Art. 15 has to cover at least what Art. 17 erases.
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsOwned(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.unifiedSharedShoppingLists)
        .where('ownerId', isEqualTo: userId),
    userId,
    ExportResourceType.sharedShoppingLists,
    limit: maxDocuments,
  );

  /// Shared lists carrying a `memberPermissions.<uid>` key — the lists the user
  /// has been given access to but does not own.
  ///
  /// `isNull: false`, NOT `isNotEqualTo: null`: the SDK builds its conditions
  /// with `if (isNotEqualTo != null) addCondition(...)` (query.dart:659), so a
  /// literal `null` argument adds NO condition at all and the probe degrades
  /// into an unfiltered read of the whole collection — refused outright by the
  /// read rule here, which would collapse this entire Art. 15 section into an
  /// error. `isNull: false` is the supported spelling of the same intent and
  /// maps to the `!= null` condition (query.dart:676-682).
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsAsMember(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.unifiedSharedShoppingLists)
        .where('memberPermissions.$userId', isNull: false),
    userId,
    ExportResourceType.sharedShoppingLists,
    limit: maxDocuments,
  );

  /// Shared lists whose `contributorUserIds` names the user (BUT-1725).
  ///
  /// Best-effort by construction, and the caller must treat a failure as a
  /// documented gap rather than an error: the read rule for this collection is
  /// `ownerId == uid || uid in memberPermissions`, so the moment this query
  /// matches a list the user has LEFT — the case the trail exists for — the
  /// server refuses the whole query. Only an Admin-SDK context can enumerate
  /// those, which is exactly why the cascade runs there.
  ///
  /// COST, known and deliberately not optimised here (BUT-1753): under that
  /// same read rule every list this probe can legally return is already
  /// returned by the owner or member probe, so on the happy path its rows are
  /// pure duplicates — each carrying a whole embedded `items` array — while
  /// billing a read apiece, up to `cap + 1`. Its only unique product is the
  /// all-or-nothing refusal signal, which `.limit(1)` would prove just as well.
  /// Not changed at ship because the caller derives `truncated` from the row
  /// count it gets back, so narrowing the limit silently disables this probe's
  /// half of the bundle's own incompleteness flag — a correctness change that
  /// needs its own review pass, not a drive-by.
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsAsContributor(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.unifiedSharedShoppingLists)
        .where('contributorUserIds', arrayContains: userId),
    userId,
    ExportResourceType.sharedShoppingLists,
    limit: maxDocuments,
  );

  // ── BUT-1450: notification analytics (Art. 15 ⊇ erased) ──

  /// `notification_history` where `userId == uid` — notifications the user
  /// received, carrying the human-readable title/body they saw. Most-recent
  /// first (the composite index userId+sentAt already exists).
  Future<List<Map<String, dynamic>>> exportNotificationHistory(
    String userId, {
    int maxDocuments = 2000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.notificationHistory)
        .where('userId', isEqualTo: userId)
        .orderBy('sentAt', descending: true),
    userId,
    ExportResourceType.notificationHistory,
    limit: maxDocuments,
  );

  /// `notification_batches` where `userId == uid`.
  Future<List<Map<String, dynamic>>> exportNotificationBatches(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.notificationBatches)
        .where('userId', isEqualTo: userId),
    userId,
    ExportResourceType.notificationBatches,
    limit: maxDocuments,
  );

  /// `notification_engagement` where `userId == uid` — open/click events.
  Future<List<Map<String, dynamic>>> exportNotificationEngagement(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.notificationEngagement)
        .where('userId', isEqualTo: userId),
    userId,
    ExportResourceType.notificationEngagement,
    limit: maxDocuments,
  );

  /// `notification_delivery` where `senderId == uid` — delivery records for
  /// notifications THIS user triggered toward others. The counterparty
  /// (`targetUserId`) is stored only as a UID and is exported as-is — NOT
  /// anonymised — per the Art. 15(4) include-the-counterparty decision (the
  /// friendly record is in notification_history, joined via notificationId).
  /// See `.claude/rules/accepted-deviations.md`.
  Future<List<Map<String, dynamic>>> exportNotificationDeliverySent(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.notificationDelivery)
        .where('senderId', isEqualTo: userId),
    userId,
    ExportResourceType.notificationDelivery,
    limit: maxDocuments,
  );

  /// `notification_delivery` where `targetUserId == uid` — delivery records for
  /// notifications delivered TO this user. (Two-query union with the sent side;
  /// Firestore has no cross-field OR.)
  Future<List<Map<String, dynamic>>> exportNotificationDeliveryReceived(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.notificationDelivery)
        .where('targetUserId', isEqualTo: userId),
    userId,
    ExportResourceType.notificationDelivery,
    limit: maxDocuments,
  );

  // ── Increment 5: pooled ratings ("Butlery-betyget") events (Art. 15 ⊇ erased) ──

  /// `users/{uid}/canonical_rating_events` subcollection — the user's frozen
  /// pooled-rating contributions (one doc per pool they voted in; doc-id =
  /// poolKey). The deletion cascade erases these, so Art. 15 right-of-access
  /// requires the export to include them. PSEUDONYMOUS, not anonymous
  /// (decision 12): the poolKey is a reproducible content hash tied to this uid.
  Future<List<Map<String, dynamic>>> exportCanonicalRatingEvents(
    String userId, {
    int maxDocuments = 1000,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.canonicalRatingEvents),
    userId,
    ExportResourceType.canonicalRatingEvents,
    limit: maxDocuments,
  );
}
