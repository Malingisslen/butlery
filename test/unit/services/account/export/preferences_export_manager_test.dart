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

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';

class _FakeDataExportRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakeDataExportRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  // Sentinel default (NOT the real 500): if production ever stops forwarding
  // `maxDocuments`, capturedMaxDocuments stays -1 and the forwarding test
  // fails instead of coincidentally matching the computed limit.
  int? capturedMaxDocuments;

  @override
  Future<List<Map<String, dynamic>>> exportUserNotifications(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMaxDocuments = maxDocuments;
    return rows;
  }
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

void main() {
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
}
