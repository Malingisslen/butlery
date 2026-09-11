// lib/services/account/export/social_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/social_export_redaction.dart';
import 'package:butlery/services/account/export/chat_group_export.dart';
import 'package:butlery/models/messaging/history_cutoff.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show
        ExportPaginationHelper,
        normalizeTimestampPaths,
        sanitizeForJson,
        sanitizeTimestamp;

/// Handles export of social data: friends, messages, shared content.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501 (closed): All direct Firestore reads route through
/// [FirebaseDataExportRepository] which enforces `validateOwnership`
/// defence-in-depth on top of Firestore rules.
class SocialExportManager with SocialExportRedaction {
  final FirebaseDataExportRepository? _exportRepo;
  static const String _logTag = 'SocialExportManager';

  SocialExportManager({FirebaseDataExportRepository? dataExportRepository})
    : _exportRepo = dataExportRepository;

  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  // BUT-1721: every section here used to fail with `{'error': ...}` alone.
  // `DataExportService` lifts a failed section into `export_metadata.warnings`,
  // and a precise token is what tells the reader (and a support session) WHICH
  // read failed rather than "something did" — a whole social section can go
  // missing from an Art. 15 bundle, so it must not go missing quietly.
  //
  // A stable sentence, never `e.toString()`: a raw Firestore/permission string
  // carries ANOTHER user's uid (`blocks/<uid>_<otherUid>` doc ids), a
  // `create_composite` URL embedding `memberPermissions.<uid>` and the project
  // id, and internal collection paths — and the aggregator now promotes this
  // value to `export_metadata.warnings[].message` at the ROOT of a bundle the
  // data subject may forward to a supervisory authority. The exception is
  // already in `AppLogger.error` above every call, so support loses nothing.
  // Same convention as `shared_shopping_list_export.dart` and
  // `family_export_manager.dart`.
  Map<String, dynamic> _failed(String section, String code) => {
    'error': '$section could not be exported.',
    'error_code': code,
  };

