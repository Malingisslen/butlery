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

  // The request counters are measured against freeMonthlyLimit, a bound derived
  // from PAID pricing, so ALL THREE of the on-device tier's outcomes must move
  // providerUsage without moving the quota. Nothing else in the suite can see
  // this: every other recordUsage call here names a billable provider, so the
  // exclusion branch is never entered and dropping it changes no assertion.
  //
  // "Two outcomes" is what this comment used to say, and the success outcome
  // was in fact missing from the exclusion set — so the dominant case, tier 0
  // ACCEPTING the page, spent paid quota. The undercount in the comment WAS
  // the defect.
  group('OCRUsageTracker — free-tier bookkeeping vs paid quota', () {
    DateTime fixedToday() => DateTime(2026, 5, 4, 12);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'an ACCEPTED on-device read costs no quota either — the dominant case',
      () async {
        final prefs = await SharedPreferences.getInstance();

        final tracker = OCRUsageTracker(timeProvider: fixedToday);
        await tracker.loadFromPersistence(prefs: prefs);
        tracker.recordUsage('on_device');

        expect(
          tracker.dailyRequestCount,
          0,
          reason:
              'tier 0 accepting the page is the whole point of the feature; '
              'roughly 500 free reads drove `remaining` to zero and made the '
              'tracker warn about a paid limit the user had never touched',
        );
        expect(tracker.monthlyRequestCount, 0);
        expect(
          tracker.providerUsage['on_device'],
          1,
          reason:
              'the read still happened — it is the QUOTA that must not move, '
              'not the bookkeeping',
        );
      },
    );

    test(
      'on-device rejections and errors are recorded but cost no quota',
      () async {
        final prefs = await SharedPreferences.getInstance();

        final tracker = OCRUsageTracker(timeProvider: fixedToday);
        await tracker.loadFromPersistence(prefs: prefs);
        tracker.recordUsage('on_device_rejected');
        tracker.recordUsage('on_device_error');

        expect(
          tracker.dailyRequestCount,
          0,
          reason: 'a free-tier outcome bills nothing, so it spends no quota',
        );
        expect(tracker.monthlyRequestCount, 0);
        expect(
          tracker.providerUsage['on_device_rejected'],
          1,
          reason:
              'still counted per-provider — the accept rate the flag-flip '
              'decision rests on is computed from these two keys',
        );
        expect(tracker.providerUsage['on_device_error'], 1);
        expect(
          prefs.getInt('ocr_usage_daily_count'),
          0,
          reason: 'and a restart must not resurrect them as spent quota',
        );
      },
    );

    test(
      'an image tier 0 rejects and OCR.space then serves costs one unit',
      () {
        final tracker = OCRUsageTracker(timeProvider: fixedToday);

        tracker.recordUsage('on_device_rejected');
        tracker.recordUsage('ocr_space');

        expect(
          tracker.dailyRequestCount,
          1,
          reason:
              'one image, one paid call, one unit — double-counting would '
              'pull the "X calls left today" figure down twice as fast',
        );
        expect(tracker.monthlyRequestCount, 1);

        final stats = tracker.getUsageStats();
        expect(stats['remaining'], OCRUsageTracker.freeMonthlyLimit - 1);
        expect(
          stats['estimated_monthly_cost'] as double,
          closeTo(0.01, 1e-9),
          reason: 'only the OCR.space leg is billable',
        );
      },
    );

    test('a run of free-tier rejections raises no quota warning', () {
      final tracker = OCRUsageTracker(timeProvider: fixedToday);

      // 400 = 80% of freeMonthlyLimit, i.e. exactly the threshold that would
      // fire "Approaching monthly limit" if these were counted as requests.
      for (var i = 0; i < 400; i++) {
        tracker.recordUsage('on_device_rejected');
      }

      expect(
        tracker.getUsageWarnings(),
        isEmpty,
        reason:
            'warning users about a paid quota they have not touched is '
            'the exact inversion of what the free tier is for',
      );
      expect(tracker.getUsageStats()['usage_percentage'], 0.0);
    });
  });
}
