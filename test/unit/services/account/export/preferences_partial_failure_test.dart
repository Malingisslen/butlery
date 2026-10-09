/// Per-read isolation and cap truncation for the multi-read sections of
/// [PreferencesExportManager] (BUT-2008, BUT-1701): notification preferences,
/// category preferences and notification delivery.
///
/// Each test refuses ONE read and asserts what the data subject still receives
/// and what the bundle says about the read that failed. A key derived from a
/// read that did not complete must be ABSENT, not false or zero: both would
/// state a fact about the user that the lookup never answered.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';

const _foreignUid = 'uid-of-another-person-9f2e45';

class _ScriptedRepository extends Fake implements FirebaseDataExportRepository {
  _ScriptedRepository({
    this.rows = const {},
    this.failing = const {},
    this.preferencesDoc,
    this.tokens = const [],
  });

  final Map<String, List<Map<String, dynamic>>> rows;
  final Set<String> failing;
  final Map<String, dynamic>? preferencesDoc;
  final List<Map<String, dynamic>> tokens;

  final Map<String, int> capturedMax = <String, int>{};

  void _maybeRefuse(String method) {
    if (failing.contains(method)) {
      // Carries another person's uid so a leak into the bundle is visible.
      throw StateError('permission-denied reading $method/$_foreignUid');
    }
  }

  List<Map<String, dynamic>> _serve(String method, int maxDocuments) {
    capturedMax[method] = maxDocuments;
    _maybeRefuse(method);
    final all = rows[method] ?? const <Map<String, dynamic>>[];
    return all.length > maxDocuments ? all.sublist(0, maxDocuments) : all;
  }

  @override
  Future<Map<String, dynamic>?> exportNotificationPreferences(
    String userId,
  ) async {
    _maybeRefuse('exportNotificationPreferences');
    return preferencesDoc;
  }

  @override
  Future<List<Map<String, dynamic>>> exportFcmTokensForUser(
    String userId, {
    int maxDocuments = -1,
  }) async {
    _maybeRefuse('exportFcmTokensForUser');
    return tokens;
  }

  @override
  Future<List<Map<String, dynamic>>> exportCategoryPreferences(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportCategoryPreferences', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportListCategoryOrders(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportListCategoryOrders', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportNotificationDeliverySent(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportNotificationDeliverySent', maxDocuments);

  @override
  Future<List<Map<String, dynamic>>> exportNotificationDeliveryReceived(
    String userId, {
    int maxDocuments = -1,
  }) async => _serve('exportNotificationDeliveryReceived', maxDocuments);
}

Map<String, dynamic> _row(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'n': i},
};

List<Map<String, dynamic>> _rows(String prefix, int n) => [
  for (var i = 0; i < n; i++) _row(prefix, i),
];

void main() {
  PreferencesExportManager managerFor(_ScriptedRepository repo) =>
      PreferencesExportManager(dataExportRepository: repo);

  group('exportNotificationPreferences read isolation (BUT-2008)', () {
    final registered = [
      {'lastUpdated': Timestamp.fromDate(DateTime.utc(2026, 3, 4, 5, 6, 7))},
    ];

    test(
      'both reads succeeding leaves no error key and the FCM note',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            preferencesDoc: {'pushEnabled': true},
            tokens: registered,
          ),
        ).exportNotificationPreferences('user-uid');

        expect(result['preferences'], {'pushEnabled': true});
        expect(result['preferences_exist'], isTrue);
        expect(result['fcm_token_registered'], isTrue);
        expect(result['fcm_token_updated_at'], isNotNull);
        expect(
          result['note'],
          'FCM token is not included for security reasons',
        );
        expect(result.keys.where((k) => k.contains('error')), isEmpty);
      },
    );

    test(
      'a user with no preferences document is an answer, not a failure',
      () async {
        final result = await managerFor(
          _ScriptedRepository(tokens: registered),
        ).exportNotificationPreferences('user-uid');

        // Present-and-false is the true negative that a failed lookup must NOT
        // be allowed to look like; see the refused-read test below.
        expect(result.containsKey('preferences'), isTrue);
        expect(result['preferences'], isNull);
        expect(result['preferences_exist'], isFalse);
        expect(result.containsKey('error_code'), isFalse);
      },
    );

    test('a refused preferences read keeps the token answer and omits what it '
        'would have said', () async {
      final result = await managerFor(
        _ScriptedRepository(
          failing: {'exportNotificationPreferences'},
          tokens: registered,
        ),
      ).exportNotificationPreferences('user-uid');

      expect(result['fcm_token_registered'], isTrue);
      expect(result.containsKey('preferences'), isFalse);
      expect(
        result.containsKey('preferences_exist'),
        isFalse,
        reason: '`preferences_exist: false` would claim the user has none',
      );
      expect(result['preferences_error_code'], 'preferences-export-failed');
      expect(
        result['error_code'],
        'notification-preferences-partial-export-failure',
      );
      expect(result.containsKey('error'), isFalse);
      expect(result['note'], 'FCM token is not included for security reasons');
      expect(jsonEncode(result), isNot(contains(_foreignUid)));
    });

