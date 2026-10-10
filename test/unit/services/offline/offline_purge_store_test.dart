// BUT-2298: a uid whose offline purge is owed survives a failed or deferred
// clear and is finished at the next start.

import 'package:butlery/services/offline/offline_purge_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/base_unit_test.dart';

void main() {
  late OfflinePurgeStore store;

  setUpAll(() async => BaseUnitTest.setupUnit());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = OfflinePurgeStore();
  });

  test('record, pending and forget round-trip', () async {
    expect(await store.pending(), isEmpty);

    await store.record('u1');
    await store.record('u2');
    expect(await store.pending(), {'u1', 'u2'});

    await store.forget('u1');
    expect(await store.pending(), {'u2'});

    await store.forget('u2');
    expect(await store.pending(), isEmpty);
  });

  test('purgeOwed clears each owed uid and forgets it', () async {
    await store.record('u1');
    await store.record('u2');
    final cleared = <String>[];

    await store.purgeOwed((uid) async => cleared.add(uid));

    expect(cleared, unorderedEquals(['u1', 'u2']));
    expect(await store.pending(), isEmpty);
  });

  test('a clear that throws keeps the uid owed, others still finish', () async {
    await store.record('bad');
    await store.record('good');

    await store.purgeOwed((uid) async {
      if (uid == 'bad') throw StateError('disk full');
    });

    expect(await store.pending(), {'bad'});
  });

  test('the signed-in uid is not cleared, only forgotten', () async {
    await store.record('me');
    await store.record('other');
    final cleared = <String>[];

    await store.purgeOwed(
      (uid) async => cleared.add(uid),
      signedInUserId: 'me',
    );

    expect(cleared, ['other']);
    expect(await store.pending(), isEmpty);
  });
}
