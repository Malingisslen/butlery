/// Unit tests for CommentTimeFormatter.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/recipe/comment_time_formatter.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 5, 23, 12);

  T at<T>(T Function() body) => withClock(Clock.fixed(fixedNow), body);

  group('relative time buckets', () {
    test('< 1 minute → "nu"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(seconds: 30))),
          'nu',
        );
      });
    });

    test('boundary at exactly 1 minute → "1m"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(minutes: 1))),
          '1m',
        );
      });
    });

    test('< 1 hour → "Xm"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(minutes: 5))),
          '5m',
        );
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(minutes: 59))),
          '59m',
        );
      });
    });

    test('< 1 day → "Xh"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(hours: 1))),
          '1h',
        );
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(hours: 23))),
          '23h',
        );
      });
    });

    test('< 7 days → "Xd"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(days: 1))),
          '1d',
        );
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(days: 6))),
          '6d',
        );
      });
    });

    test('>= 7 days → "DD/MM"', () {
      at(() {
        expect(
          CommentTimeFormatter.format(DateTime.utc(2026, 4, 1)),
          '1/4',
        );
        expect(
          CommentTimeFormatter.format(DateTime.utc(2025, 12, 15)),
          '15/12',
        );
      });
    });

    test('exactly 7 days ago → "DD/MM" (boundary)', () {
      at(() {
        expect(
          CommentTimeFormatter.format(
              fixedNow.subtract(const Duration(days: 7))),
          '${fixedNow.subtract(const Duration(days: 7)).day}/${fixedNow.subtract(const Duration(days: 7)).month}',
        );
      });
    });
  });
}
