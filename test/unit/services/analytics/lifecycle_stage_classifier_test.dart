/// Unit tests for [classifyLifecycleStage] (BUT-639).
///
/// Pure function — no DI / no fixtures. Tests pin `now` so boundaries are
/// deterministic regardless of when the suite runs.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

void main() {
  group('classifyLifecycleStage', () {
    final now = DateTime.utc(2026, 4, 30, 12);

    test('missing signupAt → new_ (defensive: never guess churn)', () {
      final stage = classifyLifecycleStage(
        signupAt: null,
        lastCookAt: now.subtract(const Duration(days: 200)),
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.new_);
    });

    test('fresh signup, no cook yet → new_', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 2)),
        lastCookAt: null,
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.new_);
    });

    test('first cook within 7d of signup → activated', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 5)),
        lastCookAt: now.subtract(const Duration(days: 1)),
        cooksLast14Days: 1,
        now: now,
      );
      expect(stage, LifecycleStage.activated);
    });

    test('boundary: cook on day 7 from signup → activated (inclusive)', () {
      final signupAt = now.subtract(const Duration(days: 7));
      final stage = classifyLifecycleStage(
        signupAt: signupAt,
        lastCookAt: signupAt.add(const Duration(days: 7)),
        cooksLast14Days: 1,
        now: now,
      );
      expect(stage, LifecycleStage.activated);
    });

    test(
      'cook on day 8 from signup, only one cook → new_ (past activation)',
      () {
        final signupAt = now.subtract(const Duration(days: 10));
        final stage = classifyLifecycleStage(
          signupAt: signupAt,
          lastCookAt: signupAt.add(const Duration(days: 8)),
          cooksLast14Days: 1,
          now: now,
        );
        expect(stage, LifecycleStage.new_);
      },
    );

    test('3+ cooks last 14 days → habitual', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 60)),
        lastCookAt: now.subtract(const Duration(days: 1)),
        cooksLast14Days: 5,
        now: now,
      );
      expect(stage, LifecycleStage.habitual);
    });

    test('boundary: exactly 3 cooks last 14 days → habitual', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 60)),
        lastCookAt: now.subtract(const Duration(days: 2)),
        cooksLast14Days: 3,
        now: now,
      );
      expect(stage, LifecycleStage.habitual);
    });

    test('boundary: 14 days since last cook → dormant', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 60)),
        lastCookAt: now.subtract(const Duration(days: 14)),
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.dormant);
    });

    test('boundary: 30 days since last cook → dormant (still in window)', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 60)),
        lastCookAt: now.subtract(const Duration(days: 30)),
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.dormant);
    });

    test('boundary: 31 days since last cook → churned', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 60)),
        lastCookAt: now.subtract(const Duration(days: 31)),
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.churned);
    });

    test(
      'BUT-1550: 30d12h since last cook → churned (sub-day precision, not '
      'collapsed onto the day-30 boundary by inDays truncation)',
      () {
        final stage = classifyLifecycleStage(
          signupAt: now.subtract(const Duration(days: 60)),
          lastCookAt: now.subtract(const Duration(days: 30, hours: 12)),
          cooksLast14Days: 0,
          now: now,
        );
        expect(stage, LifecycleStage.churned);
      },
    );

    test(
      'priority: 5 cooks but lastCookAt 40d ago → churned (recency wins)',
      () {
        // Spec-mandated: stale-but-prolific user must classify as churned.
        // The 5 in cooksLast14Days is irrelevant if lastCookAt > 30d.
        final stage = classifyLifecycleStage(
          signupAt: now.subtract(const Duration(days: 200)),
          lastCookAt: now.subtract(const Duration(days: 40)),
          cooksLast14Days: 5,
          now: now,
        );
        expect(stage, LifecycleStage.churned);
      },
    );

    test(
      'priority: 4 cooks but lastCookAt 20d ago → dormant (recency wins)',
      () {
        final stage = classifyLifecycleStage(
          signupAt: now.subtract(const Duration(days: 200)),
          lastCookAt: now.subtract(const Duration(days: 20)),
          cooksLast14Days: 4,
          now: now,
        );
        expect(stage, LifecycleStage.dormant);
      },
    );

    test('never cooked, signed up 35d ago → churned', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 35)),
        lastCookAt: null,
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.churned);
    });

    test('never cooked, signed up 20d ago → dormant', () {
      final stage = classifyLifecycleStage(
        signupAt: now.subtract(const Duration(days: 20)),
        lastCookAt: null,
        cooksLast14Days: 0,
        now: now,
      );
      expect(stage, LifecycleStage.dormant);
    });

    test(
      'BUT-1550: never cooked, signed up 30d12h ago → churned (sub-day '
      'precision on the never-cooked branch too, symmetric with last-cook)',
      () {
        // The never-cooked branch got the same .inDays → Duration fix; guard it
        // so a bad merge reverting just this branch to truncation can't slip a
        // 30d12h-since-signup churned user back to dormant undetected.
        final stage = classifyLifecycleStage(
          signupAt: now.subtract(const Duration(days: 30, hours: 12)),
          lastCookAt: null,
          cooksLast14Days: 0,
          now: now,
        );
        expect(stage, LifecycleStage.churned);
      },
    );

    test('wireValue strips trailing underscore on new_', () {
      expect(LifecycleStage.new_.wireValue, 'new');
      expect(LifecycleStage.activated.wireValue, 'activated');
      expect(LifecycleStage.habitual.wireValue, 'habitual');
      expect(LifecycleStage.dormant.wireValue, 'dormant');
      expect(LifecycleStage.churned.wireValue, 'churned');
    });
  });
}
