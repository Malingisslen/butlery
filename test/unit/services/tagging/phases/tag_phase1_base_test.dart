/// Direct unit tests for [TagPhase1Base.containsSwedishWord] + [Phase1Result]
/// (BUT-1149 coverage burndown — previously zero direct coverage).
///
/// Covers the two cleanly-isolated surfaces: the Swedish word-boundary matcher
/// (the tricky bit — short words must not match as substrings, å/ä/ö count as
/// boundaries, case-insensitive) and the Phase1Result accessors (tag/status/
/// decision lookups with unknown defaults). The full calculate() orchestration
/// depends on the Phase1*Calculator chain + a populated IngredientLookupResult
/// and is left to the tagging integration tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

void main() {
  group('containsSwedishWord', () {
    test('matches a whole word with separators around it', () {
      expect(TagPhase1Base.containsSwedishWord('ris och bönor', 'ris'), isTrue);
    });

    test('matches the word at the start or end of the text', () {
      expect(TagPhase1Base.containsSwedishWord('ris', 'ris'), isTrue);
      expect(
        TagPhase1Base.containsSwedishWord('jag vill ha ris', 'ris'),
        isTrue,
      );
    });

    test('does NOT match the word as a substring inside another', () {
      // "ris" inside "korianderfrisk" must not match (the doc's example).
      expect(
        TagPhase1Base.containsSwedishWord('korianderfrisk', 'ris'),
        isFalse,
      );
    });

    test('treats Swedish letters as part of a word (no false boundary)', () {
      // "kött" must not match inside "köttbullar".
      expect(
        TagPhase1Base.containsSwedishWord('köttbullar', 'kött'),
        isFalse,
      );
      expect(
        TagPhase1Base.containsSwedishWord('kött och potatis', 'kött'),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(TagPhase1Base.containsSwedishWord('RIS finns här', 'ris'), isTrue);
    });
  });

  group('Phase1Result accessors', () {
    Phase1Result result() => Phase1Result(
      tags: const {'under-30-min', 'kyckling'},
      allergenStatus: const {'gluten': TriState.free},
      dietaryStatus: const {'vegan': TriState.contains},
      lookup: IngredientLookupResult.empty(),
      decisions: const [
        TagDecision(
          type: 'allergen',
          key: 'gluten',
          result: TriState.free,
          reason: 'no gluten ingredients',
        ),
      ],
    );

    test('hasTag reflects membership', () {
      final r = result();
      expect(r.hasTag('kyckling'), isTrue);
      expect(r.hasTag('fisk'), isFalse);
    });

    test('getAllergenStatus / getDietaryStatus return value or unknown', () {
      final r = result();
      expect(r.getAllergenStatus('gluten'), TriState.free);
      expect(r.getAllergenStatus('peanut'), TriState.unknown); // default
      expect(r.getDietaryStatus('vegan'), TriState.contains);
      expect(r.getDietaryStatus('keto'), TriState.unknown);
    });

    test('getAllergenDecision finds the matching decision, else null', () {
      final r = result();
      expect(r.getAllergenDecision('gluten')?.reason, 'no gluten ingredients');
      expect(r.getAllergenDecision('peanut'), isNull);
      // The lone decision is type "allergen", so a dietary lookup misses.
      expect(r.getDietaryDecision('gluten'), isNull);
    });

    test('hasProperty delegates to the lookup (empty → false)', () {
      expect(result().hasProperty('dairy'), isFalse);
    });
  });
}
