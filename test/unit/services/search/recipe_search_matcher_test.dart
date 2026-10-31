// This suite proves that a person typing into any recipe search box finds a
// recipe by anything they can see on it, with words allowed to land in
// different fields, and that their own tag edits decide what is findable.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/search/recipe_search_matcher.dart';

TagResult _tagResult({
  Set<String> tags = const {},
  Map<String, TriState> dietary = const {},
  Map<String, TriState> allergen = const {},
}) => TagResult(
  tags: tags,
  allergenStatus: allergen,
  dietaryStatus: dietary,
  coverage: 1.0,
  generatedAt: DateTime(2026, 1, 1),
);

/// A recipe whose visible text is deliberately unrelated to every query used
/// below, so a match can only come from the field under test.
Recipe _recipe({
  String title = 'Zzz',
  String description = '',
  String mealType = 'Qqq',
  List<String> ingredients = const [],
  List<String> instructions = const [],
  String? cuisine,
  String? sourceAuthor,
  int? portions,
  int? timeMinutes,
  double? rating,
  List<RecipePersonalTag>? personalTags,
  TagResult? tagResult,
  TagOverrides? tagOverrides,
}) {
  return Recipe(
    core: RecipeCore(
      id: 'r',
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTags: personalTags,
      cuisine: cuisine,
      sourceAuthor: sourceAuthor,
      tagResult: tagResult,
      tagOverrides: tagOverrides,
    ),
    type: RecipeType.personal,
  );
}

bool _finds(Recipe r, String q) => RecipeSearchMatcher.matches(r, q);

