/// Per-read isolation and cap truncation for [SocialExportManager]
/// (BUT-2008, BUT-1701).
///
/// Sections that make several reads used to share one `try`, so a refusal on
/// the last one threw away the rows the earlier ones had already fetched and
/// the bundle said the whole section failed. These tests refuse ONE read at a
/// time and assert what the data subject still receives, what the bundle says
/// about the read that failed, and that it never says "none" about it.
///
/// The fake serves every read through one place that honours `maxDocuments`
/// like a real query's `limit`, so the N+1 probe sees what Firestore would
/// give it.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/social_export_manager.dart';

const _foreignUid = 'uid-of-another-person-9f2e45';

class _ScriptedRepository extends Fake implements FirebaseDataExportRepository {
  _ScriptedRepository({
    this.rows = const {},
    this.failing = const {},
    this.conversations = const [],
    this.conversationCount,
    this.failCount = false,
  });

  /// Rows per repository method name.
  final Map<String, List<Map<String, dynamic>>> rows;

  /// Method names whose read throws.
  final Set<String> failing;

  final List<Map<String, dynamic>> conversations;

  /// What `countConversations` answers; null leaves it unscripted.
  final int? conversationCount;
  final bool failCount;

  final Map<String, int> capturedMax = <String, int>{};
  int countCalls = 0;

  List<Map<String, dynamic>> _serve(String method, int maxDocuments) {
    capturedMax[method] = maxDocuments;
    if (failing.contains(method)) {
      // Carries another person's uid so a leak into the bundle is visible.
      throw StateError('permission-denied reading blocks/me_$_foreignUid');
    }
    final all = rows[method] ?? const <Map<String, dynamic>>[];
    return all.length > maxDocuments ? all.sublist(0, maxDocuments) : all;
  }

