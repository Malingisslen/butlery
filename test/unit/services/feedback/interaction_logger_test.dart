/// Unit tests for InteractionLogger circular buffer.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/feedback/interaction_logger.dart';

void main() {
  group('InteractionEntry', () {
    test('toJson serializes timestamp as ISO 8601', () {
      final e = InteractionEntry(
        screenName: 'home',
        actionType: 'tap',
        timestamp: DateTime.utc(2026, 1, 1, 10),
      );
      expect(e.toJson(), {
        'screenName': 'home',
        'actionType': 'tap',
        'timestamp': '2026-01-01T10:00:00.000Z',
      });
    });
  });

  group('logInteraction + getRecentInteractions', () {
    test('empty logger returns empty list', () {
      expect(InteractionLogger().getRecentInteractions(), isEmpty);
    });

    test('single interaction is returned', () {
      final logger = InteractionLogger();
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        logger.logInteraction('home', 'tap');
      });
      final list = logger.getRecentInteractions();
      expect(list, hasLength(1));
      expect(list.single.screenName, 'home');
      expect(list.single.actionType, 'tap');
      expect(list.single.timestamp, DateTime.utc(2026, 1, 1));
    });

    test('chronological order preserved while count < buffer size', () {
      final logger = InteractionLogger();
      for (var i = 0; i < 5; i++) {
        withClock(Clock.fixed(DateTime.utc(2026, 1, 1, i)), () {
          logger.logInteraction('s$i', 'a$i');
        });
      }
      final list = logger.getRecentInteractions();
      expect(list.map((e) => e.screenName), ['s0', 's1', 's2', 's3', 's4']);
    });

    test('exactly 20 entries: all kept, chronological', () {
      final logger = InteractionLogger();
      for (var i = 0; i < 20; i++) {
        withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, i)), () {
          logger.logInteraction('s$i', 'a');
        });
      }
      final list = logger.getRecentInteractions();
      expect(list, hasLength(20));
      expect(list.first.screenName, 's0');
      expect(list.last.screenName, 's19');
    });

    test(
      'after overflow (21 entries): drops oldest, keeps last 20 in order',
      () {
        final logger = InteractionLogger();
        for (var i = 0; i < 21; i++) {
          withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, i)), () {
            logger.logInteraction('s$i', 'a');
          });
        }
        final list = logger.getRecentInteractions();
        expect(list, hasLength(20));
        // s0 was overwritten; oldest remaining is s1
        expect(list.first.screenName, 's1');
        expect(list.last.screenName, 's20');
      },
    );

    test('after wrapping multiple times the order is still right', () {
      final logger = InteractionLogger();
      for (var i = 0; i < 50; i++) {
        withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, i)), () {
          logger.logInteraction('s$i', 'a');
        });
      }
      final list = logger.getRecentInteractions();
      expect(list, hasLength(20));
      // last 20: s30..s49
      expect(list.first.screenName, 's30');
      expect(list.last.screenName, 's49');
    });
  });

  group('toJsonList', () {
    test('serializes each entry via toJson', () {
      final logger = InteractionLogger();
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        logger.logInteraction('home', 'tap');
        logger.logInteraction('settings', 'scroll');
      });
      final jsonList = logger.toJsonList();
      expect(jsonList, hasLength(2));
      expect(jsonList[0]['screenName'], 'home');
      expect(jsonList[1]['actionType'], 'scroll');
    });

    test('empty when no interactions logged', () {
      expect(InteractionLogger().toJsonList(), isEmpty);
    });
  });
}
