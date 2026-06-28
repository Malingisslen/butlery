/// Direct unit tests for [UploadProgressTracker] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure progress math (clock-driven). Covers milestone-crossing detection
/// (checkMilestoneNotification), average-speed and overall-progress aggregation
/// across active uploads, and getUploadDuration (pinned with withClock). The
/// per-update speed/ETA path needs the clock to advance between two updateProgress
/// calls and is left to integration.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/upload_progress_tracker.dart';

ImageUploadStatus status({double progress = 0.0, double? speed}) =>
    ImageUploadStatus(
      state: ImageUploadState.uploading,
      progress: progress,
      uploadSpeedBytesPerSecond: speed,
    );

void main() {
  group('checkMilestoneNotification', () {
    final tracker = UploadProgressTracker();

    test('fires when a milestone is newly crossed', () {
      final e = tracker.checkMilestoneNotification(
        previousProgress: 0.20,
        currentProgress: 0.30,
      );
      expect(e, isNotNull);
      expect(e!.data?['milestone'], 0.25);
    });

    test('does not fire when no milestone lies in the interval', () {
      // 0.25 already passed, 0.50 not yet reached.
      expect(
        tracker.checkMilestoneNotification(
          previousProgress: 0.30,
          currentProgress: 0.40,
        ),
        isNull,
      );
    });

    test('fires for the 50% milestone', () {
      final e = tracker.checkMilestoneNotification(
        previousProgress: 0.40,
        currentProgress: 0.60,
      );
      expect(e?.data?['milestone'], 0.50);
    });
  });

  group('aggregation', () {
    final tracker = UploadProgressTracker();

    test('getAverageUploadSpeed averages the non-null speeds', () {
      final avg = tracker.getAverageUploadSpeed({
        'a': status(speed: 100),
        'b': status(speed: 300),
      });
      expect(avg, 200);
    });

    test('getAverageUploadSpeed is 0 for empty or all-null speeds', () {
      expect(tracker.getAverageUploadSpeed({}), 0.0);
      expect(tracker.getAverageUploadSpeed({'a': status()}), 0.0);
    });

    test('calculateOverallProgress averages the progress values', () {
      final overall = tracker.calculateOverallProgress({
        'a': status(progress: 0.2),
        'b': status(progress: 0.8),
      });
      expect(overall, 0.5);
    });

    test('calculateOverallProgress is 0 when there are no uploads', () {
      expect(tracker.calculateOverallProgress({}), 0.0);
    });
  });

  group('getUploadDuration', () {
    test('null for an untracked file', () {
      expect(UploadProgressTracker().getUploadDuration('nope'), isNull);
    });

    test('elapsed time since startTracking (clock-pinned)', () {
      final tracker = UploadProgressTracker();
      final t0 = DateTime.utc(2026, 1, 1);
      withClock(Clock.fixed(t0), () => tracker.startTracking('f'));
      withClock(Clock.fixed(t0.add(const Duration(seconds: 5))), () {
        expect(tracker.getUploadDuration('f'), const Duration(seconds: 5));
      });
    });
  });
}
