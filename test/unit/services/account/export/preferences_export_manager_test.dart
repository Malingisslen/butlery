/// Direct unit tests for [PreferencesExportManager] notification export
/// (BUT-1562).
///
/// Proves the GDPR Article-15/20 notification export honours its size cap
/// honestly: the `truncated` flag (and the accompanying human-readable note)
/// must appear ONLY when the 500-record cap is actually reached, and the
/// computed cap must be forwarded to the repository so the query itself is
/// bounded. Before BUT-1562 the method emitted a static "Limited to last 500"
/// note on every export and never set `truncated`, so a caller could not tell
/// a full 3-notification export from a silently-clipped 5000-notification one.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';

class _FakeDataExportRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakeDataExportRepository(
    this.rows, {
    this.deliveredRows,
    this.historyRows,
    this.batchRows,
    this.engagementRows,
    this.deliverySentRows,
    this.deliveryReceivedRows,
  });
  final List<Map<String, dynamic>> rows;

  // Each of the BUT-1450 sections is seeded independently and stays null when a
  // fixture does not cover it, so calling the WRONG sibling method throws
  // instead of quietly returning another section's rows.
  // BUT-1957. Seeded independently of `rows`, which is the TOP-LEVEL
  // `user_notifications` collection — a different collection one word away.
  // Keeping them separate is what lets a test prove the section reads its own.
  final List<Map<String, dynamic>>? deliveredRows;
  final List<Map<String, dynamic>>? historyRows;
  final List<Map<String, dynamic>>? batchRows;
  final List<Map<String, dynamic>>? engagementRows;
  final List<Map<String, dynamic>>? deliverySentRows;
  final List<Map<String, dynamic>>? deliveryReceivedRows;

  // Sentinel default (NOT the real 500): if production ever stops forwarding
  // `maxDocuments`, capturedMaxDocuments stays -1 and the forwarding test
  // fails instead of coincidentally matching the computed limit.
  int? capturedMaxDocuments;

  /// Per-method captured `maxDocuments`, keyed by repository method name.
  final Map<String, int> capturedMax = <String, int>{};

  List<Map<String, dynamic>> _seeded(
    List<Map<String, dynamic>>? seeded,
    String method,
  ) =>
      seeded ??
      (throw UnimplementedError('$method was not seeded by this fixture'));

  @override
  Future<List<Map<String, dynamic>>> exportUserNotifications(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMaxDocuments = maxDocuments;
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> exportDeliveredNotifications(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportDeliveredNotifications'] = maxDocuments;
    return _seeded(deliveredRows, 'exportDeliveredNotifications');
  }

  @override
  Future<List<Map<String, dynamic>>> exportNotificationHistory(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportNotificationHistory'] = maxDocuments;
    return _seeded(historyRows, 'exportNotificationHistory');
  }

  @override
  Future<List<Map<String, dynamic>>> exportNotificationBatches(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportNotificationBatches'] = maxDocuments;
    return _seeded(batchRows, 'exportNotificationBatches');
  }

  @override
  Future<List<Map<String, dynamic>>> exportNotificationEngagement(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportNotificationEngagement'] = maxDocuments;
    return _seeded(engagementRows, 'exportNotificationEngagement');
  }

  @override
  Future<List<Map<String, dynamic>>> exportNotificationDeliverySent(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportNotificationDeliverySent'] = maxDocuments;
    return _seeded(deliverySentRows, 'exportNotificationDeliverySent');
  }

  @override
  Future<List<Map<String, dynamic>>> exportNotificationDeliveryReceived(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMax['exportNotificationDeliveryReceived'] = maxDocuments;
    return _seeded(deliveryReceivedRows, 'exportNotificationDeliveryReceived');
  }
}

/// BUT-1760: every export read raises [error], so each section's catch block is
/// the only thing that can shape the result. `Fake.noSuchMethod` would raise a
/// bare `UnimplementedError` — useless here, because the defect under test is
/// what happens to an exception whose STRING carries other people's identifiers.
class _ThrowingDataExportRepository extends Fake
    implements FirebaseDataExportRepository {
  _ThrowingDataExportRepository(this.error);
  final Object error;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(error);
}

