import 'dart:math';

import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String? uid = 'guest-1';

  GuestImportSession session() =>
      GuestImportSession(uid: () => uid, random: Random(1));

  setUp(() {
    uid = 'guest-1';
    SharedPreferences.setMockInitialValues({});
  });

  test('begin makes a fresh 20 character id the server accepts', () {
    final s = session();
    final first = s.begin();
    final second = s.begin();

    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{1,64}$')));
    expect(first, hasLength(20));
    expect(second, isNot(first));
    expect(s.currentId, second);
  });

  test('currentId begins an import when there is none', () {
    final s = session();
    expect(s.currentId, hasLength(20));
    expect(s.currentId, s.currentId);
  });

  test('three imports leave none, and the same import counts once', () async {
    final s = session();
    await s.load();
    expect(s.remaining, 3);

    s.begin();
    await s.recordSuccess();
    await s.recordSuccess();
    expect(s.usedCount, 1);
    expect(s.remaining, 2);

    for (var i = 0; i < 2; i++) {
      s.begin();
      await s.recordSuccess();
    }
    expect(s.remaining, 0);

    s.begin();
    await s.recordSuccess();
    expect(s.usedCount, 4);
    expect(s.remaining, 0, reason: 'floored at zero');
  });

  test('the count survives a new session and belongs to the uid', () async {
    final first = session();
    await first.load();
    first.begin();
    await first.recordSuccess();

    final again = session();
    await again.load();
    expect(again.usedCount, 1);

    uid = 'guest-2';
    expect(again.usedCount, 0, reason: 'another guest has not used any');
    await again.load();
    expect(again.remaining, 3);
  });

  test('the server refusing the import empties what is left', () async {
    final s = session();
    await s.load();
    var hits = 0;
    s.limitHits.addListener(() => hits++);

    await s.recordLimitReached();

    expect(hits, 1);
    expect(s.remaining, 0);
    final again = session();
    await again.load();
    expect(again.remaining, 0);
  });

  test('nothing is recorded without a signed-in user', () async {
    uid = null;
    final s = session();
    s.begin();
    await s.recordSuccess();
    expect(s.usedCount, 0);
    expect(s.remaining, 3);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  group('a session disposed on sign-out while a save is in flight', () {
    test('recording a success finishes quietly', () async {
      final s = session();
      await s.load();
      s.begin();
      final pending = s.recordSuccess();
      s.dispose();

      await expectLater(pending, completes);
    });

    test('recording the server limit finishes quietly', () async {
      final s = session();
      await s.load();
      final pending = s.recordLimitReached();
      s.dispose();

      await expectLater(pending, completes);
    });

    test('a limit reported after disposal changes nothing', () async {
      final s = session();
      await s.load();
      s.dispose();

      await expectLater(s.recordLimitReached(), completes);

      expect(
        (await SharedPreferences.getInstance()).getKeys(),
        isEmpty,
        reason: 'nothing saved for a session that is gone',
      );
    });
  });
}
