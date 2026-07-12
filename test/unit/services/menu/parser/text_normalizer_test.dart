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

  group('stripSpokenFillers', () {
    test('removes standalone filler tokens', () {
      expect(
        stripSpokenFillers('eh alltså tre middagar typ'),
        'tre middagar',
      );
    });

    test('removes multi-word filler phrases', () {
      expect(
        stripSpokenFillers('tre middagar du vet och två luncher'),
        'tre middagar och två luncher',
      );
    });

    test('never strips fillers as substrings of real words', () {
      // "typ" inside "typisk", "va" inside "varje", "ba" inside "bara".
      expect(
        stripSpokenFillers('typisk husmanskost varje dag bara'),
        'typisk husmanskost varje dag bara',
      );
    });

    test('leaves a clean typed prompt unchanged', () {
      expect(
        stripSpokenFillers('tre middagar och två vegetariska'),
        'tre middagar och två vegetariska',
      );
    });
  });

  group('resolveSelfCorrections', () {
    const numbers = [
      ['en', 'två', 'tre', 'fyra', 'fem', 'åtta', 'nio'],
    ];
    const dietary = [
      ['vegetarisk', 'vegetariskt', 'vegansk', 'veganskt'],
    ];

    String resolve(String s) => resolveSelfCorrections(
      s,
      exactVocabularies: numbers,
      stemVocabularies: dietary,
    );

    test('digit correction: last wins', () {
      expect(resolveSelfCorrections('3 nej 4 middagar'), '4 middagar');
    });

    test('number-word correction with comma: last wins', () {
      expect(resolve('tre, nej fyra middagar'), 'fyra middagar');
    });

    test('multi-word marker: "nej förlåt"', () {
      expect(resolve('tre nej förlåt fyra middagar'), 'fyra middagar');
    });

    test('em-dash separated correction', () {
      expect(resolve('tre — nej fyra middagar'), 'fyra middagar');
    });

    test('chained corrections resolve to the final value', () {
      expect(resolve('tre nej fyra nej fem middagar'), 'fem middagar');
    });

    test('å/ä/ö values work despite ASCII-only \\b (två, åtta, nio)', () {
      // Dart's \b treats å/ä/ö as non-word chars — the explicit lookarounds
      // must handle values that start or end with them.
      expect(resolve('tre, nej två middagar'), 'två middagar');
      expect(resolve('åtta, nej nio middagar'), 'nio middagar');
    });

    test('restated-phrase correction drops the whole retracted phrase', () {
      expect(
        resolve('tre middagar nej fyra middagar'),
        'fyra middagar',
      );
    });

    test('restated phrase resolves across a plural→singular shift', () {
      // Natural Swedish: correcting down to one forces the noun singular.
      // An exact backreference would miss this — nouns match by stem.
      expect(
        resolve('två middagar, nej en middag'),
        'en middag',
      );
    });

    test('mixed digit/word renderings pair up (Whisper inconsistency)', () {
      expect(resolve('tre, nej 4 middagar'), '4 middagar');
      expect(resolve('4, nej tre middagar'), 'tre middagar');
    });

    test('restated phrase requires the SAME noun on both sides', () {
      expect(
        resolve('tre dagar nej fyra veckor'),
        'tre dagar nej fyra veckor',
      );
    });

    test('same-category dietary correction with inflection suffix', () {
      expect(resolve('vegetariskt nej veganskt'), 'veganskt');
    });

    test('exact-match numbers: an inflected lookalike is NOT a number', () {
      // "trevliga" must not be treated as a retraction target/replacement
      // for "tre" — numbers are whole-word matches only.
      expect(
        resolve('fyra, nej trevliga middagar'),
        'fyra, nej trevliga middagar',
      );
    });

    test('no false boundary inside words (råtta is not åtta)', () {
      expect(
        resolve('råtta nej nio middagar'),
        'råtta nej nio middagar',
      );
    });

    test('marker between DIFFERENT vocabularies never deletes content', () {
      // "tre" is a number, "vegetariskt" is dietary — not a correction pair.
      expect(resolve('tre nej vegetariskt'), 'tre nej vegetariskt');
    });

    test('a lone marker with no preceding value is untouched', () {
      expect(resolve('nej fyra middagar'), 'nej fyra middagar');
    });
  });
}