  @override
  Future<List<Map<String, dynamic>>> exportFriendsSubcollection(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportFriendsSubcollection', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsSent(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportSocialRequestsSent', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportSocialRequestsReceived(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportSocialRequestsReceived', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportFriendCategories(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportFriendCategories', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportSharedRecipesReceived(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportSharedRecipesReceived', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportSharedMenusReceived(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportSharedMenusReceived', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsReceived(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportSharedShoppingListsReceived', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportOutgoingBlocks(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportOutgoingBlocks', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportReportsByReporter(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportReportsByReporter', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportPingsSent(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportPingsSent', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = -1,
    int maxMessagesPerConversation = -1,
  }) async => conversations;

  // Answered, because an unanswered chat-groups leg would put an `error_code`
  // on every messages section in this file.
  @override
  Future<List<Map<String, dynamic>>> exportChatGroups(
    String userId, {
    int maxGroups = -1,
  }) async => const [];

  @override
  Future<int> countConversations(String userId) async {
    countCalls++;
    if (failCount) throw StateError('count refused for $_foreignUid');
    return conversationCount ??
        (throw StateError('this fixture did not script a count'));
  }
}

Map<String, dynamic> _row(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'n': i},
};

List<Map<String, dynamic>> _rows(String prefix, int n) => [
  for (var i = 0; i < n; i++) _row(prefix, i),
];

void main() {
  SocialExportManager managerFor(_ScriptedRepository repo) =>
      SocialExportManager(dataExportRepository: repo);

  group('exportFriends read isolation (BUT-2008)', () {
    // key, id key, total key, repository method, row prefix
    const legs = [
      (
        'friends',
        'friend_id',
        'total_friends',
        'exportFriendsSubcollection',
        'f',
      ),
      (
        'friend_requests_sent',
        'request_id',
        'total_pending_sent',
        'exportSocialRequestsSent',
        's',
      ),
      (
        'friend_requests_received',
        'request_id',
        'total_pending_received',
        'exportSocialRequestsReceived',
        'r',
      ),
      (
        'friend_categories',
        'category_id',
        'total_categories',
        'exportFriendCategories',
        'c',
      ),
    ];

    Map<String, List<Map<String, dynamic>>> allSeeded() => {
      for (final leg in legs) leg.$4: _rows(leg.$5, 2),
    };

    for (final failed in legs) {
      test('a refused ${failed.$1} read keeps the other three and says which '
          'one failed', () async {
        final result = await managerFor(
          _ScriptedRepository(rows: allSeeded(), failing: {failed.$4}),
        ).exportFriends('user-uid');

        for (final other in legs.where((l) => l != failed)) {
          expect(
            (result[other.$1] as List).map((e) => (e as Map)[other.$2]),
            ['${other.$5}0', '${other.$5}1'],
            reason: '${other.$1} was fetched before the refusal',
          );
          expect(result[other.$3], 2);
          expect(result.containsKey('${other.$1}_error_code'), isFalse);
        }
        // No empty list and no zero beside the marker: both would say "you
        // have none", which a read that did not complete cannot know.
        expect(result.containsKey(failed.$1), isFalse);
        expect(result.containsKey(failed.$3), isFalse);
        expect(result['${failed.$1}_error_code'], '${failed.$1}-export-failed');
        expect(result['${failed.$1}_error'], 'Could not export ${failed.$1}.');
        expect(result['error_code'], 'friends-partial-export-failure');
        expect(
          result.containsKey('error'),
          isFalse,
          reason: 'the other three legs did ship, so the section did not fail',
        );
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      });
    }

    test(
      'a clipped leg still stamps truncated when another leg is refused',
      () async {
        final cap = ExportPaginationHelper.getLimitForType('friends');
        final result = await managerFor(
          _ScriptedRepository(
            rows: {'exportFriendsSubcollection': _rows('f', cap + 1)},
            failing: {'exportFriendCategories'},
          ),
        ).exportFriends('user-uid');

        expect(result['truncated'], isTrue);
        expect(result['total_friends'], cap);
        expect(result['error_code'], 'friends-partial-export-failure');
      },
    );

    test(
      'all four refused is the outright failure with the exact sentence',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: allSeeded(),
            failing: {for (final leg in legs) leg.$4},
          ),
        ).exportFriends('user-uid');

        expect(result['error'], 'Friends could not be exported.');
        expect(result['error_code'], 'friends-export-failed');
        for (final leg in legs) {
          expect(result.containsKey(leg.$1), isFalse, reason: leg.$1);
          expect(result.containsKey(leg.$3), isFalse, reason: leg.$3);
        }
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      },
    );

    test('no refusal leaves no error key at all', () async {
      final result = await managerFor(
        _ScriptedRepository(rows: allSeeded()),
      ).exportFriends('user-uid');

      expect(result.keys.where((k) => k.contains('error')), isEmpty);
    });
  });

  group('exportSharedContent read isolation (BUT-2008)', () {
    // key, id key, total key, repository method
    const legs = [
      (
        'shared_recipes_received',
        'share_id',
        'total_shared_recipes',
        'exportSharedRecipesReceived',
      ),
      (
        'shared_menus_received',
        'menu_id',
        'total_shared_menus',
        'exportSharedMenusReceived',
      ),
      (
        'shared_shopping_lists_received',
        'share_id',
        'total_shared_shopping_lists',
        'exportSharedShoppingListsReceived',
      ),
    ];

    Map<String, List<Map<String, dynamic>>> allSeeded() => {
      for (final leg in legs) leg.$4: _rows('${leg.$4}-', 2),
    };

    for (final failed in legs) {
      test('a refused ${failed.$1} read keeps the other two and says which '
          'one failed', () async {
        final result = await managerFor(
          _ScriptedRepository(rows: allSeeded(), failing: {failed.$4}),
        ).exportSharedContent('user-uid');

        for (final other in legs.where((l) => l != failed)) {
          expect(
            (result[other.$1] as List).map((e) => (e as Map)[other.$2]),
            ['${other.$4}-0', '${other.$4}-1'],
          );
          expect(result[other.$3], 2);
        }
        expect(result.containsKey(failed.$1), isFalse);
        expect(result.containsKey(failed.$3), isFalse);
        expect(result['${failed.$1}_error_code'], '${failed.$1}-export-failed');
        expect(result['error_code'], 'shared-content-partial-export-failure');
        expect(result.containsKey('error'), isFalse);
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      });
    }

    test('the disclosure and provenance sentences are byte-identical on the '
        'success and the partial path', () async {
      final success = await managerFor(
        _ScriptedRepository(rows: allSeeded()),
      ).exportSharedContent('user-uid');
      final partial = await managerFor(
        _ScriptedRepository(
          rows: allSeeded(),
          failing: {'exportSharedMenusReceived'},
        ),
      ).exportSharedContent('user-uid');

      // Both keys are the Art. 12(1) text for what the rows that DID ship
      // had removed; a partial section ships rows, so it owes the same text.
      expect(success['data_minimisation'], isA<String>());
      expect(success['provenance'], isA<String>());
      expect(partial['data_minimisation'], success['data_minimisation']);
      expect(partial['provenance'], success['provenance']);
    });

    test(
      'all three refused is the outright failure with the exact sentence',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: allSeeded(),
            failing: {for (final leg in legs) leg.$4},
          ),
        ).exportSharedContent('user-uid');

        expect(result, {
          'error': 'Shared content could not be exported.',
          'error_code': 'shared-content-export-failed',
        });
      },
    );
  });

  // BUT-1701: these reads rode a repository default with no truncation signal,
  // so a user past the cap received a clipped bundle presented as complete.
  // Each now runs the N+1 probe. The triple is below / at / over, because
  // `>= cap` and `> cap` agree on two of the three and only the middle one
  // tells a complete export from a clipped one.
  group('BUT-1701 cap boundaries', () {
    final cases = [
      (
        name: 'friend categories',
        type: 'friend_categories',
        method: 'exportFriendCategories',
        run: (SocialExportManager m) => m.exportFriends('user-uid'),
        listKey: 'friend_categories',
        idKey: 'category_id',
        totalKey: 'total_categories',
        seed: (int n) => _rows('c', n),
      ),
      (
        name: 'outgoing blocks',
        type: 'outgoing_blocks',
        method: 'exportOutgoingBlocks',
        run: (SocialExportManager m) => m.exportBlocks('user-uid'),
        listKey: 'outgoing_blocks',
        idKey: 'blockedUserId',
        totalKey: null,
        seed: (int n) => [
          for (var i = 0; i < n; i++) {'blockedUserId': 'c$i'},
        ],
      ),
      (
        name: 'reports filed',
        type: 'reports_filed',
        method: 'exportReportsByReporter',
        run: (SocialExportManager m) => m.exportReports('user-uid'),
        listKey: 'reports',
        idKey: 'report_id',
        totalKey: 'total',
        seed: (int n) => _rows('c', n),
      ),
      (
        name: 'pings sent',
        type: 'pings_sent',
        method: 'exportPingsSent',
        run: (SocialExportManager m) => m.exportPings('user-uid'),
        listKey: 'pings',
        idKey: 'ping_id',
        totalKey: 'total',
        seed: (int n) => _rows('c', n),
      ),
    ];

    for (final c in cases) {
      final cap = ExportPaginationHelper.getLimitForType(c.type);

      test(
        '${c.name}: below the cap everything ships and nothing is flagged',
        () async {
          final result = await c.run(
            managerFor(
              _ScriptedRepository(rows: {c.method: c.seed(cap - 1)}),
            ),
          );

          expect(result[c.listKey], hasLength(cap - 1));
          expect(result.containsKey('truncated'), isFalse);
        },
      );

      test(
        '${c.name}: exactly at the cap is complete, not truncated',
        () async {
          final result = await c.run(
            managerFor(_ScriptedRepository(rows: {c.method: c.seed(cap)})),
          );

          expect(result[c.listKey], hasLength(cap));
          expect(result.containsKey('truncated'), isFalse);
          if (c.totalKey != null) expect(result[c.totalKey], cap);
        },
      );

      test('${c.name}: one past the cap is flagged and the probe row is '
          'trimmed', () async {
        final repo = _ScriptedRepository(rows: {c.method: c.seed(cap + 1)});
        final result = await c.run(managerFor(repo));

        final list = (result[c.listKey] as List).cast<Map>();
        expect(result['truncated'], isTrue);
        expect(list, hasLength(cap));
        expect(list.last[c.idKey], 'c${cap - 1}');
        expect(
          jsonEncode(list),
          isNot(contains('"c$cap"')),
          reason: 'the N+1 probe row must not reach the bundle',
        );
        if (c.totalKey != null) expect(result[c.totalKey], cap);
        // Asked for one more than the cap, or the flag could never be set.
        expect(repo.capturedMax[c.method], cap + 1);
      });
    }
  });

  group('exportMessages conversation-count probe (BUT-1701)', () {
    final cap = ExportPaginationHelper.getLimitForType('conversations');

    List<Map<String, dynamic>> conversations(
      int n, {
      Map<String, dynamic>? at0,
    }) => [
      for (var i = 0; i < n; i++)
        {
          'id': 'conv$i',
          'data': {'title': 'Samtal $i'},
          'messages': <Map<String, dynamic>>[],
          if (i == 0) ...?at0,
        },
    ];

    test('a page below the cap never asks for a count', () async {
      final repo = _ScriptedRepository(conversations: conversations(cap - 1));

      final result = await managerFor(repo).exportMessages('user-uid');

      expect(repo.countCalls, 0, reason: 'nobody under the cap pays for it');
      expect(result.containsKey('conversations_truncated'), isFalse);
      expect(result.containsKey('conversation_count_error_code'), isFalse);
      expect(result.containsKey('error_code'), isFalse);
    });

    test('a full page that is the whole set is not flagged', () async {
      final repo = _ScriptedRepository(
        conversations: conversations(cap),
        conversationCount: cap,
      );

      final result = await managerFor(repo).exportMessages('user-uid');

      expect(repo.countCalls, 1);
      expect(result['total_conversations'], cap);
      expect(result.containsKey('conversations_truncated'), isFalse);
      expect(result.containsKey('error_code'), isFalse);
    });

    test('a full page of a larger set is flagged truncated', () async {
      final repo = _ScriptedRepository(
        conversations: conversations(cap),
        conversationCount: cap + 1,
      );

      final result = await managerFor(repo).exportMessages('user-uid');

      expect(result['conversations_truncated'], isTrue);
      expect(result['total_conversations'], cap);
      expect(
        result.containsKey('error_code'),
        isFalse,
        reason: 'clipped is not failed; the flag alone says so',
      );
    });

    test(
      'a count that cannot be read is reported, never read as complete',
      () async {
        final repo = _ScriptedRepository(
          conversations: conversations(cap),
          failCount: true,
        );

        final result = await managerFor(repo).exportMessages('user-uid');

        expect(
          result['conversation_count_error_code'],
          'conversation-count-failed',
        );
        expect(result['error_code'], 'conversation-count-failed');
        expect(result.containsKey('conversations_truncated'), isFalse);
        expect(
          result['conversations'],
          hasLength(cap),
          reason: 'the page already in hand still ships',
        );
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      },
    );

    test(
      'a failed count does not overwrite a failure already reported',
      () async {
        final repo = _ScriptedRepository(
          conversations: conversations(cap, at0: {'error_code': 'read-failed'}),
          failCount: true,
        );

        final result = await managerFor(repo).exportMessages('user-uid');

        expect(result['error_code'], 'conversation-messages-read-failed');
        expect(
          result['conversation_count_error_code'],
          'conversation-count-failed',
        );
      },
    );
  });
}