class _FakeFcmTokenRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakeFcmTokenRepository(this.tokenRows);
  final List<Map<String, dynamic>> tokenRows;

  @override
  Future<List<Map<String, dynamic>>> exportFcmTokensSubcollection(
    String userId, {
    int maxDocuments = 50,
  }) async => tokenRows;
}

Map<String, dynamic> _row(int i) => {
  'id': 'n$i',
  'data': {'type': 'social', 'title': 'Hi', 'body': 'there', 'isRead': false},
};

/// A BUT-1450 analytics record with a stable, per-index title so a trimmed
/// payload can be told apart from a re-ordered one.
Map<String, dynamic> _record(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'userId': 'user-uid', 'title': 'Notis $i'},
};

/// One of the four single-query sections migrated onto
/// [ExportPaginationHelper.fetchCapped] in BUT-1662. They share the same
/// truncation contract, so they share the same three proofs; the fixture seeds
/// only this section's rows, so a method wired to the wrong repository call
/// throws `UnimplementedError` instead of passing on a sibling's data.
class _CappedSection {
  const _CappedSection({
    required this.method,
    required this.type,
    required this.payloadKey,
    required this.idPrefix,
    required this.seed,
    required this.invoke,
  });

  final String method;
  final String type;
  final String payloadKey;
  final String idPrefix;
  final _FakeDataExportRepository Function(List<Map<String, dynamic>> rows)
  seed;
  final Future<Map<String, dynamic>> Function(PreferencesExportManager m)
  invoke;
}

final _cappedSections = <_CappedSection>[
  _CappedSection(
    method: 'exportNotificationHistory',
    type: 'notification_history',
    payloadKey: 'notification_history',
    idPrefix: 'h',
    seed: (rows) => _FakeDataExportRepository(const [], historyRows: rows),
    invoke: (m) => m.exportNotificationHistory('user-uid'),
  ),
  _CappedSection(
    method: 'exportNotificationBatches',
    type: 'notification_batches',
    payloadKey: 'notification_batches',
    idPrefix: 'b',
    seed: (rows) => _FakeDataExportRepository(const [], batchRows: rows),
    invoke: (m) => m.exportNotificationBatches('user-uid'),
  ),
  _CappedSection(
    method: 'exportNotificationEngagement',
    type: 'notification_engagement',
    payloadKey: 'notification_engagement',
    idPrefix: 'e',
    seed: (rows) => _FakeDataExportRepository(const [], engagementRows: rows),
    invoke: (m) => m.exportNotificationEngagement('user-uid'),
  ),
];

Map<String, dynamic> _deliveredRow(int i) => {
  'id': 'd$i',
  'data': {
    'type': 'win_back',
    'message': 'Vi saknar dig $i',
    'bodyShown': 'Vi saknar dig $i',
    'variant': 'b',
    'contextKey': 'ctx',
    'read': false,
  },
};

