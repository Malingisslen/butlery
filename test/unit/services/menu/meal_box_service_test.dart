/// BUT-2486 part 5: listing the fridge and freezer boxes folds eaten lunches
/// into the count and tidies away long-empty boxes.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/meal_box_repository.dart';
import 'package:butlery/services/menu/meal_box_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements MealBoxRepository {}

MealBox _box(
  String id, {
  int count = 0,
  Map<String, int> takes = const {},
  DateTime? updatedAt,
}) => MealBox(
  id: id,
  recipeId: 'r-$id',
  recipeTitle: 'Gryta $id',
  location: MealBoxLocation.fridge,
  storedOn: DateTime(2025, 12, 1),
  count: count,
  takes: takes,
  updatedAt: updatedAt,
);

void main() {
  final today = DateTime(2026, 1, 10, 12);

  late _MockRepo repo;
  late MealBoxService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_box('fallback'));
    registerFallbackValue(<String>[]);
    registerFallbackValue(MealBoxLocation.fridge);
    registerFallbackValue(DateTime(2026));
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.foldTakes(any(), any())).thenAnswer((_) async {});
    when(() => repo.delete(any())).thenAnswer((_) async {});
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = MealBoxService(repository: repo);
  });

  Future<List<MealBox>> listToday(List<MealBox> stored) {
    when(() => repo.list()).thenAnswer((_) async => stored);
    return withClock(Clock.fixed(today), service.list);
  }

  test(
    'folds lunches before today into the count and shows the reduced box',
    () async {
      final box = _box(
        'a',
        count: 5,
        takes: {'2026-01-05': 2, '2026-01-09': 1, '2026-01-10': 1},
        updatedAt: DateTime(2026, 1, 1),
      );

      final shown = await listToday([box]);

      final keys =
          verify(() => repo.foldTakes(box, captureAny())).captured.single
              as Iterable<String>;
      expect(keys.toSet(), {'2026-01-05', '2026-01-09'});
      expect(shown.single.count, 2);
      expect(shown.single.takes, {'2026-01-10': 1});
      verifyNever(() => repo.delete(any()));
    },
  );

  test('a box with no past lunches is not written', () async {
    final box = _box('a', count: 3, takes: {'2026-01-10': 1});

    final shown = await listToday([box]);

    verifyNever(() => repo.foldTakes(any(), any()));
    expect(shown.single, same(box));
  });

  test('an empty box older than 30 days is deleted and not returned', () async {
    final stale = _box(
      'stale',
      updatedAt: today.subtract(const Duration(days: 31)),
    );

    final shown = await listToday([stale]);

    expect(shown, isEmpty);
    verify(() => repo.delete('stale')).called(1);
  });

  test('an empty box younger than 30 days is kept for an undo', () async {
    final recent = _box(
      'recent',
      updatedAt: today.subtract(const Duration(days: 29)),
    );

    final shown = await listToday([recent]);

    expect(shown.single.id, 'recent');
    verifyNever(() => repo.delete(any()));
  });

  test('an old box that still holds food is kept', () async {
    final old = _box(
      'old',
      count: 1,
      updatedAt: today.subtract(const Duration(days: 90)),
    );

    final shown = await listToday([old]);

    expect(shown.single.id, 'old');
    verifyNever(() => repo.delete(any()));
  });

  test('a box emptied by folding today gets its own 30 days', () async {
    final box = _box(
      'a',
      count: 1,
      takes: {'2026-01-05': 1},
      updatedAt: today.subtract(const Duration(days: 90)),
    );

    final shown = await listToday([box]);

    expect(shown.single.count, 0);
    verifyNever(() => repo.delete(any()));
  });

  test('a failed fold still returns the box and the others', () async {
    final failing = _box('bad', count: 3, takes: {'2026-01-05': 1});
    final fine = _box('fine', count: 2);
    when(() => repo.foldTakes(any(), any())).thenThrow(StateError('offline'));

    final shown = await listToday([failing, fine]);

    verify(() => repo.foldTakes(failing, any())).called(1);
    expect(shown.map((b) => b.id), ['bad', 'fine']);
    expect(shown.first.count, 3);
  });

  test('a failed delete still returns the box', () async {
    final stale = _box(
      'stale',
      updatedAt: today.subtract(const Duration(days: 40)),
    );
    when(() => repo.delete(any())).thenThrow(StateError('denied'));

    final shown = await listToday([stale]);

    verify(() => repo.delete('stale')).called(1);
    expect(shown.single.id, 'stale');
  });

  group('writes (part 5b)', () {
    test('a blank title is refused before anything is written', () async {
      final blank = MealBox(
        id: '',
        recipeTitle: '   ',
        location: MealBoxLocation.fridge,
        storedOn: DateTime(2026, 1, 10),
        count: 2,
      );

      await expectLater(service.add(blank), throwsArgumentError);
      verifyNever(() => repo.add(any()));
    });

    test('add returns the id the repository gave', () async {
      when(() => repo.add(any())).thenAnswer((_) async => 'new-id');

      expect(await service.add(_box('x', count: 2)), 'new-id');
    });

    test('setRemaining keeps the boxes planned lunches take', () async {
      when(() => repo.setCount(any(), any())).thenAnswer((_) async {});
      final box = _box('a', count: 5, takes: {'2026-01-12': 2});

      await service.setRemaining(box, 2);

      verify(() => repo.setCount('a', 4)).called(1);
    });

    test('setRemaining never stores more than the rules allow', () async {
      when(() => repo.setCount(any(), any())).thenAnswer((_) async {});
      final box = _box('a', count: 99, takes: {'2026-01-12': 3});

      await service.setRemaining(box, 99);

      verify(() => repo.setCount('a', MealBox.maxCount)).called(1);
    });

    test('a refused count reaches the caller', () async {
      when(() => repo.setCount(any(), any())).thenThrow(StateError('denied'));

      await expectLater(service.setCount('a', 1), throwsStateError);
    });

    test(
      'a date in the future is refused before anything is written',
      () async {
        await expectLater(
          withClock(
            Clock.fixed(today),
            () => service.setStoredOn('a', today.add(const Duration(days: 1))),
          ),
          throwsArgumentError,
        );
        verifyNever(() => repo.setStoredOn(any(), any()));
      },
    );

    test('a box with nothing left is not moved', () async {
      final box = _box('a', count: 2, takes: {'2026-01-12': 2});

      await expectLater(
        service.move(box, MealBoxLocation.freezer),
        throwsArgumentError,
      );
      verifyNever(() => repo.move(any(), any(), any()));
    });

    test('a box is not moved to where it already is', () async {
      await expectLater(
        service.move(_box('a', count: 2), MealBoxLocation.fridge),
        throwsArgumentError,
      );
    });

    test('a move is dated today and returns the new id', () async {
      when(() => repo.move(any(), any(), any())).thenAnswer((_) async => 'b');
      final box = _box('a', count: 2);

      final id = await withClock(
        Clock.fixed(today),
        () => service.move(box, MealBoxLocation.freezer),
      );

      expect(id, 'b');
      verify(() => repo.move(box, MealBoxLocation.freezer, today)).called(1);
    });

    test('a box with one portion left can still be moved', () async {
      when(() => repo.move(any(), any(), any())).thenAnswer((_) async => 'b');
      final box = _box('a', count: 3, takes: {'2026-01-12': 2});

      await withClock(
        Clock.fixed(today),
        () => service.move(box, MealBoxLocation.freezer),
      );

      verify(() => repo.move(box, MealBoxLocation.freezer, today)).called(1);
    });

    test('a date up to now is written', () async {
      when(() => repo.setStoredOn(any(), any())).thenAnswer((_) async {});

      await withClock(Clock.fixed(today), () async {
        await service.setStoredOn('a', DateTime(2026, 1, 3));
        await service.setStoredOn('a', today);
      });

      verify(() => repo.setStoredOn('a', DateTime(2026, 1, 3))).called(1);
      verify(() => repo.setStoredOn('a', today)).called(1);
    });

    test('restore and undoMove reach their own repository calls', () async {
      when(() => repo.restore(any())).thenAnswer((_) async {});
      when(() => repo.undoMove(any(), any())).thenAnswer((_) async {});
      final box = _box('a', count: 2);

      await service.restore(box);
      await service.undoMove(box, 'b');

      verify(() => repo.restore(box)).called(1);
      verify(() => repo.undoMove(box, 'b')).called(1);
      verifyNever(() => repo.delete(any()));
    });

    test('a refused delete reaches the caller', () async {
      when(() => repo.delete(any())).thenThrow(StateError('denied'));

      await expectLater(service.remove('a'), throwsStateError);
    });
  });

  test('shown hides a box with nothing left and no lunch planned', () {
    final emptied = _box('empty');
    final planned = _box('planned', takes: {'2026-01-12': 1});
    final full = _box('full', count: 2);

    expect(
      MealBoxService.shown([emptied, planned, full]).map((b) => b.id),
      ['planned', 'full'],
    );
  });
}
