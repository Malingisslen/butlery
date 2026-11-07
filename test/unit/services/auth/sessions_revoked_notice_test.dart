import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/auth/sessions_revoked_notice.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  Future<SessionsRevokedNotice> notice([
    Map<String, Object> seed = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(seed);
    return SessionsRevokedNotice(
      prefs: await SharedPreferences.getInstance(),
      now: now,
    );
  }

  test('one check per sign-in, and only after the read succeeded', () async {
    final n = await notice();
    final signIn = now.subtract(const Duration(days: 1));
    expect(n.needsCheck(signIn), isTrue);
    expect(n.needsCheck(signIn), isTrue, reason: 'not marked until it worked');
    await n.markChecked(signIn);
    expect(n.needsCheck(signIn), isFalse);
    expect(n.needsCheck(now), isTrue, reason: 'a new sign-in checks again');
    expect(n.needsCheck(null), isFalse);
  });

  test('nothing to announce without a revoke time', () async {
    expect(await (await notice()).due(null), isNull);
  });

  test('a recent revoke is announced once, then not again', () async {
    final n = await notice();
    final at = now.subtract(const Duration(hours: 2));
    expect(await n.due(at), at);
    expect(await n.due(at), isNull);
  });

  test('a newer revoke is announced after an older one was seen', () async {
    final n = await notice();
    await n.due(now.subtract(const Duration(days: 3)));
    final newer = now.subtract(const Duration(hours: 1));
    expect(await n.due(newer), newer);
  });

  test('a revoke older than thirty days is history, not news', () async {
    final n = await notice();
    expect(await n.due(now.subtract(const Duration(days: 31))), isNull);
  });

  test(
    'the device that pressed the button is not told about its own press',
    () async {
      final n = await notice();
      await n.markPressedHere();
      // The server stamps a moment after the press, and may run a little ahead.
      expect(await n.due(now.add(const Duration(minutes: 1))), isNull);
    },
  );

  test('a later press from another device is still announced here', () async {
    final n = await notice();
    await n.markPressedHere();
    final later = now.add(const Duration(hours: 1));
    expect(await n.due(later), later);
  });
}