void main() {
  // BUT-1957: `users/{uid}/notifications`, the SUBCOLLECTION. The account
  // deletion cascade began erasing it in the same change, and Art. 15 must
  // reach anything Art. 17 removes — so this section exists to keep the export
  // a superset of the erasure.
  group('PreferencesExportManager.exportDeliveredNotifications (BUT-1957)', () {
    final cap = ExportPaginationHelper.getLimitForType(
      'delivered_notifications',
    );

    test(
      'routes to the delivered-notifications read, not the top-level one',
      () async {
        // Named for what it measures. It discriminates at the MANAGER seam only —
        // which repository METHOD was called — because the fixture is keyed by
        // method name. Which Firestore COLLECTION that method reads is decided a
        // layer down and is pinned in `data_export_service_test.dart`, over a
        // real repository, where a wrong collection name can actually show.
        //
        // The fixture answers both sources and they disagree: `rows` (the
        // top-level collection) holds a row that must NOT appear, `deliveredRows`
        // the one that must.
        final manager = PreferencesExportManager(
          dataExportRepository: _FakeDataExportRepository(
            [_row(99)],
            deliveredRows: [_deliveredRow(1)],
          ),
        );

        final result = await manager.exportDeliveredNotifications('user-uid');
        final rows = result['notifications'] as List<dynamic>;

        expect(result['total_count'], 1);
        expect((rows.single as Map)['notification_id'], 'd1');
      },
    );

    test('passes every field through, including the push text shown', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          const [],
          deliveredRows: [_deliveredRow(1)],
        ),
      );

      final result = await manager.exportDeliveredNotifications('user-uid');
      final row =
          (result['notifications'] as List<dynamic>).single
              as Map<String, dynamic>;

      // These are the fields that made the collection worth erasing: the text
      // the person actually saw, and their win-back copy assignment.
      expect(row['message'], 'Vi saknar dig 1');
      expect(row['bodyShown'], 'Vi saknar dig 1');
      expect(row['variant'], 'b');
      expect(row['notification_id'], 'd1');
    });

    // The `data_minimisation` sentence is the ONLY thing in the bundle that
    // tells the data subject a third party is in these rows, and it was
    // asserted by nothing — deleting it left the suite green. It is prose in a
    // GDPR artifact, so it gets a test like any other claim.
    test('carries the data-minimisation note about the sharer name', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          const [],
          deliveredRows: [_deliveredRow(1)],
        ),
      );

      final result = await manager.exportDeliveredNotifications('user-uid');

      expect(result['data_minimisation'], isA<String>());
      expect(result['data_minimisation'], contains('delade'));
      expect(result['data_minimisation'], contains('namnet'));
      // `'förnamnet'` contains `'namnet'`, so the assertion above would stay
      // green on a regression to the underclaiming wording this sentence was
      // corrected FROM. A single-token display name is exported whole, so
      // "förnamnet" would be false.
      expect(result['data_minimisation'], isNot(contains('förnamn')));
    });

    test('forwards the cap to the repository query', () async {
      final fake = _FakeDataExportRepository(
        const [],
        deliveredRows: [_deliveredRow(1)],
      );
      final manager = PreferencesExportManager(dataExportRepository: fake);

      await manager.exportDeliveredNotifications('user-uid');

      // cap + 1: the probe fetches one extra row so it can tell "exactly `cap`
      // total" from "more than `cap`, some omitted".
      expect(fake.capturedMax['exportDeliveredNotifications'], cap + 1);
    });

    test('omits the truncated flag below the cap', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          const [],
          deliveredRows: List.generate(3, _deliveredRow),
        ),
      );

      final result = await manager.exportDeliveredNotifications('user-uid');

      expect(result['total_count'], 3);
      expect(result.containsKey('truncated'), isFalse);
      expect(result.containsKey('note'), isFalse);
    });

    test('stamps truncated + note once rows are omitted', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          const [],
          deliveredRows: List.generate(cap + 1, _deliveredRow),
        ),
      );

      final result = await manager.exportDeliveredNotifications('user-uid');

      expect(result['truncated'], isTrue);
      expect(result['note'], contains('$cap'));
    });
  });

  group('PreferencesExportManager.exportNotifications (BUT-1562)', () {
    final cap = ExportPaginationHelper.getLimitForType('user_notifications');

    test('omits truncated flag and note when below the cap', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          List.generate(3, _row),
        ),
      );

      final result = await manager.exportNotifications('user-uid');

      expect(result['total_count'], 3);
      expect(result.containsKey('truncated'), isFalse);
      expect(result.containsKey('note'), isFalse);
    });

    test(
      'omits truncated flag when exactly at the cap (nothing omitted)',
      () async {
        // Boundary: the manager fetches cap+1 so it can tell "exactly `cap`
        // total" from "more than `cap`, some omitted". A repo holding exactly
        // `cap` rows returns `cap` (< cap+1), so a complete export must NOT
        // claim truncation. Guards the off-by-one where `length >= cap` would
        // falsely stamp a full 500-notification GDPR export as truncated.
        final manager = PreferencesExportManager(
          dataExportRepository: _FakeDataExportRepository(
            List.generate(cap, _row),
          ),
        );

        final result = await manager.exportNotifications('user-uid');

        expect(result['total_count'], cap);
        expect(result.containsKey('truncated'), isFalse);
        expect(result.containsKey('note'), isFalse);
      },
    );

    test('sets truncated flag and note when more than the cap exist', () async {
      // Repo holds more than `cap`: the cap+1 probe returns cap+1 rows, so the
      // export declares itself truncated and trims to exactly `cap` records.
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeDataExportRepository(
          List.generate(cap + 1, _row),
        ),
      );

      final result = await manager.exportNotifications('user-uid');

      expect(result['total_count'], cap);
      expect(result['truncated'], isTrue);
      expect(result['note'], contains('$cap'));
    });

    test(
      'forwards cap + 1 to the repository query (N+1 truncation probe)',
      () async {
        final repo = _FakeDataExportRepository(const []);
        final manager = PreferencesExportManager(dataExportRepository: repo);

        await manager.exportNotifications('user-uid');

        expect(repo.capturedMaxDocuments, cap + 1);
      },
    );
  });

  group('PreferencesExportManager.exportFcmTokens redaction', () {
    // The security invariant of this manager: a GDPR export must never leak the
    // raw FCM push credential. exportFcmTokens must reduce any 'token' field to
    // a short prefix followed by '...[redacted]', so the full credential never
    // reaches the user's data bundle.
    const fullToken =
        'fMNq9RtCkX_abcdefghijklmnopqrstuvwxyz0123456789-LIVEFCMTOKEN';

    test(
      'redacts a real token to prefix + marker, dropping the credential',
      () async {
        final manager = PreferencesExportManager(
          dataExportRepository: _FakeFcmTokenRepository([
            {'token': fullToken, 'platform': 'android'},
          ]),
        );

        final result = await manager.exportFcmTokens('user-uid');
        final tokens = result['tokens'] as List;
        final exported = (tokens.single as Map)['token'] as String;

        // Redacted shape: exactly the 10-char prefix + the marker.
        expect(exported, endsWith('...[redacted]'));
        expect(
          exported,
          '${fullToken.substring(0, 10)}...[redacted]',
        );
        // The invariant: the raw credential must not survive anywhere in output.
        expect(exported.contains(fullToken), isFalse);
        expect(result.toString().contains(fullToken), isFalse);
        // Non-token metadata is preserved for portability.
        expect((tokens.single as Map)['platform'], 'android');
      },
    );

    test('redacts a short (<10 char) token without a RangeError', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeFcmTokenRepository([
          {'token': 'abc'},
        ]),
      );

      final result = await manager.exportFcmTokens('user-uid');
      final exported =
          ((result['tokens'] as List).single as Map)['token'] as String;

      // clamp(0, len) keeps substring in range: whole short string + marker.
      expect(exported, 'abc...[redacted]');
    });

    test('leaves a row untouched when it carries no token field', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _FakeFcmTokenRepository([
          {'platform': 'ios', 'createdAt': 'unknown'},
        ]),
      );

      final result = await manager.exportFcmTokens('user-uid');
      final row = (result['tokens'] as List).single as Map;

      expect(row.containsKey('token'), isFalse);
      expect(row['platform'], 'ios');
    });
  });

  // BUT-1662: the four BUT-1450 notification-analytics sections moved onto
  // ExportPaginationHelper.fetchCapped. Before the move they derived
  // `truncated` from `rows.length >= limit`, which stamps a COMPLETE export as
  // truncated whenever the user happens to hold exactly `limit` records — a
  // false incompleteness claim on an Article 15 data-portability bundle.
  for (final section in _cappedSections) {
    group('PreferencesExportManager.${section.method} (BUT-1662)', () {
      final cap = ExportPaginationHelper.getLimitForType(section.type);

      test(
        'omits truncated when exactly at the cap (nothing was left out)',
        () async {
          final manager = PreferencesExportManager(
            dataExportRepository: section.seed(
              List.generate(cap, (i) => _record(section.idPrefix, i)),
            ),
          );

          final result = await section.invoke(manager);

          expect(result.containsKey('error'), isFalse);
          expect((result[section.payloadKey] as List).length, cap);
          expect(result['total_count'], cap);
          expect(
            result.containsKey('truncated'),
            isFalse,
            reason:
                'the bundle holds every record the user has, so it must not '
                'declare itself clipped',
          );
        },
      );

      test(
        'flags truncated and trims the payload to exactly the cap',
        () async {
          // Source holds cap + 1: the N+1 probe returns cap + 1 rows, so the
          // section declares truncation AND ships only the first `cap`.
          final manager = PreferencesExportManager(
            dataExportRepository: section.seed(
              List.generate(cap + 1, (i) => _record(section.idPrefix, i)),
            ),
          );

          final result = await section.invoke(manager);

          final records = (result[section.payloadKey] as List)
              .cast<Map<String, dynamic>>();
          expect(result['truncated'], isTrue);
          expect(records.length, cap);
          // The probe row itself must not reach the bundle...
          expect(
            records.map((r) => r['id']),
            isNot(contains('${section.idPrefix}$cap')),
          );
          // ...and the records that DID ship carry their payload verbatim.
          expect((records.first['data'] as Map)['title'], 'Notis 0');
        },
      );

      test(
        'total_count counts the included records, not the N+1 probe fetch',
        () async {
          // A CappedExport.length regression (counting the pre-trim fetch) would
          // ship `cap` records while claiming cap + 1 — a bundle whose own
          // manifest disagrees with its contents.
          final manager = PreferencesExportManager(
            dataExportRepository: section.seed(
              List.generate(cap + 1, (i) => _record(section.idPrefix, i)),
            ),
          );

          final result = await section.invoke(manager);

          expect(
            result['total_count'],
            (result[section.payloadKey] as List).length,
          );
          expect(result['total_count'], isNot(cap + 1));
        },
      );
    });
  }

  group('PreferencesExportManager.exportNotificationDelivery (BUT-1662)', () {
    // Two independent legs (sender + target) that each carry the cap, so the
    // section is truncated when EITHER leg clipped. An N-leg OR needs a
    // positive test per leg, or a collapse to one leg ships silently.
    final cap = ExportPaginationHelper.getLimitForType('notification_delivery');

    PreferencesExportManager managerWith({
      required int sent,
      required int received,
    }) => PreferencesExportManager(
      dataExportRepository: _FakeDataExportRepository(
        const [],
        deliverySentRows: List.generate(sent, (i) => _record('s', i)),
        deliveryReceivedRows: List.generate(received, (i) => _record('r', i)),
      ),
    );

    test('omits truncated when both legs sit exactly at the cap', () async {
      final result = await managerWith(
        sent: cap,
        received: cap,
      ).exportNotificationDelivery('user-uid');

      expect(result.containsKey('error'), isFalse);
      expect(result['sent_count'], cap);
      expect(result['received_count'], cap);
      expect(result['total_count'], cap * 2);
      expect(result.containsKey('truncated'), isFalse);
    });

    test('flags truncated when only the SENT leg is over the cap', () async {
      final result = await managerWith(
        sent: cap + 1,
        received: 3,
      ).exportNotificationDelivery('user-uid');

      final records = (result['notification_delivery'] as List)
          .cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(result['sent_count'], cap, reason: 'the sent leg is trimmed');
      expect(result['received_count'], 3);
      expect(records.length, cap + 3);
      expect(result['total_count'], records.length);
      expect(records.map((r) => r['id']), isNot(contains('s$cap')));
    });

    test(
      'flags truncated when only the RECEIVED leg is over the cap',
      () async {
        final result = await managerWith(
          sent: 3,
          received: cap + 1,
        ).exportNotificationDelivery('user-uid');

        final records = (result['notification_delivery'] as List)
            .cast<Map<String, dynamic>>();
        expect(result['truncated'], isTrue);
        expect(
          result['received_count'],
          cap,
          reason: 'the received leg is trimmed',
        );
        expect(result['sent_count'], 3);
        expect(records.length, cap + 3);
        expect(result['total_count'], records.length);
        expect(records.map((r) => r['id']), isNot(contains('r$cap')));
      },
    );

    test(
      'omits truncated when the two legs COMBINED exceed the cap but neither leg does',
      () async {
        // The regression this section exists to prevent: comparing the MERGED
        // length against a single cap. Each leg carries the cap independently, so
        // a user with 666 sent + 666 received notifications has a complete export
        // even though 1332 > 1000 records ship.
        final perLeg = (cap * 2) ~/ 3;
        expect(perLeg <= cap, isTrue, reason: 'premise: neither leg clips');
        expect(
          perLeg * 2 > cap,
          isTrue,
          reason: 'premise: the merge exceeds cap',
        );

        final result = await managerWith(
          sent: perLeg,
          received: perLeg,
        ).exportNotificationDelivery('user-uid');

        expect(result['total_count'], perLeg * 2);
        expect(
          result.containsKey('truncated'),
          isFalse,
          reason:
              'both legs returned every record they had; the export is complete',
        );
      },
    );

    test(
      'de-dupes a self-targeted record while the leg counts stay per-leg',
      () async {
        // A notification the user sent to themselves matches BOTH queries. It
        // must be exported once, so total_count is below sent + received — the
        // manifest describes the bundle, the leg counts describe the queries.
        final manager = PreferencesExportManager(
          dataExportRepository: _FakeDataExportRepository(
            const [],
            deliverySentRows: [_record('s', 0), _record('s', 1)],
            deliveryReceivedRows: [_record('s', 1), _record('r', 0)],
          ),
        );

        final result = await manager.exportNotificationDelivery('user-uid');

        final ids = (result['notification_delivery'] as List)
            .cast<Map<String, dynamic>>()
            .map((r) => r['id'])
            .toList();
        expect(ids, ['s0', 's1', 'r0']);
        expect(result['total_count'], 3);
        expect(result['sent_count'], 2);
        expect(result['received_count'], 2);
        expect(result.containsKey('truncated'), isFalse);
      },
    );
  });

  group('BUT-1662 rewired sections forward the N+1 probe size', () {
    // The cap only bounds the Firestore query if it actually reaches the
    // repository. The fake defaults `maxDocuments` to a sentinel -1 no real
    // caller would pass, so a dropped forward fails here instead of
    // coincidentally matching the real default.
    test('each section asks its repository for its own cap + 1', () async {
      final repo = _FakeDataExportRepository(
        const [],
        historyRows: const [],
        batchRows: const [],
        engagementRows: const [],
        deliverySentRows: const [],
        deliveryReceivedRows: const [],
      );
      final manager = PreferencesExportManager(dataExportRepository: repo);

      await manager.exportNotificationHistory('user-uid');
      await manager.exportNotificationBatches('user-uid');
      await manager.exportNotificationEngagement('user-uid');
      await manager.exportNotificationDelivery('user-uid');

      int capOf(String type) => ExportPaginationHelper.getLimitForType(type);
      expect(repo.capturedMax, {
        'exportNotificationHistory': capOf('notification_history') + 1,
        'exportNotificationBatches': capOf('notification_batches') + 1,
        'exportNotificationEngagement': capOf('notification_engagement') + 1,
        'exportNotificationDeliverySent': capOf('notification_delivery') + 1,
        'exportNotificationDeliveryReceived':
            capOf('notification_delivery') + 1,
      });
    });
  });

  /// BUT-1760: all nine sections used to fail with `{'error': e.toString()}`.
  ///
  /// Two defects in one line. The raw string lands in an Article-15 artifact
  /// the data subject downloads and may forward to a supervisory authority,
  /// and a Firestore refusal string routinely names ANOTHER person's uid (a
  /// notification counterparty ends up in composite doc ids), an internal
  /// document path, or a `create_composite` URL embedding field paths and the
  /// project id. And with no `error_code`, the section could only be named at
  /// bundle level by `DataExportService`'s derived fallback — the manager
  /// itself said nothing about WHICH read failed.
  group('PreferencesExportManager failure envelopes (BUT-1760)', () {
    // A realistic refusal, not a bare Exception: the message is the payload
    // under test. `uid-bob` is a second data subject, so its presence anywhere
    // in the returned map is the leak itself.
    final leaky = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message:
          'Missing or insufficient permissions: '
          'users/uid-alice/notification_delivery/uid-alice_uid-bob',
    );

    // (section phrase used in the authored sentence, error_code, call).
    final cases =
        <
          (
            String,
            String,
            Future<Map<String, dynamic>> Function(PreferencesExportManager),
          )
        >[
          (
            'preferences',
            'preferences-export-failed',
            (m) => m.exportPreferences('alice'),
          ),
          (
            'notifications',
            'notifications-export-failed',
            (m) => m.exportNotifications('alice'),
          ),
          // BUT-1957. In the TABLE rather than in a test of its own: a
          // standalone `completion(isA<Map>())` was satisfied by a mutant that
          // returned the raw exception string, which is the BUT-1760 leak this
          // table exists to deny.
          (
            'delivered notifications',
            'delivered-notifications-export-failed',
            (m) => m.exportDeliveredNotifications('alice'),
          ),
          (
            'notification preferences',
            'notification-preferences-export-failed',
            (m) => m.exportNotificationPreferences('alice'),
          ),
          (
            'FCM tokens',
            'fcm-tokens-export-failed',
            (m) => m.exportFcmTokens('alice'),
          ),
          (
            'category preferences',
            'category-preferences-export-failed',
            (m) => m.exportCategoryPreferences('alice'),
          ),
          (
            'notification history',
            'notification-history-export-failed',
            (m) => m.exportNotificationHistory('alice'),
          ),
          (
            'notification batches',
            'notification-batches-export-failed',
            (m) => m.exportNotificationBatches('alice'),
          ),
          (
            'notification engagement',
            'notification-engagement-export-failed',
            (m) => m.exportNotificationEngagement('alice'),
          ),
          (
            'notification delivery',
            'notification-delivery-export-failed',
            (m) => m.exportNotificationDelivery('alice'),
          ),
        ];

    for (final (section, code, call) in cases) {
      test('$section returns an authored sentence + $code, never the raw '
          'exception', () async {
        final result = await call(
          PreferencesExportManager(
            dataExportRepository: _ThrowingDataExportRepository(leaky),
          ),
        );

        expect(
          result['error'],
          'Could not export $section.',
          reason: 'an authored sentence, not e.toString()',
        );
        expect(
          result['error_code'],
          code,
          reason:
              'the token DataExportService names the failing section by in '
              'export_metadata.warnings',
        );
        // The whole map, not just `error`: a leak anywhere in the section is
        // still a leak in the bundle.
        final encoded = jsonEncode(result);
        expect(
          encoded,
          isNot(contains('uid-bob')),
          reason: "another data subject's uid must never reach the bundle",
        );
        expect(
          encoded,
          isNot(contains('users/uid-alice/notification_delivery')),
          reason: 'internal document paths must never reach the bundle',
        );
        expect(encoded, isNot(contains('permission-denied')));
      });
    }

    // The two sections that also carry a human-readable `note` must keep it —
    // replacing the envelope must not silently drop the sentence the data
    // subject actually reads.
    test('the notification sections keep their explanatory note', () async {
      final manager = PreferencesExportManager(
        dataExportRepository: _ThrowingDataExportRepository(leaky),
      );

      expect(
        (await manager.exportNotifications('alice'))['note'],
        'Notifications may not be available',
      );
      expect(
        (await manager.exportNotificationPreferences('alice'))['note'],
        'Notification preferences may not be available',
      );
    });

    test('every section carries its OWN token', () {
      final codes = cases.map((c) => c.$2).toList();
      expect(
        codes.toSet(),
        hasLength(codes.length),
        reason:
            'a shared token would make the bundle-level warning unable to say '
            'which read failed — the reason the codes are authored at all',
      );
    });
  });
}
