/// Unit tests for rate limit models — sealed classes, factories, constants.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../../../test_support/base_unit_test.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

// The fixture `functions/src/__tests__/llm-cost-ledger.test.ts` uses for the
// server's `utcDayKey`/`utcMonthKey`: one minute either side of a month end.
final _jan31At2359 = DateTime.utc(2026, 1, 31, 23, 59);
final _feb01At0001 = DateTime.utc(2026, 2, 1, 0, 1);

void main() {
  group('RateLimitResult', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('RateLimitAllowed has correct type getters', () {
      const result = RateLimitAllowed(
        remainingInWindow: 5,
        limitType: LimitType.perHour,
      );
      expect(result.isAllowed, isTrue);
      expect(result.isDenied, isFalse);
      expect(result.remainingInWindow, 5);
    });

    test('RateLimitDenied has correct type getters', () {
      const result = RateLimitDenied(
        message: 'Too many requests',
        retryAfter: Duration(seconds: 60),
        limitType: LimitType.perDay,
        suggestedAction: FallbackAction.retryLater,
      );
      expect(result.isDenied, isTrue);
      expect(result.isAllowed, isFalse);
      expect(result.retryAfter, const Duration(seconds: 60));
    });
  });

  group('ImportOperation', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('basic factory creates non-LLM operation', () {
      final op = ImportOperation.basic('url');
      expect(op.requiresLlm, isFalse);
      expect(op.llmType, isNull);
      expect(op.sourceType, 'url');
    });

    test('withLlm factory creates LLM operation', () {
      final op = ImportOperation.withLlm('url', LlmOperationType.enhancement);
      expect(op.requiresLlm, isTrue);
      expect(op.llmType, LlmOperationType.enhancement);
    });
  });

  group('UsageLimits', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('empty factory returns all zeros', () {
      final limits = UsageLimits.empty();
      expect(limits.importsToday, 0);
      expect(limits.llmEnhancementsToday, 0);
      expect(limits.totalLlmToday, 0);
    });

    test('totalLlmToday sums three LLM fields', () {
      const limits = UsageLimits(
        llmEnhancementsToday: 5,
        llmExtractionsToday: 3,
        llmVisionToday: 2,
      );
      expect(limits.totalLlmToday, 10);
    });
  });

  group('ImportRateLimits constants', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('importsPerMinute is 10', () {
      expect(ImportRateLimits.importsPerMinute, 10);
    });

    test('importsPerDay is 100', () {
      expect(ImportRateLimits.importsPerDay, 100);
    });

    test('llmCostPerDay is 0.50', () {
      expect(ImportRateLimits.llmCostPerDay, 0.50);
    });

    test('llmCostPerMonth is 10.00', () {
      expect(ImportRateLimits.llmCostPerMonth, 10.00);
    });
  });

  // BUT-2243: the app reads the server's ledger and must key it exactly as the
  // server does, or it shows a stale day's spend as today's (or forgets
  // today's).
  group('ServerLlmCost keys and resets', () {
    test(
      'day and month keys are the UTC date on either side of a month end',
      () {
        expect(ServerLlmCost.dayKeyOf(_jan31At2359), '2026-01-31');
        expect(ServerLlmCost.monthKeyOf(_jan31At2359), '2026-01');
        expect(ServerLlmCost.dayKeyOf(_feb01At0001), '2026-02-01');
        expect(ServerLlmCost.monthKeyOf(_feb01At0001), '2026-02');
      },
    );

    // Discriminates only on a host whose zone is not UTC (a Swedish
    // developer machine; run with TZ=Europe/Stockholm to see it bite). On a
    // UTC host `toLocal()` is the identity and this repeats the case above.
    test('a local DateTime is keyed by its UTC date, not its wall clock', () {
      expect(ServerLlmCost.dayKeyOf(_feb01At0001.toLocal()), '2026-02-01');
      expect(ServerLlmCost.dayKeyOf(_jan31At2359.toLocal()), '2026-01-31');
      expect(ServerLlmCost.monthKeyOf(_jan31At2359.toLocal()), '2026-01');
    });

    test('the day resets at the next UTC midnight', () {
      expect(ServerLlmCost.dayResetAfter(_jan31At2359), DateTime.utc(2026, 2));
      expect(
        ServerLlmCost.dayResetAfter(_feb01At0001),
        DateTime.utc(2026, 2, 2),
      );
      expect(ServerLlmCost.dayResetAfter(_feb01At0001).isUtc, isTrue);
    });

    // Same TZ caveat as the key test above: bites under TZ=Europe/Stockholm,
    // where 23:59 UTC on 31 Jan is already 1 Feb on the wall clock.
    test('resets are computed from the UTC instant of a local DateTime', () {
      final local = _jan31At2359.toLocal();
      expect(
        ServerLlmCost.dayResetAfter(local),
        ServerLlmCost.dayResetAfter(_jan31At2359),
      );
      expect(ServerLlmCost.dayResetAfter(local), DateTime.utc(2026, 2));
      expect(
        ServerLlmCost.monthResetAfter(local),
        ServerLlmCost.monthResetAfter(_jan31At2359),
      );
      expect(ServerLlmCost.monthResetAfter(local), DateTime.utc(2026, 2));
    });

    test('the month resets at the first instant of the next UTC month', () {
      expect(
        ServerLlmCost.monthResetAfter(_jan31At2359),
        DateTime.utc(2026, 2),
      );
      expect(
        ServerLlmCost.monthResetAfter(_feb01At0001),
        DateTime.utc(2026, 3),
      );
      expect(
        ServerLlmCost.monthResetAfter(DateTime.utc(2026, 12, 15)),
        DateTime.utc(2027),
      );
    });
  });

  group('ServerLlmCost.fromFirestore', () {
    test('no ledger doc means nothing spent', () {
      final cost = ServerLlmCost.fromFirestore(null, _feb01At0001);
      expect(cost.costToday, 0.0);
      expect(cost.costThisMonth, 0.0);
    });

    test('keys matching now carry their spend through', () {
      final cost = ServerLlmCost.fromFirestore({
        'costToday': 0.3,
        'dayKey': '2026-02-01',
        'costThisMonth': 4.0,
        'monthKey': '2026-02',
      }, _feb01At0001);
      expect(cost.costToday, 0.3);
      expect(cost.costThisMonth, 4.0);
    });

    // The server writes after the last call of the day; nothing rewrites the
    // doc at midnight. A stale key is therefore the normal state of the doc on
    // the first check of a new day or month.
    test('a stale day key counts today as 0 and leaves the month alone', () {
      final cost = ServerLlmCost.fromFirestore({
        'costToday': 0.3,
        'dayKey': '2026-01-31',
        'costThisMonth': 4.0,
        'monthKey': '2026-02',
      }, _feb01At0001);
      expect(cost.costToday, 0.0);
      expect(cost.costThisMonth, 4.0);
    });

    test('a stale month key counts the month as 0 and leaves today alone', () {
      final cost = ServerLlmCost.fromFirestore({
        'costToday': 0.3,
        'dayKey': '2026-02-01',
        'costThisMonth': 4.0,
        'monthKey': '2026-01',
      }, _feb01At0001);
      expect(cost.costToday, 0.3);
      expect(cost.costThisMonth, 0.0);
    });

    test('a whole-number spend stored as an int is read', () {
      final cost = ServerLlmCost.fromFirestore({
        'costToday': 1,
        'dayKey': '2026-02-01',
        'costThisMonth': 10,
        'monthKey': '2026-02',
      }, _feb01At0001);
      expect(cost.costToday, 1.0);
      expect(cost.costThisMonth, 10.0);
    });
  });

  // BUT-2243 A5: the server enforces the ceilings, the app warns early with
  // its own copy of them. Read out of the TypeScript source, so a change on
  // one side only reddens here instead of making the app and the server
  // disagree about when the user is out of AI help.
  group('the app and the server agree on the ledger contract', () {
    final ts = File(
      'functions/src/middleware/llm_cost_ledger.ts',
    ).readAsStringSync();

    double tsNumber(String field) {
      final m = RegExp(field + r':\s*([0-9.]+)').firstMatch(ts);
      expect(m, isNotNull, reason: '$field is gone from llm_cost_ledger.ts');
      return double.parse(m!.group(1)!);
    }

    test('the same day and month ceilings', () {
      expect(tsNumber('perDayUsd'), ImportRateLimits.llmCostPerDay);
      expect(tsNumber('perMonthUsd'), ImportRateLimits.llmCostPerMonth);
    });

    test('the same ledger doc id', () {
      final m = RegExp(r'LLM_COST_DOC_ID\s*=\s*"([^"]+)"').firstMatch(ts);
      expect(m, isNotNull, reason: 'LLM_COST_DOC_ID is gone or reshaped');
      expect(m!.group(1), ServerLlmCost.docId);
    });
  });
}
