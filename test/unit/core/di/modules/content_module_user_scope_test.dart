/// The cold-start ingredient load runs before sign-in, when the ingredients
/// read is denied, so the list must be fetched again once a user is signed
/// in. Without that, the first save of the session pays the whole load inside
/// its tagging step.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';

class _MockIngredientRepository extends Mock implements IngredientRepository {}

void main() {
  late _MockIngredientRepository repo;
  late IngredientRegistryService registry;
  late GetIt userScope;

  setUp(() {
    repo = _MockIngredientRepository();
    when(() => repo.getByGroup(any())).thenAnswer((_) async => []);
    when(() => repo.getByGroup('spice')).thenAnswer(
      (_) async => [
        const IngredientData(
          id: 'firestoreonlyspice',
          swedish: 'firestoreonlyspice',
          english: 'firestoreonlyspice',
          group: 'spice',
          properties: {},
        ),
      ],
    );
    registry = IngredientRegistryService(ingredientRepository: repo);
    GetIt.instance.registerSingleton<IngredientRegistryService>(registry);
    userScope = GetIt.asNewInstance();
  });

  tearDown(() async {
    await userScope.reset();
    await GetIt.instance.unregister<IngredientRegistryService>();
  });

  test('signing in loads the ingredient list into the registry', () async {
    await ContentModule().configureUserScope(userScope);
    await pumpEventQueue();

    expect(registry.allIngredients, contains('firestoreonlyspice'));
  });
}
