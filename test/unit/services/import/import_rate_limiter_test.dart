/// Unit tests for `ImportRateLimiter` — pins the contract of:
///
/// - Per-minute / per-hour / per-day basic import limits (inclusive boundary).
/// - LLM-type quotas (enhancement/extraction/vision share day-window; they
///   reset together).
/// - Daily and monthly USD cost ceilings, read from the server-written ledger
///   `rate_limits/llm_cost` (BUT-2243).
/// - Fail-closed behaviour when Firestore throws.
/// - Anonymous (unauthenticated) callers are allowed but not tracked.
/// - Time-window reset semantics — counters drop to 1 at exactly windowSize
///   elapsed, persist below it.
/// - Cache invalidation after `recordUsage`, and a cache keyed to the user.
/// - Cold start: a fresh user with no persisted state allows the full quota.
/// - `getUsageStats` returns persisted state; `isLlmAvailable` reflects daily
///   LLM cap.
///
/// Time control is via `package:clock` `withClock(...)`, so we can land on
/// the 59.999s / 60.000s boundary precisely. Firestore is FakeFirebaseFirestore
/// because `runTransaction` works there for plain set/get without
/// `FieldValue.increment` or `serverTimestamp`.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _uid = 'user-rate-limit-1';

// A reference instant we anchor every test on, so windows are computed
// against a stable clock.
// Local time — FakeFirebaseFirestore round-trips DateTime via Timestamp and
// returns local-zone DateTime on read, so anchoring in local time keeps
// equality checks straightforward (production also uses `clock.now()` which
// is local).
final _t0 = DateTime(2026, 5, 24, 12, 0, 0);

// The cost ceilings are UTC calendar windows, so their tests run on a UTC
// clock and seed the ledger with literal keys for this instant. 18:00 UTC on
// 24 May: six hours to the day's reset, seven days and six hours to June's.
final _tUtc = DateTime.utc(2026, 5, 24, 18);
const _today = '2026-05-24';
const _thisMonth = '2026-05';

/// Build a [UsageLimits] doc into Firestore at /users/{uid}/rate_limits/imports.
Future<void> _seedUsage(
  FakeFirebaseFirestore firestore,
  String uid,
  UsageLimits usage,
) async {
  await firestore
      .collection('users')
      .doc(uid)
      .collection('rate_limits')
      .doc('imports')
      .set(usage.toFirestore());
}

/// Write the server's AI cost ledger at /users/{uid}/rate_limits/llm_cost, the
/// shape `functions/src/middleware/llm_cost_ledger.ts` writes.
Future<void> _seedLedger(
  FirebaseFirestore firestore,
  String uid, {
  required double costToday,
  required String dayKey,
  required double costThisMonth,
  required String monthKey,
}) async {
  await firestore
      .collection('users')
      .doc(uid)
      .collection('rate_limits')
      .doc('llm_cost')
      .set({
        'costToday': costToday,
        'dayKey': dayKey,
        'costThisMonth': costThisMonth,
        'monthKey': monthKey,
      });
}

