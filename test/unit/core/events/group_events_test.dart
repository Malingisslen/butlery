/// Unit tests for GroupEventBus.
///
/// Static lazy-initialized stream controller. Tests verify each emit
/// helper fires the right enum value, the dispose/recreate lifecycle,
/// and that the broadcast nature lets multiple listeners observe the
/// same events.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/events/group_events.dart';

void main() {
  tearDown(GroupEventBus.dispose);

  group('emit helpers', () {
    test('groupCreated fires created event', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.groupCreated();
      expect(await future, GroupEventType.created);
    });

    test('groupUpdated fires updated event', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.groupUpdated();
      expect(await future, GroupEventType.updated);
    });

    test('groupDeleted fires deleted event', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.groupDeleted();
      expect(await future, GroupEventType.deleted);
    });

    test('memberAdded fires memberAdded event', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.memberAdded();
      expect(await future, GroupEventType.memberAdded);
    });

    test('memberRemoved fires memberRemoved event', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.memberRemoved();
      expect(await future, GroupEventType.memberRemoved);
    });

    test('add forwards a raw event type', () async {
      final future = GroupEventBus.events.first;
      GroupEventBus.add(GroupEventType.updated);
      expect(await future, GroupEventType.updated);
    });
  });

  test('events and stream getters expose the same broadcast stream', () async {
    final received = <GroupEventType>[];
    final subA = GroupEventBus.events.listen(received.add);
    final subB = GroupEventBus.stream.listen(received.add);

    GroupEventBus.groupCreated();
    await Future<void>.delayed(Duration.zero);
    await subA.cancel();
    await subB.cancel();

    // Both subscriptions saw the same event.
    expect(received, [GroupEventType.created, GroupEventType.created]);
  });

  test('dispose closes controller; next access lazily recreates', () async {
    // Generate one event so a controller exists.
    final firstFuture = GroupEventBus.events.first;
    GroupEventBus.groupCreated();
    await firstFuture;

    GroupEventBus.dispose();

    // After dispose, asking for events again lazily creates a fresh
    // controller — emit + observe round-trips.
    final secondFuture = GroupEventBus.events.first;
    GroupEventBus.groupUpdated();
    expect(await secondFuture, GroupEventType.updated);
  });

  test('dispose is idempotent — calling twice does not throw', () {
    GroupEventBus.dispose();
    expect(GroupEventBus.dispose, returnsNormally);
  });
}
