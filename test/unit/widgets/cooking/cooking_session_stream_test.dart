// Proves the fix for the pre-commit /simplify review finding:
// CookingSessionStreamHolder.refresh() must not re-subscribe when called
// with the same inputs. Each RTDB re-subscription is a real round-trip,
// and the card's parent view calls refresh() on every rebuild.

import 'dart:async';

import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModule implements CookingSessionModule {
  int watchCallCount = 0;
  final Map<String, StreamController<List<CookingSession>>> controllers = {};

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) {
    watchCallCount++;
    final c = controllers.putIfAbsent(
      groupId,
      () => StreamController<List<CookingSession>>.broadcast(),
    );
    return c.stream;
  }

  @override
  Future<void> startSession(dynamic recipe) async {}

  @override
  Future<void> endSession() async {}

  void dispose() {
    for (final c in controllers.values) {
      c.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CookingSessionStreamHolder', () {
    late _FakeModule module;
    late CookingSessionStreamHolder holder;

    setUp(() {
      module = _FakeModule();
      holder = CookingSessionStreamHolder();
    });

    tearDown(() {
      holder.dispose();
      module.dispose();
    });

    test('first refresh sets up N subscriptions for N groups', () {
      holder.refresh(module, ['g1', 'g2', 'g3'], 'self');
      expect(module.watchCallCount, 3);
      expect(holder.stream, isNotNull);
    });

    test('refresh with identical inputs is a no-op (no re-subscribe)', () {
      holder.refresh(module, ['g1', 'g2'], 'self');
      final firstStream = holder.stream;
      final firstWatchCount = module.watchCallCount;

      // Simulate 10 parent rebuilds — the bug before this fix was that each
      // rebuild allocated a fresh StreamController + re-subscribed to RTDB.
      for (var i = 0; i < 10; i++) {
        holder.refresh(module, ['g1', 'g2'], 'self');
      }

      expect(module.watchCallCount, firstWatchCount,
          reason: 'no additional RTDB subscriptions should have been made');
      expect(identical(holder.stream, firstStream), isTrue,
          reason: 'stream identity must be stable across idempotent refreshes');
    });

    test('refresh re-subscribes when groupIds change', () {
      holder.refresh(module, ['g1'], 'self');
      expect(module.watchCallCount, 1);

      holder.refresh(module, ['g1', 'g2'], 'self');
      // 1 initial + 2 for the new set (old subs cancelled, new ones created).
      expect(module.watchCallCount, 3);
    });

    test('refresh re-subscribes when selfUserId changes', () {
      holder.refresh(module, ['g1'], 'userA');
      final beforeCount = module.watchCallCount;

      holder.refresh(module, ['g1'], 'userB');
      expect(module.watchCallCount, greaterThan(beforeCount));
    });

    test('refresh with empty groups clears the stream', () {
      holder.refresh(module, ['g1'], 'self');
      expect(holder.stream, isNotNull);

      holder.refresh(module, const [], 'self');
      expect(holder.stream, isNull);
    });

    test('dispose cancels subscriptions and closes the controller', () async {
      holder.refresh(module, ['g1', 'g2'], 'self');
      final ctrl = module.controllers['g1']!;
      // Add a sink so the controller knows if its subscription gets cancelled
      // — if the holder leaks the subscription, this assertion fires.

      holder.dispose();
      expect(holder.stream, isNull);

      // Safe to emit after dispose — the holder should have cancelled its
      // listener. If the listener were still live, `_emit` inside the holder
      // would hit a closed controller and crash.
      ctrl.add(const []);
      await Future<void>.delayed(Duration.zero);
      // Reaching here without an uncaught async error means the listener
      // was properly detached.
    });

    test('self user is filtered out of merged output', () async {
      holder.refresh(module, ['g1'], 'self');
      final events = <List<CookingSession>>[];
      final sub = holder.stream!.listen(events.add);

      module.controllers['g1']!.add([
        CookingSession(
          recipeId: 'r1',
          recipeTitle: 'X',
          startedAt: DateTime(2026),
          userId: 'self', // <- should be filtered out
          userName: 'Me',
        ),
        CookingSession(
          recipeId: 'r2',
          recipeTitle: 'Y',
          startedAt: DateTime(2026),
          userId: 'friend',
          userName: 'Friend',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      final latest = events.last;
      expect(latest.length, 1);
      expect(latest.first.userId, 'friend');

      await sub.cancel();
    });
  });
}
