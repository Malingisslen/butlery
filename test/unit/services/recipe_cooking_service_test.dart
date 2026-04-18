/// Tests for [RecipeCookingService] — verifies atomic increment wiring and
/// per-session dedup.
///
/// Two behavioural contracts under test:
/// 1. A single `markAsCooked` call drives exactly one atomic write through
///    the repository ([RecipeRepository.incrementCookCount]).
/// 2. Rapid same-day double-tap on the same recipe counts once; a second
///    call on a different day (simulated via package:clock) counts again.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';

class _MockRecipeRepository extends Mock implements RecipeRepository {}

class _FakeDateTime extends Fake implements DateTime {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDateTime());
  });

  group('RecipeCookingService.markAsCooked', () {
    late _MockRecipeRepository repo;
    late RecipeCookingService service;

    setUp(() {
      repo = _MockRecipeRepository();
      service = RecipeCookingService(recipeRepository: repo);
    });

    test('single call writes once via incrementCookCount', () async {
      when(() => repo.incrementCookCount(any(), any()))
          .thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 18, 30)), () async {
        final ok = await service.markAsCooked('r1');
        expect(ok, isTrue);
      });

      verify(() => repo.incrementCookCount('r1', any())).called(1);
    });

    test('rapid same-day double call only increments once', () async {
      when(() => repo.incrementCookCount(any(), any()))
          .thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 18, 30)), () async {
        final first = await service.markAsCooked('r1');
        final second = await service.markAsCooked('r1');
        expect(first, isTrue, reason: 'first tap should commit');
        expect(second, isFalse,
            reason: 'second same-day tap must be swallowed by session guard');
      });

      verify(() => repo.incrementCookCount('r1', any())).called(1);
    });

    test('different recipes on the same day each count independently',
        () async {
      when(() => repo.incrementCookCount(any(), any()))
          .thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 19, 00)), () async {
        await service.markAsCooked('r1');
        await service.markAsCooked('r2');
      });

      verify(() => repo.incrementCookCount('r1', any())).called(1);
      verify(() => repo.incrementCookCount('r2', any())).called(1);
    });

    test('next-day call after same-recipe counts again', () async {
      when(() => repo.incrementCookCount(any(), any()))
          .thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 23, 59)), () async {
        final dayOne = await service.markAsCooked('r1');
        expect(dayOne, isTrue);
      });
      await withClock(Clock.fixed(DateTime(2026, 4, 19, 7, 00)), () async {
        final dayTwo = await service.markAsCooked('r1');
        expect(dayTwo, isTrue,
            reason: 'session guard is day-bucketed so cooking the same recipe '
                'the next day must be counted');
      });

      verify(() => repo.incrementCookCount('r1', any())).called(2);
    });

    test('empty recipeId short-circuits without touching the repository',
        () async {
      final ok = await service.markAsCooked('');
      expect(ok, isFalse);
      verifyNever(() => repo.incrementCookCount(any(), any()));
    });

    test('repository failure bubbles up and does NOT poison the guard',
        () async {
      when(() => repo.incrementCookCount(any(), any()))
          .thenAnswer((_) async => false);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 10, 00)), () async {
        final firstAttempt = await service.markAsCooked('r1');
        expect(firstAttempt, isFalse);

        when(() => repo.incrementCookCount(any(), any()))
            .thenAnswer((_) async => true);

        final retry = await service.markAsCooked('r1');
        expect(retry, isTrue,
            reason: 'a failed write must NOT mark the recipe as counted — '
                'the user needs to be able to retry');
      });

      verify(() => repo.incrementCookCount('r1', any())).called(2);
    });

    test('passes a DateTime close to clock.now() to the repository', () async {
      DateTime? captured;
      when(() => repo.incrementCookCount(any(), any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[1] as DateTime;
        return true;
      });

      final fixed = DateTime(2026, 4, 18, 12, 34, 56);
      await withClock(Clock.fixed(fixed), () async {
        await service.markAsCooked('r1');
      });

      expect(captured, equals(fixed));
    });
  });
}
