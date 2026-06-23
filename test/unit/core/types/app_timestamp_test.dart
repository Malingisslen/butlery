/// Unit tests for AppTimestamp.
///
/// Pin the factory variants, the serialization round-trips
/// (Firestore Timestamp / ISO string / milliseconds / JSON), the
/// comparison operators, the duration math, and the equality contract.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/types/app_timestamp.dart';

void main() {
  group('factories', () {
    test('fromDateTime preserves the input', () {
      final dt = DateTime.utc(2026, 3, 14, 9);
      expect(AppTimestamp.fromDateTime(dt).dateTime, dt);
    });

    test('now uses clock.now() and stores as UTC', () {
      final fixed = DateTime.utc(2026, 5, 1, 12);
      withClock(Clock.fixed(fixed), () {
        final ts = AppTimestamp.now();
        expect(ts.isUtc, isTrue);
        expect(ts.utcDateTime, fixed);
      });
    });

    test('nowUtc alias also stores UTC', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 1, 12)), () {
        expect(AppTimestamp.nowUtc().isUtc, isTrue);
      });
    });

    test('fromFirestore converts to UTC', () {
      final stamp = Timestamp.fromDate(DateTime.utc(2026, 1, 1, 10));
      final ts = AppTimestamp.fromFirestore(stamp);
      expect(ts.utcDateTime, DateTime.utc(2026, 1, 1, 10));
      expect(ts.isUtc, isTrue);
    });

    test('fromMilliseconds stores UTC', () {
      final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      final ts = AppTimestamp.fromMilliseconds(ms);
      expect(ts.utcDateTime, DateTime.utc(2026, 1, 1));
      expect(ts.isUtc, isTrue);
    });
  });

  group('accessors', () {
    test('utcDateTime / localDateTime / dateTime', () {
      final ts = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1, 10));
      expect(ts.utcDateTime, DateTime.utc(2026, 1, 1, 10));
      expect(ts.localDateTime, DateTime.utc(2026, 1, 1, 10).toLocal());
      expect(ts.dateTime, DateTime.utc(2026, 1, 1, 10));
    });

    test('local-time component getters use localDateTime', () {
      final ts = AppTimestamp.fromDateTime(DateTime(2026, 5, 23, 14, 30, 45));
      expect(ts.year, 2026);
      expect(ts.month, 5);
      expect(ts.day, 23);
      expect(ts.hour, 14);
      expect(ts.minute, 30);
      expect(ts.second, 45);
    });

    test('UTC component getters use utcDateTime', () {
      final ts = AppTimestamp.fromDateTime(
        DateTime.utc(2026, 5, 23, 14, 30, 45),
      );
      expect(ts.utcYear, 2026);
      expect(ts.utcMonth, 5);
      expect(ts.utcDay, 23);
      expect(ts.utcHour, 14);
      expect(ts.utcMinute, 30);
      expect(ts.utcSecond, 45);
    });
  });

  group('serialization', () {
    test('toFirestore → fromFirestore round-trip preserves UTC instant', () {
      final original = AppTimestamp.fromDateTime(DateTime.utc(2026, 2, 14, 10));
      final stamp = original.toFirestore();
      final restored = AppTimestamp.fromFirestore(stamp);
      expect(restored.utcDateTime, original.utcDateTime);
    });

    test('toMilliseconds → fromMilliseconds round-trips', () {
      final original = AppTimestamp.fromDateTime(DateTime.utc(2026, 2, 14, 10));
      final ms = original.toMilliseconds();
      expect(
        AppTimestamp.fromMilliseconds(ms).utcDateTime,
        original.utcDateTime,
      );
    });

    test('toIsoString always emits UTC ISO 8601', () {
      final ts = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1, 10, 30));
      expect(ts.toIsoString(), '2026-01-01T10:30:00.000Z');
    });

    test('toJson + fromJson round-trips via milliseconds', () {
      final original = AppTimestamp.fromDateTime(DateTime.utc(2026, 5, 23, 14));
      final json = original.toJson();
      expect(json, containsPair('timestamp', isA<int>()));
      final restored = AppTimestamp.fromJson(json);
      expect(restored.utcDateTime, original.utcDateTime);
    });
  });

  group('comparison + duration math', () {
    final earlier = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
    final later = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 2));

    test('isBefore / isAfter / isAtSameMomentAs', () {
      expect(earlier.isBefore(later), isTrue);
      expect(later.isAfter(earlier), isTrue);
      expect(earlier.isAtSameMomentAs(earlier), isTrue);
      expect(earlier.isAfter(later), isFalse);
    });

    test('add returns a new AppTimestamp', () {
      final later2 = earlier.add(const Duration(days: 1));
      expect(later2.utcDateTime, DateTime.utc(2026, 1, 2));
    });

    test('subtract returns a new AppTimestamp', () {
      final earlier2 = later.subtract(const Duration(days: 1));
      expect(earlier2.utcDateTime, DateTime.utc(2026, 1, 1));
    });

    test('difference returns the gap', () {
      expect(later.difference(earlier), const Duration(days: 1));
    });
  });

  group('equality + hash', () {
    test('two AppTimestamps with same DateTime are equal', () {
      final a = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
      final b = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different DateTimes are unequal', () {
      final a = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
      final b = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 2));
      expect(a, isNot(b));
    });

    test('identical short-circuit in operator==', () {
      final a = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
      expect(a == a, isTrue);
    });

    test('!= a non-AppTimestamp', () {
      // ignore: unrelated_type_equality_checks
      expect(AppTimestamp.now() == 'not-a-timestamp', isFalse);
    });
  });

  group('toUtc / toLocal', () {
    test('toUtc returns UTC-flagged variant', () {
      final ts = AppTimestamp.fromDateTime(DateTime(2026, 1, 1));
      expect(ts.toUtc().isUtc, isTrue);
    });

    test('toLocal returns local-flagged variant', () {
      final ts = AppTimestamp.fromDateTime(DateTime.utc(2026, 1, 1));
      expect(ts.toLocal().isUtc, isFalse);
    });
  });

  test('toString delegates to DateTime.toString', () {
    final dt = DateTime.utc(2026, 1, 1, 10);
    expect(AppTimestamp.fromDateTime(dt).toString(), dt.toString());
  });
}
