import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/errors/message_send_error_mapper.dart';

/// BUT-1903. The rule refuses a `sentAt` more than an hour ahead of the server,
/// and `Message` stamps the device clock — so a phone with a wrong clock is
/// refused on every send. Firestore returns ONE opaque `permission-denied` for
/// every conjunct on that rule (the clock bound, the rate limiter, the
/// account-maturity gate, the age gate, membership), so the clock message has
/// to be earned rather than guessed. These cases pin what earns it.
void main() {
  final t0 = DateTime.utc(2026, 8, 19, 12);

  FirebaseException denied() =>
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

  Future<MessageSendFailure> classifyAt(
    DateTime now,
    Object error,
    Future<DateTime?> Function() reader,
  ) {
    return withClock(
      Clock.fixed(now),
      () => MessageSendErrorMapper.classify(error, readServerIssuedAt: reader),
    );
  }

  group('MessageSendErrorMapper.classify', () {
    test(
      'blames the clock only when the lead exceeds the rule\'s own bound',
      () async {
        // Two hours ahead of a token Google stamped moments ago.
        final result = await classifyAt(
          t0.add(const Duration(hours: 2)),
          denied(),
          () async => t0,
        );
        expect(result, MessageSendFailure.clockAhead);
      },
    );

    test('a device inside the bound gets the generic message', () async {
      // Ten minutes ahead: ALLOWED by the rule, so this denial came from the
      // rate limiter or the maturity gate. Blaming the clock here would be the
      // wrong answer for every brand-new user, which is the whole reason this
      // threshold is the rule's bound and not something smaller.
      final result = await classifyAt(
        t0.add(const Duration(minutes: 10)),
        denied(),
        () async => t0,
      );
      expect(result, MessageSendFailure.other);
    });

    test('exactly at the bound is not blamed on the clock', () async {
      // The comparison is strictly greater-than, matching `<=` in the rule: a
      // device exactly on the bound is still allowed to write.
      final result = await classifyAt(
        t0.add(MessageSendErrorMapper.maxSentAtLead),
        denied(),
        () async => t0,
      );
      expect(result, MessageSendFailure.other);
    });

    test('the threshold is the rule\'s own hour, not something smaller', () {
      // Pinned as a VALUE, because nothing else in this file does. Every other
      // case derives its fixture from the constant, so the suite self-adjusts
      // and stays green at any bound between ten minutes and two hours — the
      // testing gate measured a drift to 30 minutes passing 8/8. The failure
      // that drift produces is the one the design forbids: a brand-new user 40
      // minutes ahead, still inside the 60-minute account-maturity window,
      // told to fix a clock that is fine.
      //
      // Mirrors `duration.value(1, 'h')` on the messages create rule in
      // `firestore.rules`. The two are synced BY HAND; this is the Dart half of
      // that contract, and the rules half is pinned by M15/M16 there.
      expect(MessageSendErrorMapper.maxSentAtLead, const Duration(hours: 1));
    });

    test('a minute past the bound is already the clock', () async {
      // The straddle's outer half. Without it, a coarsened comparison —
      // `lead.inHours > maxSentAtLead.inHours`, which `Duration` invites —
      // passes every other case while silently returning a device 61 to 119
      // minutes ahead to the generic message. That band is the commonest real
      // skew shape, and it is exactly the population this branch exists for.
      final result = await classifyAt(
        t0.add(
          MessageSendErrorMapper.maxSentAtLead + const Duration(minutes: 1),
        ),
        denied(),
        () async => t0,
      );
      expect(result, MessageSendFailure.clockAhead);
    });

    test('a non-permission error never reaches the probe', () async {
      var probeCalls = 0;
      final result = await classifyAt(
        t0.add(const Duration(hours: 2)),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        () async {
          probeCalls++;
          return t0;
        },
      );
      expect(result, MessageSendFailure.other);
      // Not incidental: an offline send must not cost a forced token refresh.
      expect(probeCalls, 0);
    });

    test('a plain exception is not a permission denial', () async {
      var probeCalls = 0;
      final result = await classifyAt(
        t0.add(const Duration(hours: 2)),
        StateError('boom'),
        () async {
          probeCalls++;
          return t0;
        },
      );
      expect(result, MessageSendFailure.other);
      // The counter is what gives this case a kill of its own. The type half of
      // the guard cannot be deleted — that would not compile — so only a
      // restructure breaks it, and a restructure that let arbitrary exceptions
      // through to the probe would cost a forced token refresh on every
      // ordinary failure.
      expect(probeCalls, 0);
    });

    test('a probe that throws degrades to the generic message', () async {
      // The diagnosis must never become a second failure.
      final result = await classifyAt(
        t0.add(const Duration(hours: 2)),
        denied(),
        () async => throw Exception('token refresh failed'),
      );
      expect(result, MessageSendFailure.other);
    });

    test(
      'a null issuedAtTime is an absence of evidence, not evidence',
      () async {
        // `IdTokenResult.issuedAtTime` is `DateTime?`. Reading a null as "the
        // clock is fine" is correct; reading it as a clock verdict would accuse
        // a user on the strength of a missing field.
        final result = await classifyAt(
          t0.add(const Duration(hours: 2)),
          denied(),
          () async => null,
        );
        expect(result, MessageSendFailure.other);
      },
    );

    test('a device running BEHIND is never blamed', () async {
      // The rule has no lower bound, so a slow clock cannot be the cause.
      final result = await classifyAt(
        t0.subtract(const Duration(hours: 5)),
        denied(),
        () async => t0,
      );
      expect(result, MessageSendFailure.other);
    });
  });
}
