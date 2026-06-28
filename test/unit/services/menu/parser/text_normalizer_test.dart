/// Direct unit tests for text_normalizer (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure Swedish-prompt text utilities for the menu-constraint parser: prompt
/// normalization, diacritic stripping (a fallback for fuzzy matching), polite-
/// preamble removal, and the Levenshtein≤1 fuzzy lookup. No mocks, no IO.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu/parser/text_normalizer.dart';

void main() {
  group('normalize', () {
    test('lowercases, trims, and collapses whitespace', () {
      expect(normalize('  Köttbullar   med   Mos  '), 'köttbullar med mos');
    });

    test('replaces sentence punctuation with spaces', () {
      expect(normalize('Hej! Vad? Bra.'), 'hej vad bra');
    });

    test('empty / whitespace-only input normalizes to empty', () {
      expect(normalize('   '), '');
    });
  });

  group('stripDiacritics', () {
    test('maps Swedish diacritics to bare ASCII', () {
      expect(stripDiacritics('åäöéèü'), 'aaoeeu');
    });

    test('leaves plain ASCII untouched', () {
      expect(stripDiacritics('vegansk'), 'vegansk');
    });
  });

  group('stripPolitePreamble', () {
    const preamble = ['kan du', 'kan', 'snälla'];

    test('strips a leading preamble word', () {
      expect(
        stripPolitePreamble('snälla fixa middag', preamble),
        'fixa middag',
      );
    });

    test('matches the longest preamble first ("kan du" over "kan")', () {
      expect(
        stripPolitePreamble('kan du laga middag', preamble),
        'laga middag',
      );
    });

    test('handles a comma after the preamble', () {
      expect(
        stripPolitePreamble('snälla, laga middag', preamble),
        'laga middag',
      );
    });

    test('strips repeated preambles until none remain', () {
      expect(stripPolitePreamble('kan kan laga', preamble), 'laga');
    });

    test('leaves a prompt with no preamble unchanged', () {
      expect(stripPolitePreamble('laga middag', preamble), 'laga middag');
    });
  });

  group('levenshtein1Lookup', () {
    const candidates = {'vegansk': 'vegan', 'kyckling': 'chicken'};

    test('returns null for tokens shorter than 6 chars', () {
      expect(levenshtein1Lookup('veg', candidates), isNull);
      expect(levenshtein1Lookup('vegan', const {'vegan': 'x'}), isNull);
    });

    test('matches a token within edit distance 1 (one insertion)', () {
      expect(levenshtein1Lookup('veganskt', candidates), 'vegan');
    });

    test('matches a token within edit distance 1 (one substitution)', () {
      expect(levenshtein1Lookup('vegankk', candidates), 'vegan');
    });

    test('returns null when two candidates are equally close (ambiguous)', () {
      // 'xanana' is one substitution from both keys → ambiguous → bail.
      expect(
        levenshtein1Lookup('xanana', const {'banana': 'a', 'canana': 'b'}),
        isNull,
      );
    });

    test('returns null when nothing is within distance 1', () {
      expect(levenshtein1Lookup('zzzzzz', candidates), isNull);
    });
  });
}
