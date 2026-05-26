/// Intent-driven unit tests for UploadQueueSummaryCalculator (Intent-Test
/// Sprint, Batch 6 — pure-calc aggregation).
///
/// Behaviours covered:
///   * Empty-queue defaults (progress = 1.0, percentage = 100, no activity)
///   * State-bucket counting across pending/uploading/retrying/completed/
///     failed/cancelled (the totals add up, no double counting)
///   * Overall progress arithmetic — completed contributes 1.0, uploading
///     contributes its `.progress`, retrying contributes its `.progress`,
///     pending/failed/cancelled contribute 0
///   * Progress percentage rounding (33 for 1/3, etc.)
///   * Speed aggregation — only `isActive` items with a non-null speed
///     count; average is sum/count
///   * Byte totals — null totalBytes/bytesTransferred are skipped (no NPE)
///   * ETA — only computed when avgSpeed > 0 AND totalBytes >
///     totalBytesTransferred; uses ceiling-of-half rounding via Duration
///   * earliestStartTime tracking — picks the oldest of many, then
///     totalElapsedTime is "now − earliest"
///   * getEnhancedQueueStatusText — all six branches
///   * getProgressDisplayText — with/without time-remaining, complete state
///   * getSpeedDisplayText — MB/s vs KB/s formatting, <= 0 returns ''
///   * getQueueSummaryText — all-success-with-time vs partial vs preparing
///   * formatDuration — sub-minute, minute, hour boundaries and exact
///     boundary values
///
/// Notable production findings surfaced (NOT fixed here, see report):
///   * `getEnhancedQueueStatusText` returns `''` when the queue is all-
///     cancelled (no pending/active/failed/completed) — silent UI state.
///   * `uploadStatusAllFailed(failed, total)` passes `total` even when
///     some items are cancelled — UI says "N of TOTAL failed" but
///     TOTAL includes cancelled items, slightly misleading.
///   * `getSpeedDisplayText` formats sub-1 KB/s speeds as "0 KB/s"
///     (toStringAsFixed(0) of 0.488…) — quietly tells the user "0".

import 'dart:io';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

ImageUploadStatus _status({
  ImageUploadState state = ImageUploadState.pending,
  double progress = 0.0,
  int? totalBytes,
  int? bytesTransferred,
  double? uploadSpeedBytesPerSecond,
  DateTime? uploadStartTime,
  File? file,
  String? url,
}) {
  return ImageUploadStatus(
    state: state,
    progress: progress,
    totalBytes: totalBytes,
    bytesTransferred: bytesTransferred,
    uploadSpeedBytesPerSecond: uploadSpeedBytesPerSecond,
    uploadStartTime: uploadStartTime,
    file: file,
    url: url,
  );
}

