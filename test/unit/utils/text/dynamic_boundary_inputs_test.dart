/// Pins the data behind the `// swedish-boundary-ok:` markers (BUT-1717): an
/// ASCII `\b` in a pattern built at runtime is only safe while the values it is
/// built from keep å/ä/ö off the edge the `\b` touches.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/moderation/content_filter_words.dart';

bool _isAscii(String s) => s.runes.every((r) => r < 128);

void main() {
  test('approximate words keep å/ä/ö off both edges', () {
    expect(RecipeTextNormalizer.approximateWords, isNotEmpty);
    for (final w in RecipeTextNormalizer.approximateWords) {
      expect(_isAscii(w[0]), isTrue, reason: 'first char of "$w"');
      expect(_isAscii(w[w.length - 1]), isTrue, reason: 'last char of "$w"');
    }
  });

  test('ingredient units are ASCII once å/ä/ö are folded', () {
    expect(RecipeTextNormalizer.ingredientUnits, isNotEmpty);
    for (final u in RecipeTextNormalizer.ingredientUnits) {
      final folded = u
          .replaceAll('å', 'a')
          .replaceAll('ä', 'a')
          .replaceAll('ö', 'o');
      expect(_isAscii(folded), isTrue, reason: '"$u"');
    }
  });

  test('code-lexicon day names and verbs start with an ASCII letter', () async {
    final lexicon = await const CodeLexiconProvider().load();
    for (final category in [
      LexiconCategory.dayNames,
      LexiconCategory.verbObjectMap,
    ]) {
      expect(lexicon.of(category), isNotEmpty, reason: category.name);
      for (final key in lexicon.of(category).keys) {
        expect(_isAscii(key[0]), isTrue, reason: '${category.name}: "$key"');
      }
    }
  });

  test('profanity entries are ASCII', () {
    expect(swedishProfanity, isNotEmpty);
    expect(englishProfanity, isNotEmpty);
    for (final w in [...swedishProfanity, ...englishProfanity]) {
      expect(_isAscii(w), isTrue, reason: '"$w"');
    }
  });
}
