/// Direct unit tests for [SocialExportManager] (BUT-1438, BUT-1401 follow-up).
///
/// Proves the GDPR Article-15/20 *social* export contract: friends, friend
/// requests (both directions), friend categories, conversations + messages,
/// shared content received, blocks (both directions), and conversation
/// memberships each appear, correctly reshaped, in the exported payload.
/// A refactor dropping any of these record types would fail an assertion
/// here even though the bundle would still assemble.
///
/// Mocking: the manager resolves its single dependency
/// ([FirebaseDataExportRepository]) via a constructor seam, so we inject a
/// `Fake` that returns canned rows per export method — no emulator.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/social_export_manager.dart';

class _FakeDataExportRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakeDataExportRepository({
    this.friends = const [],
    this.sentRequests = const [],
    this.receivedRequests = const [],
    this.categories = const [],
    this.conversations = const [],
    this.sharedRecipes = const [],
    this.sharedMenus = const [],
    this.outgoingBlocks = const [],
    this.incomingBlocks = const [],
    this.memberships = const [],
  });

  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> sentRequests;
  final List<Map<String, dynamic>> receivedRequests;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> conversations;
  final List<Map<String, dynamic>> sharedRecipes;
  final List<Map<String, dynamic>> sharedMenus;
  final List<Map<String, dynamic>> outgoingBlocks;
  final List<Map<String, dynamic>> incomingBlocks;
  final List<Map<String, dynamic>> memberships;

  /// Per-method captured `maxDocuments`, keyed by repository method name.
  /// Every override that the manager is expected to pass a cap to defaults to
  /// a sentinel -1 no real caller would pass, so a production path that stops
  /// forwarding its cap fails the forwarding test instead of coincidentally
  /// matching the repository's own default. The remaining overrides
  /// (blocks, memberships) keep the real defaults — the manager forwards
  /// nothing to them and they carry no truncation probe.
  final Map<String, int> capturedMax = <String, int>{};

  /// `exportConversationsAndMessages` takes TWO caps, so it records into its
  /// own fields rather than [capturedMax].
  int? capturedMaxConversations;
  int? capturedMaxMessagesPerConversation;

  @override
  Future<List<Map<String, dynamic>>> exportFriendsSubcollection(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportFriendsSubcollection'] = maxDocuments;
    return friends;
  }

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsSent(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportSocialRequestsSent'] = maxDocuments;
    return sentRequests;
  }

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsReceived(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportSocialRequestsReceived'] = maxDocuments;
    return receivedRequests;
  }

  @override
  Future<List<Map<String, dynamic>>> exportFriendCategories(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportFriendCategories'] = maxDocuments;
    return categories;
  }

  @override
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = -1,
    int maxMessagesPerConversation = -1,
  }) async {
    capturedMaxConversations = maxConversations;
    capturedMaxMessagesPerConversation = maxMessagesPerConversation;
    return conversations;
  }

  @override
  Future<List<Map<String, dynamic>>> exportSharedRecipesReceived(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportSharedRecipesReceived'] = maxDocuments;
    return sharedRecipes;
  }

  @override
  Future<List<Map<String, dynamic>>> exportSharedMenusReceived(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportSharedMenusReceived'] = maxDocuments;
    return sharedMenus;
  }

  @override
  Future<List<Map<String, dynamic>>> exportOutgoingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) async => outgoingBlocks;

  @override
  Future<List<Map<String, dynamic>>> exportIncomingBlocks(
    String userId, {
    int maxDocuments = 500,
  }) async => incomingBlocks;

  @override
  Future<List<Map<String, dynamic>>> exportConversationMemberships(
    String userId, {
    int maxDocuments = 500,
  }) async => memberships;
}

