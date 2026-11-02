/// BUT-1508: the pantry watcher gets the pantry service and the user id from
/// its caller instead of looking them up.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';

class _MockPantryService extends Mock implements PantryService {}

void main() {
  test('watches the pantry of the given user through the given service', () {
    final service = _MockPantryService();
    final controller = StreamController<List<PantryItem>>();
    when(() => service.watchAll('u1')).thenAnswer((_) => controller.stream);
    var changes = 0;

    final watcher = RecipePantryWatcher(
      pantryService: service,
      userId: 'u1',
      onChanged: () => changes++,
    );
    addTearDown(() async {
      watcher.dispose();
      await controller.close();
    });

    verify(() => service.watchAll('u1')).called(1);
    controller.add(const []);
    return Future<void>.delayed(Duration.zero).then((_) {
      expect(changes, 1);
      expect(watcher.pantry, isEmpty);
    });
  });

  test('without a service or a user nothing is watched', () {
    final watcher = RecipePantryWatcher(
      pantryService: null,
      userId: 'u1',
      onChanged: () => fail('nothing to report'),
    );
    addTearDown(watcher.dispose);

    expect(watcher.pantry, isNull);
  });
}
