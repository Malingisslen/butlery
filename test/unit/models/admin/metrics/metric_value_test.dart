/// Direct unit tests for the [MetricValue] sealed union (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Pure value types the admin renderer switches on. The logic worth pinning:
/// ScalarMetric.deltaPercent (period-over-period %, null when there's no basis)
/// and the per-subtype isEmpty rule that drives the "Ingen data" placeholder.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/metrics/metric_value.dart';

void main() {
  group('ScalarMetric', () {
    test('is never empty — even a value of 0 is data', () {
      expect(const ScalarMetric(0).isEmpty, isFalse);
    });

    test('deltaPercent computes the period-over-period change', () {
      expect(const ScalarMetric(150, previous: 100).deltaPercent, 50.0);
      expect(const ScalarMetric(50, previous: 100).deltaPercent, -50.0);
    });

    test('deltaPercent is null without a usable basis', () {
      expect(const ScalarMetric(10).deltaPercent, isNull); // no previous
      expect(const ScalarMetric(10, previous: 0).deltaPercent, isNull); // ÷0
    });
  });

  group('isEmpty by subtype', () {
    test('SeriesMetric is empty only with no points', () {
      expect(const SeriesMetric([]).isEmpty, isTrue);
      expect(const SeriesMetric([SeriesPoint('a', 1)]).isEmpty, isFalse);
    });

    test('BreakdownMetric is empty only with no rows', () {
      expect(const BreakdownMetric([]).isEmpty, isTrue);
      expect(const BreakdownMetric([BreakdownRow('a', 1)]).isEmpty, isFalse);
    });

    test('FunnelMetric is empty only with no stages', () {
      expect(const FunnelMetric([]).isEmpty, isTrue);
      expect(const FunnelMetric([FunnelStage('a', 1)]).isEmpty, isFalse);
    });

    test('MatrixMetric is empty if cells OR either axis is empty', () {
      expect(
        const MatrixMetric(['r'], ['c'], [
          [1],
        ]).isEmpty,
        isFalse,
      );
      expect(const MatrixMetric([], ['c'], []).isEmpty, isTrue); // no rows
      expect(const MatrixMetric(['r'], [], []).isEmpty, isTrue); // no cols
      expect(const MatrixMetric(['r'], ['c'], []).isEmpty, isTrue); // no cells
    });
  });
}
