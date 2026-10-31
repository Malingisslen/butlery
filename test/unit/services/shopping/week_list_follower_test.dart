/// Kärnflöde 8B: a burst of saves to one week becomes one write to the week's
/// list, weeks do not wait for each other, and a failing sync never throws
/// into the app.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/shopping/week_list_follower.dart';

// Mondays of two different ISO weeks.
final _week24 = DateTime(2026, 6, 8);
final _week25 = DateTime(2026, 6, 15);

void main() {
  group('WeekListFollower', () {
    test('a burst of saves to one week is one sync, two seconds after the '
        'last save', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        final synced = <DateTime>[];
        WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async => synced.add(week),
        );

        saves.add(_week24);
        async.elapse(const Duration(seconds: 1));
        saves.add(_week24);
        async.elapse(const Duration(seconds: 1));
        saves.add(_week24);
        async.elapse(const Duration(milliseconds: 1999));
        expect(synced, isEmpty, reason: 'each save restarts the wait');

        async.elapse(const Duration(milliseconds: 1));
        expect(synced, [_week24]);

        async.elapse(const Duration(seconds: 30));
        expect(synced, hasLength(1), reason: 'nothing else is pending');
      });
    });

    test('two weeks saved together are two syncs, each for its own week', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        final synced = <DateTime>[];
        WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async => synced.add(week),
        );

        saves
          ..add(_week24)
          ..add(_week25)
          ..add(_week24);
        async.elapse(const Duration(seconds: 2));

        expect(synced, unorderedEquals([_week24, _week25]));
      });
    });

    test('a failing sync is logged, not thrown, and the next save still '
        'syncs', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        var calls = 0;
        final follower = WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async {
            calls++;
            if (calls == 1) throw StateError('the list could not be written');
          },
        );
        Object? escaped;

        runZonedGuarded(() {
          saves.add(_week24);
          async.elapse(const Duration(seconds: 2));
          follower.idle();
          async.flushMicrotasks();
          saves.add(_week24);
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
        }, (e, _) => escaped = e);

        expect(escaped, isNull);
        expect(calls, 2);
      });
    });

    test('two saves of one week never run their syncs at the same time', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        final gates = <Completer<void>>[];
        var running = 0;
        var maxRunning = 0;
        WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async {
            running++;
            if (running > maxRunning) maxRunning = running;
            final gate = Completer<void>();
            gates.add(gate);
            await gate.future;
            running--;
          },
        );

        saves.add(_week24);
        async.elapse(const Duration(seconds: 2));
        expect(gates, hasLength(1));

        saves.add(_week24);
        async.elapse(const Duration(seconds: 2));
        expect(gates, hasLength(1), reason: 'waits for the run in progress');

        gates.first.complete();
        async.flushMicrotasks();
        expect(gates, hasLength(2));
        gates.last.complete();
        async.flushMicrotasks();
        expect(maxRunning, 1);
      });
    });

    test('dispose cancels a pending sync and ignores later saves', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        final synced = <DateTime>[];
        final follower = WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async => synced.add(week),
        );

        saves.add(_week24);
        async.elapse(const Duration(seconds: 1));
        follower.dispose();
        async.flushMicrotasks();
        saves.add(_week25);
        async.elapse(const Duration(seconds: 10));

        expect(synced, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a pause of its own is honoured', () {
      fakeAsync((async) {
        final saves = StreamController<DateTime>.broadcast();
        final synced = <DateTime>[];
        WeekListFollower(
          savedWeeks: saves.stream,
          sync: (week) async => synced.add(week),
          pause: const Duration(milliseconds: 300),
        );

        saves.add(_week24);
        async.elapse(const Duration(milliseconds: 299));
        expect(synced, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(synced, [_week24]);
      });
    });
  });

  group('MenuShoppingOptionsMemory', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    test('nothing remembered reads as the sheet\'s drawn defaults', () {
      final options = MenuShoppingOptionsMemory(preferences).read();

      expect(options, const MenuShoppingMergeOptions());
    });

    test('without device storage the defaults are read and a write is a '
        'no-op', () async {
      final memory = MenuShoppingOptionsMemory(null);

      await memory.write(const MenuShoppingMergeOptions(convertUnits: false));

      expect(memory.read(), const MenuShoppingMergeOptions());
    });

    test('the rules the user confirmed are read back the same, switch by '
        'switch', () async {
      const chosen = MenuShoppingMergeOptions(
        mergeDuplicates: false,
        convertUnits: true,
        subtractPantry: false,
      );

      await MenuShoppingOptionsMemory(preferences).write(chosen);

      final read = MenuShoppingOptionsMemory(preferences).read();
      expect(read.mergeDuplicates, isFalse);
      expect(read.convertUnits, isTrue);
      expect(read.subtractPantry, isFalse);
    });
  });
}
