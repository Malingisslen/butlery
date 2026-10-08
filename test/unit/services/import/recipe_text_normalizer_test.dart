import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';

void main() {
  final fp = ContentFingerprint();

  // BUT-1713: a unit token is stripped only when it stands alone, never when
  // it is inside a Swedish word.
  //
  // Measured, not assumed (2026-07-27): reverting
  // [RecipeTextNormalizer._allUnitsRe] to `\b` reddens exactly the FOUR
  // å/ä/ö cases below — "2 dl mjöl", "vitkål", "1 gul lök", "3 st rödlök".
  // The remaining seven are recall controls: they are identical under both
  // regexes and exist to prove the tightening did not stop stripping real
  // units. Do not delete them as redundant, and do not widen this claim.
  group('normalizeIngredientName — Swedish letters survive unit stripping', () {
    const cases = <String, String>{
      '2 dl mjöl': 'mjöl', // 'l' after 'ö' — was 'mjö'
      'vitkål': 'vitkål', // was 'vitkå'
      '1 gul lök': 'gul lök', // was 'gul ök'
      // Sharpest case: the unit sits WHOLLY INSIDE the word. "rödlök" has no
      // ASCII boundary before its 'l' (preceded by 'd'), but 'ö' on both sides
      // of "dl" opened two phantom ones, so `\bdl\b` matched mid-word — "3 st
      // rödlök" normalized to 'röök' (leading 'st' plus the embedded 'dl').
      '3 st rödlök': 'rödlök',
      '2 dl havregryn': 'havregryn',
      '1 dl mjölk': 'mjölk', // already correct — must stay correct
      // Real units must still be stripped, on both edges of the line.
      '500 g blandfärs': 'blandfärs',
      '1 påse socker': 'socker',
      '3 skivor bacon': 'bacon',
      '2 dl grädde': 'grädde',
      // BUT-1739: was the pinned quirk '2 grädde'. The amount regex is
      // anchored at `^`, so on a qualifier-prefixed line it saw no leading
      // digit and the stripped "ca" left the amount stranded — the same
      // ingredient fingerprinted two different ways depending on whether the
      // writer typed "ca". The qualifier is now removed first.
      'ca 2 dl grädde': 'grädde',
      'cirka 2 dl grädde': 'grädde',
      'ungefär 2 dl grädde': 'grädde',
      'ungefär 500 g potatis': 'potatis',
      'ca 1 kg högrev': 'högrev',
      // The qualifier is not required to be leading, and a line without one
      // is unaffected by the reordering.
      '2 dl ca grädde': 'grädde',
    };

    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () {
        expect(RecipeTextNormalizer.normalizeIngredientName(input), expected);
      });
    });
  });

  group('qualifier-invariance of duplicate matching', () {
    const bare = ['1 kg högrev', '2 st lök', '3 dl buljong', '500 g potatis'];
    const qualified = [
      'ca 1 kg högrev',
      '2 st lök',
      'ungefär 3 dl buljong',
      'cirka 500 g potatis',
    ];

    test('the same ingredients written with and without "ca/cirka/ungefär" '
        'match fully', () {
      expect(fp.ingredientSimilarity(bare, qualified), 1.0);
    });

    test('a genuinely different ingredient still lowers the match', () {
      // Recall control: the full match above must come from qualifier-stripping,
      // not from the comparison having gone blind to the ingredient list.
      expect(
        fp.ingredientSimilarity(bare, [...bare.take(3), '500 g rotselleri']),
        lessThan(1.0),
      );
    });
  });
}
