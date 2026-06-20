/// Tests for ParseEventsRepository — the import-health drill-down source. It
/// must filter parse events by domain, sort newest-first, optionally keep only
/// failures, and degrade to empty on error. A bug here would show the wrong
/// domain's attempts or the wrong order behind a tapped row.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/parse_events_repository.dart';

import '../../test_support/base_unit_test.dart';

Future<void> _seed(
  FakeFirebaseFirestore db,
  String id,
  String domain,
  bool success,
  DateTime when,
) async {
  await db.collection('parse_events').doc(id).set({
    'domain': domain,
    'success': success,
    'timestamp': Timestamp.fromDate(when),
    'url': 'https://$domain/recipe/$id',
  });
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('returns only the domain, newest first', () async {
    final db = FakeFirebaseFirestore();
    await _seed(db, 'a', 'koket.se', false, DateTime.utc(2026, 6, 1));
    await _seed(db, 'b', 'koket.se', true, DateTime.utc(2026, 6, 3));
    await _seed(db, 'c', 'ica.se', false, DateTime.utc(2026, 6, 2));

    final page =
        await ParseEventsRepository(firestore: db).getByDomain('koket.se');

    expect(page.events.length, 2);
    // Timestamp.toDate() is local — compare the instant.
    expect(
        page.events.first.timestamp!.isAtSameMomentAs(DateTime.utc(2026, 6, 3)),
        isTrue); // newest first
    expect(page.events.every((e) => e.domain == 'koket.se'), isTrue);
    expect(page.truncated, isFalse);
  });

  test('failuresOnly keeps just the failed attempts', () async {
    final db = FakeFirebaseFirestore();
    await _seed(db, 'a', 'koket.se', false, DateTime.utc(2026, 6, 1));
    await _seed(db, 'b', 'koket.se', true, DateTime.utc(2026, 6, 3));

    final page = await ParseEventsRepository(firestore: db)
        .getByDomain('koket.se', failuresOnly: true);

    expect(page.events.length, 1);
    expect(page.events.single.success, isFalse);
  });

  test('no events for the domain yields an empty page', () async {
    final db = FakeFirebaseFirestore();
    await _seed(db, 'a', 'ica.se', false, DateTime.utc(2026, 6, 1));

    final page =
        await ParseEventsRepository(firestore: db).getByDomain('koket.se');
    expect(page.events, isEmpty);
    expect(page.truncated, isFalse);
  });
}
