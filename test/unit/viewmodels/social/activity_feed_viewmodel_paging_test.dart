// Fetching the next page or reloading never empties the list on screen: a
// failure keeps what is shown and reports it (A16).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockFeed extends Mock implements ActivityFeedService {}

List<ActivityEvent> _page(int from, int count) => [
  for (var i = from; i < from + count; i++)
    ActivityEvent(
      id: 'e$i',
      actorId: 'a',
      actorDisplayName: 'Anna',
      type: ActivityEventType.values.first,
      recipeId: 'r$i',
      recipeTitle: 'Recept $i',
      createdAt: DateTime(2026, 1, 1).subtract(Duration(minutes: i)),
    ),
];

void main() {
  late _MockFeed feed;
  late ActivityFeedViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(DateTime(2026));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    feed = _MockFeed();
    TestServiceLocator.registerMock<ActivityFeedService>(feed);
    vm = ActivityFeedViewModel();
    when(
      () => feed.fetchFeed(limit: any(named: 'limit')),
    ).thenAnswer((_) async => _page(0, 20));
    await vm.loadFeed();
  });

  tearDown(() async {
    vm.dispose();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  test('a failed next page keeps the list and reports the failure', () async {
    when(
      () => feed.fetchFeed(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenThrow(Exception('unavailable'));

    await vm.loadMore();

    expect(vm.events, hasLength(20));
    expect(vm.loadMoreError, isNotNull);
    expect(vm.isLoadingMore, isFalse);
  });

  test('the list stays while the next page loads', () async {
    when(
      () => feed.fetchFeed(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async {
      expect(vm.events, hasLength(20), reason: 'no spinner replaced the list');
      expect(vm.isLoadingMore, isTrue);
      return _page(20, 5);
    });

    await vm.loadMore();

    expect(vm.events, hasLength(25));
  });

  test('a failed refresh keeps the list', () async {
    when(
      () => feed.fetchFeed(limit: any(named: 'limit')),
    ).thenThrow(Exception('unavailable'));

    await vm.refresh();

    expect(vm.events, hasLength(20));
    expect(vm.error, isNotNull);
  });

  test(
    'a refresh that lands during a next page is not given the old page',
    () async {
      final slowPage = Completer<List<ActivityEvent>>();
      when(
        () => feed.fetchFeed(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) => slowPage.future);

      final pending = vm.loadMore();
      when(
        () => feed.fetchFeed(limit: any(named: 'limit')),
      ).thenAnswer((_) async => _page(100, 20));
      await vm.refresh();
      slowPage.complete(_page(20, 5));
      await pending;

      expect(vm.events, hasLength(20));
      expect(vm.events.first.id, 'e100');
    },
  );
}
