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

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
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

  @override
  Future<List<Map<String, dynamic>>> exportFriendsSubcollection(
    String userId, {
    int maxDocuments = 1000,
  }) async => friends;

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsSent(
    String userId, {
    int maxDocuments = 500,
  }) async => sentRequests;

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsReceived(
    String userId, {
    int maxDocuments = 500,
  }) async => receivedRequests;

  @override
  Future<List<Map<String, dynamic>>> exportFriendCategories(
    String userId, {
    int maxDocuments = 100,
  }) async => categories;

  @override
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = 100,
    int maxMessagesPerConversation = 500,
  }) async => conversations;

  @override
  Future<List<Map<String, dynamic>>> exportSharedRecipesReceived(
    String userId, {
    int maxDocuments = 1000,
  }) async => sharedRecipes;

  @override
  Future<List<Map<String, dynamic>>> exportSharedMenusReceived(
    String userId, {
    int maxDocuments = 500,
  }) async => sharedMenus;

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

void main() {
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
}
