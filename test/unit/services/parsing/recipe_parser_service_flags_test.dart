/// The heading-capture kill switch reaches the tiers through the parser
/// service: switching it off must keep the section headings as ingredient
/// lines, switching nothing must stamp the sections.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

const _grouped = '''
Kanelbullar

Ingredienser:
Deg:
5 dl vetemjöl
25 g jäst
Fyllning:
75 g smör
2 msk kanel

Gör så här:
Baka allt.
Servera.
''';

void main() {
  Future<List<String?>> sectionsFrom(RecipeParserService service) async {
    final result = await service.parseFromText(text: _grouped, useLlm: false);
    expect(result.success, isTrue);
    return result.recipe!.ingredients.value!.map((i) => i.section).toList();
  }

  test('with the switch on the sections are stamped', () async {
    final flags = _MockFeatureFlags();
    when(
      () => flags.isEnabled(FeatureFlags.ingredientSectionCapture),
    ).thenReturn(true);
    final service = RecipeParserService(
      getCurrentUserId: () => 'u',
      getFeatureFlags: () => flags,
    );

    expect(await sectionsFrom(service), contains('Deg'));
  });

  test('with the switch off no section is stamped', () async {
    final flags = _MockFeatureFlags();
    when(
      () => flags.isEnabled(FeatureFlags.ingredientSectionCapture),
    ).thenReturn(false);
    final service = RecipeParserService(
      getCurrentUserId: () => 'u',
      getFeatureFlags: () => flags,
    );

    expect(await sectionsFrom(service), everyElement(isNull));
  });
}