void main() {
  group('fields', () {
    test(
      'title',
      () => expect(_finds(_recipe(title: 'Lasagne'), 'lasag'), isTrue),
    );
    test(
      'description',
      () => expect(
        _finds(_recipe(description: 'Krämig och god'), 'kramig'),
        isTrue,
      ),
    );
    test(
      'meal type',
      () => expect(_finds(_recipe(mealType: 'Middag'), 'middag'), isTrue),
    );
    test(
      'ingredient',
      () => expect(
        _finds(_recipe(ingredients: ['2 dl grädde']), 'grädde'),
        isTrue,
      ),
    );
    test(
      'instruction',
      () => expect(
        _finds(_recipe(instructions: ['Vispa smeten slät']), 'vispa'),
        isTrue,
      ),
    );
    test(
      'cuisine',
      () =>
          expect(_finds(_recipe(cuisine: 'Thailändsk'), 'thailandsk'), isTrue),
    );
    test(
      'source author',
      () => expect(
        _finds(_recipe(sourceAuthor: 'Tessin Bror'), 'tessin'),
        isTrue,
      ),
    );
    test('personal tag and cookbook name', () {
      final r = _recipe(
        personalTags: [
          RecipePersonalTag.manual(tagId: 'a', name: 'Julbordet'),
          RecipePersonalTag.manual(tagId: 'b', name: 'Mammas kokbok'),
        ],
      );
      expect(_finds(r, 'julbordet'), isTrue);
      expect(_finds(r, 'mammas kokbok'), isTrue);
    });
    test('a word in none of the fields does not match', () {
      expect(_finds(_recipe(title: 'Lasagne'), 'sushi'), isFalse);
    });
  });

  group('auto tags', () {
    test('found by stored slug', () {
      final r = _recipe(tagResult: _tagResult(tags: {'noodle-dish'}));
      expect(_finds(r, 'noodle-dish'), isTrue);
    });

    test('found by a word only the Swedish display name carries', () {
      // 'noodle-dish' is shown as "Nudlar"; the slug has no "nudlar" in it.
      final tagged = _recipe(tagResult: _tagResult(tags: {'noodle-dish'}));
      expect(_finds(tagged, 'nudlar'), isTrue);
      expect(_finds(_recipe(), 'nudlar'), isFalse);
    });

    test('display name with "&" is found ("Fisk & skaldjur")', () {
      final r = _recipe(tagResult: _tagResult(tags: {'fisk-och-skaldjur'}));
      expect(_finds(r, 'fisk & skaldjur'), isTrue);
    });

    test('a tag the person removed is not findable', () {
      final r = _recipe(
        tagResult: _tagResult(tags: {'pasta-dish'}),
        tagOverrides: const TagOverrides(removedTags: {'pasta-dish'}),
      );
      expect(_finds(r, 'pasta'), isFalse);
    });

    test('a tag the person added is findable', () {
      final r = _recipe(
        tagResult: _tagResult(),
        tagOverrides: const TagOverrides(addedTags: {'fredagsmys'}),
      );
      expect(_finds(r, 'fredagsmys'), isTrue);
    });

    test('recipe with no tag result still searches its other fields', () {
      expect(_finds(_recipe(title: 'Soppa'), 'soppa'), isTrue);
      expect(_finds(_recipe(title: 'Soppa'), 'vegetarisk'), isFalse);
    });
  });

  group('dietary and allergen free-tags follow the effective status', () {
    test('vegetarisk matches only when status is free', () {
      expect(
        _finds(
          _recipe(
            tagResult: _tagResult(dietary: {'vegetarisk': TriState.free}),
          ),
          'vegetarisk',
        ),
        isTrue,
      );
      for (final s in [TriState.contains, TriState.unknown]) {
        expect(
          _finds(
            _recipe(tagResult: _tagResult(dietary: {'vegetarisk': s})),
            'vegetarisk',
          ),
          isFalse,
          reason: '$s must not be findable as vegetarian',
        );
      }
    });

    test('a dietary override flips it in both directions', () {
      final contains = _recipe(
        tagResult: _tagResult(dietary: {'vegetarisk': TriState.contains}),
        tagOverrides: const TagOverrides(
          dietaryOverrides: {'vegetarisk': TriState.free},
        ),
      );
      final free = _recipe(
        tagResult: _tagResult(dietary: {'vegetarisk': TriState.free}),
        tagOverrides: const TagOverrides(
          dietaryOverrides: {'vegetarisk': TriState.contains},
        ),
      );
      expect(_finds(contains, 'vegetarisk'), isTrue);
      expect(_finds(free, 'vegetarisk'), isFalse);
    });

    test('an override counts even where the tagger set no status', () {
      final r = _recipe(
        tagResult: _tagResult(),
        tagOverrides: const TagOverrides(
          dietaryOverrides: {'vegetarisk': TriState.free},
        ),
      );
      expect(_finds(r, 'vegetarisk'), isTrue);
    });

    test('glutenfri matches only when gluten is free', () {
      expect(
        _finds(
          _recipe(tagResult: _tagResult(allergen: {'gluten': TriState.free})),
          'glutenfri',
        ),
        isTrue,
      );
      expect(
        _finds(
          _recipe(
            tagResult: _tagResult(allergen: {'gluten': TriState.contains}),
          ),
          'glutenfri',
        ),
        isFalse,
      );
    });

    test('an allergen override flips it in both directions', () {
      final nowFree = _recipe(
        tagResult: _tagResult(allergen: {'gluten': TriState.contains}),
        tagOverrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.free},
        ),
      );
      final nowContains = _recipe(
        tagResult: _tagResult(allergen: {'gluten': TriState.free}),
        tagOverrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.contains},
        ),
      );
      expect(_finds(nowFree, 'glutenfri'), isTrue);
      expect(_finds(nowContains, 'glutenfri'), isFalse);
    });
  });

  group('multi-word queries', () {
    test('words may match different fields', () {
      final r = _recipe(
        ingredients: ['500 g kycklingfilé'],
        tagResult: _tagResult(tags: {'ugnsbakad'}),
      );
      expect(_finds(r, 'kyckling ugnsbakad'), isTrue);
    });

    test('every word must match somewhere', () {
      final r = _recipe(
        ingredients: ['500 g kycklingfilé'],
        tagResult: _tagResult(tags: {'ugnsbakad'}),
      );
      expect(_finds(r, 'kyckling grillad'), isFalse);
    });
  });

  group('folding', () {
    test('å ä ö fold to a o in both query and recipe', () {
      final r = _recipe(title: 'Köttbullar');
      expect(_finds(r, 'kottbullar'), isTrue);
      expect(_finds(r, 'KÖTTBULLAR'), isTrue);
      expect(_finds(_recipe(title: 'Gräddsås'), 'graddsas'), isTrue);
    });

    test('accents fold: creme finds crème and the reverse', () {
      expect(_finds(_recipe(title: 'Crème brûlée'), 'creme brulee'), isTrue);
      expect(_finds(_recipe(title: 'Creme'), 'crème'), isTrue);
    });
  });

  group('empty and numeric queries', () {
    test('empty and whitespace queries return every recipe', () {
      final all = [_recipe(title: 'A'), _recipe(title: 'B')];
      expect(RecipeSearchMatcher.filter(all, ''), hasLength(2));
      expect(RecipeSearchMatcher.filter(all, '   \t '), hasLength(2));
    });

    test('an empty query returns a copy, so sorting it leaves the input', () {
      final all = [_recipe(title: 'B'), _recipe(title: 'A')];
      final result = RecipeSearchMatcher.filter(all, '')
        ..sort((x, y) => x.title.compareTo(y.title));
      expect(identical(result, all), isFalse);
      expect(all.map((r) => r.title), ['B', 'A']);
    });

    test('a number matches portions, time and rating', () {
      expect(_finds(_recipe(portions: 6), '6'), isTrue);
      expect(_finds(_recipe(timeMinutes: 45), '45'), isTrue);
      expect(_finds(_recipe(rating: 4.5), '4.5'), isTrue);
      expect(_finds(_recipe(portions: 6, timeMinutes: 45), '99'), isFalse);
    });

    test('a non-numeric word never matches the numeric fields', () {
      expect(_finds(_recipe(portions: 6), 'six'), isFalse);
    });

    test('filter keeps only matching recipes, in order', () {
      final a = _recipe(title: 'Pasta A');
      final b = _recipe(title: 'Soppa');
      final c = _recipe(title: 'Pasta C');
      expect(RecipeSearchMatcher.filter([a, b, c], 'pasta'), [a, c]);
    });
  });
}
