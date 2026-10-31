import 'package:butlery/services/ocr/ocr_usage_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OCRUsageTracker', () {
    late OCRUsageTracker tracker;

    setUp(() {
      tracker = OCRUsageTracker();
    });

    test('each recorded key increments only its own count', () {
      tracker.recordUsage('on_device');
      tracker.recordUsage('on_device');
      tracker.recordUsage('on_device_rejected');
      tracker.recordUsage('on_device_error');
      tracker.recordUsage('cache_hits');

      expect(tracker.providerUsage['on_device'], 2);
      expect(tracker.providerUsage['on_device_rejected'], 1);
      expect(tracker.providerUsage['on_device_error'], 1);
      expect(tracker.providerUsage['cache_hits'], 1);
    });

    test('an unknown key is counted rather than dropped', () {
      tracker.recordUsage('some_new_outcome');
      tracker.recordUsage('some_new_outcome');

      expect(tracker.providerUsage['some_new_outcome'], 2);
      expect(tracker.providerUsage['on_device'], 0);
    });

    test('getUsageStats exposes exactly provider_usage and cache_hit_rate', () {
      tracker.recordUsage('on_device');
      tracker.recordUsage('cache_hits');

      final stats = tracker.getUsageStats();

      expect(stats.keys.toSet(), {'provider_usage', 'cache_hit_rate'});
      expect((stats['provider_usage'] as Map)['on_device'], 1);
      expect(stats['cache_hit_rate'], 0.5);
    });

    test('cache hit rate is 0 when nothing has been recorded', () {
      expect(tracker.calculateCacheHitRate(), 0.0);
    });

    test('cache hit rate is cache hits over all recorded outcomes', () {
      tracker.recordUsage('cache_hits');
      tracker.recordUsage('on_device');
      tracker.recordUsage('on_device_rejected');
      tracker.recordUsage('on_device_error');

      expect(tracker.calculateCacheHitRate(), 0.25);
    });

    test('providerUsage cannot be mutated by callers', () {
      expect(
        () => tracker.providerUsage['on_device'] = 99,
        throwsUnsupportedError,
      );

      tracker.recordUsage('on_device');
      expect(tracker.providerUsage['on_device'], 1);
    });

    test('getUsageStats provider_usage is a snapshot, not a live view', () {
      final snapshot =
          tracker.getUsageStats()['provider_usage'] as Map<String, int>;
      tracker.recordUsage('on_device');

      expect(snapshot['on_device'], 0);
    });
  });
}
