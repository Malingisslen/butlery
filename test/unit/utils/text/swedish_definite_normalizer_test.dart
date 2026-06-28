/// Direct unit tests for [SwedishDefiniteNormalizer] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Strips Swedish definite-form suffixes ("citronen" → "citron") so the CRF
/// feature extractor can match ingredients written in definite form. Decisions
/// hinge on KnownIngredients membership, so each strip test asserts BOTH premises
/// — the base IS known and the definite form is NOT (the normalizer no-ops on
/// already-known words, so a word whose definite form is itself in the lexicon,
/// like "löken", has nothing to strip). Definite forms are built by appending the
/// suffix to the base literal so the å/ä/ö bytes always match the base.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/utils/text/swedish_definite_normalizer.dart';

void main() {
  group('tryNormalize strips definite suffixes to a known base', () {
    test('-en (common gender): citron+en → citron', () {
      const base = 'citron';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}en'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}en'), base);
    });

    test('-et (neuter): smör+et → smör', () {
      const base = 'smör';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}et'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}et'), base);
    });

    test('-erna (definite plural): tomat+erna → tomat', () {
      const base = 'tomat';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}erna'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}erna'), base);
    });

    test('-na (definite plural): äpple+na → äpple', () {
      const base = 'äpple';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}na'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}na'), base);
    });

    test('-n after a vowel: pasta+n → pasta', () {
      const base = 'pasta';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}n'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}n'), base);
    });

    test('-en with -e restoration: grädde → grädden → grädde', () {
      const base = 'grädde';
      expect(KnownIngredients.isKnown(base), isTrue);
      // Definite of "grädde" is "grädden" (grädde + n); -en strip gives "grädd"
      // (not known) so the +e restoration branch must rebuild "grädde".
      expect(KnownIngredients.isKnown('${base}n'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}n'), base);
    });

    test('informal doubled consonant: lök+ken → lök', () {
      const base = 'lök';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(KnownIngredients.isKnown('${base}ken'), isFalse);
      expect(SwedishDefiniteNormalizer.tryNormalize('${base}ken'), base);
    });
  });

  group('tryNormalize returns null', () {
    test('when the word is already a known ingredient (no over-stripping)', () {
      const base = 'lök';
      expect(KnownIngredients.isKnown(base), isTrue);
      expect(SwedishDefiniteNormalizer.tryNormalize(base), isNull);
    });

    test('for words shorter than the minimum length', () {
      expect(SwedishDefiniteNormalizer.tryNormalize('ris'), isNull);
    });

    test('when stripping does not yield a known ingredient', () {
      expect(SwedishDefiniteNormalizer.tryNormalize('xyzzyen'), isNull);
    });
  });

  group('normalize / isDefiniteForm', () {
    test('normalize returns the base form (case-insensitively)', () {
      const base = 'citron';
      expect(
        SwedishDefiniteNormalizer.normalize('${base}en'.toUpperCase()),
        base,
      );
    });

    test('normalize returns the lowercased original when no base matches', () {
      expect(SwedishDefiniteNormalizer.normalize('Foobarxyz'), 'foobarxyz');
    });

    test('isDefiniteForm is true for a definite form, false for the base', () {
      const base = 'citron';
      expect(SwedishDefiniteNormalizer.isDefiniteForm('${base}en'), isTrue);
      expect(SwedishDefiniteNormalizer.isDefiniteForm(base), isFalse);
    });
  });
}
