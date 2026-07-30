// lib/services/account/export/social_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// Handles export of social data: friends, messages, shared content.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501 (closed): All direct Firestore reads route through
/// [FirebaseDataExportRepository] which enforces `validateOwnership`
/// defence-in-depth on top of Firestore rules.
class SocialExportManager {
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
  /// and the copy embedded in `lastMessage`. Names, user ids, read timestamps
  /// and message content are deliberately kept.
  ///
  /// BUT-1772, Malin's call 2026-07-30. This is the OPPOSITE redaction to
  /// [SharedShoppingListExport], which strips names and keeps ids, and the
  /// asymmetry is the decision rather than an oversight: a shopping row's
  /// cached `addedByDisplayName` is a denormalised copy of a profile that the
  /// paired `*UserId` makes redundant, while a conversation stripped of names
  /// is a list of opaque uids that fails Art. 12(1)'s "intelligible" limb. An
  /// avatar URL is different in kind from a name — a durable, directly
  /// dereferenceable pointer to another person's photograph, which survives in
  /// any file this bundle is forwarded to and keeps resolving after they leave
  /// the thread or delete their account — and it buys the requester nothing.
  ///
  /// The requester's OWN avatar stays. Withholding the subject's own data is
  /// the opposite failure to the one this guards against.
  ///
  /// When BUT-1767 repoints the message query at the collection production
  /// actually writes, each message row arrives carrying its own
  /// `senderAvatarUrl`; this redaction must be extended to cover it then. The
  /// `messages` array ships empty today, so there is nothing here to strip yet.
  Map<String, dynamic> _dropOtherPeoplesAvatars(
    Map<String, dynamic> source,
    String userId,
  ) {
    final copy = Map<String, dynamic>.from(source);

    // Both branches FAIL CLOSED on a shape they do not recognise: an unexpected
    // shape drops the field entirely rather than falling through to the
    // untouched copy. A redaction that silently no-ops on a schema it has not
    // seen is the expensive failure — it ships the data while the
    // `data_minimisation` line still claims it was removed. Neither drop loses
    // anything the requester is owed: `participantAvatarUrls` holds nothing but
    // avatars, and `lastMessage` is a denormalised PREVIEW of a row that also
    // belongs in `messages`.
    final avatars = copy['participantAvatarUrls'];
    if (avatars != null) {
      if (avatars is Map) {
        copy['participantAvatarUrls'] = <String, dynamic>{
          userId: ?avatars[userId],
        };
      } else {
        copy.remove('participantAvatarUrls');
        copy['redaction_fell_back'] = true;
      }
    }

    // The conversation document embeds its most recent message for previews, so
    // the sender's avatar rides along here even while `messages` carries nothing
    // (BUT-1767).
    final lastMessage = copy['lastMessage'];
    if (lastMessage != null) {
      if (lastMessage is Map) {
        if (lastMessage['senderId'] != userId) {
          copy['lastMessage'] = Map<String, dynamic>.from(
            lastMessage.cast<String, dynamic>(),
          )..remove('senderAvatarUrl');
        }
      } else {
        copy.remove('lastMessage');
        copy['redaction_fell_back'] = true;
      }
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
          // Only include messages sent by this user or received by this user.
          final messageData =
              sanitizeForJson(msg['data']) as Map<String, dynamic>;
          final recipientIds = messageData['recipientIds'] as List?;
          if (messageData['senderId'] == userId ||
              (recipientIds != null && recipientIds.contains(userId))) {
            messagesList.add({
              'message_id': msg['id'],
              'data': messageData,
            });
          }
        }

        final conversationData = <String, dynamic>{
          'conversation_id': convo['id'],
          'conversation_info': _dropOtherPeoplesAvatars(
            sanitizeForJson(convo['data']) as Map<String, dynamic>,
            userId,
          ),
          'messages': messagesList,
          'message_count': messagesList.length,
        };
        if (convo['messages_truncated'] == true) {
          conversationData['messages_truncated'] = true;
        }
        messagesData['conversations'].add(conversationData);
        messagesData['total_messages'] += messagesList.length;
      }

      messagesData['total_conversations'] =
          messagesData['conversations'].length;

      // Section level, matching SharedShoppingListExport, rather than duplicated
      // into each of up to 100 conversations.
      //
      // It states the DROP and stops. The keep side is deliberately not
      // enumerated: the sibling section shipped a positive list that named four
      // of six fields and thereby made the bundle state something false about
      // itself, and this document carries more than the obvious keeps —
      // `lastReadTimestamps`, `reactions`, poll `voterIds` and `perUserSettings`
      // among them (BUT-1774 asks Malin about the last of those). A list that
      // must stay exhaustive to stay true is a list that will stop being true.
      messagesData['data_minimisation'] =
          "Other participants' profile pictures have been removed. Everything "
          'else this conversation held is kept as it was stored.';

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
          'data': sanitizeForJson(entry['data']),
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
          'data': sanitizeForJson(entry['data']),
        });
      }

      sharedData['total_shared_recipes'] =
          sharedData['shared_recipes_received'].length;
      sharedData['total_shared_menus'] =
          sharedData['shared_menus_received'].length;
      if (sharedRecipes.truncated || sharedMenus.truncated) {
        sharedData['truncated'] = true;
      }

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

  /// Export blocked users (both directions)
  Future<Map<String, dynamic>> exportBlocks(String userId) async {
    try {
      final outgoing = await _exports.exportOutgoingBlocks(userId);
      final incoming = await _exports.exportIncomingBlocks(userId);

      return {
        'outgoing_blocks': outgoing.map(sanitizeForJson).toList(),
        'incoming_blocks': incoming.map(sanitizeForJson).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export blocks', e);
      return _failed('Blocked users', 'blocks-export-failed');
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
