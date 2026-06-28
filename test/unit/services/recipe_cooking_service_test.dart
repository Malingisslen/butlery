/// Tests for [RecipeCookingService] — verifies atomic cook-event wiring and
/// per-session dedup.
///
/// Two behavioural contracts under test:
/// 1. A single `markAsCooked` call drives exactly one atomic write through
///    the repository ([CookEventRepository.logCookEvent] — event doc +
///    cookCount bump in one batch, BUT-838).
/// 2. Rapid same-day double-tap on the same recipe counts once; a second
///    call on a different day (simulated via package:clock) counts again.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';

class _MockCookEventRepository extends Mock implements CookEventRepository {}

class _FakeDateTime extends Fake implements DateTime {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDateTime());
  });

  group('RecipeCookingService.markAsCooked', () {
    late _MockCookEventRepository repo;
    late RecipeCookingService service;

    setUp(() {
      repo = _MockCookEventRepository();
      service = RecipeCookingService(cookEventRepository: repo);
    });

    test('single call writes once via logCookEvent', () async {
      when(() => repo.logCookEvent(any(), any())).thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 18, 30)), () async {
        final ok = await service.markAsCooked('r1');
        expect(ok, isTrue);
      });

      verify(() => repo.logCookEvent('r1', any())).called(1);
    });

    test('rapid same-day double call only logs once', () async {
      when(() => repo.logCookEvent(any(), any())).thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 18, 30)), () async {
        final first = await service.markAsCooked('r1');
        final second = await service.markAsCooked('r1');
        expect(first, isTrue, reason: 'first tap should commit');
        expect(
          second,
          isFalse,
          reason: 'second same-day tap must be swallowed by session guard',
        );
      });

      verify(() => repo.logCookEvent('r1', any())).called(1);
    });

    test(
      'different recipes on the same day each count independently',
      () async {
        when(
          () => repo.logCookEvent(any(), any()),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(DateTime(2026, 4, 18, 19, 00)), () async {
          await service.markAsCooked('r1');
          await service.markAsCooked('r2');
        });

        verify(() => repo.logCookEvent('r1', any())).called(1);
        verify(() => repo.logCookEvent('r2', any())).called(1);
      },
    );

    test('next-day call after same-recipe counts again', () async {
      when(() => repo.logCookEvent(any(), any())).thenAnswer((_) async => true);

      await withClock(Clock.fixed(DateTime(2026, 4, 18, 23, 59)), () async {
        final dayOne = await service.markAsCooked('r1');
        expect(dayOne, isTrue);
      });
      await withClock(Clock.fixed(DateTime(2026, 4, 19, 7, 00)), () async {
        final dayTwo = await service.markAsCooked('r1');
        expect(
          dayTwo,
          isTrue,
          reason:
              'session guard is day-bucketed so cooking the same recipe '
              'the next day must be counted',
        );
      });

      verify(() => repo.logCookEvent('r1', any())).called(2);
    });

    test(
      'empty recipeId short-circuits without touching the repository',
      () async {
        final ok = await service.markAsCooked('');
        expect(ok, isFalse);
        verifyNever(() => repo.logCookEvent(any(), any()));
      },
    );

    test(
      'repository failure bubbles up and does NOT poison the guard',
      () async {
        when(
          () => repo.logCookEvent(any(), any()),
        ).thenAnswer((_) async => false);

        await withClock(Clock.fixed(DateTime(2026, 4, 18, 10, 00)), () async {
          final firstAttempt = await service.markAsCooked('r1');
          expect(firstAttempt, isFalse);

          when(
            () => repo.logCookEvent(any(), any()),
          ).thenAnswer((_) async => true);

          final retry = await service.markAsCooked('r1');
          expect(
            retry,
            isTrue,
            reason:
                'a failed write must NOT mark the recipe as counted — '
                'the user needs to be able to retry',
          );
        });

        verify(() => repo.logCookEvent('r1', any())).called(2);
      },
    );

    test('passes a DateTime close to clock.now() to the repository', () async {
      DateTime? captured;
      when(() => repo.logCookEvent(any(), any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[1] as DateTime;
        return true;
      });

      final fixed = DateTime(2026, 4, 18, 12, 34, 56);
      await withClock(Clock.fixed(fixed), () async {
        await service.markAsCooked('r1');
      });

      expect(captured, equals(fixed));
    });

    test('threads attendeeMemberIds through to logCookEvent', () async {
      List<String>? captured;
      when(
        () => repo.logCookEvent(
          any(),
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      ).thenAnswer((inv) async {
        captured = inv.namedArguments[#attendeeMemberIds] as List<String>;
        return true;
      });

      await withClock(Clock.fixed(DateTime(2026, 4, 20, 18)), () async {
        await service.markAsCooked(
          'r1',
          attendeeMemberIds: const ['liam', 'u1'],
        );
      });

      expect(captured, ['liam', 'u1']);
    });

    test(
      'session guard suppresses a same-day repeat even when attendees differ',
      () async {
        when(
          () => repo.logCookEvent(
            any(),
            any(),
            attendeeMemberIds: any(named: 'attendeeMemberIds'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(DateTime(2026, 4, 21, 18)), () async {
          final first = await service.markAsCooked(
            'r1',
            attendeeMemberIds: const ['liam'],
          );
          final second = await service.markAsCooked(
            'r1',
            attendeeMemberIds: const ['emma'],
          );
          expect(first, isTrue);
          // Dedup key is recipe|day, NOT attendee-aware — a different attendee
          // set on the same recipe/day must still be one write, or rapid taps
          // would double-count.
          expect(second, isFalse);
        });

        verify(
          () => repo.logCookEvent(
            'r1',
            any(),
            attendeeMemberIds: any(named: 'attendeeMemberIds'),
          ),
        ).called(1);
      },
    );
  });
}