/// BUT-1721: a repository whose first capped read throws, carrying exactly the
/// text that must never reach the data subject — another person's uid inside a
/// composite doc id, and a `create_composite` index URL naming a member field
/// path and the project id.
///
/// The aggregator's own leak test in `data_export_service_test.dart` is a
/// CONTROL, not coverage of this: because it derives the bundle-root message
/// rather than copying the section's, it passes with the leak still present in
/// every section body. The section body is the part the user downloads, so it
/// needs its own assertion here.
class _ThrowingFriendsRepository extends Fake
    implements FirebaseDataExportRepository {
  static const String foreignUid = 'uid-of-another-person-9f2e45';
  static const String leakyText =
      'PERMISSION_DENIED reading blocks/me_$foreignUid; '
      'https://console.firebase.google.com/project/butlery-prod-42/firestore/'
      'indexes?create_composite=memberPermissions.$foreignUid';

  @override
  Future<List<Map<String, dynamic>>> exportFriendsSubcollection(
    String userId, {
    int maxDocuments = 500,
  }) async => throw StateError(leakyText);
}

void main() {
  group('SocialExportManager failure envelope (BUT-1721)', () {
    test('a failed friends read carries a stable token and never the raw '
        'exception', () async {
      final manager = SocialExportManager(
        dataExportRepository: _ThrowingFriendsRepository(),
      );

      final result = await manager.exportFriends('u1');

      expect(
        result['error_code'],
        'friends-export-failed',
        reason:
            'the token is what DataExportService lifts to bundle level; '
            'without it the section can fail while the bundle reads complete',
      );
      expect(
        result['error'] as String,
        isNot(contains(_ThrowingFriendsRepository.foreignUid)),
        reason:
            'another data subject`s uid must not ship inside the requester`s '
            'Art. 15 bundle',
      );
      expect(
        result['error'] as String,
        isNot(contains('create_composite')),
        reason: 'an index URL names the project and a member field path',
      );
      expect(
        result.containsKey('friends'),
        isFalse,
        reason:
            'a failed section must not also present an empty list, which reads '
            'as "you have no friends" rather than "this could not be read"',
      );
    });
  });

  group('SocialExportManager.exportFriends (BUT-1438)', () {
    test(
      'includes all four friend record types, reshaped, with totals',
      () async {
        final manager = SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            friends: [
              {
                'id': 'fr1',
                'data': {'name': 'Anna'},
              },
            ],
            sentRequests: [
              {
                'id': 'req-s1',
                'data': {'to': 'Bob'},
              },
            ],
            receivedRequests: [
              {
                'id': 'req-r1',
                'data': {'from': 'Cara'},
              },
              {
                'id': 'req-r2',
                'data': {'from': 'Dan'},
              },
            ],
            categories: [
              {
                'id': 'cat1',
                'data': {'label': 'Family'},
              },
            ],
          ),
        );

        final result = await manager.exportFriends('user-uid');

        expect(result['friends'], [
          {
            'friend_id': 'fr1',
            'data': {'name': 'Anna'},
          },
        ]);
        expect(result['friend_requests_sent'], [
          {
            'request_id': 'req-s1',
            'data': {'to': 'Bob'},
          },
        ]);
        expect((result['friend_requests_received'] as List), hasLength(2));
        expect(result['friend_categories'], [
          {
            'category_id': 'cat1',
            'data': {'label': 'Family'},
          },
        ]);
        expect(result['total_friends'], 1);
        expect(result['total_pending_sent'], 1);
        expect(result['total_pending_received'], 2);
        expect(result['total_categories'], 1);
      },
    );

    test('all four record-type keys present even when empty', () async {
      final manager = SocialExportManager(
        dataExportRepository: _FakeDataExportRepository(),
      );

      final result = await manager.exportFriends('user-uid');

      for (final key in const [
        'friends',
        'friend_requests_sent',
        'friend_requests_received',
        'friend_categories',
      ]) {
        expect(result.containsKey(key), isTrue, reason: 'missing $key');
        expect(result[key], isEmpty);
      }
    });
  });

  /// BUT-1772 — Malin's call, 2026-07-30: the conversations section keeps other
  /// participants' names and user ids and strips their AVATAR URLs. The
  /// opposite redaction to the shared-list export, made with both on the table.
  ///
  /// Both halves are pinned here. "Strip the avatars" must not quietly become
  /// "strip more" — a section reduced to opaque uids fails Art. 12(1) just as a
  /// bundle carrying a durable pointer to someone else's photograph fails
  /// Art. 15(4).
  group('SocialExportManager conversation redaction (BUT-1772)', () {
    const userId = 'user-uid';
    const otherUid = 'other-uid';
    const otherAvatar = 'https://example.test/avatars/other-uid.jpg';
    const ownAvatar = 'https://example.test/avatars/user-uid.jpg';

    SocialExportManager buildManager() => SocialExportManager(
      dataExportRepository: _FakeDataExportRepository(
        conversations: [
          {
            'id': 'conv1',
            'data': {
              'title': 'Middagsplaner',
              'participantIds': [userId, otherUid],
              'participantDisplayNames': {userId: 'Malin', otherUid: 'Anna'},
              'participantAvatarUrls': {
                userId: ownAvatar,
                otherUid: otherAvatar,
              },
              'lastReadTimestamps': {userId: 1, otherUid: 2},
              // The conversation document embeds its newest message for
              // previews, so the sender's avatar rides along here even while
              // `messages` is empty (BUT-1767).
              'lastMessage': {
                'senderId': otherUid,
                'senderDisplayName': 'Anna',
                'senderAvatarUrl': otherAvatar,
                'content': 'Ses kl 18',
              },
            },
            'messages': const <Map<String, dynamic>>[],
          },
        ],
      ),
    );

    test(
      'another participant s avatar URL appears NOWHERE in the bundle',
      () async {
        final result = await buildManager().exportMessages(userId);

        // Asserted against the whole serialised section, not just the map: a copy
        // hiding in `lastMessage` would pass a map-only assertion.
        expect(
          json.encode(result),
          isNot(contains(otherAvatar)),
          reason:
              'an avatar URL is a durable pointer to another person s photograph '
              'and keeps resolving after they leave the thread',
        );
      },
    );

    test('the requester s OWN avatar URL is kept', () async {
      final result = await buildManager().exportMessages(userId);
      final convo =
          (result['conversations'] as List).single as Map<String, dynamic>;
      final info = convo['conversation_info'] as Map<String, dynamic>;

      expect(
        (info['participantAvatarUrls'] as Map)[userId],
        ownAvatar,
        reason:
            'withholding the subject s own data is the opposite failure to the '
            'one this redaction guards against',
      );
    });

    test(
      'names, ids, read timestamps and message content are UNTOUCHED',
      () async {
        final result = await buildManager().exportMessages(userId);
        final convo =
            (result['conversations'] as List).single as Map<String, dynamic>;
        final info = convo['conversation_info'] as Map<String, dynamic>;

        expect(info['title'], 'Middagsplaner');
        expect(info['participantIds'], [userId, otherUid]);
        expect(info['participantDisplayNames'], {
          userId: 'Malin',
          otherUid: 'Anna',
        });
        expect(info['lastReadTimestamps'], {userId: 1, otherUid: 2});

        final lastMessage = info['lastMessage'] as Map<String, dynamic>;
        expect(lastMessage['senderId'], otherUid);
        expect(
          lastMessage['senderDisplayName'],
          'Anna',
          reason:
              'the name is the decided keep — stripping it leaves opaque uids '
              'and fails the "intelligible" limb of Art. 12(1)',
        );
        expect(lastMessage['content'], 'Ses kl 18');
        expect(lastMessage.containsKey('senderAvatarUrl'), isFalse);
      },
    );

    test(
      'the section states what it dropped, and does not enumerate the keeps',
      () async {
        final result = await buildManager().exportMessages(userId);

        final line = result['data_minimisation'] as String;
        expect(
          line,
          contains('profile pictures'),
          reason: 'a bundle that silently redacts states something false',
        );
        // The keep side must NOT be a list. The sibling section shipped one that
        // named four of six fields; this document carries lastReadTimestamps,
        // reactions, poll voterIds and perUserSettings on top of the obvious
        // keeps, so any enumeration here starts out incomplete.
        expect(
          line,
          isNot(contains('names, user ids')),
          reason:
              'an enumeration that must stay exhaustive to stay true will stop '
              'being true',
        );
      },
    );

    /// The requester's OWN avatar on the `lastMessage` leg, which the map leg's
    /// test does not reach. The guard is replicated across two fields and the
    /// untested twin is the one the other fixtures omit: turning
    /// `senderId != userId` into an unconditional strip reddened nothing, so a
    /// conversation whose newest message the requester sent could lose their own
    /// avatar silently.
    test(
      'the requester s own avatar survives on the embedded lastMessage',
      () async {
        final manager = SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            conversations: [
              {
                'id': 'conv1',
                'data': {
                  'participantIds': [userId, otherUid],
                  'lastMessage': {
                    'senderId': userId,
                    'senderDisplayName': 'Malin',
                    'senderAvatarUrl': ownAvatar,
                    'content': 'Jag fixar efterrätten',
                  },
                },
                'messages': const <Map<String, dynamic>>[],
              },
            ],
          ),
        );

        final result = await manager.exportMessages(userId);
        final convo =
            (result['conversations'] as List).single as Map<String, dynamic>;
        final info = convo['conversation_info'] as Map<String, dynamic>;
        final lastMessage = info['lastMessage'] as Map<String, dynamic>;

        expect(
          lastMessage['senderAvatarUrl'],
          ownAvatar,
          reason:
              'this is the requester s own message and their own picture — '
              'withholding it is the opposite failure to the one guarded against',
        );
        expect(
          info.containsKey('redaction_fell_back'),
          isFalse,
          reason:
              'nothing was dropped wholesale, so the bundle must not say it was',
        );
      },
    );

    /// FAIL CLOSED. A redaction that silently no-ops on a shape it does not
    /// recognise ships the data while the bundle claims it was removed — the
    /// expensive direction, because nothing surfaces it.
    test('an unexpected lastMessage shape drops the field entirely', () async {
      final manager = SocialExportManager(
        dataExportRepository: _FakeDataExportRepository(
          conversations: [
            {
              'id': 'conv1',
              'data': {
                'participantIds': [userId, otherUid],
                // A plausible legacy preview shape: a bare string rather than
                // the embedded message map.
                'lastMessage': 'Anna: $otherAvatar',
              },
              'messages': const <Map<String, dynamic>>[],
            },
          ],
        ),
      );

      final result = await manager.exportMessages(userId);
      final convo =
          (result['conversations'] as List).single as Map<String, dynamic>;
      final info = convo['conversation_info'] as Map<String, dynamic>;

      expect(json.encode(result), isNot(contains(otherAvatar)));
      expect(info.containsKey('lastMessage'), isFalse);
      expect(info['redaction_fell_back'], isTrue);
    });

    test(
      'an unexpected participantAvatarUrls shape drops the field entirely',
      () async {
        final manager = SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            conversations: [
              {
                'id': 'conv1',
                'data': {
                  'participantIds': [userId, otherUid],
                  // A future/legacy shape: a LIST of {uid, url} rather than a map.
                  'participantAvatarUrls': [
                    {'uid': otherUid, 'url': otherAvatar},
                  ],
                },
                'messages': const <Map<String, dynamic>>[],
              },
            ],
          ),
        );

        final result = await manager.exportMessages(userId);
        final convo =
            (result['conversations'] as List).single as Map<String, dynamic>;
        final info = convo['conversation_info'] as Map<String, dynamic>;

        expect(json.encode(result), isNot(contains(otherAvatar)));
        expect(info.containsKey('participantAvatarUrls'), isFalse);
        expect(
          info['redaction_fell_back'],
          isTrue,
          reason:
              'the bundle must admit that a field was dropped wholesale rather '
              'than silently losing it',
        );
      },
    );
  });

  group('SocialExportManager.exportMessages (BUT-1438)', () {
    test(
      'includes conversations and only messages involving the user',
      () async {
        const userId = 'user-uid';
        final manager = SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            conversations: [
              {
                'id': 'conv1',
                'data': {'title': 'Dinner plans'},
                'messages': [
                  {
                    'id': 'm1',
                    'data': {'senderId': userId, 'text': 'mine'},
                  },
                  {
                    'id': 'm2',
                    'data': {
                      'senderId': 'other',
                      'recipientIds': [userId],
                      'text': 'to me',
                    },
                  },
                  {
                    'id': 'm3',
                    'data': {
                      'senderId': 'other',
                      'recipientIds': ['someone-else'],
                      'text': 'not mine',
                    },
                  },
                ],
              },
            ],
          ),
        );

        final result = await manager.exportMessages(userId);

        final conversations = result['conversations'] as List;
        expect(conversations, hasLength(1));
        final convo = conversations.single as Map<String, dynamic>;
        expect(convo['conversation_id'], 'conv1');
        expect(convo['conversation_info'], {'title': 'Dinner plans'});
        final messages = convo['messages'] as List;
        // m3 (neither sent by nor addressed to the user) is excluded.
        expect(messages, hasLength(2));
        expect(
          messages.map((m) => (m as Map)['message_id']),
          containsAll(<String>['m1', 'm2']),
        );
        expect(convo['message_count'], 2);
        expect(result['total_conversations'], 1);
        expect(result['total_messages'], 2);
      },
    );

    test(
      'forwards the declared conversation and per-conversation message caps',
      () async {
        // Both caps must actually reach the repository: its own defaults are
        // LOWER than the declared export limits (100 conversations / 500
        // messages vs 500 / 1000), so a regression that stopped forwarding
        // them would silently drop four fifths of a heavy user's
        // conversations from an Article 15/20 bundle — no error, and (see the
        // truncation test below) no usable flag either. The sentinel default
        // on the fake is what makes a dropped forward visible; matching the
        // real defaults would have let the regression pass.
        final repo = _FakeDataExportRepository();
        await SocialExportManager(
          dataExportRepository: repo,
        ).exportMessages('user-uid');

        expect(
          repo.capturedMaxConversations,
          ExportPaginationHelper.getLimitForType('conversations'),
        );
        expect(
          repo.capturedMaxMessagesPerConversation,
          ExportPaginationHelper.getLimitForType('messages_per_conversation'),
        );
      },
    );

    test(
      'carries a per-conversation messages_truncated flag through, and omits '
      'it on complete conversations',
      () async {
        // The manager's copy is correct and this pins it. Two defects AROUND
        // it are known and deliberately NOT asserted as desired behaviour:
        //   1. firebase_data_export_repository computes the flag as
        //      `docs.length >= maxMessagesPerConversation`, the false-positive
        //      rule BUT-1562/1662 retired everywhere else, so a conversation
        //      holding exactly `cap` messages is stamped clipped;
        //   2. data_export_service's nested truncation pass only walks
        //      `section.values.whereType<Map>()`, and this flag lives inside
        //      the `conversations` LIST — so it never reaches
        //      `truncated_collections` and the user never sees it.
        // This test exists so both are greppable: it is the only reference to
        // `messages_truncated` anywhere under test/.
        const userId = 'user-uid';
        final manager = SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            conversations: [
              {
                'id': 'clipped',
                'data': {'title': 'Long thread'},
                'messages': [
                  {
                    'id': 'm1',
                    'data': {'senderId': userId, 'text': 'hej'},
                  },
                ],
                'messages_truncated': true,
              },
              {
                'id': 'complete',
                'data': {'title': 'Short thread'},
                'messages': [
                  {
                    'id': 'm2',
                    'data': {'senderId': userId, 'text': 'hej igen'},
                  },
                ],
                'messages_truncated': false,
              },
            ],
          ),
        );

        final result = await manager.exportMessages(userId);

        final conversations = (result['conversations'] as List)
            .cast<Map<String, dynamic>>();
        final clipped = conversations.firstWhere(
          (c) => c['conversation_id'] == 'clipped',
        );
        final complete = conversations.firstWhere(
          (c) => c['conversation_id'] == 'complete',
        );

        expect(clipped['messages_truncated'], isTrue);
        // Omitted rather than `false`, matching the section-root convention.
        expect(complete.containsKey('messages_truncated'), isFalse);
        // Positive control: the absence above is not a build that fell over.
        expect((complete['messages'] as List), hasLength(1));
      },
    );
  });

  group('SocialExportManager.exportSharedContent (BUT-1438)', () {
    test('includes shared recipes and menus received, with totals', () async {
      final manager = SocialExportManager(
        dataExportRepository: _FakeDataExportRepository(
          sharedRecipes: [
            {
              'id': 'sr1',
              'data': {'title': 'Pasta'},
            },
          ],
          sharedMenus: [
            {
              'id': 'sm1',
              'data': {'name': 'Week 1'},
            },
          ],
        ),
      );

      final result = await manager.exportSharedContent('user-uid');

      expect(result['shared_recipes_received'], [
        {
          'share_id': 'sr1',
          'data': {'title': 'Pasta'},
        },
      ]);
      expect(result['shared_menus_received'], [
        {
          'menu_id': 'sm1',
          'data': {'name': 'Week 1'},
        },
      ]);
      expect(result['total_shared_recipes'], 1);
      expect(result['total_shared_menus'], 1);
    });
  });

  group('SocialExportManager.exportBlocks (BUT-1438)', () {
    test('includes blocks in both directions, sanitized for JSON', () async {
      // Unlike other record types, blocks pass the whole raw map through
      // sanitizeForJson with no id/data envelope. Including a DateTime proves
      // sanitization actually ran (it must become an ISO-8601 string) — not
      // just that the value was forwarded unchanged.
      final blockedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final manager = SocialExportManager(
        dataExportRepository: _FakeDataExportRepository(
          outgoingBlocks: [
            {'blockedUserId': 'x', 'blockedAt': blockedAt},
          ],
          incomingBlocks: [
            {'blockerUserId': 'y'},
          ],
        ),
      );

      final result = await manager.exportBlocks('user-uid');

      expect(result['outgoing_blocks'], [
        {'blockedUserId': 'x', 'blockedAt': blockedAt.toIso8601String()},
      ]);
      expect(result['incoming_blocks'], [
        {'blockerUserId': 'y'},
      ]);
    });
  });

  group('SocialExportManager.exportConversationMemberships (BUT-1438)', () {
    test('includes membership records', () async {
      final manager = SocialExportManager(
        dataExportRepository: _FakeDataExportRepository(
          memberships: [
            {'conversationId': 'conv1', 'role': 'member'},
          ],
        ),
      );

      final result = await manager.exportConversationMemberships('user-uid');

      expect(result['memberships'], [
        {'conversationId': 'conv1', 'role': 'member'},
      ]);
    });
  });

  // BUT-1698: these sections applied their caps SILENTLY — no `truncated` key
  // whatsoever — so a user at or over a cap received a clipped Article 15/20
  // bundle presented as complete. They now run the same N+1 probe the
  // preferences sections use (BUT-1662): fetch cap + 1, flag only when a row
  // beyond the cap actually exists, trim to the cap. `data_export_service`
  // rolls a section-root `truncated` into `truncated_collections` verbatim, so
  // this key IS the completeness signal the user sees.
  group('SocialExportManager.exportFriends truncation (BUT-1698)', () {
    final friendCap = ExportPaginationHelper.getLimitForType('friends');
    final requestCap = ExportPaginationHelper.getLimitForType(
      'friend_requests',
    );

    SocialExportManager managerWith({
      int friends = 0,
      int sent = 0,
      int received = 0,
    }) => SocialExportManager(
      dataExportRepository: _FakeDataExportRepository(
        friends: List.generate(friends, (i) => _cappedRow('f', i)),
        sentRequests: List.generate(sent, (i) => _cappedRow('s', i)),
        receivedRequests: List.generate(received, (i) => _cappedRow('r', i)),
      ),
    );

    test('omits truncated when every leg sits exactly at its cap', () async {
      // Boundary: "exactly `cap` records exist" is a COMPLETE export. Deriving
      // the flag from `length >= cap` would stamp it truncated and tell the
      // user data was withheld when none was.
      final result = await managerWith(
        friends: friendCap,
        sent: requestCap,
        received: requestCap,
      ).exportFriends('user-uid');

      expect((result['friends'] as List).length, friendCap);
      expect(result['total_friends'], friendCap);
      expect(result['total_pending_sent'], requestCap);
      expect(result['total_pending_received'], requestCap);
      expect(result.containsKey('truncated'), isFalse);
    });

    test('flags truncated and trims when the FRIENDS leg is over', () async {
      final result = await managerWith(
        friends: friendCap + 1,
        sent: 2,
        received: 2,
      ).exportFriends('user-uid');

      final friends = (result['friends'] as List).cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(friends.length, friendCap);
      expect(result['total_friends'], friendCap);
      // The probe row must not reach the bundle.
      expect(
        friends.map((f) => f['friend_id']),
        isNot(contains('f$friendCap')),
      );
    });

    test('flags truncated when only the SENT-requests leg is over', () async {
      // Each leg carries the cap independently, so the OR needs a positive
      // case per leg — a collapse to a single leg would ship silently.
      final result = await managerWith(
        friends: 2,
        sent: requestCap + 1,
        received: 2,
      ).exportFriends('user-uid');

      expect(result['truncated'], isTrue);
      expect(result['total_pending_sent'], requestCap);
      expect(result['total_pending_received'], 2);
    });

    test(
      'flags truncated when only the RECEIVED-requests leg is over',
      () async {
        final result = await managerWith(
          friends: 2,
          sent: 2,
          received: requestCap + 1,
        ).exportFriends('user-uid');

        expect(result['truncated'], isTrue);
        expect(result['total_pending_received'], requestCap);
        expect(result['total_pending_sent'], 2);
      },
    );

    test('forwards cap + 1 to each capped repository query', () async {
      final repo = _FakeDataExportRepository();
      await SocialExportManager(
        dataExportRepository: repo,
      ).exportFriends('user-uid');

      // Whole-map equality rather than three field checks: it proves per-leg
      // forwarding AND that every read this section makes is accounted for.
      // `exportFriendCategories` records the SENTINEL because the manager
      // forwards no cap to it at all — that fourth record type rides the
      // repository's implicit default (100) and is therefore NOT covered by
      // the section-root `truncated` flag the other three legs OR into. A
      // user with more than 100 categories gets a section that positively
      // asserts completeness. Deferred to BUT-1701; when it closes, this
      // entry becomes `categoryCap + 1` and a positive truncation test for
      // the categories leg belongs beside the other three.
      expect(repo.capturedMax, {
        'exportFriendsSubcollection': friendCap + 1,
        'exportSocialRequestsSent': requestCap + 1,
        'exportSocialRequestsReceived': requestCap + 1,
        'exportFriendCategories': -1,
      });
    });
  });

  group('SocialExportManager.exportSharedContent truncation (BUT-1698)', () {
    final recipeCap = ExportPaginationHelper.getLimitForType('recipes');
    final menuCap = ExportPaginationHelper.getLimitForType('menus');

    SocialExportManager managerWith({int recipes = 0, int menus = 0}) =>
        SocialExportManager(
          dataExportRepository: _FakeDataExportRepository(
            sharedRecipes: List.generate(recipes, (i) => _cappedRow('sr', i)),
            sharedMenus: List.generate(menus, (i) => _cappedRow('sm', i)),
          ),
        );

    test('omits truncated when both legs sit exactly at their cap', () async {
      final result = await managerWith(
        recipes: recipeCap,
        menus: menuCap,
      ).exportSharedContent('user-uid');

      expect(result['total_shared_recipes'], recipeCap);
      expect(result['total_shared_menus'], menuCap);
      expect(result.containsKey('truncated'), isFalse);
    });

    test('flags truncated and trims when the RECIPES leg is over', () async {
      final result = await managerWith(
        recipes: recipeCap + 1,
        menus: 1,
      ).exportSharedContent('user-uid');

      final recipes = (result['shared_recipes_received'] as List)
          .cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(recipes.length, recipeCap);
      expect(result['total_shared_recipes'], recipeCap);
      expect(
        recipes.map((r) => r['share_id']),
        isNot(contains('sr$recipeCap')),
      );
    });

    test('flags truncated when only the MENUS leg is over', () async {
      final result = await managerWith(
        recipes: 1,
        menus: menuCap + 1,
      ).exportSharedContent('user-uid');

      expect(result['truncated'], isTrue);
      expect(result['total_shared_menus'], menuCap);
      expect(result['total_shared_recipes'], 1);
    });

    test('forwards cap + 1 to each capped repository query', () async {
      final repo = _FakeDataExportRepository();
      await SocialExportManager(
        dataExportRepository: repo,
      ).exportSharedContent('user-uid');

      expect(repo.capturedMax, {
        'exportSharedRecipesReceived': recipeCap + 1,
        'exportSharedMenusReceived': menuCap + 1,
      });
    });
  });
}

/// A capped-section row with a stable, per-index id so a trimmed payload can be
/// told apart from a re-ordered one.
Map<String, dynamic> _cappedRow(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'n': i},
};
