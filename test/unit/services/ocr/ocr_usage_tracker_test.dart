import 'package:butlery/services/ocr/ocr_usage_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OCRUsageTracker — SharedPreferences persistence (BUT-682)', () {
    DateTime fixedToday() => DateTime(2026, 5, 4, 12);
    DateTime fixedYesterday() => DateTime(2026, 5, 3, 12);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('recordUsage persists daily count after load', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final tracker = OCRUsageTracker(timeProvider: fixedToday);
      await tracker.loadFromPersistence(prefs: prefs);
      tracker.recordUsage('ocr_space');
      tracker.recordUsage('google_vision');

      expect(prefs.getInt('ocr_usage_daily_count'), 2);
      expect(prefs.getString('ocr_usage_daily_date'), '2026-05-04');
    });

    test('persisted count survives reconstruction on the same day', () async {
      SharedPreferences.setMockInitialValues({
        'ocr_usage_daily_count': 7,
        'ocr_usage_daily_date': '2026-05-04',
      });
      final prefs = await SharedPreferences.getInstance();

      final tracker = OCRUsageTracker(timeProvider: fixedToday);
      await tracker.loadFromPersistence(prefs: prefs);

      expect(
        tracker.dailyRequestCount,
        7,
        reason: 'Loaded count from same-day persistence',
      );
    });

    test(
      'next recordUsage on the same day continues from loaded count',
      () async {
        SharedPreferences.setMockInitialValues({
          'ocr_usage_daily_count': 7,
          'ocr_usage_daily_date': '2026-05-04',
        });
        final prefs = await SharedPreferences.getInstance();

        final tracker = OCRUsageTracker(timeProvider: fixedToday);
        await tracker.loadFromPersistence(prefs: prefs);
        tracker.recordUsage('ocr_space');

        expect(
          tracker.dailyRequestCount,
          8,
          reason: 'Continues from loaded base, not from zero',
        );
        expect(prefs.getInt('ocr_usage_daily_count'), 8);
      },
    );

    test('stale-date entry is dropped on load', () async {
      SharedPreferences.setMockInitialValues({
        'ocr_usage_daily_count': 99,
        'ocr_usage_daily_date': '2026-05-03',
      });
      final prefs = await SharedPreferences.getInstance();

      final tracker = OCRUsageTracker(timeProvider: fixedToday);
      await tracker.loadFromPersistence(prefs: prefs);

      expect(
        tracker.dailyRequestCount,
        0,
        reason: 'Yesterday\'s count is dropped, fresh day starts at 0',
      );
    });

    test('without loadFromPersistence, tracker is in-memory only', () async {
      // Tracker never gets a prefs reference — recordUsage must short-circuit
      // its persistence path. We separately confirm prefs were not touched.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final tracker = OCRUsageTracker(timeProvider: fixedToday);
      tracker.recordUsage('ocr_space');
      expect(tracker.dailyRequestCount, 1);
      expect(
        prefs.getInt('ocr_usage_daily_count'),
        isNull,
        reason: '_persistDaily must no-op when _prefs is null',
      );
      expect(prefs.getString('ocr_usage_daily_date'), isNull);
    });

    test(
      'day rollover after load resets daily count and overwrites prefs',
      () async {
        // Persistence shows 7 from "yesterday". Wall clock advances to today.
        SharedPreferences.setMockInitialValues({
          'ocr_usage_daily_count': 7,
          'ocr_usage_daily_date': '2026-05-03',
        });
        final prefs = await SharedPreferences.getInstance();

        final tracker = OCRUsageTracker(timeProvider: fixedToday);
        await tracker.loadFromPersistence(prefs: prefs);
        tracker.recordUsage('ocr_space');

        expect(tracker.dailyRequestCount, 1);
        expect(prefs.getString('ocr_usage_daily_date'), '2026-05-04');
        expect(prefs.getInt('ocr_usage_daily_count'), 1);
      },
    );

    test('yesterday timeProvider behaves consistently', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final tracker = OCRUsageTracker(timeProvider: fixedYesterday);
      await tracker.loadFromPersistence(prefs: prefs);
      tracker.recordUsage('ocr_space');

      expect(prefs.getString('ocr_usage_daily_date'), '2026-05-03');
    });
  });
}
