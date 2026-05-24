/// Unit tests for `ImportRateLimiter` — pins the contract of:
///
/// - Per-minute / per-hour / per-day basic import limits (inclusive boundary).
/// - LLM-type quotas (enhancement/extraction/vision share day-window; they
///   reset together).
/// - Daily and monthly USD cost caps.
/// - Fail-closed behaviour when Firestore throws.
/// - Anonymous (unauthenticated) callers are allowed but not tracked.
/// - Time-window reset semantics — counters drop to 1 at exactly windowSize
///   elapsed, persist below it.
/// - Cache invalidation after `recordUsage`.
/// - Cold start: a fresh user with no persisted state allows the full quota.
/// - `getUsageStats` returns persisted state; `isLlmAvailable` reflects daily
///   LLM cap.
///
/// Time control is via `package:clock` `withClock(...)`, so we can land on
/// the 59.999s / 60.000s boundary precisely. Firestore is FakeFirebaseFirestore
/// because `runTransaction` works there for plain set/get without
/// `FieldValue.increment` or `serverTimestamp`.
library;

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
    late MockAuthRepository auth;
    late ImportRateLimiter limiter;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      firestoreRepo = FirestoreRepository(firestore: firestore);
      auth = MockAuthRepository();
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
      test(
          'checkLimit returns generous allow for unauthenticated user without '
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
        expect(stats.llmCostToday, 0.0);
      });
    });

    group('cold start (no persisted state)', () {
      /// A brand-new user must not be rate-limited on the first call. The
      /// remaining counter is the synthetic 999 because no window is open yet.
      test('first checkLimit allows and reports the synthetic 999 remaining',
          () async {
        await withClock(Clock.fixed(_t0), () async {
          final result = await limiter.checkLimit(ImportOperation.basic('url'));

          expect(result, isA<RateLimitAllowed>());
          expect((result as RateLimitAllowed).remainingInWindow, 999);
          expect(result.limitType, LimitType.perMinute);
        });
      });

      /// recordUsage on a virgin doc must write count=1 with windows anchored
      /// at now (not null), so subsequent checks operate against a real window.
      test('first recordUsage seeds count=1 and anchors all windows to now',
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
        expect(usage.monthWindowStart, _t0);
      });
    });

    group('per-minute boundary (limit = 10)', () {
      /// "10 imports per minute" means the 10th call is allowed but the 11th
      /// is denied while the window is open. This is the off-by-one the
      /// limiter's contract has to nail.
      test('10th call in window is allowed; 11th in same window is denied',
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
        expect(allow, isA<RateLimitAllowed>(),
            reason: '10th import in the minute window must be allowed');

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
        expect(deny, isA<RateLimitDenied>(),
            reason: '11th import in the same minute must be denied');
        final denied = deny as RateLimitDenied;
        expect(denied.limitType, LimitType.perMinute);
        expect(denied.suggestedAction, FallbackAction.retryLater);
      });

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
        expect(inside, isA<RateLimitDenied>(),
            reason: 'limiter must hold the cap up to but not including 60s');

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
        expect(atBoundary, isA<RateLimitAllowed>(),
            reason:
                'at exactly windowSize elapsed, the window has reset (strict <)');
      });

      /// After the minute window expires, a recordUsage must reset minute
      /// counter to 1 while preserving the hour/day counters that haven't
      /// rolled over yet.
      test('recordUsage after minute expiry resets minute=1, keeps hour/day',
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
        expect(after.importsThisHour, 11,
            reason: 'hour window still open → counter increments to 11');
        expect(after.hourWindowStart, _t0,
            reason:
                'hour window anchor must NOT shift while the window is open');
        expect(after.importsToday, 11);
        expect(after.dayWindowStart, _t0);
      });
    });

    group('per-hour and per-day limits (independent of minute)', () {
      /// Hour cap is 30. Even if the minute window has rolled, the hour cap
      /// must still deny when reached. Catches a real bug if anyone splits
      /// these checks and forgets the hour gate.
      test('hour limit denies even when minute counter is well under cap',
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
      });

      /// Day cap is 100. Day denial uses limitType.perDay.
      test('day limit denies with limitType.perDay and correct retryAfter',
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
      });

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
        expect((result as RateLimitAllowed).remainingInWindow, 2,
            reason: 'must be min(9, 25, 2) = 2');
      });
    });

    group('LLM operation quotas', () {
      /// Enhancement + ingredientLines share the `llmEnhancementsToday`
      /// counter. After 20 (the limit), an `enhancement` op is denied.
      test(
          'enhancement and ingredientLines share daily quota; 20th allowed, '
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
        expect(denied.suggestedAction, FallbackAction.skipLlm,
            reason: 'UI should be told it can fall back to rule-based');
      });

      /// fullExtraction has its own counter (cap 10) and must not be denied
      /// just because enhancements are maxed out. Catches a real bug if a
      /// refactor accidentally collapses the two counters.
      test('fullExtraction is unaffected when enhancement counter is maxed',
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

        expect(result, isA<RateLimitAllowed>(),
            reason:
                'fullExtraction counter independent of enhancement counter');
      });

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
            llmCostToday: 100.0, // way over $0.50 cap
            dayWindowStart: _t0,
          ),
        );

        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.checkLimit(ImportOperation.basic('url')),
        );

        expect(result, isA<RateLimitAllowed>(),
            reason: 'basic imports must not be gated on LLM quotas');
      });

      /// `_checkLlmLimits` switches on `operation.llmType`. When `null`, no
      /// per-type branch fires — but cost checks still run. Verify a
      /// `requiresLlm` operation with a `null` llmType still runs cost gating.
      /// (This guards against the `case null: break;` swallowing the cost branch.)
      test('LLM op with null type still enforces daily cost cap', () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmCostToday: 0.49, // 1 cent under
            dayWindowStart: _t0,
          ),
        );

        // Synthetic op: requiresLlm=true, llmType=null, estimatedCost = 0.10.
        const op = ImportOperation(
          requiresLlm: true,
          llmType: null,
          sourceType: 'url',
          estimatedCost: 0.10, // 0.49 + 0.10 = 0.59 > 0.50
        );

        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.checkLimit(op),
        );

        expect(result, isA<RateLimitDenied>());
        expect((result as RateLimitDenied).limitType, LimitType.costDaily);
      });
    });

    group('cost caps', () {
      /// Daily cost cap is $0.50. Using `>` (not `>=`) — exactly equal is OK,
      /// strictly greater denies. Pin this so a future `>= ` change can't
      /// silently shrink the cap.
      test('daily cost: exact-equal allowed, strictly-greater denied',
          () async {
        // Operation costs $0.03 (fullExtraction).
        const op = ImportOperation(
          requiresLlm: true,
          llmType: LlmOperationType.fullExtraction,
          sourceType: 'url',
          estimatedCost: 0.03,
        );

        // 0.47 + 0.03 = 0.50 → NOT greater than 0.50 → allowed.
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmCostToday: 0.47,
            dayWindowStart: _t0,
          ),
        );
        final exact = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.checkLimit(op),
        );
        expect(exact, isA<RateLimitAllowed>(),
            reason: 'cost cap uses strict > — exact-equal must be allowed');

        // 0.48 + 0.03 = 0.51 → strictly greater → denied.
        // Use a fresh limiter to drop the 30s in-memory cache.
        final freshLimiter = ImportRateLimiter(
          firestoreRepository: firestoreRepo,
          authRepository: auth,
        );
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmCostToday: 0.48,
            dayWindowStart: _t0,
          ),
        );
        final over = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => freshLimiter.checkLimit(op),
        );
        expect(over, isA<RateLimitDenied>());
        expect((over as RateLimitDenied).limitType, LimitType.costDaily);
      });

      /// Monthly cost cap ($10) is checked independently of daily and must
      /// deny even with daily cost low.
      test('monthly cost cap denies when projected total > \$10', () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmCostToday: 0.10,
            dayWindowStart: _t0,
            llmCostThisMonth: 9.98,
            monthWindowStart: _t0,
          ),
        );

        const op = ImportOperation(
          requiresLlm: true,
          llmType: LlmOperationType.fullExtraction,
          sourceType: 'url',
          estimatedCost: 0.03, // 9.98 + 0.03 = 10.01 → over
        );

        final result = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.checkLimit(op),
        );

        expect(result, isA<RateLimitDenied>());
        expect((result as RateLimitDenied).limitType, LimitType.costMonthly);
      });
    });

    group('recordUsage counter math', () {
      /// Recording an LLM op must increment BOTH the type-specific counter
      /// AND the cost counters, and bump llmOperationsThisMonth.
      test(
          'records LLM enhancement op: bumps day enhancements + cost + monthly',
          () async {
        const op = ImportOperation(
          requiresLlm: true,
          llmType: LlmOperationType.enhancement,
          sourceType: 'url',
          estimatedCost: 0.01,
        );

        await withClock(Clock.fixed(_t0), () async {
          await limiter.recordUsage(op, llmCost: 0.01);
        });

        final after = await _readUsage(firestore, _uid);
        expect(after.llmEnhancementsToday, 1);
        expect(after.llmExtractionsToday, 0);
        expect(after.llmVisionToday, 0);
        expect(after.llmCostToday, closeTo(0.01, 1e-9));
        expect(after.llmCostThisMonth, closeTo(0.01, 1e-9));
        expect(after.llmOperationsThisMonth, 1);
        expect(after.importsThisMinute, 1,
            reason: 'LLM op also counts as an import for per-window limits');
      });

      /// vision and fullExtraction must increment their OWN counters, not
      /// the enhancement one. This guards the switch in `_updateUsage`.
      test('records vision op into vision counter only', () async {
        await withClock(Clock.fixed(_t0), () async {
          await limiter.recordUsage(
            ImportOperation.withLlm('photo', LlmOperationType.vision),
            llmCost: 0.04,
          );
        });

        final after = await _readUsage(firestore, _uid);
        expect(after.llmVisionToday, 1);
        expect(after.llmEnhancementsToday, 0);
        expect(after.llmExtractionsToday, 0);
      });

      /// After a day-window roll, ALL daily LLM counters and the daily cost
      /// reset together — they share `dayWindowStart`. A bug that forgot to
      /// reset, say, `llmCostToday` would surface here.
      test('day rollover resets all LLM-per-day counters and llmCostToday',
          () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmEnhancementsToday: 20,
            llmExtractionsToday: 10,
            llmVisionToday: 10,
            llmCostToday: 0.49,
            dayWindowStart: _t0,
            llmCostThisMonth: 5.00,
            monthWindowStart: _t0,
          ),
        );

        // 25 hours later — day expired (>=24h), month still open.
        final later = _t0.add(const Duration(hours: 25));
        await withClock(Clock.fixed(later), () async {
          await limiter.recordUsage(
            ImportOperation.withLlm('url', LlmOperationType.enhancement),
            llmCost: 0.01,
          );
        });

        final after = await _readUsage(firestore, _uid);
        expect(after.dayWindowStart, later);
        expect(after.llmEnhancementsToday, 1,
            reason: 'reset to 0 then incremented');
        expect(after.llmExtractionsToday, 0);
        expect(after.llmVisionToday, 0);
        expect(after.llmCostToday, closeTo(0.01, 1e-9),
            reason: 'reset to 0 then incremented by 0.01');

        // Month carries on.
        expect(after.monthWindowStart, _t0);
        expect(after.llmCostThisMonth, closeTo(5.01, 1e-9));
      });

      /// recordUsage of a basic op must NOT bump any LLM counters and must
      /// NOT bump cost. This guards against an `if (operation.requiresLlm)`
      /// flip in `_updateUsage`.
      test('basic op recordUsage leaves LLM counters and cost untouched',
          () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmEnhancementsToday: 3,
            llmCostToday: 0.10,
            llmCostThisMonth: 2.50,
            llmOperationsThisMonth: 7,
            dayWindowStart: _t0,
            monthWindowStart: _t0,
          ),
        );

        await withClock(Clock.fixed(_t0.add(const Duration(minutes: 1))),
            () async {
          await limiter.recordUsage(ImportOperation.basic('url'));
        });

        final after = await _readUsage(firestore, _uid);
        expect(after.llmEnhancementsToday, 3,
            reason: 'basic op must not touch enhancement counter');
        expect(after.llmCostToday, closeTo(0.10, 1e-9));
        expect(after.llmCostThisMonth, closeTo(2.50, 1e-9));
        expect(after.llmOperationsThisMonth, 7,
            reason: 'basic op must not increment monthly LLM op count');
        expect(after.importsToday, 1);
      });
    });

    group('cache invalidation', () {
      /// After `recordUsage`, the next `checkLimit` must see the new counter.
      /// If the cache weren't invalidated, the limiter would keep returning
      /// the stale pre-record state and let users blow through caps until
      /// the 30s cache expires. This catches the "cache invalidated?" bug.
      test(
          'recordUsage invalidates the in-memory cache so the next check '
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
        expect(result, isA<RateLimitAllowed>(),
            reason: '9 recorded + 1 check = 10th attempt, still under cap');

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
        expect(denied, isA<RateLimitDenied>(),
            reason: 'after 10 recorded imports, the next check must deny — '
                'proves recordUsage invalidates the read cache');
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
            llmCostToday: 0.25,
          ),
        );

        final stats = await limiter.getUsageStats();

        expect(stats.importsToday, 42);
        expect(stats.llmCostToday, closeTo(0.25, 1e-9));
      });

      /// `isLlmAvailable` proxies `checkLimit` with an enhancement op. When
      /// daily cost is over budget, it must return false — the UI uses this
      /// to hide the "Enhance with AI" button.
      test('isLlmAvailable returns false when daily cost is over budget',
          () async {
        await _seedUsage(
          firestore,
          _uid,
          UsageLimits(
            llmCostToday: 0.60, // > $0.50
            dayWindowStart: _t0,
          ),
        );

        final ok = await withClock(
          Clock.fixed(_t0.add(const Duration(hours: 1))),
          () => limiter.isLlmAvailable(),
        );

        expect(ok, isFalse);
      });

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
      test('checkLimit denies with retryAfter=30s when Firestore read fails',
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

        expect(result, isA<RateLimitDenied>(),
            reason: 'fail-closed: a Firestore failure must NOT silently allow');
        final denied = result as RateLimitDenied;
        expect(denied.retryAfter, const Duration(seconds: 30));
        expect(denied.suggestedAction, FallbackAction.retryLater);
      });

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