  /// Export friends, friend requests, and friend categories
  Future<Map<String, dynamic>> exportFriends(String userId) async {
    try {
      final friendsData = <String, dynamic>{
        'friends': [],
        'friend_requests_sent': [],
        'friend_requests_received': [],
        'friend_categories': [],
      };
      // BUT-1698: each capped read carries its own N+1 truncation probe, and
      // the section declares itself truncated when ANY of them clipped. Before
      // this the caps applied silently, so an Art. 15/20 bundle that had
      // dropped records still read as complete.
      final friends = await ExportPaginationHelper.fetchCapped(
        type: 'friends',
        fetch: (max) =>
            _exports.exportFriendsSubcollection(userId, maxDocuments: max),
      );
      for (final entry in friends.items) {
        friendsData['friends'].add({
          'friend_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final sentRequests = await ExportPaginationHelper.fetchCapped(
        type: 'friend_requests',
        fetch: (max) =>
            _exports.exportSocialRequestsSent(userId, maxDocuments: max),
      );
      for (final entry in sentRequests.items) {
        friendsData['friend_requests_sent'].add({
          'request_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final receivedRequests = await ExportPaginationHelper.fetchCapped(
        type: 'friend_requests',
        fetch: (max) =>
            _exports.exportSocialRequestsReceived(userId, maxDocuments: max),
      );
      for (final entry in receivedRequests.items) {
        friendsData['friend_requests_received'].add({
          'request_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final categories = await _exports.exportFriendCategories(userId);
      for (final entry in categories) {
        friendsData['friend_categories'].add({
          'category_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      friendsData['total_friends'] = friendsData['friends'].length;
      friendsData['total_pending_sent'] =
          friendsData['friend_requests_sent'].length;
      friendsData['total_pending_received'] =
          friendsData['friend_requests_received'].length;
      friendsData['total_categories'] = friendsData['friend_categories'].length;
      // `friend_categories` still rides the repository's own default cap and is
      // not probed here — tracked on BUT-1701 with the other implicit-default
      // caps (blocks, memberships, reports, pings, the conversation list).
      if (friends.truncated ||
          sentRequests.truncated ||
          receivedRequests.truncated) {
        friendsData['truncated'] = true;
      }

      return friendsData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export friends', e);
      return _failed('Friends', 'friends-export-failed');
    }
  }

  /// [source] with every OTHER participant's avatar URL removed — the map entry
  /// and the copy embedded in `lastMessage` — and `perUserSettings` narrowed to
  /// the requester's own entry. Names, user ids, `lastReadTimestamps` and
  /// message content are deliberately kept.
  ///
  /// BUT-1854 (Malin, 2026-09-11) adds one more removal, and it is a different
  /// KIND: `lastMessage` goes when the preview predates
  /// the requester's own `memberSince` on a GROUP conversation. Those
  /// withhold another person's data; this one applies an access rule the
  /// requester is already subject to everywhere else in the app.
  ///
  /// This is the OPPOSITE redaction to [SharedShoppingListExport], which strips
  /// names and keeps ids, and the asymmetry is the decision rather than an
  /// oversight: a shopping row's cached `addedByDisplayName` is a denormalised
  /// copy of a profile that the paired `*UserId` makes redundant, while a
  /// conversation stripped of names is a list of opaque uids that fails
  /// Art. 12(1)'s "intelligible" limb.
  ///
  /// BUT-1774 (Malin, 2026-07-30) closed the two fields BUT-1772 had left open,
  /// and split them: another member's `perUserSettings` — mute / pin / archive —
  /// is pure third-party behaviour the client never renders for anyone but
  /// yourself, so "you have already seen it in the app" is false for it and it
  /// GOES. `lastReadTimestamps` STAYS: it sits inside the requester's own thread
  /// history and has a weak but real counterpart in what the app already shows
  /// (`MessageStatus.read` displays *that* a message was read, just not when).
  /// Do not "tidy up" by stripping it too — that is the decided keep.
  Map<String, dynamic> _redactOtherParticipants(
    Map<String, dynamic> source,
    String userId,
  ) {
    final copy = Map<String, dynamic>.from(source);

    // BUT-1854. Read from `source`, the untouched input, rather than from the
    // `copy` the loop below rewrites.
    //
    // Moving this read below the loop changes NO outcome today. The loop narrows
    // `memberSince` to the requester's OWN entry, which is the one entry this
    // predicate wants, and on its fail-closed branch removes the field — which
    // this predicate also reads as "no stamp" and drops the preview for.
    //
    // It reads from `source` anyway, and the reason is what it cannot do rather
    // than what it does: taking the input directly means a future change to
    // that loop's narrowing cannot silently change which stamp this compares
    // against. That is a property of the shape, not a defect being prevented,
    // so do not write a test claiming it catches something.
    final rawMemberSince = source['memberSince'];
    final ownJoinedAt = rawMemberSince is Map
        ? sanitizeTimestamp(rawMemberSince[userId])
        : null;
    // `!= null`, the test `Conversation.canReadMessageAt` applies: an empty
    // string is a group there, and a cast here would throw a non-String
    // value out of the whole messages section.
    final isGroup = source['groupId'] != null;

    // Three uid-keyed maps, one rule: keep the requester's own entry, drop
    // everyone else's. Written once rather than three times because three
    // copies of one decision is how they drift (BUT-1772/BUT-1798).
    //   participantAvatarUrls — BUT-1772: a durable pointer to someone else's
    //     photograph, which outlives the app and buys the requester nothing.
    //   perUserSettings — BUT-1774: another member's mute/pin/archive state is
    //     pure third-party behaviour the client never renders for anyone else.
    //   memberSince — BUT-1838: when someone ELSE joined the group. Follows
    //     perUserSettings rather than lastReadTimestamps (which is kept),
    //     decided on its own merits — analogy is the error BUT-1732 records.
    for (final field in const [
      'participantAvatarUrls',
      'perUserSettings',
      'memberSince',
    ]) {
      final value = copy[field];
      if (value == null) continue;
      if (value is Map) {
        copy[field] = <String, dynamic>{userId: ?value[userId]};
      } else {
        // FAIL CLOSED. An unrecognised shape drops the field entirely rather
        // than falling through to the untouched copy — a redaction that
        // silently no-ops on a schema it has not seen ships the data while the
        // `data_minimisation` line still claims it was removed.
        copy.remove(field);
        copy['redaction_fell_back'] = true;
      }
    }

    // The conversation document embeds its most recent message for previews, so
    // the sender's avatar rides along here even while `messages` carries nothing
    // (BUT-1767).
    final lastMessage = copy['lastMessage'];
    if (lastMessage is Map) {
      // BUT-1854, Malin's call of 2026-09-11 (option A). The preview is a
      // denormalised copy of a message, and a group member may not read one
      // sent before they joined — `firestore.rules` refuses it, and the chat
      // screen, the conversations list and the messages section of this very
      // bundle all honour that.
      //
      // `sentAt` reaches here as an ISO string: the caller passes
      // `sanitizeForJson(convo['data'])`, so nothing in this map is still a
      // `Timestamp`. The comparison itself is `isWithinJoinedHistory`, shared
      // with `Conversation.canReadMessageAt`.
      //
      // A DIRECT chat has no cut-off at all and keeps its preview — dropping it
      // there would withhold the requester's own data, which is the opposite
      // Art. 15 failure. A GROUP with no readable stamp for this user fails
      // closed and drops it, matching `canReadMessageAt`.
      final previewSentAt = sanitizeTimestamp(lastMessage['sentAt']);
      final withinHistory =
          !isGroup ||
          (previewSentAt != null &&
              ownJoinedAt != null &&
              isWithinJoinedHistory(
                sentAt: DateTime.parse(previewSentAt),
                memberSince: DateTime.parse(ownJoinedAt),
              ));

      if (withinHistory) {
        copy['lastMessage'] = dropAvatarUnlessOwn(
          Map<String, dynamic>.from(lastMessage.cast<String, dynamic>()),
          ownerIdField: 'senderId',
          avatarField: 'senderAvatarUrl',
          userId: userId,
        );
      } else {
        // NOT `redaction_fell_back`. That flag means "a shape we do not
        // recognise".
        copy.remove('lastMessage');
      }
    } else if (lastMessage != null) {
      copy.remove('lastMessage');
      copy['redaction_fell_back'] = true;
    }

    return copy;
  }

  /// Export all conversations and messages
  Future<Map<String, dynamic>> exportMessages(String userId) async {
    try {
      final messagesData = <String, dynamic>{
        'conversations': [],
        'total_conversations': 0,
        'total_messages': 0,
      };
      final conversationLimit = ExportPaginationHelper.getLimitForType(
        'conversations',
      );
      final messageLimit = ExportPaginationHelper.getLimitForType(
        'messages_per_conversation',
      );

      final conversations = await _exports.exportConversationsAndMessages(
        userId,
        maxConversations: conversationLimit,
        maxMessagesPerConversation: messageLimit,
      );

      for (final convo in conversations) {
        final messagesList = <Map<String, dynamic>>[];
        final rawMessages = (convo['messages'] as List)
            .cast<Map<String, dynamic>>();

        for (final msg in rawMessages) {
          // BUT-1767: every message in a conversation the requester
          // participates in belongs in their Art. 15 bundle — the ones they
          // received as much as the ones they sent; a chat is a two-sided
          // record and half of it is not the record.
          //
          // The filter this replaces kept a row only if `senderId == userId`
          // OR `recipientIds` contained them. `recipientIds` is not a field any
          // message document has ever carried (`MessageDto.toFirestore` writes
          // sender + `conversationId`; recipients are derived from the
          // conversation's `participantIds`), so the second limb was always
          // false and every received message was dropped — a filter on a
          // non-existent field throws nothing and reads as deliberate scoping.
          //
          // BUT-1904, before any field-level redaction: another participant's
          // duplicate-guard notice is not the requester's record to receive.
          // Dropped rather than stripped — the whole record belongs to someone
          // else, so there is no field to remove. The predicate is NARROWER
          // than the chat screen's; `isOthersBlockedRow` says why.
          final storedRow =
              sanitizeForJson(msg['data']) as Map<String, dynamic>;
          if (isOthersBlockedRow(storedRow, userId: userId)) continue;

          // BUT-1772's per-row half: names and uids stay, the durable pointer
          // to someone else's photograph goes.
          final messageData = dropAvatarUnlessOwn(
            storedRow,
            ownerIdField: 'senderId',
            avatarField: 'senderAvatarUrl',
            userId: userId,
          );
          messagesList.add({
            'message_id': msg['id'],
            'data': messageData,
            // BUT-1832. Kept OUT of `data`, which is the stored message
            // document verbatim; the vote is a separate document under it
            // (`messages/{id}/poll_votes/{uid}`) and folding it in would make
            // the bundle describe a shape Firestore does not hold. Only the
            // requester's own row is read, so nothing here needs redacting.
            if (msg['your_poll_vote'] != null)
              'your_poll_vote': sanitizeForJson(msg['your_poll_vote']),
          });
        }

        final conversationInfo = _redactOtherParticipants(
          sanitizeForJson(convo['data']) as Map<String, dynamic>,
          userId,
        );
        // The requester's OWN `perUserSettings` entry survives the redaction
        // above by decision (BUT-1774), and `conversation_action_operations`
        // writes both of its stamps as a local `clock.now().toIso8601String()`
        // — no `Z`, no offset — so they reach the bundle as plain strings under
        // a metadata line promising UTC. The uid is resolved by lookup rather
        // than spelled into a dotted path, so the walk cannot depend on what
        // characters a uid may contain.
        final ownSettings =
            (conversationInfo['perUserSettings'] as Map?)?[userId];
        if (ownSettings is Map<String, dynamic>) {
          normalizeTimestampPaths(ownSettings, const [
            'pinnedAt',
            'archivedAt',
          ]);
        }

        final conversationData = <String, dynamic>{
          'conversation_id': convo['id'],
          'conversation_info': conversationInfo,
          'messages': messagesList,
          'message_count': messagesList.length,
        };
        if (convo['messages_truncated'] == true) {
          conversationData['messages_truncated'] = true;
        }
        // BUT-1832: the vote overlay clipped, while the messages themselves did
        // not. `DataExportService`'s nested walk lifts any `*_truncated` flag,
        // so naming it this way is what puts it in the bundle's truncation
        // notice.
        if (convo['poll_votes_truncated'] == true) {
          conversationData['poll_votes_truncated'] = true;
        }
        // Its own key, never folded into `error_code` below: that one says the
        // conversation's MESSAGES could not be read, and the section sentence
        // it triggers says exactly that. A vote row that failed while every
        // message came through is a different and smaller claim.
        if (convo['poll_votes_error_code'] is String) {
          conversationData['poll_votes_error_code'] =
              convo['poll_votes_error_code'];
          messagesData['error_code'] ??= 'conversation-poll-votes-read-failed';
        }
        // BUT-1838: carry the per-conversation failure marker UP. The
        // repository's new per-conversation catch stops one unreadable
        // conversation failing the whole section — but a row that silently
        // reports `message_count: 0` is byte-identical to a conversation that
        // genuinely has no messages, so without this the bundle would describe
        // itself as complete. `DataExportService` only lifts `error_code` at
        // SECTION root, and its nested walk looks for `truncated`, not this.
        // Trading a loud failure for silence on an Art. 15 bundle is the wrong
        // direction, whichever way the section-level behaviour improved.
        if (convo['error_code'] is String) {
          conversationData['error_code'] = convo['error_code'];
          // No `error` key: the section is INCOMPLETE, not failed — the other
          // conversations did export, and `DataExportService` renders that as
          // "may be incomplete" rather than "could not be exported".
          messagesData['error_code'] = 'conversation-messages-read-failed';
        }
        messagesData['conversations'].add(conversationData);
        messagesData['total_messages'] += messagesList.length;
      }

      messagesData['total_conversations'] =
          messagesData['conversations'].length;

      // BUT-1838: the one fact a group holds that the conversation does not —
      // who added you. Its own class so a failure there cannot take this
      // section down.
      //
      // BUT-1862: the failure code is lifted OUT before the merge. `addAll`
      // overwrites, and `ChatGroupExport` reports failure under the same
      // generic `error_code` this section already uses, so on a double failure
      // the bundle named only the second one. `DataExportService` builds its
      // one warning per section from the root `error_code`, so the losing code
      // produced no bundle-level warning. Same treatment as
      // `poll_votes_error_code` above, for the same reason.
      final chatGroups = await ChatGroupExport(_exports).export(userId);
      final chatGroupsErrorCode = chatGroups.remove('error_code');
      messagesData.addAll(chatGroups);
      if (chatGroupsErrorCode is String) {
        messagesData['chat_groups_error_code'] = chatGroupsErrorCode;
        // `??=`, because the conversations branch above claims the root key
        // unconditionally while the poll-votes branch already yields to it.
        // This leg takes the key only when neither did.
        messagesData['error_code'] ??= chatGroupsErrorCode;
      }

      // Section level, matching SharedShoppingListExport, rather than duplicated
      // into each of up to 100 conversations.
      //
      // The keep side is deliberately not enumerated: the sibling section
      // shipped a positive list that named four of six fields and thereby made
      // the bundle state something false about
      // itself, and this document carries more than the obvious keeps —
      // `lastReadTimestamps` and `reactions` among them. A list that must stay
      // exhaustive to stay true is a list that will stop being true. Both drops
      // are named because BUT-1774 made `perUserSettings` a decided removal; a
      // bundle that redacts silently states something false.
      //
      // BUT-1832 is why that list no longer says "poll `voterIds`": votes moved
      // to `messages/{id}/poll_votes/{uid}` and no live writer puts one back in
      // the message copy, so naming that array would point at a field recording
      // nothing. The requester's own vote is exported beside each poll message
      // as `your_poll_vote`, which keeps the sentence below true.
      // BUT-1904 narrowed "everything else is kept as it was stored" to the
      // rows that are HERE. It was a categorical claim about FIELDS, and it
      // stopped being true the moment a whole ROW could be withheld: a bundle
      // that overclaims its own completeness is as false as one that redacts
      // silently.
      // BUT-2014: the chat_groups sentence is CONDITIONAL on that section
      // actually being here. Since the leg's failure branch omits its key
      // rather than shipping an empty list, describing what the section
      // contains would, on a failed leg, describe something the bundle does
      // not carry — a note that misstates the artefact it is attached to,
      // which is the Art. 12(1) defect the omission was made to avoid.
      final chatGroupsNote = messagesData.containsKey('chat_groups')
          ? 'The chat_groups section beside it is a summary rather than a '
                'copy: it carries the group name, who created it, who '
                'administers it and who added YOU — not the other members you '
                'can already see above.'
          : 'The chat_groups section could not be read on this export and has '
                'been left out entirely rather than shown as empty; see '
                'chat_groups_error_code.';
      messagesData['data_minimisation'] =
          "Other participants' profile pictures have been removed, as have "
          'their own notification settings for this conversation (muted, '
          'pinned, archived) and, for a group chat, the moment each of THEM '
          'joined it. Rows where the app stopped a duplicate message that '
          'someone ELSE sent have been left out entirely — yours are kept. '
          'For a group chat, the one-line preview of the most '
          'recent message is left out when that message was sent before you '
          'joined — the same cut-off the app itself applies, so the preview '
          'cannot show you something the chat will not. '
          'Of the rows that ARE here, nothing else has been changed. '
          '$chatGroupsNote';

      return messagesData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export messages', e);
      return _failed('Messages', 'messages-export-failed');
    }
  }

  /// Export content shared with the user
  Future<Map<String, dynamic>> exportSharedContent(String userId) async {
    try {
      final sharedData = <String, dynamic>{
        'shared_recipes_received': [],
        'shared_menus_received': [],
        'shared_shopping_lists_received': [],
      };
      // BUT-1698: both legs are probed independently and the section is
      // truncated when either clipped.
      final sharedRecipes = await ExportPaginationHelper.fetchCapped(
        type: 'recipes',
        fetch: (max) =>
            _exports.exportSharedRecipesReceived(userId, maxDocuments: max),
      );
      for (final entry in sharedRecipes.items) {
        sharedData['shared_recipes_received'].add({
          'share_id': entry['id'],
          'data': dropSharerAvatar(entry, userId),
        });
      }

      final sharedMenus = await ExportPaginationHelper.fetchCapped(
        type: 'menus',
        fetch: (max) =>
            _exports.exportSharedMenusReceived(userId, maxDocuments: max),
      );
      for (final entry in sharedMenus.items) {
        sharedData['shared_menus_received'].add({
          'menu_id': entry['id'],
          'data': dropSharerAvatar(entry, userId),
        });
      }

      // BUT-1798: the third contentType this collection has always carried and
      // nothing exported. Distinct key from `shared_shopping_lists_*` (which
      // read `unified_shared_shopping_lists`) so the two provenances stay
      // tellable apart in the bundle.
      final sharedLists = await ExportPaginationHelper.fetchCapped(
        type: 'shopping_lists',
        fetch: (max) => _exports.exportSharedShoppingListsReceived(
          userId,
          maxDocuments: max,
        ),
      );
      for (final entry in sharedLists.items) {
        sharedData['shared_shopping_lists_received'].add({
          'share_id': entry['id'],
          'data': dropOtherMembersNamesInListData(
            dropSharerAvatar(entry, userId),
            userId,
          ),
        });
      }

      sharedData['total_shared_recipes'] =
          sharedData['shared_recipes_received'].length;
      sharedData['total_shared_menus'] =
          sharedData['shared_menus_received'].length;
      sharedData['total_shared_shopping_lists'] =
          sharedData['shared_shopping_lists_received'].length;
      if (sharedRecipes.truncated ||
          sharedMenus.truncated ||
          sharedLists.truncated) {
        sharedData['truncated'] = true;
      }

      // Section level, matching the conversations section, and stating the drop
      // only — see the note there on why the keep side is never enumerated.
      sharedData['data_minimisation'] =
          'The profile picture of whoever shared each item has been removed. '
          'In shared shopping lists, the names of other members have also been '
          'removed — from the list itself and from each item, including who '
          'added, bought or last changed it. Your own name is kept so you can '
          'recognise your entries. Everything else these shares held is kept '
          'as it was stored.';
      sharedData['provenance'] =
          'shared_shopping_lists_received holds lists a friend sent you a copy '
          'of. Lists you were made a member of are in the '
          'shared_shopping_lists sections elsewhere in this export.';

      return sharedData;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export shared content',
        e,
      );
      return _failed(
        'Shared content',
        'shared-content-export-failed',
      );
    }
  }

  /// Export the blocks this user PLACED. The other direction — who has
  /// blocked them — is deliberately absent.
  ///
  /// BUT-2018: an Art. 15 bundle must not tell a requester who blocked them,
  /// nor how many people did. Art. 15(4) permits withholding a copy where it
  /// would adversely affect the rights and freedoms of others, and a block is
  /// placed by someone wanting distance from — often — the very person now
  /// requesting the copy. Malin's explicit call, 2026-09-05, over keeping the
  /// uids and over keeping a bare count.
  ///
  /// The omission is STATED in `data_minimisation`: an omission the subject
  /// cannot see is an Art. 12(1) gap rather than a minimisation decision.
  ///
  /// That sentence is emitted on every path, including the failure one, and
  /// that is a control rather than a style choice. This method issues no query
  /// against the incoming direction, so it cannot know whether anyone has
  /// blocked this user — a note that appeared, or read differently, only when
  /// somebody had would reconstruct the exact fact the section withholds.
  ///
  /// A failed read emits its error envelope and NO list: an empty list beside
  /// a failure marker reads as "you have blocked nobody", which is a claim
  /// this section is in no position to make.
  ///
  /// Coupled across languages: `scenario_blockMirrorExemptionRestsOnTheSameDecision`
  /// in `functions/src/__tests__/account-deletion-cascade.test.ts` reads THIS
  /// FILE as text and fails on a single- or double-quoted `incoming_blocks`
  /// key. The server's block-mirror export exemption rests on the same
  /// decision, and that is what stops the two halves drifting apart.
  Future<Map<String, dynamic>> exportBlocks(String userId) async {
    const dataMinimisation =
        'Only the blocks you placed are included. Who has blocked YOU is left '
        'out of this export deliberately, and so is how many people have. '
        'GDPR Article 15(4) allows us to withhold a copy where releasing it '
        'would adversely affect someone else, and a block is placed by a '
        'person who wants distance. This sentence is part of every export, so '
        'its presence tells you nothing about whether anyone has blocked you.';

    try {
      final outgoing = await _exports.exportOutgoingBlocks(userId);
      return {
        // `blockedAt` is stored as a STRING by `BlockRecord.toFirestore()`,
        // so it reaches `sanitizeForJson`'s primitive arm and would ship with
        // whatever zone the blocking device had — under a bundle that says
        // every stamp is UTC. Normalised here rather than in `sanitizeForJson`,
        // which must not rewrite strings that are user content.
        'outgoing_blocks': outgoing.map((block) {
          final row = sanitizeForJson(block) as Map<String, dynamic>;
          normalizeTimestampPaths(row, const ['blockedAt']);
          return row;
        }).toList(),
        'data_minimisation': dataMinimisation,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export outgoing_blocks',
        e,
      );
      // `error` and `error_code` together: `DataExportService`'s warning
      // aggregation reads them as different claims, and with one direction
      // left there is no partial outcome to report — the section either
      // returned or it did not.
      return {
        ..._failed('Blocked users', 'blocks-export-failed'),
        'data_minimisation': dataMinimisation,
      };
    }
  }

  /// Export conversation memberships
  Future<Map<String, dynamic>> exportConversationMemberships(
    String userId,
  ) async {
    try {
      final memberships = await _exports.exportConversationMemberships(userId);
      return {
        'memberships': memberships.map(sanitizeForJson).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export conversation memberships',
        e,
      );
      return _failed(
        'Conversation memberships',
        'conversation-memberships-export-failed',
      );
    }
  }

  /// BUT-1396: Export moderation reports the user filed (`reports` where
  /// `reporterId == uid`). The whole doc is exported, including the free-text
  /// `description` field (the genuine PII; `reason` itself is an enum) — data
  /// the deletion cascade erases, so Art. 15 requires it in the export.
  Future<Map<String, dynamic>> exportReports(String userId) async {
    try {
      final reports = await _exports.exportReportsByReporter(userId);
      return {
        'reports': reports
            .map(
              (e) => {
                'report_id': e['id'],
                'data': sanitizeForJson(e['data']),
              },
            )
            .toList(),
        'total': reports.length,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export reports', e);
      return _failed('Reports', 'reports-export-failed');
    }
  }

  /// How many times the user has been REPORTED by others, and when last.
  ///
  /// The counterpart to [exportReports], which covers reports they FILED. Only
  /// the two counters are exported; who reported them is withheld under
  /// Art. 15(4) — those are other people, and naming them would expose someone
  /// who used a safety feature.
  ///
  /// Malin's explicit call, 2026-09-08, reversing ADR-0017 the same day.
  Future<Map<String, dynamic>> exportModerationCounters(String userId) async {
    try {
      final counters = await _exports.exportModerationCounters(userId);
      return {
        'moderation_counters': counters == null
            ? null
            : sanitizeForJson(counters),
        // Art. 12(1): a withholding the reader cannot see is an undisclosed
        // gap, not a minimisation decision.
        'data_minimisation':
            'This shows how many times your content has been reported by other '
            'people, and when it last happened. Who reported you is not '
            'included: that is information about them, and disclosing it would '
            'expose someone who used a safety feature.',
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export moderation counters',
        e,
      );
      return _failed(
        'Moderation counters',
        'moderation-counters-export-failed',
      );
    }
  }

  /// BUT-1396: Export group pings the user sent (`pings` collection-group
  /// where `fromUserId == uid`).
  Future<Map<String, dynamic>> exportPings(String userId) async {
    try {
      final pings = await _exports.exportPingsSent(userId);
      return {
        'pings': pings
            .map(
              (e) => {
                'ping_id': e['id'],
                'data': sanitizeForJson(e['data']),
              },
            )
            .toList(),
        'total': pings.length,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export pings', e);
      return _failed('Pings', 'pings-export-failed');
    }
  }
}
