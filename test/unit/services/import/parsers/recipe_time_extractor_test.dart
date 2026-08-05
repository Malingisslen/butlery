import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/parsers/recipe_time_extractor.dart';

/// Fixtures are taken verbatim from `butlery-corpus` OCR pages wherever the
/// corpus has the form — the labels, the composite and the resting-time trap
/// are all shapes that occur on real photographed pages, not invented ones.
void main() {
  group('RecipeTimeExtractor', () {
    test('reads an explicit total label', () {
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 50 minuter'),
        equals(50),
      );
      expect(RecipeTimeExtractor.extract('Total tid: 1 timme'), equals(60));
    });

    test('reads a phase label when no total is present', () {
      for (final label in const [
        'Koktid',
        'Gräddningstid',
        'Bakningstid',
        'Friteringstid',
        'Stektid',
        'Ugnstid',
      ]) {
        expect(
          RecipeTimeExtractor.extract('$label: 25 min'),
          equals(25),
          reason: '$label should be read as the dish time',
        );
      }
    });

    test('a total outranks a phase on the same page', () {
      const page = '''
Koktid: 20 minuter
Tillagningstid: 45 minuter''';
      expect(RecipeTimeExtractor.extract(page), equals(45));
    });

    test('the total wins even when the phase is listed first and is longer', () {
      // Order must not decide it — the earlier code took whichever number came
      // first, which is exactly the failure this class exists to remove.
      const page = '''
Gräddningstid: 90 minuter
Tillagningstid: 30 minuter''';
      expect(RecipeTimeExtractor.extract(page), equals(30));
    });

    test('resting time is never the answer', () {
      // The shape this class exists for: "Fin sillsallad" is a 45-minute
      // recipe on a corpus page that also says "Vilotid: minst 2 timmar", and
      // an unlabelled scavenge can come back with the 2 hours.
      const page = '''
Fin sillsallad
Tillagningstid: 45 minuter
Vilotid: minst 2 timmar''';
      expect(RecipeTimeExtractor.extract(page), equals(45));
    });

    test('a wait label COLLAPSED onto the work line does not discard it', () {
      // OCR merges adjacent bullet rows. Skipping any line that mentions a
      // wait label handed exactly this shape to the cruder fallback, which
      // answered with the 2 hours. Both orders, because reading the first
      // number on the line is right in one and wrong in the other.
      expect(
        RecipeTimeExtractor.extract(
          'Tillagningstid: 45 minuter Vilotid: 2 timmar',
        ),
        equals(45),
      );
      expect(
        RecipeTimeExtractor.extract(
          'Vilotid: 2 timmar Tillagningstid: 45 minuter',
        ),
        equals(45),
      );
    });

    test('the wait segment of a collapsed row is cut off, not read', () {
      // The ONLY thing `_waitPattern` still does is truncate the tail after a
      // work label at any following wait label. Measured 2026-08-05: with that
      // truncation deleted, all 20 other fixtures in this file answer
      // identically — every one of them puts the work NUMBER between the work
      // label and the wait label, so taking the first duration in the tail is
      // right either way, and the whole five-label wait list was pinned by
      // nothing.
      //
      // The discriminating shape is a collapsed row whose work value did not
      // survive OCR. Then the first duration after the work label belongs to
      // the WAIT, and answering it would report two hours of resting as the
      // cooking time. null hands the page back to the caller's cruder
      // fallback, which is the safe answer.
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: Vilotid: 2 timmar'),
        isNull,
      );
      expect(RecipeTimeExtractor.extract('Koktid — Jästid: 2 timmar'), isNull);
      // Positive control, same shape: with the work value present the label
      // IS read, so the nulls above cannot be explained by the line having
      // been skipped before `_minutesAfter` ever ran.
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 45 min Vilotid: 2 timmar'),
        equals(45),
      );
    });

    test('a bare "Tid:" total still outranks a phase label', () {
      // `tid` is only safe on the total list because the boundary helper stops
      // it matching inside "koktid"/"vilotid". If that ever regresses, this
      // returns 60.
      expect(
        RecipeTimeExtractor.extract('Tid: 30 min\nKoktid: 60 min'),
        equals(30),
      );
    });

    test('bare "tid" in ordinary prose is not a label', () {
      // The colon is half of what makes bare `tid` safe (the boundary helper is
      // the other half). This fixture is the one the pattern's own doc comment
      // names: without `(?=\s*:)` the word fires mid-sentence and the step
      // timer that follows it becomes the dish total.
      expect(
        RecipeTimeExtractor.extract(
          'Ta ut smöret i god tid, ca 20 min innan servering',
        ),
        isNull,
      );
      // Positive control on the same word: with a colon it IS the label, so
      // the null above is the colon guard talking and not a lost label list.
      expect(RecipeTimeExtractor.extract('Tid: 20 min'), equals(20));
      // ...and the compound labels still need no colon, which is why the guard
      // is on the bare alternative alone.
      expect(
        RecipeTimeExtractor.extract('Total tid 40 minuter'),
        equals(40),
      );
    });

    test('a nonsense composite is refused, not returned', () {
      // The composite branch returns BEFORE reaching DurationParser, so it does
      // not inherit that parser's sanity cap and had to restate it. Both
      // fixtures are the ones the code comment names.
      //
      // 0 is the dangerous one: it is non-null, so it wins the caller's `??`,
      // suppresses the fallback that had the right answer, and lands in
      // `Recipe.timeMinutes` where `<= 0` is a validation failure.
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 0 tim 0 min'),
        isNull,
      );
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 99 timmar och 999 min'),
        isNull,
      );
      // The cap is inclusive at 12 h, and this is the control that the bound
      // rejects nonsense rather than the whole composite branch.
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 12 timmar och 0 min'),
        equals(720),
      );
    });

    test('a sub-minute labelled time is null, not 0', () {
      // 0 is non-null, so it would win the caller's `??`, suppress the
      // fallback that had the right answer, and land in `Recipe.timeMinutes`
      // where `<= 0` is a validation failure.
      expect(RecipeTimeExtractor.extract('Friteringstid: 45 sekunder'), isNull);
    });

    test('a page with ONLY a waiting label yields null, never the wait', () {
      for (final label in const [
        'Vilotid',
        'Kyltid',
        'Jästid',
        'Marineringstid',
        'Svalningstid',
      ]) {
        expect(
          RecipeTimeExtractor.extract('$label: 2 timmar'),
          isNull,
          reason: '$label is waiting, not work',
        );
      }
    });

    test('sums the composite form instead of taking the first number', () {
      // parseSwedishDurationMatch returns the FIRST match, so a bare delegation
      // would answer 60 here. The corpus carries this shape on real pages, one
      // of them with a verified gold of 70.
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 1 timme och 10 minuter'),
        equals(70),
      );
      expect(
        RecipeTimeExtractor.extract('Tillagningstid: 1 tim 30 min'),
        equals(90),
      );
    });

    group('composite boundaries — each one has a failing input', () {
      test('does not eat the decimal half of an hour', () {
        // Without the leading lookbehind the hour group matches the "5" of
        // "1,5" and this answers 320.
        expect(
          RecipeTimeExtractor.extract('Tillagningstid: 1,5 timme 20 min'),
          equals(90),
        );
      });

      test('the "h" abbreviation does not fire before å/ä/ö', () {
        // ASCII \b fires between "h" and "å", and a permissive bridge then
        // reaches the next number: "2 hål ... 20 min" answered 140.
        expect(
          RecipeTimeExtractor.extract('Koktid: 2 hål i degen, 20 min'),
          equals(20),
        );
      });

      test('an unrelated later number is not summed into the hour', () {
        // "1 timme, ca 20 min per sida" is one hour of cooking with a 20-min
        // step inside it, not 80 minutes.
        expect(
          RecipeTimeExtractor.extract(
            'Tillagningstid: 1 timme, ca 20 min per sida',
          ),
          equals(60),
        );
      });
    });

    test('an unlabelled step timer is NOT taken as the dish time', () {
      // The whole point of the change. `_extractTime`'s unanchored
      // `(\d+)\s*min` matches here; this must not.
      const page = '''
Potatisgratäng
Skala potatisen och skiva den tunt.
Koka i 20 minuter tills den mjuknat.
Grädda sedan i ugn.''';
      expect(RecipeTimeExtractor.extract(page), isNull);
    });

    test('empty and label-free text yield null', () {
      expect(RecipeTimeExtractor.extract(''), isNull);
      expect(RecipeTimeExtractor.extract('Pannkakor\n3 dl mjöl'), isNull);
    });

    group(
      'word boundaries (Dart \\b is ASCII-only, so å/ä/ö are the risk)',
      () {
        test('a label embedded in a longer word does not match', () {
          // "koktiden" continues past the label; treating it as a labelled time
          // would read a sentence about the cooking time as the cooking time.
          expect(
            RecipeTimeExtractor.extract('Koktiden beror på 30 minuter extra'),
            isNull,
          );
        });

        test('a label preceded by å/ä/ö does not match', () {
          // The phantom-boundary direction: ASCII \b would fire between "å" and
          // "koktid" and read this as a label.
          expect(RecipeTimeExtractor.extract('påkoktid 15 min'), isNull);
        });

        test('a label followed by å/ä/ö does not match', () {
          expect(RecipeTimeExtractor.extract('koktidsångare 15 min'), isNull);
        });

        test('a real label surrounded by Swedish letters still matches', () {
          expect(
            RecipeTimeExtractor.extract('Kött — tillagningstid 40 minuter'),
            equals(40),
          );
        });
      },
    );
  });
}
