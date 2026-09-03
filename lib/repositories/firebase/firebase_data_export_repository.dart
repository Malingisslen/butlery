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
  // BUT-1992: three `users/{uid}` subcollections the deletion cascade erases
  // and the export previously omitted (Art. 15 ⊇ Art. 17).
  userIngredients('users/{uid}/ingredients'),
  userOnboarding('users/{uid}/onboarding'),
  userAcquisition('users/{uid}/acquisition'),
  userNotifications('user_notifications'),
  // BUT-1957. A DIFFERENT collection from `userNotifications` above, one word
  // apart: that one is the TOP-LEVEL `user_notifications`, this one is the
  // subcollection `users/{uid}/notifications`. The tag spells the path out so a
  // log line cannot be read as the other.
  userDeliveredNotifications('users/{uid}/notifications'),
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
    this.maxPollVoteLookupsPerConversation = 200,
  });

  /// How many poll messages in ONE conversation get their vote row looked up.
  ///
  /// A vote lives in a subcollection, so there is one probe per poll and no
  /// query that can batch them (a `collectionGroup('poll_votes')` read is
  /// denied — that path has no collection-group match block).
  ///
  /// Each probe costs about THREE reads, not one: the client read plus the two
  /// `get()`s the rule itself performs, since `inPollConversation()` fetches the
  /// message and then its conversation, and rules `get()`s are billed. So the
  /// worst case is roughly `maxConversations × cap × 3` — at 100 conversations
  /// and this cap, ~60 000 reads. The probe also fires on every poll whether or
  /// not the user voted in it, so somebody who voted in nothing still pays.
  ///
  /// (An earlier version of this comment said "one read per poll" and quoted
  /// 50 000 as the number the cap exists to avoid — understating the real cost
  /// by about 3× and landing above its own threshold. If this budget is ever
  /// argued about, argue it with the ×3.)
  ///
  /// Past the cap the conversation says so, and `DataExportService` lifts that
  /// into the bundle's truncation notice.
  ///
  /// Constructor-injected rather than a parameter on
  /// [exportConversationsAndMessages]: several test doubles OVERRIDE that
  /// method, and every named argument added to it breaks them at compile time.
  final int maxPollVoteLookupsPerConversation;

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

  /// Whether a message document carries a poll, i.e. whether it can have a vote
  /// row at all. Mirrors `MessageQueryModule`'s test, deliberately loose: a
  /// malformed poll must still be probed, because the vote row is written
  /// against the message id and does not care what the poll map looks like.
  bool _hasPoll(Map<String, dynamic> data) {
    final metadata = data['metadata'];
    return metadata is Map && metadata['poll'] is Map;
  }

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
  ///
  /// BUT-1832: each exported POLL message also carries the requester's own vote
  /// row, read one document at a time — see the comment at the probe.
  /// [maxPollVoteLookupsPerConversation] is the read budget for that leg.
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
      // BUT-1838: the history cut-off is a RULE, not a filter. For a group
      // conversation `firestore.rules` refuses anything sent before this user
      // joined, and a query returning one refused document fails ENTIRELY — so
      // an unfiltered read here would throw out of the loop and fail the whole
      // messages section, which is the `messages-export-failed` outcome
      // BUT-1767 had just finished fixing.
      final rawMemberSince = convoDoc.data()['memberSince'];
      final ownStamp = rawMemberSince is Map ? rawMemberSince[userId] : null;
      var messagesQuery = firestore
          .collection(FirestoreCollections.messages)
          .where('conversationId', isEqualTo: convoDoc.id);
      if (ownStamp is Timestamp) {
        messagesQuery = messagesQuery.where(
          'sentAt',
          isGreaterThanOrEqualTo: ownStamp,
        );
      }
      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot;
      try {
        messagesSnapshot = await messagesQuery
            .orderBy('sentAt')
            .limit(maxMessagesPerConversation + 1)
            .get();
      } catch (e) {
        // Per CONVERSATION, not per section. Before BUT-1838 one bad
        // conversation took the whole `messages` section down with it —
        // every other conversation, every message, and the chat-groups leg.
        results.add(<String, dynamic>{
          'id': convoDoc.id,
          'data': convoDoc.data(),
          'messages': const <Map<String, dynamic>>[],
          'messages_truncated': false,
          'error_code': 'conversation-messages-read-failed',
        });
        continue;
      }

      final truncated =
          messagesSnapshot.docs.length > maxMessagesPerConversation;
      final kept = truncated
          ? messagesSnapshot.docs.sublist(0, maxMessagesPerConversation)
          : messagesSnapshot.docs;

      final messages = <Map<String, dynamic>>[];
      var pollsProbed = 0;
      var pollVotesTruncated = false;
      var pollVotesFailed = false;
      for (final msgDoc in kept) {
        final entry = <String, dynamic>{
          'id': msgDoc.id,
          'data': msgDoc.data(),
        };
        // BUT-1832: a poll vote is no longer part of the message document. It
        // used to live in `metadata.poll.options[].voterIds` and therefore left
        // with the message; it now lives at
        // `messages/{id}/poll_votes/{voterUid}`, which the rules, the
        // collection-group index and the Art. 17 sweep all reached and Art. 15
        // did not. The message copy of `voterIds` is written empty and never
        // updated again, so without this leg the requester's own votes are in
        // the bundle as zeroes.
        //
        // Per PARENT, never `collectionGroup('poll_votes')`: there is no
        // collection-group match block for this path, so that read is denied
        // outright. The per-document read is the one the participant rule
        // allows.
        if (_hasPoll(msgDoc.data())) {
          if (pollsProbed >= maxPollVoteLookupsPerConversation) {
            pollVotesTruncated = true;
          } else {
            pollsProbed++;
            try {
              final voteDoc = await firestore
                  .collection(FirestoreCollections.messages)
                  .doc(msgDoc.id)
                  .collection(FirestoreCollections.pollVotes)
                  .doc(userId)
                  .get();
              // Only the requester's own row. The other voters' rows are third-
              // party behaviour, and the tally they add up to is not something
              // the requester sees attributed in the app either.
              if (voteDoc.exists) entry['your_poll_vote'] = voteDoc.data();
            } catch (e) {
              // Never fatal — one unreadable vote must not cost the requester
              // the conversation. It is reported instead: an Art. 15 bundle
              // that quietly omits a row states something false about itself.
              //
              // Logged as well as flagged. The flag tells the requester the
              // overlay is incomplete; it cannot tell anyone WHY, and
              // `permission-denied`, `unavailable` and a malformed row are three
              // different problems with three different fixes.
              AppLogger.warning(
                'Poll-vote probe failed for one message; the conversation is '
                'exported without that vote overlay: $e',
              );
              pollVotesFailed = true;
            }
          }
        }
        messages.add(entry);
      }
      results.add(<String, dynamic>{
        'id': convoDoc.id,
        'data': convoDoc.data(),
        'messages': messages,
        'messages_truncated': truncated,
        // `DataExportService`'s nested walk lifts any `*_truncated` into
        // `truncated_collections` — but only from a map it can actually reach.
        // `SocialExportManager` rebuilds each conversation map key by key, so
        // it MUST copy this one across, exactly as it does for
        // `messages_truncated`. The walk finds it there; it cannot find it here.
        // (An earlier version of this comment said "so this needs no plumbing
        // above", which invited deleting the facade line that carries it.)
        if (pollVotesTruncated) 'poll_votes_truncated': true,
        // Deliberately NOT the `error_code` key beside it: that one means the
        // conversation's MESSAGES could not be read, and the facade turns it
        // into exactly that sentence for the whole section. A vote overlay that
        // failed while every message came through is a smaller, different
        // claim, and one key cannot make both.
        if (pollVotesFailed)
          'poll_votes_error_code': 'conversation-poll-votes-read-failed',
      });
    }
    return results;
  }

  /// BUT-1838: the chat groups the requester belongs to.
  ///
  /// The conversation section already carries the group's NAME (as `title`) and
  /// its membership (as `participantIds`), so this leg exists for the one fact
  /// that lives nowhere else and is genuinely about the requester: **who added
  /// them to the group**. It is deliberately a projection, not the document —
  /// dumping `chat_groups` would re-export three uid-keyed maps that duplicate
  /// what `conversation_info` already holds, and a second copy of a redaction
  /// decision is how the two drift apart (BUT-1772/BUT-1798).
  ///
  /// `adminIds` is kept: it is the group's structure, the requester sees who
  /// can remove people in the app, and their own client may read this whole
  /// document under `firestore.rules`. Other members' `memberAddedBy` entries
  /// are NOT kept — who invited someone else is third-party behaviour.
  ///
  /// `memberIds array-contains` is equality-shaped, so the automatic
  /// single-field index serves it; no composite entry is needed.
  Future<List<Map<String, dynamic>>> exportChatGroups(
    String userId, {
    int maxGroups = 100,
  }) async {
    await _guardSelfExport(userId, ExportResourceType.conversations);
    final snapshot = await firestore
        .collection(FirestoreCollections.chatGroups)
        .where('memberIds', arrayContains: userId)
        .limit(maxGroups)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final addedBy = data['memberAddedBy'];
      return <String, dynamic>{
        'group_id': doc.id,
        'name': data['name'],
        'conversation_id': data['conversationId'],
        'created_by': data['createdBy'],
        'created_at': data['createdAt'],
        'admin_ids': data['adminIds'],
        'you_were_added_by': addedBy is Map ? addedBy[userId] : null,
      };
    }).toList();
  }

  /// One `shared_content` leg: `contentType == [contentType]` AND the caller is
  /// a recipient.
  ///
  /// Filtered on `sharedToUserIds` because that is the only membership field
  /// `firestore.rules`' `allow list` recognises (:722) — filtering on anything
  /// else is refused for every recipient, which fails the whole section rather
  /// than returning the rows.
  ///
  /// Membership was briefly written under a second spelling as well, so rows
  /// predating that fix stayed readable. Retired 2026-08-03: the project holds
  /// only test data, so the compatibility field protected nothing and two
  /// copies of one fact could only drift apart.
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

  /// `users/{uid}/settings` — the WHOLE collection.
  ///
  /// BUT-1992: this fetched `settings/preferences` by id while
  /// `deleteUserPreferences` sweeps the whole collection (BUT-1957). Any second
  /// document under `settings` was therefore erasable but not exportable, and
  /// `firestore.rules` leaves the id unconstrained on an owner-only create, so a
  /// second document is one client write away. Widened rather than narrowing the
  /// deleter: narrowing leaves a residual the probe reports and no step can
  /// clear.
  Future<List<Map<String, dynamic>>> exportUserSettings(
    String userId, {
    int maxDocuments = 50,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userSettings),
    userId,
    ExportResourceType.userSettings,
    limit: maxDocuments,
  );

  /// `users/{uid}/ingredients` — the user's own ingredient library.
  ///
  /// BUT-1992, Malin's call 2026-09-03: user-authored content, so it is exported.
  /// Grows with use, hence the higher cap.
  Future<List<Map<String, dynamic>>> exportUserIngredients(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.ingredients),
    userId,
    ExportResourceType.userIngredients,
    limit: maxDocuments,
  );

  /// `users/{uid}/onboarding` — how far the user got through onboarding.
  ///
  /// BUT-1992, Malin's call 2026-09-03: exported. Thin, but it is a behavioural
  /// record of the subject and no exemption covers low-value personal data.
  Future<List<Map<String, dynamic>>> exportOnboardingProgress(
    String userId, {
    int maxDocuments = 50,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userOnboarding),
    userId,
    ExportResourceType.userOnboarding,
    limit: maxDocuments,
  );

  /// `users/{uid}/acquisition` — install attribution (BUT-612).
  ///
  /// BUT-1992, Malin's explicit call 2026-09-03: exported UNPROJECTED, chosen
  /// over the product objection that it reads as surprising. Art. 15(1)(a)+(g)
  /// give the subject the right to know the SOURCE of their data, which the
  /// legal seat called the strongest of the ten. The row carries source, medium,
  /// campaign and a first-seen stamp — no spend, no partner identity, nothing
  /// about anyone else. Do NOT strip the campaign name without reopening
  /// ADR-0011: "it sounds bad" was weighed and rejected as a reason.
  Future<List<Map<String, dynamic>>> exportAcquisition(
    String userId, {
    int maxDocuments = 50,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userAcquisition),
    userId,
    ExportResourceType.userAcquisition,
    limit: maxDocuments,
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

  /// `users/{userId}/notifications` — the in-app notification rows the
  /// win-back and activity-digest jobs write (BUT-1957). Distinct from
  /// [exportUserNotifications], which reads the top-level collection.
  Future<List<Map<String, dynamic>>> exportDeliveredNotifications(
    String userId, {
    int maxDocuments = 500,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userDeliveredNotifications)
        // The cascade erases this subcollection by ENUMERATION, so it removes
        // rows this ordered query cannot see — one missing `createdAt` and the
        // row is erasable but not exportable. Both writers set the field today;
        // a third would not inherit the obligation from anything but this.
        .orderBy('createdAt', descending: true),
    userId,
    ExportResourceType.userDeliveredNotifications,
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

  /// `user_fcm_tokens` filtered on the `userId` FIELD — the only shape that
  /// returns a row.
  ///
  /// BUT-1990: two readers stood here and neither could ever answer. One asked
  /// for `users/{uid}/fcm_tokens`, a subcollection no writer in `lib/` or
  /// `functions/src/` has ever written and which `firestore.rules` grants no
  /// read on, so it was denied as well as empty. The other asked for
  /// `user_fcm_tokens/{userId}`, but the doc id is `{userId}_{deviceId}` (see
  /// the rules block and `FirebaseDeviceRepository`), so it missed every real
  /// document. The field filter is what `deleteAllByUser` already uses, and the
  /// read rule is written on the same field, so a list query satisfies it.
  Future<List<Map<String, dynamic>>> exportFcmTokensForUser(
    String userId, {
    int maxDocuments = 50,
  }) => _queryList(
    firestore
        .collection(FirestoreCollections.userFcmTokens)
        .where('userId', isEqualTo: userId),
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