void main() {
  group('calculateQueueSummary — empty input', () {
    /// Empty queue must be treated as "nothing to do, you're done" so the
    /// UI doesn't render a spinner or 0% bar when there's no work.
    test('returns total=0, progress=1.0, percentage=100, hasActivity=false',
        () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({});

      expect(summary['total'], 0);
      expect(summary['pending'], 0);
      expect(summary['uploading'], 0);
      expect(summary['retrying'], 0);
      expect(summary['completed'], 0);
      expect(summary['failed'], 0);
      expect(summary['cancelled'], 0);
      expect(summary['active'], 0);
      expect(summary['hasActivity'], isFalse);
      expect(summary['overallProgress'], 1.0);
      expect(summary['progressPercentage'], 100);
      expect(summary['totalBytes'], 0);
      expect(summary['totalBytesTransferred'], 0);
      expect(summary['averageSpeedBytesPerSecond'], 0.0);
      expect(summary['totalElapsedTime'], isNull);
      expect(summary['estimatedTimeRemaining'], isNull);
      expect(summary['statusText'], '');
    });
  });

  group('calculateQueueSummary — state bucket counts', () {
    /// Every status enum value must land in exactly one bucket and
    /// `active` must equal uploading+retrying — otherwise the UI's
    /// "X uploading, Y waiting" line will lie.
    test('counts each state once and active = uploading + retrying', () {
      final states = {
        'a': _status(state: ImageUploadState.pending),
        'b': _status(state: ImageUploadState.pending),
        'c': _status(state: ImageUploadState.uploading, progress: 0.5),
        'd': _status(state: ImageUploadState.retrying, progress: 0.2),
        'e': _status(state: ImageUploadState.completed),
        'f': _status(state: ImageUploadState.failed),
        'g': _status(state: ImageUploadState.cancelled),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['total'], 7);
      expect(summary['pending'], 2);
      expect(summary['uploading'], 1);
      expect(summary['retrying'], 1);
      expect(summary['completed'], 1);
      expect(summary['failed'], 1);
      expect(summary['cancelled'], 1);
      expect(summary['active'], 2); // uploading + retrying
      // Buckets must sum to total — no item double-counted or dropped.
      final bucketSum = (summary['pending'] as int) +
          (summary['uploading'] as int) +
          (summary['retrying'] as int) +
          (summary['completed'] as int) +
          (summary['failed'] as int) +
          (summary['cancelled'] as int);
      expect(bucketSum, summary['total']);
      expect(summary['hasActivity'], isTrue);
    });

    /// `hasActivity` must remain false when nothing is pending or active
    /// (i.e. queue is settled — only completed/failed/cancelled). This
    /// drives whether the UI shows the activity banner at all.
    test('hasActivity is false when no pending and no active uploads', () {
      final states = {
        'a': _status(state: ImageUploadState.completed),
        'b': _status(state: ImageUploadState.failed),
        'c': _status(state: ImageUploadState.cancelled),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['hasActivity'], isFalse);
      expect(summary['active'], 0);
    });
  });

  group('calculateQueueSummary — overall progress arithmetic', () {
    /// Completed = 1.0, in-flight contributes `.progress`, everything
    /// else 0. This is the contract that drives the progress bar.
    test(
        'completed contributes 1.0, uploading/retrying contribute progress, '
        'failed/cancelled/pending contribute 0', () {
      final states = {
        'pending': _status(state: ImageUploadState.pending),
        'uploading': _status(state: ImageUploadState.uploading, progress: 0.40),
        'retrying': _status(state: ImageUploadState.retrying, progress: 0.20),
        'completed': _status(state: ImageUploadState.completed),
        'failed': _status(state: ImageUploadState.failed, progress: 0.99),
        'cancelled': _status(state: ImageUploadState.cancelled, progress: 0.99),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      // 0 + 0.40 + 0.20 + 1.0 + 0 + 0 = 1.6 / 6 items = 0.2666…
      expect(
          summary['overallProgress'], closeTo((0.40 + 0.20 + 1.0) / 6, 1e-9));
      expect(summary['progressPercentage'], 27); // round(26.66…)
    });

    /// 1 of 3 completed = 33.33% → must round to 33 (not 34), and an
    /// all-pending queue must read 0% (not 100% from the empty-default).
    test('progress percentage rounds half-to-even / nearest for 1-of-3', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(state: ImageUploadState.completed),
        'b': _status(state: ImageUploadState.pending),
        'c': _status(state: ImageUploadState.pending),
      });
      expect(summary['progressPercentage'], 33);
      expect(summary['overallProgress'], closeTo(1 / 3, 1e-9));
    });

    /// All-pending queue is 0% — guards against accidentally inheriting
    /// the empty-queue default of 100%.
    test('all-pending queue is 0% progress, not the empty-default 100%', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(state: ImageUploadState.pending),
        'b': _status(state: ImageUploadState.pending),
      });
      expect(summary['overallProgress'], 0.0);
      expect(summary['progressPercentage'], 0);
    });

    /// All-completed queue must read exactly 100% — off-by-one in the
    /// sum (e.g. counting completed as 0.99) would surface here.
    test('all-completed queue reads exactly 100%', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(state: ImageUploadState.completed),
        'b': _status(state: ImageUploadState.completed),
      });
      expect(summary['overallProgress'], 1.0);
      expect(summary['progressPercentage'], 100);
    });
  });

  group('calculateQueueSummary — speed aggregation', () {
    /// Only `isActive` items (uploading + retrying) with a non-null speed
    /// feed the average. Completed/pending items with stale speeds must
    /// be ignored — otherwise the average drags toward zero as items
    /// finish.
    test('average only counts active uploads with non-null speed', () {
      final states = {
        'active1': _status(
          state: ImageUploadState.uploading,
          progress: 0.5,
          uploadSpeedBytesPerSecond: 2000.0,
        ),
        'active2': _status(
          state: ImageUploadState.retrying,
          progress: 0.1,
          uploadSpeedBytesPerSecond: 4000.0,
        ),
        'done_with_stale_speed': _status(
          state: ImageUploadState.completed,
          uploadSpeedBytesPerSecond: 99999.0, // must be ignored
        ),
        'active_no_speed': _status(
          state: ImageUploadState.uploading,
          progress: 0.2,
          uploadSpeedBytesPerSecond: null, // must not count toward denom
        ),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      // (2000 + 4000) / 2 = 3000
      expect(summary['averageSpeedBytesPerSecond'], 3000.0);
    });

    /// No active uploads → averageSpeed is 0.0 (not NaN from 0/0).
    test('average speed is 0.0 when no active uploads with speed', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(state: ImageUploadState.completed),
        'b': _status(state: ImageUploadState.failed),
      });
      expect(summary['averageSpeedBytesPerSecond'], 0.0);
    });
  });

  group('calculateQueueSummary — byte totals are null-safe', () {
    /// Null totalBytes / bytesTransferred must be skipped silently — a
    /// single null item must not poison the aggregate.
    test('null totalBytes and bytesTransferred are skipped (no NPE)', () {
      final states = {
        'sized': _status(
          state: ImageUploadState.uploading,
          progress: 0.5,
          totalBytes: 1000,
          bytesTransferred: 500,
        ),
        'unsized': _status(
          state: ImageUploadState.uploading,
          progress: 0.3,
          totalBytes: null,
          bytesTransferred: null,
        ),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['totalBytes'], 1000);
      expect(summary['totalBytesTransferred'], 500);
    });
  });

  group('calculateQueueSummary — estimated time remaining', () {
    /// ETA = remaining bytes / avg speed, rounded to nearest second.
    test('ETA is computed when speed > 0 and totalBytes > transferred', () {
      // 5000 bytes remaining at 1000 B/s = 5s.
      final states = {
        'a': _status(
          state: ImageUploadState.uploading,
          progress: 0.5,
          totalBytes: 10000,
          bytesTransferred: 5000,
          uploadSpeedBytesPerSecond: 1000.0,
        ),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['estimatedTimeRemaining'], const Duration(seconds: 5));
    });

    /// totalBytes == transferred → upload is byte-complete, no ETA.
    test('ETA is null when transferred has caught up to total', () {
      final states = {
        'a': _status(
          state: ImageUploadState.uploading,
          progress: 1.0,
          totalBytes: 1000,
          bytesTransferred: 1000,
          uploadSpeedBytesPerSecond: 500.0,
        ),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['estimatedTimeRemaining'], isNull);
    });

    /// avgSpeed == 0 → ETA is null (avoid division-by-zero).
    test('ETA is null when no active uploads contribute speed', () {
      final states = {
        'a': _status(
          state: ImageUploadState.pending,
          totalBytes: 1000,
          bytesTransferred: 0,
        ),
      };

      final summary =
          UploadQueueSummaryCalculator.calculateQueueSummary(states);

      expect(summary['averageSpeedBytesPerSecond'], 0.0);
      expect(summary['estimatedTimeRemaining'], isNull);
    });
  });

  group('calculateQueueSummary — earliest start time', () {
    /// totalElapsedTime is `clock.now() - earliestStartTime`. Must pick
    /// the OLDEST start across the whole queue (not the newest) so the
    /// elapsed-time UI reflects when the user actually kicked things off.
    test('picks the earliest of multiple start times', () {
      final fixedNow = DateTime.utc(2026, 5, 25, 12, 0, 0);
      withClock(Clock.fixed(fixedNow), () {
        final states = {
          'newer': _status(
            state: ImageUploadState.uploading,
            uploadStartTime: fixedNow.subtract(const Duration(seconds: 10)),
          ),
          'older': _status(
            state: ImageUploadState.uploading,
            uploadStartTime: fixedNow.subtract(const Duration(seconds: 30)),
          ),
          'newest': _status(
            state: ImageUploadState.uploading,
            uploadStartTime: fixedNow.subtract(const Duration(seconds: 2)),
          ),
        };

        final summary =
            UploadQueueSummaryCalculator.calculateQueueSummary(states);

        expect(summary['totalElapsedTime'], const Duration(seconds: 30));
      });
    });

    /// No item has a startTime → totalElapsedTime stays null (don't
    /// fabricate "0s elapsed" out of nothing).
    test('totalElapsedTime is null when no item has a start time', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(state: ImageUploadState.pending),
      });
      expect(summary['totalElapsedTime'], isNull);
    });
  });

  group('getEnhancedQueueStatusText — branches', () {
    /// Empty queue is the only path that must return '' from a contract
    /// standpoint — UI should not show a status pill for "nothing".
    test('total == 0 returns empty string', () {
      expect(
        UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
            0, 0, 0, 0, 0, 0.0),
        '',
      );
    });

    /// Active + pending → "uploading N (P% complete, K waiting)".
    test('active with pending uses the with-pending template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          /*pending*/ 3,
          /*active*/ 2,
          /*completed*/ 0,
          /*failed*/ 0,
          /*total*/ 5,
          /*progress*/ 0.4);
      // SV template: "Laddar upp 2 bilder (40% klart, 3 väntar)"
      expect(text, contains('2'));
      expect(text, contains('40'));
      expect(text, contains('3'));
    });

    /// Active with no pending uses the no-pending variant — the two
    /// templates have different argument arity so a swap would NPE.
    test('active with no pending uses the no-pending template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 2, 0, 0, 2, 0.5);
      expect(text, contains('2'));
      expect(text, contains('50'));
      expect(text, isNot(contains('väntar')));
    });

    /// Pending-only (nothing actively uploading yet).
    test('pending-only routes to the waiting template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          5, 0, 0, 0, 5, 0.0);
      expect(text, contains('5'));
      expect(text.toLowerCase(), contains('väntar'));
    });

    /// Partial failure — some completed, some failed.
    test('mixed completed + failed routes to partial-failure template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 0, /*completed*/ 2, /*failed*/ 1, /*total*/ 3, 2 / 3);
      expect(text, contains('2'));
      expect(text, contains('3'));
      expect(text, contains('1'));
    });

    /// All failed — no completed.
    test('all-failed (no completed) routes to all-failed template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 0, 0, /*failed*/ 3, /*total*/ 3, 0.0);
      expect(text, contains('3'));
      expect(text.toLowerCase(), contains('misslyckades'));
    });

    /// All success.
    test('completed == total routes to all-success template', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 0, /*completed*/ 4, 0, /*total*/ 4, 1.0);
      expect(text, contains('4'));
      expect(text.toLowerCase(), contains('framgångsrikt'));
    });

    /// BUT-1102 fix: all-cancelled queue surfaces a dedicated message
    /// instead of rendering blank UI. `cancelled` is now threaded through
    /// the function signature as a named param.
    test('BUT-1102: all-cancelled queue surfaces a dedicated status text', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 0, 0, 0, /*total*/ 2, 0.0,
          cancelled: 2);
      expect(text, isNotEmpty,
          reason: 'must surface a status string, not render blank UI');
      expect(text, contains('2'),
          reason: 'count of cancelled items belongs in the message');
    });

    /// Defensive: without `cancelled` (default 0), behaviour matches the
    /// pre-fix empty-string return — preserves source-compat for any caller
    /// that hasn't been updated to pass the new param.
    test('all-zero counters with no cancelled still returns empty', () {
      final text = UploadQueueSummaryCalculator.getEnhancedQueueStatusText(
          0, 0, 0, 0, /*total*/ 2, 0.0);
      expect(text, '');
    });
  });

  group('getProgressDisplayText', () {
    /// With a time-remaining duration, output must include both the
    /// percentage and the formatted time — UI relies on both being there.
    test('with timeRemaining uses progress-with-time template', () {
      final text = UploadQueueSummaryCalculator.getProgressDisplayText(
          0.45, const Duration(seconds: 90));
      expect(text, contains('45'));
      expect(text, contains('1m 30s'));
    });

    /// Progress < 1.0 and no time-remaining → simple percent template
    /// (must NOT say "complete").
    test('progress < 1.0 with no time uses percent template', () {
      final text =
          UploadQueueSummaryCalculator.getProgressDisplayText(0.5, null);
      expect(text, contains('50'));
      expect(text.toLowerCase(), isNot(contains('slutförd')));
    });

    /// Progress == 1.0 → "complete" label, regardless of percent.
    test('progress == 1.0 returns the complete label', () {
      final text =
          UploadQueueSummaryCalculator.getProgressDisplayText(1.0, null);
      expect(text.toLowerCase(), contains('slutförd'));
    });
  });

  group('getSpeedDisplayText', () {
    /// 0 (and any negative — defensive) must produce empty string so the
    /// UI hides the speed chip rather than rendering "0 KB/s".
    test('returns empty string for zero or negative bytesPerSecond', () {
      expect(UploadQueueSummaryCalculator.getSpeedDisplayText(0), '');
      expect(UploadQueueSummaryCalculator.getSpeedDisplayText(-100), '');
    });

    /// Just above 1 MB/s must render as MB/s with one decimal.
    test('>= 1 MB/s renders MB/s with one decimal', () {
      // 1.5 MB/s
      final text =
          UploadQueueSummaryCalculator.getSpeedDisplayText(1.5 * 1024 * 1024);
      expect(text, '1.5 MB/s');
    });

    /// Exactly 1.0 MB/s sits on the boundary — must take the MB branch,
    /// not fall back to KB.
    test('exactly 1.0 MB/s takes the MB branch (boundary)', () {
      final text =
          UploadQueueSummaryCalculator.getSpeedDisplayText(1024.0 * 1024.0);
      expect(text, '1.0 MB/s');
    });

    /// Sub-MB rates render as KB/s with no decimals.
    test('sub-MB renders KB/s with zero decimals', () {
      // 200 KB/s
      final text = UploadQueueSummaryCalculator.getSpeedDisplayText(200 * 1024);
      expect(text, '200 KB/s');
    });
  });

  group('getQueueSummaryText', () {
    /// total == 0 returns '' (no summary for nothing).
    test('returns empty string for total == 0', () {
      expect(
        UploadQueueSummaryCalculator.getQueueSummaryText(0, 0, 0, null),
        '',
      );
    });

    /// All complete + no failures + elapsed time → "all uploaded in X
    /// (100% success)". Must include the formatted time.
    test('completed==total, failed==0, with elapsed → all-success-with-time',
        () {
      final text = UploadQueueSummaryCalculator.getQueueSummaryText(
          3, 0, 3, const Duration(seconds: 75));
      // expect formatted "1m 15s" in there
      expect(text, contains('1m 15s'));
      expect(text, contains('100'));
    });

    /// All complete + no failures + null elapsed → "all uploaded (100%
    /// success)" with no time string.
    test('completed==total with null elapsed omits the time text', () {
      final text =
          UploadQueueSummaryCalculator.getQueueSummaryText(2, 0, 2, null);
      expect(text, contains('100'));
      expect(text, isNot(contains('på ')));
    });

    /// Partial-progress (some completed OR some failed) builds the
    /// composite "X of Y completed, F failed (R% success)" string.
    test('partial progress concatenates completion + failure + success rate',
        () {
      final text =
          UploadQueueSummaryCalculator.getQueueSummaryText(2, 1, 4, null);
      // 2 of 4 completed
      expect(text, contains('2'));
      expect(text, contains('4'));
      // 1 failed
      expect(text, contains('1'));
      // 50% success
      expect(text, contains('50'));
    });

    /// Partial with no failures still mentions completion + rate but
    /// must NOT include the failure clause.
    test('partial completed with zero failures omits failure clause', () {
      final text =
          UploadQueueSummaryCalculator.getQueueSummaryText(1, 0, 4, null);
      expect(text, contains('1'));
      expect(text, contains('4'));
      // 25% success
      expect(text, contains('25'));
      // No "misslyckades" comma-clause
      expect(text, isNot(contains('misslyckades')));
    });

    /// Nothing done yet (no completed, no failed, but total > 0) → the
    /// preparing template. This is the catch-all final-else branch.
    test('zero completed and zero failed with total > 0 returns preparing', () {
      final text =
          UploadQueueSummaryCalculator.getQueueSummaryText(0, 0, 5, null);
      expect(text.toLowerCase(), contains('förbereder'));
    });
  });

  group('formatDuration', () {
    /// Zero duration must render as "0s" (not "" or NPE).
    test('zero duration renders as 0s', () {
      expect(UploadQueueSummaryCalculator.formatDuration(Duration.zero), '0s');
    });

    /// Under a minute → "Ns".
    test('sub-minute renders as seconds only', () {
      expect(
        UploadQueueSummaryCalculator.formatDuration(
            const Duration(seconds: 45)),
        '45s',
      );
    });

    /// Exactly 60s renders as "1m" (NOT "1m 0s").
    test('exactly 60s renders as 1m (no trailing 0s)', () {
      expect(
        UploadQueueSummaryCalculator.formatDuration(
            const Duration(seconds: 60)),
        '1m',
      );
    });

    /// Minutes + seconds path.
    test('150s renders as 2m 30s', () {
      expect(
        UploadQueueSummaryCalculator.formatDuration(
            const Duration(seconds: 150)),
        '2m 30s',
      );
    });

    /// Exactly 3600s renders as "1h" (NOT "1h 0m") and crosses the
    /// hour boundary cleanly.
    test('exactly 3600s renders as 1h (no trailing 0m)', () {
      expect(
        UploadQueueSummaryCalculator.formatDuration(
            const Duration(seconds: 3600)),
        '1h',
      );
    });

    /// Hours + minutes path — and seconds within the hour are dropped.
    test('1h 15m 45s renders as 1h 15m (seconds dropped in hours range)', () {
      expect(
        UploadQueueSummaryCalculator.formatDuration(
            const Duration(hours: 1, minutes: 15, seconds: 45)),
        '1h 15m',
      );
    });
  });

  group('calculateQueueSummary — formatted display fields are wired', () {
    /// Smoke: the summary map must surface every formatted field the UI
    /// consumes. A refactor that drops one of these from the return map
    /// would silently break the upload card.
    test('returns all formatted display keys', () {
      final summary = UploadQueueSummaryCalculator.calculateQueueSummary({
        'a': _status(
          state: ImageUploadState.uploading,
          progress: 0.5,
          totalBytes: 10000,
          bytesTransferred: 5000,
          uploadSpeedBytesPerSecond: 2000.0,
        ),
      });

      expect(summary.containsKey('statusText'), isTrue);
      expect(summary.containsKey('progressText'), isTrue);
      expect(summary.containsKey('speedText'), isTrue);
      expect(summary.containsKey('summaryText'), isTrue);
      // And speedText is the rendered KB/s string for 2000 B/s.
      expect(summary['speedText'], '2 KB/s');
    });
  });
}
