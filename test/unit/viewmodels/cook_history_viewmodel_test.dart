/// The history list's contract: newest-first pages, filters that keep the
/// right cooks, and a "Lagas ofta" list built from recipe counters alone.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cook_event.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/viewmodels/cook_history_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _MockCookEvents extends Mock implements CookEventRepository {}

CookEvent _event(String id, String recipeId, DateTime at, {int? rating}) =>
    CookEvent(
      id: id,
      userId: 'u',
      recipeId: recipeId,
      cookedAt: at,
      rating: rating,
    );

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  late _MockCookEvents events;
  late MockUnifiedRecipeService recipes;

  setUp(() {
    events = _MockCookEvents();
    recipes = MockUnifiedRecipeService();
  });

  CookHistoryViewModel build() =>
      CookHistoryViewModel(cookEvents: events, recipes: recipes);

  test('load reads one page and reports no more when it is short', () async {
    when(
      () => events.fetchRecent(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => [_event('a', 'r1', DateTime(2026, 11, 20))]);
    recipes.setRecipeState(recipes: [], isInitialized: true);

    final vm = build();
    await vm.load();

    expect(vm.isLoading, isFalse);
    expect(vm.hasMore, isFalse);
    expect(vm.entries.single.event.id, 'a');
    // No matching recipe: the row still exists, without a title.
    expect(vm.entries.single.title, isNull);
  });

  test(
    'a full page offers more and the next page starts after the last row',
    () async {
      final page = [
        for (var i = 0; i < CookHistoryViewModel.pageSize; i++)
          _event(
            'e$i',
            'r1',
            DateTime(2026, 11, 20).subtract(Duration(days: i)),
          ),
      ];
      when(
        () => events.fetchRecent(limit: any(named: 'limit')),
      ).thenAnswer((_) async => page);
      when(
        () => events.fetchRecent(
          limit: any(named: 'limit'),
          before: page.last.cookedAt,
        ),
      ).thenAnswer((_) async => [_event('older', 'r1', DateTime(2026, 1, 1))]);
      recipes.setRecipeState(recipes: [], isInitialized: true);

      final vm = build();
      await vm.load();
      expect(vm.hasMore, isTrue);

      await vm.loadMore();

      expect(vm.entries.last.event.id, 'older');
      expect(vm.hasMore, isFalse);
    },
  );

  test(
    'favorites keeps rating 4 and up, lastMonth drops older cooks',
    () async {
      final now = DateTime(2026, 11, 23);
      when(
        () => events.fetchRecent(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => [
          _event('high', 'r1', DateTime(2026, 11, 20), rating: 5),
          _event('low', 'r1', DateTime(2026, 11, 10), rating: 2),
          _event('old', 'r1', DateTime(2026, 9, 1), rating: 4),
        ],
      );
      recipes.setRecipeState(recipes: [], isInitialized: true);

      await withClock(Clock.fixed(now), () async {
        final vm = build();
        await vm.load();

        vm.setFilter(CookHistoryFilter.favorites);
        expect(vm.entries.map((e) => e.event.id), ['high', 'old']);

        vm.setFilter(CookHistoryFilter.lastMonth);
        expect(vm.entries.map((e) => e.event.id), ['high', 'low']);
      });
    },
  );

  test('a failed first load is reported, not swallowed', () async {
    when(
      () => events.fetchRecent(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenThrow(Exception('offline'));
    recipes.setRecipeState(recipes: [], isInitialized: true);

    final vm = build();
    await vm.load();

    expect(vm.hasFailed, isTrue);
    expect(vm.isLoading, isFalse);
  });

  Recipe recipe(String id, int cooks, {double? rating}) => RecipeFactory.build(
    id: id,
    rating: rating,
  ).copyWith(cookCount: cooks);

  test('frequent lists the most-cooked first and caps at 5', () {
    recipes.setRecipeState(
      recipes: [
        recipe('two', 2),
        recipe('three', 3),
        recipe('four', 4),
        recipe('five', 5),
        recipe('six', 6),
        recipe('seven', 7),
      ],
      isInitialized: true,
    );

    final ids = build().frequent.map((r) => r.id).toList();

    // Six qualify; the cap cuts the least cooked.
    expect(ids, ['seven', 'six', 'five', 'four', 'three']);
  });

  test('frequent leaves out a recipe cooked only once', () {
    recipes.setRecipeState(
      recipes: [recipe('once', 1), recipe('two', 2)],
      isInitialized: true,
    );

    expect(build().frequent.map((r) => r.id), ['two']);
  });

  test('favorites judges a cook without its own rating by the recipe, '
      'and the cook\'s own rating wins over the recipe\'s', () async {
    recipes.setRecipeState(
      recipes: [recipe('r1', 3, rating: 4.5)],
      isInitialized: true,
    );
    when(
      () => events.fetchRecent(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => [
        _event('unrated', 'r1', DateTime(2026, 11, 20)),
        _event('own-low', 'r1', DateTime(2026, 11, 19), rating: 2),
      ],
    );

    final vm = build();
    await vm.load();
    vm.setFilter(CookHistoryFilter.favorites);

    expect(vm.entries.map((e) => e.event.id), ['unrated']);
  });
}
