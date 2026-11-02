import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';

class _IngredientRepo extends Mock implements IngredientRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loading the weights asks the registry link for enriched names once',
    () async {
      var asked = 0;
      final registry = IngredientRegistryService(
        ingredientRepository: _IngredientRepo(),
      );
      final strategy = IngredientParsingStrategy(
        registry: () {
          asked++;
          return registry;
        },
      );

      await strategy.parseLine('2 dl mjölk');
      await strategy.parseLine('1 ägg');

      expect(strategy.hasCrf, isTrue);
      expect(asked, 1);
    },
  );

  test(
    'without a registry link the strategy still loads its weights',
    () async {
      final strategy = IngredientParsingStrategy();

      await strategy.parseLine('2 dl mjölk');

      expect(strategy.hasCrf, isTrue);
    },
  );
}