/// Read back the persisted usage doc (or empty if absent).
Future<UsageLimits> _readUsage(
  FakeFirebaseFirestore firestore,
  String uid,
) async {
  final snap = await firestore
      .collection('users')
      .doc(uid)
      .collection('rate_limits')
      .doc('imports')
      .get();
  if (!snap.exists) return UsageLimits.empty();
  return UsageLimits.fromFirestore(snap.data()!);
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('ImportRateLimiter', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreRepository firestoreRepo;
    late FakeAuthRepository auth;
    late ImportRateLimiter limiter;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      firestoreRepo = FirestoreRepository(firestore: firestore);
      auth = FakeAuthRepository();
      auth.setAuthState(userId: _uid);
      limiter = ImportRateLimiter(
        firestoreRepository: firestoreRepo,
        authRepository: auth,
      );
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    group('authentication gating', () {
      /// An anonymous caller is permissively allowed (we don't gate the import
      /// pipeline on auth) but the limiter must NOT touch Firestore at all —
      /// that would leak a write under a missing user id.
      test('checkLimit returns generous allow for unauthenticated user without '
          'reading Firestore', () async {
        auth.setAuthState(userId: null);

        await withClock(Clock.fixed(_t0), () async {
          final result = await limiter.checkLimit(ImportOperation.basic('url'));

          expect(result, isA<RateLimitAllowed>());
          final allowed = result as RateLimitAllowed;
          expect(allowed.remainingInWindow, 999);
        });

        // Doc must not exist — anonymous reads/writes are off.
        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('rate_limits')
            .doc('imports')
            .get();
        expect(snap.exists, isFalse);
      });

      /// `recordUsage` is a no-op when there's no signed-in user — otherwise
      /// we'd write to /users/null/... or worse, blow up.
      test('recordUsage is a no-op when unauthenticated', () async {
        auth.setAuthState(userId: null);

        await withClock(Clock.fixed(_t0), () async {
          await limiter.recordUsage(ImportOperation.basic('url'));
        });

        // No /users/* doc should exist at all.
        final users = await firestore.collection('users').get();
        expect(users.docs, isEmpty);
      });

      /// `getUsageStats` must be safe to call before auth too — returns empty.
      test('getUsageStats returns empty when unauthenticated', () async {
        auth.setAuthState(userId: null);

        final stats = await limiter.getUsageStats();

        expect(stats.importsThisMinute, 0);
        expect(stats.importsToday, 0);
      });
    });

    group('cold start (no persisted state)', () {
      /// A brand-new user must not be rate-limited on the first call. The
      /// remaining counter is the synthetic 999 because no window is open yet.
      test(
        'first checkLimit allows and reports the synthetic 999 remaining',
        () async {
          await withClock(Clock.fixed(_t0), () async {
            final result = await limiter.checkLimit(
              ImportOperation.basic('url'),
            );

            expect(result, isA<RateLimitAllowed>());
            expect((result as RateLimitAllowed).remainingInWindow, 999);
            expect(result.limitType, LimitType.perMinute);
          });
        },
      );

      /// recordUsage on a virgin doc must write count=1 with windows anchored
      /// at now (not null), so subsequent checks operate against a real window.
      test(
        'first recordUsage seeds count=1 and anchors all windows to now',
        () async {
          await withClock(Clock.fixed(_t0), () async {
            await limiter.recordUsage(ImportOperation.basic('url'));
          });

          final usage = await _readUsage(firestore, _uid);
          expect(usage.importsThisMinute, 1);
          expect(usage.importsThisHour, 1);
          expect(usage.importsToday, 1);
          expect(usage.minuteWindowStart, _t0);
          expect(usage.hourWindowStart, _t0);
          expect(usage.dayWindowStart, _t0);
        },
      );
    });

    group('per-minute boundary (limit = 10)', () {
      /// "10 imports per minute" means the 10th call is allowed but the 11th
      /// is denied while the window is open. This is the off-by-one the
      /// limiter's contract has to nail.
      test(
        '10th call in window is allowed; 11th in same window is denied',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsThisMinute: 9,
              minuteWindowStart: _t0,
              importsThisHour: 9,
              hourWindowStart: _t0,
              importsToday: 9,
              dayWindowStart: _t0,
            ),
          );

          // 10th call: 9 < 10 → still allowed.
          final allow = await withClock(
            Clock.fixed(_t0.add(const Duration(seconds: 5))),
            () => limiter.checkLimit(ImportOperation.basic('url')),
          );
          expect(
            allow,
            isA<RateLimitAllowed>(),
            reason: '10th import in the minute window must be allowed',
          );

          // Bump the persisted state to count=10 (simulating record after 10th).
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsThisMinute: 10,
              minuteWindowStart: _t0,
              importsThisHour: 10,
              hourWindowStart: _t0,
              importsToday: 10,
              dayWindowStart: _t0,
            ),
          );

          // 11th call: 10 >= 10 → denied. Use a fresh limiter so the 30s
          // in-memory cache (which holds count=9) doesn't shadow the new state.
          final freshLimiter = ImportRateLimiter(
            firestoreRepository: firestoreRepo,
            authRepository: auth,
          );
          final deny = await withClock(
            Clock.fixed(_t0.add(const Duration(seconds: 10))),
            () => freshLimiter.checkLimit(ImportOperation.basic('url')),
          );
          expect(
            deny,
            isA<RateLimitDenied>(),
            reason: '11th import in the same minute must be denied',
          );
          final denied = deny as RateLimitDenied;
          expect(denied.limitType, LimitType.perMinute);
          expect(denied.suggestedAction, FallbackAction.retryLater);
        },
      );

      /// At exactly 59.999s, the minute window is still open and a maxed-out
      /// counter denies. At exactly 60.000s (== windowSize), `_isInWindow`
      /// returns false and the limiter must allow again.
      test(
        'window expires at exactly 60s — denied at 59.999s, allowed at 60.000s',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsThisMinute: 10,
              minuteWindowStart: _t0,
            ),
          );

          // Just inside the window — still denied.
          final inside = await withClock(
            Clock.fixed(_t0.add(const Duration(milliseconds: 59999))),
            () => limiter.checkLimit(ImportOperation.basic('url')),
          );
          expect(
            inside,
            isA<RateLimitDenied>(),
            reason: 'limiter must hold the cap up to but not including 60s',
          );

          // Cache will be 30s old at this point but we never recordUsage'd, so
          // it's still valid. Create a fresh limiter to bypass the in-memory
          // cache and re-fetch — the contract under test is the window math,
          // not the cache.
          final freshLimiter = ImportRateLimiter(
            firestoreRepository: firestoreRepo,
            authRepository: auth,
          );

          // Exactly at the boundary — `<` makes this OUT of the window.
          final atBoundary = await withClock(
            Clock.fixed(_t0.add(const Duration(seconds: 60))),
            () => freshLimiter.checkLimit(ImportOperation.basic('url')),
          );
          expect(
            atBoundary,
            isA<RateLimitAllowed>(),
            reason:
                'at exactly windowSize elapsed, the window has reset (strict <)',
          );
        },
      );

      /// After the minute window expires, a recordUsage must reset minute
      /// counter to 1 while preserving the hour/day counters that haven't
      /// rolled over yet.
      test(
        'recordUsage after minute expiry resets minute=1, keeps hour/day',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsThisMinute: 10,
              minuteWindowStart: _t0,
              importsThisHour: 10,
              hourWindowStart: _t0,
              importsToday: 10,
              dayWindowStart: _t0,
            ),
          );

          // 2 minutes later — minute window has rolled, hour and day haven't.
          final later = _t0.add(const Duration(minutes: 2));
          await withClock(Clock.fixed(later), () async {
            await limiter.recordUsage(ImportOperation.basic('url'));
          });

          final after = await _readUsage(firestore, _uid);
          expect(after.importsThisMinute, 1);
          expect(after.minuteWindowStart, later);
          expect(
            after.importsThisHour,
            11,
            reason: 'hour window still open → counter increments to 11',
          );
          expect(
            after.hourWindowStart,
            _t0,
            reason:
                'hour window anchor must NOT shift while the window is open',
          );
          expect(after.importsToday, 11);
          expect(after.dayWindowStart, _t0);
        },
      );
    });

    group('per-hour and per-day limits (independent of minute)', () {
      /// Hour cap is 30. Even if the minute window has rolled, the hour cap
      /// must still deny when reached. Catches a real bug if anyone splits
      /// these checks and forgets the hour gate.
      test(
        'hour limit denies even when minute counter is well under cap',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsThisMinute: 1,
              minuteWindowStart: _t0.add(const Duration(minutes: 50)),
              importsThisHour: 30,
              hourWindowStart: _t0,
            ),
          );

          final result = await withClock(
            Clock.fixed(_t0.add(const Duration(minutes: 50))),
            () => limiter.checkLimit(ImportOperation.basic('url')),
          );

          expect(result, isA<RateLimitDenied>());
          expect((result as RateLimitDenied).limitType, LimitType.perHour);
          // retryAfter should be the time remaining in the hour window.
          expect(result.retryAfter, const Duration(minutes: 10));
        },
      );

      /// Day cap is 100. Day denial uses limitType.perDay.
      test(
        'day limit denies with limitType.perDay and correct retryAfter',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              importsToday: 100,
              dayWindowStart: _t0,
            ),
          );

          final result = await withClock(
            Clock.fixed(_t0.add(const Duration(hours: 6))),
            () => limiter.checkLimit(ImportOperation.basic('url')),
          );

          expect(result, isA<RateLimitDenied>());
          final denied = result as RateLimitDenied;
          expect(denied.limitType, LimitType.perDay);
          expect(denied.retryAfter, const Duration(hours: 18));
        },
      );

      /// Remaining-in-window must report the MOST RESTRICTIVE window's slack,
      /// not the minute slack. If only 2 are left in the day, that's the
      /// number the UI should show — not 9 (the minute remainder).
      test('remainingInWindow reports the most restrictive window', () async {
        // Minute used 1/10 (9 left), hour used 5/30 (25 left), day used 98/100
        // (2 left). The right answer for the user is 2.
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            importsThisMinute: 1,
            minuteWindowStart: _t0,
            importsThisHour: 5,
            hourWindowStart: _t0,
            importsToday: 98,
            dayWindowStart: _t0,
          ),
        );

        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(seconds: 1))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );

        expect(result, isA<RateLimitAllowed>());
        expect(
          (result as RateLimitAllowed).remainingInWindow,
          2,
          reason: 'must be min(9, 25, 2) = 2',
        );
      });
    });

    group('LLM operation quotas', () {
      /// Enhancement + ingredientLines share the `llmEnhancementsToday`
      /// counter. After 20 (the limit), an `enhancement` op is denied.
      test('enhancement and ingredientLines share daily quota; 20th allowed, '
          '21st denied', () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmEnhancementsToday: 20,
            dayWindowStart: _t0,
          ),
        );

        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.checkLimit(
            ImportOperation.withLlm('url', LlmOperationType.enhancement),
          ),
        );

        expect(result, isA<RateLimitDenied>());
        final denied = result as RateLimitDenied;
        expect(denied.limitType, LimitType.llmDaily);
        expect(
          denied.suggestedAction,
          FallbackAction.skipLlm,
          reason: 'UI should be told it can fall back to rule-based',
        );
      });

      /// fullExtraction has its own counter (cap 10) and must not be denied
      /// just because enhancements are maxed out. Catches a real bug if a
      /// refactor accidentally collapses the two counters.
      test(
        'fullExtraction is unaffected when enhancement counter is maxed',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              llmEnhancementsToday: 20, // maxed
              llmExtractionsToday: 5, // not maxed
              dayWindowStart: _t0,
            ),
          );

          final result = await withClock(
            Clock.fixed(_t0.add(const Duration(hours: 1))),
            () => limiter.checkLimit(
              ImportOperation.withLlm('url', LlmOperationType.fullExtraction),
            ),
          );

          expect(
            result,
            isA<RateLimitAllowed>(),
            reason: 'fullExtraction counter independent of enhancement counter',
          );
        },
      );

      /// A basic (non-LLM) import must skip LLM checks entirely. If the LLM
      /// quota is exhausted, basic imports must still be allowed.
      test('basic import is not denied by exhausted LLM quotas', () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmEnhancementsToday: 20,
            llmExtractionsToday: 10,
            llmVisionToday: 10,
            dayWindowStart: _tUtc,
          ),
        );
        await _seedLedger(
          firestore,
          _uid,
          costToday: 100.0, // way over the $0.50 ceiling
          dayKey: _today,
          costThisMonth: 100.0,
          monthKey: _thisMonth,
        );

        final result = await withClock(
          Clock.fixed(_tUtc.add(const Duration(hours: 1))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );

        expect(
          result,
          isA<RateLimitAllowed>(),
          reason: 'basic imports must not be gated on LLM quotas',
        );
      });

      /// `_checkLlmLimits` switches on `operation.llmType`. When `null`, no
      /// per-type branch fires — but cost checks still run. Verify a
      /// `requiresLlm` operation with a `null` llmType still runs cost gating.
      /// (This guards against the `case null: break;` swallowing the cost branch.)
      test('LLM op with null type still enforces daily cost cap', () async {
        await _seedUsage(firestore, _uid, UsageLimits(dayWindowStart: _tUtc));
        await _seedLedger(
          firestore,
          _uid,
          costToday: 0.50,
          dayKey: _today,
          costThisMonth: 0.50,
          monthKey: _thisMonth,
        );

        const op = ImportOperation(
          requiresLlm: true,
          llmType: null,
          sourceType: 'url',
        );

        final result = await withClock(
          Clock.fixed(_tUtc),
          () => limiter.checkLimit(op),
        );

        expect(result, isA<RateLimitDenied>());
        expect((result as RateLimitDenied).limitType, LimitType.costDaily);
      });
    });

    // BUT-2243: the ceilings compare the server's ledger
    // with the same `>=` and in the same order as the server's
    // `checkCostCeiling`, and add no estimate for the call about to be made.
    group('cost ceilings from the server ledger', () {
      const extraction = ImportOperation(
        requiresLlm: true,
        llmType: LlmOperationType.fullExtraction,
        sourceType: 'url',
        estimatedCost: 0.03,
      );

      Future<RateLimitResult> checkAt(DateTime now) =>
          withClock(Clock.fixed(now), () => limiter.checkLimit(extraction));

      test(
        'today at exactly the daily ceiling denies until UTC midnight',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.50,
            dayKey: _today,
            costThisMonth: 0.50,
            monthKey: _thisMonth,
          );

          final result = await checkAt(_tUtc);

          expect(result, isA<RateLimitDenied>());
          final denied = result as RateLimitDenied;
          expect(denied.limitType, LimitType.costDaily);
          expect(denied.retryAfter, const Duration(hours: 6));
          expect(denied.suggestedAction, FallbackAction.skipLlm);
        },
      );

      // 0.4999 + the call's own 0.03 estimate is over the ceiling; the server
      // lets this call through, so the app must too.
      test(
        'just below the daily ceiling allows, with no estimate added',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.4999,
            dayKey: _today,
            costThisMonth: 0.4999,
            monthKey: _thisMonth,
          );

          expect(await checkAt(_tUtc), isA<RateLimitAllowed>());
        },
      );

      test(
        'the month at exactly its ceiling denies until the next UTC month',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.10,
            dayKey: _today,
            costThisMonth: 10.0,
            monthKey: _thisMonth,
          );

          final result = await checkAt(_tUtc);

          expect(result, isA<RateLimitDenied>());
          final denied = result as RateLimitDenied;
          expect(denied.limitType, LimitType.costMonthly);
          expect(denied.retryAfter, const Duration(days: 7, hours: 6));
          expect(denied.suggestedAction, FallbackAction.skipLlm);
        },
      );

      test(
        'just below the monthly ceiling allows, with no estimate added',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.10,
            dayKey: _today,
            costThisMonth: 9.9999,
            monthKey: _thisMonth,
          );

          expect(await checkAt(_tUtc), isA<RateLimitAllowed>());
        },
      );

      // Both ceilings reached: the server answers `llm_cost_month`, so the app
      // must say "next month", not "tomorrow".
      test('the month is checked before the day', () async {
        await _seedLedger(
          firestore,
          _uid,
          costToday: 0.50,
          dayKey: _today,
          costThisMonth: 10.0,
          monthKey: _thisMonth,
        );

        final result = await checkAt(_tUtc);

        expect((result as RateLimitDenied).limitType, LimitType.costMonthly);
      });

      // The server writes the ledger after a call and nothing rewrites it at
      // midnight, so yesterday's spend sits there under yesterday's key.
      test('a ledger whose day key is yesterday does not deny today', () async {
        await _seedLedger(
          firestore,
          _uid,
          costToday: 5.0,
          dayKey: '2026-05-23',
          costThisMonth: 5.0,
          monthKey: _thisMonth,
        );

        expect(await checkAt(_tUtc), isA<RateLimitAllowed>());
      });

      test(
        'a ledger whose month key is last month does not deny this month',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.10,
            dayKey: _today,
            costThisMonth: 50.0,
            monthKey: '2026-04',
          );

          expect(await checkAt(_tUtc), isA<RateLimitAllowed>());
        },
      );

      // A 30-second cache
      // like the one on the import counters would let a user keep calling
      // after the server has already refused.
      test('the ledger is re-read on every check, not cached', () async {
        await _seedLedger(
          firestore,
          _uid,
          costToday: 0.10,
          dayKey: _today,
          costThisMonth: 0.10,
          monthKey: _thisMonth,
        );
        expect(await checkAt(_tUtc), isA<RateLimitAllowed>());

        await _seedLedger(
          firestore,
          _uid,
          costToday: 0.50,
          dayKey: _today,
          costThisMonth: 0.50,
          monthKey: _thisMonth,
        );
        final result = await checkAt(_tUtc.add(const Duration(seconds: 5)));

        expect(result, isA<RateLimitDenied>());
        expect((result as RateLimitDenied).limitType, LimitType.costDaily);
      });

      test('an unreadable ledger fails closed', () async {
        final repo = _LedgerFailingRepository();
        final failingLimiter = ImportRateLimiter(
          firestoreRepository: repo,
          authRepository: auth,
        );
        // Positive control, and it fills the import-counter cache, so the
        // next check's only Firestore access is the ledger read.
        expect(
          await withClock(
            Clock.fixed(_tUtc),
            () => failingLimiter.checkLimit(extraction),
          ),
          isA<RateLimitAllowed>(),
        );

        repo.failFromNow = true;
        final result = await withClock(
          Clock.fixed(_tUtc.add(const Duration(seconds: 5))),
          () => failingLimiter.checkLimit(extraction),
        );

        expect(result, isA<RateLimitDenied>());
        final denied = result as RateLimitDenied;
        expect(denied.retryAfter, const Duration(seconds: 30));
        expect(denied.suggestedAction, FallbackAction.retryLater);
      });
    });

    group('recordUsage counter math', () {
      /// Recording an LLM op increments the type-specific counter only.
      test(
        'records LLM enhancement op into the enhancement counter only',
        () async {
          const op = ImportOperation(
            requiresLlm: true,
            llmType: LlmOperationType.enhancement,
            sourceType: 'url',
            estimatedCost: 0.01,
          );

          await withClock(Clock.fixed(_t0), () async {
            await limiter.recordUsage(op);
          });

          final after = await _readUsage(firestore, _uid);
          expect(after.llmEnhancementsToday, 1);
          expect(after.llmExtractionsToday, 0);
          expect(after.llmVisionToday, 0);
          expect(
            after.importsThisMinute,
            0,
            reason:
                'a model call made during an import is not a second '
                'import (BUT-2239)',
          );
        },
      );

      /// vision and fullExtraction must increment their OWN counters, not
      /// the enhancement one. This guards the switch in `_updateUsage`.
      test('records vision op into vision counter only', () async {
        await withClock(Clock.fixed(_t0), () async {
          await limiter.recordUsage(
            ImportOperation.withLlm('photo', LlmOperationType.vision),
          );
        });

        final after = await _readUsage(firestore, _uid);
        expect(after.llmVisionToday, 1);
        expect(after.llmEnhancementsToday, 0);
        expect(after.llmExtractionsToday, 0);
      });

      /// After a day-window roll, ALL daily LLM counters reset together —
      /// they share `dayWindowStart`.
      test(
        'day rollover resets all LLM-per-day counters',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              llmEnhancementsToday: 20,
              llmExtractionsToday: 10,
              llmVisionToday: 10,
              dayWindowStart: _t0,
            ),
          );

          // 25 hours later — day expired (>=24h).
          final later = _t0.add(const Duration(hours: 25));
          await withClock(Clock.fixed(later), () async {
            await limiter.recordUsage(
              ImportOperation.withLlm('url', LlmOperationType.enhancement),
            );
          });

          final after = await _readUsage(firestore, _uid);
          expect(after.dayWindowStart, later);
          expect(
            after.llmEnhancementsToday,
            1,
            reason: 'reset to 0 then incremented',
          );
          expect(after.llmExtractionsToday, 0);
          expect(after.llmVisionToday, 0);
        },
      );

      /// recordUsage of a basic op must NOT bump any LLM counters. This
      /// guards against an `if (operation.requiresLlm)` flip in `_updateUsage`.
      test(
        'basic op recordUsage leaves LLM counters untouched',
        () async {
          await _seedUsage(
            firestore,
            _uid,
            UsageLimits(
              llmEnhancementsToday: 3,
              dayWindowStart: _t0,
            ),
          );

          await withClock(
            Clock.fixed(_t0.add(const Duration(minutes: 1))),
            () async {
              await limiter.recordUsage(ImportOperation.basic('url'));
            },
          );

          final after = await _readUsage(firestore, _uid);
          expect(
            after.llmEnhancementsToday,
            3,
            reason: 'basic op must not touch enhancement counter',
          );
          expect(after.importsToday, 1);
        },
      );

      // BUT-2243 A1: the rules now admit only `UsageLimits.toFirestore()`'s
      // keys on this doc, so a write that carried an old cost key along would
      // be refused and the user's import counters would stop moving. Runs on
      // a fake that honours `SetOptions(merge: true)` inside a transaction —
      // the stock fake drops it, and a merge would then look like a whole-doc
      // write here.
      test('recordUsage over a doc holding the old cost keys writes the whole '
          'doc and drops them', () async {
        final mergeAware = _MergeHonouringFirestore();
        final docRef = mergeAware
            .collection('users')
            .doc(_uid)
            .collection('rate_limits')
            .doc('imports');
        await docRef.set({
          ...UsageLimits(importsToday: 4, dayWindowStart: _t0).toFirestore(),
          'llmCostToday': 0.42,
          'llmCostThisMonth': 3.0,
          'llmOperationsThisMonth': 9,
          'monthWindowStart': Timestamp.fromDate(_t0),
        });
        final mergeLimiter = ImportRateLimiter(
          firestoreRepository: FirestoreRepository(firestore: mergeAware),
          authRepository: auth,
        );

        await withClock(
          Clock.fixed(_t0.add(const Duration(minutes: 1))),
          () => mergeLimiter.recordUsage(ImportOperation.basic('url')),
        );

        final stored = (await docRef.get()).data()!;
        expect(
          stored.keys.toSet(),
          const UsageLimits().toFirestore().keys.toSet(),
        );
        expect(
          stored['importsToday'],
          5,
          reason: 'the legacy doc was read, not replaced by an empty one',
        );
      });
    });

    group('cache invalidation', () {
      /// After `recordUsage`, the next `checkLimit` must see the new counter.
      /// If the cache weren't invalidated, the limiter would keep returning
      /// the stale pre-record state and let users blow through caps until
      /// the 30s cache expires. This catches the "cache invalidated?" bug.
      test('recordUsage invalidates the in-memory cache so the next check '
          'sees fresh counters', () async {
        // Prime the cache by calling checkLimit (counter = 0 in Firestore).
        await withClock(Clock.fixed(_t0), () async {
          await limiter.checkLimit(ImportOperation.basic('url'));
        });

        // Record 9 imports — each call hits Firestore in a transaction.
        for (var i = 0; i < 9; i++) {
          await withClock(
            Clock.fixed(_t0.add(Duration(seconds: i))),
            () => limiter.recordUsage(ImportOperation.basic('url')),
          );
        }

        // 10th check must still allow; an 11th would deny.
        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(seconds: 10))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );
        expect(
          result,
          isA<RateLimitAllowed>(),
          reason: '9 recorded + 1 check = 10th attempt, still under cap',
        );

        // Now record the 10th. Next check (11th) MUST deny — if the cache
        // wasn't invalidated by recordUsage, it would still see count=9.
        await withClock(
          Clock.fixed(_t0.add(const Duration(seconds: 11))),
          () => limiter.recordUsage(ImportOperation.basic('url')),
        );
        final denied = await withClock(
          Clock.fixed(_t0.add(const Duration(seconds: 12))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );
        expect(
          denied,
          isA<RateLimitDenied>(),
          reason:
              'after 10 recorded imports, the next check must deny — '
              'proves recordUsage invalidates the read cache',
        );
      });

      // BUT-2243: the 30-second cache used to be keyed to nothing, so signing
      // in as someone else within it showed them the previous account's
      // counters.
      test('an account switch within 30 s does not serve the previous '
          "user's counters", () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(importsThisMinute: 10, minuteWindowStart: _t0),
        );
        final first = await withClock(
          Clock.fixed(_t0),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );
        expect(
          first,
          isA<RateLimitDenied>(),
          reason: 'premise: user A is at the per-minute cap, and is cached',
        );

        auth.setAuthState(userId: 'user-rate-limit-2');
        final second = await withClock(
          Clock.fixed(_t0.add(const Duration(seconds: 5))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );

        expect(second, isA<RateLimitAllowed>());
        expect((second as RateLimitAllowed).remainingInWindow, 999);
      });
    });

    group('helper APIs', () {
      /// getUsageStats must surface the real persisted state, not the cached
      /// 999-allowance. UI uses this for "X / 100 imports today" displays.
      test('getUsageStats returns the persisted UsageLimits', () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            importsToday: 42,
            dayWindowStart: _t0,
          ),
        );

        final stats = await limiter.getUsageStats();

        expect(stats.importsToday, 42);
      });

      /// `isLlmAvailable` proxies `checkLimit` with an enhancement op. When
      /// daily cost is over budget, it must return false — the UI uses this
      /// to hide the "Enhance with AI" button.
      test(
        'isLlmAvailable returns false when daily cost is over budget',
        () async {
          await _seedLedger(
            firestore,
            _uid,
            costToday: 0.60, // > $0.50
            dayKey: _today,
            costThisMonth: 0.60,
            monthKey: _thisMonth,
          );

          final ok = await withClock(
            Clock.fixed(_tUtc),
            () => limiter.isLlmAvailable(),
          );

          expect(ok, isFalse);
        },
      );

      /// And the happy path: returns true when LLM is healthy.
      test('isLlmAvailable returns true on a fresh account', () async {
        final ok = await withClock(
          Clock.fixed(_t0),
          () => limiter.isLlmAvailable(),
        );

        expect(ok, isTrue);
      });
    });

    group('fail-closed on Firestore errors', () {
      /// If Firestore throws (network down, rules deny, etc.), the limiter
      /// must DENY — not silently allow, which would open us to abuse.
      /// We simulate by injecting a [_ThrowingFirestoreRepository] that
      /// blows up on the underlying `firestore` getter access path.
      test(
        'checkLimit denies with retryAfter=30s when Firestore read fails',
        () async {
          final brokenRepo = _ThrowingFirestoreRepository();
          final brokenLimiter = ImportRateLimiter(
            firestoreRepository: brokenRepo,
            authRepository: auth,
          );

          final result = await withClock(
            Clock.fixed(_t0),
            () => brokenLimiter.checkLimit(ImportOperation.basic('url')),
          );

          expect(
            result,
            isA<RateLimitDenied>(),
            reason: 'fail-closed: a Firestore failure must NOT silently allow',
          );
          final denied = result as RateLimitDenied;
          expect(denied.retryAfter, const Duration(seconds: 30));
          expect(denied.suggestedAction, FallbackAction.retryLater);
        },
      );

      /// recordUsage failures must be swallowed — we never want a counter
      /// update glitch to break a successful import. The contract is "best
      /// effort" with a logged warning. Verify it doesn't throw.
      test('recordUsage swallows Firestore errors without throwing', () async {
        final brokenRepo = _ThrowingFirestoreRepository();
        final brokenLimiter = ImportRateLimiter(
          firestoreRepository: brokenRepo,
          authRepository: auth,
        );

        // No expect().throws — just await and expect normal completion.
        await withClock(Clock.fixed(_t0), () async {
          await brokenLimiter.recordUsage(ImportOperation.basic('url'));
        });

        // If we got here, the contract held.
        expect(true, isTrue);
      });

      /// BUT-1415: a transient transaction failure must be RETRIED. Two
      /// transient throws then success ⇒ 3 bounded attempts, and the op is
      /// counted once.
      test(
        'recordUsage retries a transient transaction failure then records once '
        '(BUT-1415)',
        () async {
          final flaky = _FlakyFirestore(failFirst: 2);
          final flakyLimiter = ImportRateLimiter(
            firestoreRepository: FirestoreRepository(firestore: flaky),
            authRepository: auth,
            // Zero backoff so the retry loop runs without real wall-clock sleeps.
            retryBaseDelay: Duration.zero,
          );

          await withClock(Clock.fixed(_t0), () async {
            await flakyLimiter.recordUsage(
              ImportOperation.withLlm('url', LlmOperationType.fullExtraction),
            );
          });

          expect(
            flaky.txAttempts,
            equals(3),
            reason: '2 transient throws + 1 success = 3 bounded attempts',
          );
          final after = await _readUsage(flaky, _uid);
          expect(
            after.llmExtractionsToday,
            1,
            reason: 'counted once despite the retries',
          );
        },
      );
    });
  });
}

