import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/menu/menu_pick_reasons.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

MenuPickSignals _signals({
  Set<String> recent = const {},
  bool recentKnown = true,
  MenuScoringContext context = MenuScoringContext.empty,
}) => MenuPickSignals(
  recentIds: recent,
  recentKnown: recentKnown,
  context: context,
  seasonTag: 'vinter',
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('MenuPickReasons', () {
    test(
      'a dish not on recent plans gets notRecent, a recent one does not',
      () {
        final fresh = RecipeFactory.build(id: 'a');
        final recent = RecipeFactory.build(id: 'b');
        final s = _signals(recent: {'b'});
        expect(
          MenuPickReasons.forRecipe(fresh, s),
          contains(MenuPickReason.notRecent),
        );
        expect(
          MenuPickReasons.forRecipe(recent, s),
          isNot(contains(MenuPickReason.notRecent)),
        );
      },
    );

    test('notRecent is never claimed when the earlier weeks were unread', () {
      final r = RecipeFactory.build(id: 'a');
      expect(
        MenuPickReasons.forRecipe(r, _signals(recentKnown: false)),
        isEmpty,
      );
    });

    test('seasonal only when the recipe carries the season tag', () {
      Recipe tagged(Set<String> tags) {
        final r = RecipeFactory.build(id: 'a');
        r.core.tagResult = TagResult(
          tags: tags,
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: 1.0,
          generatedAt: DateTime(2026),
        );
        return r;
      }

      final s = _signals(recentKnown: false);
      expect(MenuPickReasons.forRecipe(tagged({'vinter'}), s), [
        MenuPickReason.seasonal,
      ]);
      expect(MenuPickReasons.forRecipe(tagged({'sommar'}), s), isEmpty);
    });

    test('pantry reason needs real overlap', () {
      final r = RecipeFactory.build(id: 'a');
      final low = _signals(
        recentKnown: false,
        context: const MenuScoringContext(pantryMatchByRecipeId: {'a': 0.2}),
      );
      final high = _signals(
        recentKnown: false,
        context: const MenuScoringContext(pantryMatchByRecipeId: {'a': 0.8}),
      );
      expect(MenuPickReasons.forRecipe(r, low), isEmpty);
      expect(MenuPickReasons.forRecipe(r, high), [MenuPickReason.pantry]);
    });

    test('family favourite needs rated votes and a high average', () {
      Recipe withFamily(double avg, int count) {
        final r = RecipeFactory.build(id: 'a');
        r.core.familyAverage = avg;
        r.core.familyRatingCount = count;
        return r;
      }

      final s = _signals(recentKnown: false);
      expect(MenuPickReasons.forRecipe(withFamily(4.5, 3), s), [
        MenuPickReason.familyFavourite,
      ]);
      expect(MenuPickReasons.forRecipe(withFamily(4.5, 0), s), isEmpty);
      expect(MenuPickReasons.forRecipe(withFamily(3.0, 5), s), isEmpty);
    });
  });

  group('MenuService soft fallback count', () {
    test('a soft wish with no match is counted; a met one is not', () async {
      final service = MenuService(
        lexiconProvider: const CodeLexiconProvider(),
      );
      final pool = [
        for (var i = 0; i < 4; i++)
          RecipeFactory.build(id: 'd$i', mealType: 'middag'),
      ];
      ParsedMenuRequest request({required bool unmet}) => ParsedMenuRequest(
        slotRequests: [
          SlotRequest(
            mealType: 'middag',
            subRequests: [
              RecipeConstraint(
                count: 2,
                isSoft: true,
                requiredTags: unmet ? const {'finns-inte'} : const {},
              ),
            ],
          ),
        ],
        globalAllergenAvoid: const {},
        globalDietaryRequire: const {},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'x',
      );

      await service.generateMenuFromParsedRequest(request(unmet: true), pool);
      expect(service.lastSoftFallbackCount, 1);
      await service.generateMenuFromParsedRequest(request(unmet: false), pool);
      expect(service.lastSoftFallbackCount, 0);
    });
  });
}
