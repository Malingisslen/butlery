/// BUT-1037: unit tests for [RecipeTextHeuristic] — the cheap gate that decides
/// whether pasted text is worth a paid LLM parse. The contract that matters:
/// real recipes (sv + en, including an ingredient-only paste) pass; non-recipe
/// content (chat, article, gibberish) is rejected so the warn dialog can fire.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/recipe_text_heuristic.dart';

void main() {
  group('RecipeTextHeuristic.looksLikeRecipe', () {
    test('typical Swedish recipe → true', () {
      const text = '''
Pannkakor
2 dl vetemjöl, 1 tsk salt, 3 ägg, 5 dl mjölk.
Blanda mjöl och salt. Tillsätt ägg och mjölk. Grädda i stekpanna.
''';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isTrue);
    });

    test('typical English recipe → true', () {
      const text = '''
Pancakes
2 cups flour, 1 tbsp sugar, 2 eggs, 1 cup milk.
Mix the dry ingredients. Add eggs and milk. Fry until golden.
''';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isTrue);
    });

    test('ingredient-only paste (amounts, no verbs) → true', () {
      // ≥3 measurement hits clears the total-hits threshold even with no verb.
      const text = '200 g smör\n3 dl socker\n4 ägg\n5 dl vetemjöl';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isTrue);
    });

    test('English metric recipe (g, not cups) → true', () {
      const text = 'Combine 200 g flour and 100 ml water, then bake.';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isTrue);
    });

    test('conversation snippet → false', () {
      const text =
          'Hey, are we still meeting at 8 tonight? I can bring the documents '
          'if you want, just let me know what works for you.';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isFalse);
    });

    test('news article snippet → false', () {
      const text =
          'The committee announced on Tuesday that the new policy would take '
          'effect next month, following months of public consultation and debate.';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isFalse);
    });

    test('gibberish → false', () {
      const text = 'asdf qwer zxcv hjkl poiu mnbv lkjh gfds';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isFalse);
    });

    test('empty / too-short → false', () {
      expect(RecipeTextHeuristic.looksLikeRecipe(''), isFalse);
      expect(RecipeTextHeuristic.looksLikeRecipe('mix'), isFalse);
    });

    test('does not match units inside other words', () {
      // "good loaf great" contains g/l/oz-like substrings but no whole-word
      // units; a single verb ("bake") alone must not pass.
      const text =
          'a good story about a great loaf that someone will bake one day';
      expect(RecipeTextHeuristic.looksLikeRecipe(text), isFalse);
    });

    test('characterization: lenient by design — one unit + one verb passes', () {
      // Pins the DELIBERATE false-positive tolerance: a single standalone unit
      // plus a cooking verb in ordinary prose passes. This is intentional —
      // never block a real recipe — so a future "tighten the gate" change must
      // consciously update this expectation rather than silently regress.
      expect(
        RecipeTextHeuristic.looksLikeRecipe(
          'I weigh 80 kg and I cook dinner most evenings.',
        ),
        isTrue,
      );
    });
  });
}
