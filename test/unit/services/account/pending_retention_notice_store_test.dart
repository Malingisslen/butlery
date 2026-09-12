import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/account/pending_retention_notice_store.dart';

/// The Art. 12(4) notice held on the device when the one-shot dialog was
/// missed. Every case here is about the notice reaching, or correctly failing
/// to reach, the person it is owed to.
void main() {
  const key = 'pending_retention_notice';
  late PendingRetentionNoticeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PendingRetentionNoticeStore();
  });

  group('write then read', () {
    test('returns the record it was given', () async {
      final holdUntil = DateTime.utc(2027, 3, 11);
      await store.write(holdUntil: holdUntil, provisional: true);

      final notice = await store.read();

      expect(notice, isNotNull);
      expect(notice!.holdUntil, holdUntil);
      expect(notice.provisional, isTrue);
    });

    test('carries no identifier — the stored keys are exactly three', () async {
      // The minimisation decision, pinned rather than described: no uid, no
      // email, no name, no resourceType, no legalBasis. This is what makes
      // plaintext storage of a legal notice defensible, so a fourth key is a
      // decision somebody has to make deliberately, not a line to slip in.
      await store.write(holdUntil: DateTime.utc(2027), provisional: false);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;

      expect(
        stored.keys.toSet(),
        {'holdUntil', 'provisional', 'writtenAt'},
      );
    });

    test('a missing hold date survives the round trip as null', () async {
      // The server sent no parsable date, so the notice says less rather than
      // naming a date nobody measured.
      await store.write(holdUntil: null, provisional: false);

      final notice = await store.read();

      expect(notice, isNotNull);
      expect(notice!.holdUntil, isNull);
    });
  });

  group('nothing to show', () {
    test('an empty store reads as absent', () async {
      expect(await store.read(), isNull);
    });

    test('clear removes the record', () async {
      await store.write(holdUntil: DateTime.utc(2027), provisional: false);
      await store.clear();

      expect(await store.read(), isNull);
    });
  });

  group('expiry', () {
    test('reads as absent once the hold date has passed', () async {
      // Past the hold there is nothing left to tell anyone about.
      final holdUntil = DateTime.utc(2026, 9, 12);
      await store.write(
        holdUntil: holdUntil,
        provisional: false,
        now: DateTime.utc(2026, 9, 1),
      );

      expect(await store.read(now: holdUntil), isNull);
      expect(
        await store.read(now: holdUntil.add(const Duration(days: 1))),
        isNull,
      );
    });

    test('is still shown the moment before the hold lifts', () async {
      final holdUntil = DateTime.utc(2026, 9, 12);
      await store.write(
        holdUntil: holdUntil,
        provisional: false,
        now: DateTime.utc(2026, 9, 1),
      );

      final notice = await store.read(
        now: holdUntil.subtract(const Duration(seconds: 1)),
      );

      expect(notice, isNotNull);
    });

    test('without a date it falls back to 30 days, not forever', () async {
      // Otherwise somebody who never taps Close meets it on every launch for
      // the life of the install.
      final writtenAt = DateTime.utc(2026, 9, 12);
      await store.write(holdUntil: null, provisional: false, now: writtenAt);

      expect(
        await store.read(
          now: writtenAt
              .add(PendingRetentionNoticeStore.fallbackLifetime)
              .subtract(const Duration(seconds: 1)),
        ),
        isNotNull,
      );
      expect(
        await store.read(
          now: writtenAt.add(PendingRetentionNoticeStore.fallbackLifetime),
        ),
        isNull,
      );
    });
  });

  group('unreadable content', () {
    test('malformed JSON reads as absent rather than throwing', () async {
      // The only consumer is a gate on the sign-in screen, and a throw there
      // costs the screen rather than buying anything.
      SharedPreferences.setMockInitialValues({key: 'not json at all'});

      expect(await store.read(), isNull);
    });

    test('a record missing writtenAt reads as absent', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({'holdUntil': null, 'provisional': false}),
      });

      expect(await store.read(), isNull);
    });

    test('an unparsable date reads as absent', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'holdUntil': 'the twelfth of never',
          'provisional': false,
          'writtenAt': DateTime.utc(2026, 9, 12).toIso8601String(),
        }),
      });

      expect(await store.read(), isNull);
    });

    test('a missing provisional flag reads as false, not as absent', () async {
      // An older write, or a partial one. The flag only hedges the wording, so
      // losing it must not cost the whole notice.
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'holdUntil': DateTime.utc(2027).toIso8601String(),
          'writtenAt': DateTime.utc(2026, 9, 12).toIso8601String(),
        }),
      });

      final notice = await store.read(now: DateTime.utc(2026, 9, 13));

      expect(notice, isNotNull);
      expect(notice!.provisional, isFalse);
    });
  });

  test('a second deletion overwrites the first, unread notice', () async {
    // The named residual (DPO, 2026-09-12): the store is a single slot, and it
    // has no key because a key would reintroduce an identifier for somebody we
    // just erased. Pinned so the behaviour is a decision on the record rather
    // than a surprise — if this ever becomes unacceptable, the fix is a design
    // change, not a bug fix.
    await store.write(holdUntil: DateTime.utc(2027, 1), provisional: false);
    await store.write(holdUntil: DateTime.utc(2027, 6), provisional: true);

    final notice = await store.read();

    expect(notice!.holdUntil, DateTime.utc(2027, 6));
    expect(notice.provisional, isTrue);
  });
}