    test('a refused token read keeps the preferences and omits the token '
        'answers', () async {
      final result = await managerFor(
        _ScriptedRepository(
          failing: {'exportFcmTokensForUser'},
          preferencesDoc: {'pushEnabled': true},
        ),
      ).exportNotificationPreferences('user-uid');

      expect(result['preferences'], {'pushEnabled': true});
      expect(result['preferences_exist'], isTrue);
      expect(
        result.containsKey('fcm_token_registered'),
        isFalse,
        reason: '`fcm_token_registered: false` would claim no device',
      );
      expect(result.containsKey('fcm_token_updated_at'), isFalse);
      expect(result['fcm_tokens_error_code'], 'fcm_tokens-export-failed');
      expect(
        result['error_code'],
        'notification-preferences-partial-export-failure',
      );
      expect(result.containsKey('error'), isFalse);
      expect(jsonEncode(result), isNot(contains(_foreignUid)));
    });

    test('both reads refused is the outright failure and says the section '
        'may be unavailable', () async {
      final result = await managerFor(
        _ScriptedRepository(
          failing: {'exportNotificationPreferences', 'exportFcmTokensForUser'},
          preferencesDoc: {'pushEnabled': true},
          tokens: registered,
        ),
      ).exportNotificationPreferences('user-uid');

      expect(result['error'], 'Could not export notification preferences.');
      expect(result['error_code'], 'notification-preferences-export-failed');
      expect(result['note'], 'Notification preferences may not be available');
      for (final key in const [
        'preferences',
        'preferences_exist',
        'fcm_token_registered',
        'fcm_token_updated_at',
      ]) {
        expect(result.containsKey(key), isFalse, reason: key);
      }
      expect(jsonEncode(result), isNot(contains(_foreignUid)));
    });
  });

  group('exportCategoryPreferences read isolation (BUT-2008)', () {
    Map<String, List<Map<String, dynamic>>> seeded() => {
      'exportCategoryPreferences': _rows('p', 2),
      'exportListCategoryOrders': _rows('o', 2),
    };

    test('no refusal ships both lists and no error key', () async {
      final result = await managerFor(
        _ScriptedRepository(rows: seeded()),
      ).exportCategoryPreferences('user-uid');

      expect((result['category_preferences'] as List), hasLength(2));
      expect((result['list_category_orders'] as List), hasLength(2));
      expect(result.keys.where((k) => k.contains('error')), isEmpty);
    });

    test(
      'a refused category_preferences read keeps list_category_orders',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: seeded(),
            failing: {'exportCategoryPreferences'},
          ),
        ).exportCategoryPreferences('user-uid');

        expect((result['list_category_orders'] as List), hasLength(2));
        expect(
          result.containsKey('category_preferences'),
          isFalse,
          reason: 'an empty list would say the user has set no preferences',
        );
        expect(
          result['category_preferences_error_code'],
          'category_preferences-export-failed',
        );
        expect(
          result['error_code'],
          'category-preferences-partial-export-failure',
        );
        expect(result.containsKey('error'), isFalse);
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      },
    );

    test(
      'a refused list_category_orders read keeps category_preferences',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: seeded(),
            failing: {'exportListCategoryOrders'},
          ),
        ).exportCategoryPreferences('user-uid');

        expect((result['category_preferences'] as List), hasLength(2));
        expect(result.containsKey('list_category_orders'), isFalse);
        expect(
          result['list_category_orders_error_code'],
          'list_category_orders-export-failed',
        );
        expect(
          result['error_code'],
          'category-preferences-partial-export-failure',
        );
        expect(result.containsKey('error'), isFalse);
      },
    );

    test(
      'both refused is the outright failure with the exact sentence',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: seeded(),
            failing: {'exportCategoryPreferences', 'exportListCategoryOrders'},
          ),
        ).exportCategoryPreferences('user-uid');

        expect(result['error'], 'Could not export category preferences.');
        expect(result['error_code'], 'category-preferences-export-failed');
        expect(result.containsKey('category_preferences'), isFalse);
        expect(result.containsKey('list_category_orders'), isFalse);
      },
    );

    test(
      'a clipped leg still stamps truncated when the other is refused',
      () async {
        final cap = ExportPaginationHelper.getLimitForType(
          'category_preferences',
        );
        final result = await managerFor(
          _ScriptedRepository(
            rows: {'exportCategoryPreferences': _rows('p', cap + 1)},
            failing: {'exportListCategoryOrders'},
          ),
        ).exportCategoryPreferences('user-uid');

        expect(result['truncated'], isTrue);
        expect(
          result['error_code'],
          'category-preferences-partial-export-failure',
        );
      },
    );
  });

  // BUT-1701. Below / at / over the cap per leg: `>= cap` and `> cap` agree on
  // two of the three, and only the middle one separates a complete export from
  // a clipped one.
  group('category preferences cap boundaries (BUT-1701)', () {
    final legs = [
      (key: 'category_preferences', method: 'exportCategoryPreferences'),
      (key: 'list_category_orders', method: 'exportListCategoryOrders'),
    ];

    for (final leg in legs) {
      final cap = ExportPaginationHelper.getLimitForType(leg.key);

      test(
        '${leg.key}: below the cap everything ships and nothing is flagged',
        () async {
          final result = await managerFor(
            _ScriptedRepository(rows: {leg.method: _rows('c', cap - 1)}),
          ).exportCategoryPreferences('user-uid');

          expect(result[leg.key], hasLength(cap - 1));
          expect(result.containsKey('truncated'), isFalse);
        },
      );

      test(
        '${leg.key}: exactly at the cap is complete, not truncated',
        () async {
          final result = await managerFor(
            _ScriptedRepository(rows: {leg.method: _rows('c', cap)}),
          ).exportCategoryPreferences('user-uid');

          expect(result[leg.key], hasLength(cap));
          expect(result.containsKey('truncated'), isFalse);
        },
      );

      test('${leg.key}: one past the cap is flagged and the probe row is '
          'trimmed', () async {
        final repo = _ScriptedRepository(
          rows: {leg.method: _rows('c', cap + 1)},
        );
        final result = await managerFor(
          repo,
        ).exportCategoryPreferences('user-uid');

        expect(result['truncated'], isTrue);
        expect(result[leg.key], hasLength(cap));
        expect(jsonEncode(result[leg.key]), isNot(contains('"c$cap"')));
        expect(repo.capturedMax[leg.method], cap + 1);
      });
    }
  });

  group('exportNotificationDelivery read isolation (BUT-2008)', () {
    Map<String, List<Map<String, dynamic>>> seeded() => {
      'exportNotificationDeliverySent': _rows('s', 2),
      'exportNotificationDeliveryReceived': _rows('r', 3),
    };

    test('no refusal ships the union and both counts', () async {
      final result = await managerFor(
        _ScriptedRepository(rows: seeded()),
      ).exportNotificationDelivery('user-uid');

      expect(result['total_count'], 5);
      expect(result['sent_count'], 2);
      expect(result['received_count'], 3);
      expect(result.keys.where((k) => k.contains('error')), isEmpty);
    });

    test('a refused sent leg keeps the received rows and derives no sent '
        'count', () async {
      final result = await managerFor(
        _ScriptedRepository(
          rows: seeded(),
          failing: {'exportNotificationDeliverySent'},
        ),
      ).exportNotificationDelivery('user-uid');

      final ids = (result['notification_delivery'] as List).map(
        (e) => (e as Map)['id'],
      );
      expect(ids, ['r0', 'r1', 'r2']);
      expect(result['total_count'], 3);
      expect(result['received_count'], 3);
      expect(
        result.containsKey('sent_count'),
        isFalse,
        reason: '`sent_count: 0` would claim the user sent nothing',
      );
      expect(
        result['notification_delivery_sent_error_code'],
        'notification_delivery_sent-export-failed',
      );
      expect(
        result['error_code'],
        'notification-delivery-partial-export-failure',
      );
      expect(result.containsKey('error'), isFalse);
      expect(jsonEncode(result), isNot(contains(_foreignUid)));
    });

    test('a refused received leg keeps the sent rows and derives no received '
        'count', () async {
      final result = await managerFor(
        _ScriptedRepository(
          rows: seeded(),
          failing: {'exportNotificationDeliveryReceived'},
        ),
      ).exportNotificationDelivery('user-uid');

      final ids = (result['notification_delivery'] as List).map(
        (e) => (e as Map)['id'],
      );
      expect(ids, ['s0', 's1']);
      expect(result['total_count'], 2);
      expect(result['sent_count'], 2);
      expect(result.containsKey('received_count'), isFalse);
      expect(
        result['notification_delivery_received_error_code'],
        'notification_delivery_received-export-failed',
      );
      expect(
        result['error_code'],
        'notification-delivery-partial-export-failure',
      );
      expect(result.containsKey('error'), isFalse);
    });

    test(
      'a clipped leg still stamps truncated when the other is refused',
      () async {
        final cap = ExportPaginationHelper.getLimitForType(
          'notification_delivery',
        );
        final result = await managerFor(
          _ScriptedRepository(
            rows: {'exportNotificationDeliverySent': _rows('s', cap + 1)},
            failing: {'exportNotificationDeliveryReceived'},
          ),
        ).exportNotificationDelivery('user-uid');

        expect(result['truncated'], isTrue);
        expect(result['sent_count'], cap);
      },
    );

    test(
      'both refused is the outright failure with the exact sentence',
      () async {
        final result = await managerFor(
          _ScriptedRepository(
            rows: seeded(),
            failing: {
              'exportNotificationDeliverySent',
              'exportNotificationDeliveryReceived',
            },
          ),
        ).exportNotificationDelivery('user-uid');

        expect(result['error'], 'Could not export notification delivery.');
        expect(result['error_code'], 'notification-delivery-export-failed');
        for (final key in const [
          'notification_delivery',
          'total_count',
          'sent_count',
          'received_count',
        ]) {
          expect(result.containsKey(key), isFalse, reason: key);
        }
        expect(jsonEncode(result), isNot(contains(_foreignUid)));
      },
    );
  });
}