/// A FirestoreRepository whose `firestore` getter throws — used to exercise
/// the fail-closed branch. We extend FirestoreRepository (concrete) and
/// override the getter to raise.
class _ThrowingFirestoreRepository extends FirestoreRepository {
  _ThrowingFirestoreRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  FirebaseFirestore get firestore =>
      throw StateError('Simulated Firestore outage');
}

/// BUT-1415: a fake whose `runTransaction` throws a transient
/// `FirebaseException` for the first [failFirst] calls, then delegates to the
/// real fake. Lets us prove `recordUsage` retries transient failures (reads +
/// writes still go through the real fake store).
class _FlakyFirestore extends FakeFirebaseFirestore {
  _FlakyFirestore({required this.failFirst});

  final int failFirst;
  int txAttempts = 0;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    txAttempts++;
    if (txAttempts <= failFirst) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

/// A FirestoreRepository that serves a working fake until [failFromNow] is
/// set, then throws on every access — so a test can fill the import-counter
/// cache first and make the ledger read the only thing that fails.
class _LedgerFailingRepository extends FirestoreRepository {
  _LedgerFailingRepository() : super(firestore: FakeFirebaseFirestore());

  bool failFromNow = false;

  @override
  FirebaseFirestore get firestore {
    if (failFromNow) throw StateError('Simulated ledger read failure');
    return super.firestore;
  }
}

/// The stock fake's transaction drops `SetOptions`, so a merge inside a
/// transaction overwrites there while it merges in production. This one hands
/// the handler a transaction that applies the options, so a test can tell a
/// whole-document write from a merge.
class _MergeHonouringFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    return super.runTransaction(
      (tx) => transactionHandler(_MergeHonouringTransaction(tx)),
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

class _MergeHonouringTransaction implements Transaction {
  _MergeHonouringTransaction(this._inner);

  final Transaction _inner;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) => _inner.get(documentReference);

  @override
  Transaction delete(DocumentReference documentReference) {
    _inner.delete(documentReference);
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _inner.update(documentReference, data);
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    if (options == null) {
      _inner.set(documentReference, data);
    } else {
      unawaited(documentReference.set(data, options));
    }
    return this;
  }
}
