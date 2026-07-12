/// Spoken-register golden set for the menu-constraint parser (kb-whisper
/// voice-prompt plan, Data/ML panel condition).
///
/// Intention: prove that TRANSCRIBED spoken Swedish — fillers, self-
/// corrections, polite ramble, Whisper-style punctuation/capitals — parses to
/// the same constraints a clean typed prompt would. Each entry is a realistic
/// transcript as KB-Whisper renders speech (capitalized, punctuated), paired
/// with the constraints the speaker meant. This is the TEXT-level half of the
/// STT→parse golden set; the audio→transcript half runs against real
/// recordings (see the voice plan — recordings are founder-supplied and this
/// suite gains a fixture folder then).
///
/// If a case here fails, the spoken-register passes (filler strip, last-wins
/// correction) or the parser itself regressed — do NOT weaken the expected
/// constraints to go green.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';
import 'package:butlery/services/menu/parser/text_normalizer.dart';

late Lexicon _lex;

class _Case {
  final String transcript;
  final String mealType;
  final int count;
  final Set<String> dietary;
  final Set<String> allergenFree;
  final int? maxTime;

  const _Case(
    this.transcript,
    this.mealType,
    this.count, {
    this.dietary = const {},
    this.allergenFree = const {},
    this.maxTime,
  });
}

// 35 spoken-register transcripts. Grouped by the failure mode they pin.
const _golden = <_Case>[
  // — Plain, with Whisper punctuation/capitals —
  _Case('Tre middagar.', 'middag', 3),
  _Case('Fyra middagar och två luncher.', 'middag', 4),
  _Case('Fyra middagar och två luncher.', 'lunch', 2),
  _Case('Middag varje dag.', 'middag', 7),

  // — Fillers —
  _Case('Eh, tre middagar.', 'middag', 3),
  _Case('Alltså, typ fyra middagar.', 'middag', 4),
  _Case('Öh, två luncher liksom.', 'lunch', 2),
  _Case('Tre middagar, du vet, och två luncher.', 'middag', 3),
  _Case('Mm, fem middagar den här veckan.', 'middag', 5),
  _Case('Asså tre vegetariska middagar.', 'middag', 3, dietary: {'vegetarisk'}),

  // — Self-corrections (last wins) —
  _Case('Tre, nej fyra middagar.', 'middag', 4),
  // å/ä/ö boundaries (Dart \b is ASCII-only — these pin the lookaround fix):
  _Case('Tre, nej två middagar.', 'middag', 2),
  _Case('Åtta, nej nio middagar.', 'middag', 9),
  // An adjective that starts with a number word ("trevliga" ⊃ "tre") must
  // never eat the real count — numbers are exact-match in the correction
  // pass (the regex-level property is pinned in text_normalizer_test).
  _Case('Fyra trevliga middagar.', 'middag', 4),
  _Case('Tre, nej förlåt, fyra middagar.', 'middag', 4),
  _Case('3, nej 4 middagar.', 'middag', 4),
  _Case('Fem, nej vänta, tre middagar och två luncher.', 'middag', 3),
  _Case(
    'Två, eller nej, tre veganska middagar.',
    'middag',
    3,
    dietary: {'vegansk'},
  ),
  _Case(
    'Tre vegetariska nej veganska middagar.',
    'middag',
    3,
    dietary: {'vegansk'},
  ),
  _Case('Tre nej fyra nej fem middagar.', 'middag', 5),
  // Restated-phrase corrections — the most common real shape: the speaker
  // repeats the noun, and Whisper may punctuate it as two sentences.
  // Pre-fix these produced 7 (both phrases survived as clauses and merged).
  _Case('Tre middagar, nej fyra middagar.', 'middag', 4),
  _Case('Tre middagar. Nej, fyra middagar.', 'middag', 4),
  _Case('Två middagar, nej en middag.', 'middag', 1),
  _Case('Tre, nej 4 middagar.', 'middag', 4),
  // UNRESOLVED marker (retraction with no replacement): last-wins has no
  // pair to collapse, so "nej" reaches the clause parser — this is the case
  // that exercises the clause_parser stop-word addition; every other
  // correction case consumes its marker before clause parsing. The trace
  // assertion below is what bites if the stop words are reverted.
  _Case('Tre middagar nej.', 'middag', 3),

  // — Filler + correction combined —
  _Case('Eh, tre, alltså nej, fyra middagar.', 'middag', 4),
  _Case('Typ två, nej tre luncher liksom.', 'lunch', 3),

  // — Polite spoken ramble —
  _Case('Kan du fixa tre middagar?', 'middag', 3),

  // — Spoken numbers and vague quantities —
  _Case('Några middagar.', 'middag', 3),
  _Case('Ett par luncher.', 'lunch', 2),
  _Case('Två till tre middagar.', 'middag', 3),
  _Case('Tre middagar, va?', 'middag', 3),

  // — Modifiers surviving the spoken passes —
  _Case('Eh, tre glutenfria middagar.', 'middag', 3, allergenFree: {'gluten'}),
  _Case(
    'Alltså fyra snabba middagar under 30 minuter.',
    'middag',
    4,
    maxTime: 30,
  ),
  _Case(
    'Två, nej förlåt, tre laktosfria middagar.',
    'middag',
    3,
    allergenFree: {'laktos'},
  ),
];

void main() {
  setUpAll(() async {
    _lex = await const CodeLexiconProvider().load();
  });

  group('spoken-prompt golden set', () {
    for (final c in _golden) {
      test('"${c.transcript}" → ${c.mealType} x${c.count}', () {
        final result = MenuConstraintParser.parse(c.transcript, _lex);
        expect(
          result.isEmpty,
          isFalse,
          reason: 'parser returned empty for "${c.transcript}"',
        );

        final slot = result.slotRequests.firstWhere(
          (s) => s.mealType == c.mealType,
          orElse: () => throw TestFailure(
            'No "${c.mealType}" slot for "${c.transcript}". '
            'Got: ${result.slotRequests.map((s) => s.mealType).toList()}',
          ),
        );
        expect(
          slot.totalCount,
          c.count,
          reason: 'count mismatch for "${c.transcript}"',
        );

        final constraints = slot.subRequests;
        // EXACT set equality, not containment: a retracted value that
        // survives a dead correction pass ("vegetarisk" lingering next to
        // the corrected "vegansk") must fail, not slip through.
        final dietaryUnion = constraints.fold<Set<String>>(
          {},
          (acc, r) => acc..addAll(r.dietaryFree),
        );
        expect(
          dietaryUnion,
          equals(c.dietary),
          reason: 'dietary set mismatch for "${c.transcript}"',
        );
        final allergenUnion = constraints.fold<Set<String>>(
          {},
          (acc, r) => acc..addAll(r.allergenFree),
        );
        expect(
          allergenUnion,
          equals(c.allergenFree),
          reason: 'allergen-free set mismatch for "${c.transcript}"',
        );
        if (c.maxTime != null) {
          expect(
            constraints.any((r) => r.maxTimeMinutes == c.maxTime),
            isTrue,
            reason: 'expected max time ${c.maxTime} for "${c.transcript}"',
          );
        }

        // Trace hygiene: unresolved correction markers and fillers must not
        // leak into the "didn't understand" trace that drives UX copy.
        const noiseWords = {
          ...kSpokenFillerWords,
          'nej',
          'förlåt',
          'vänta',
          'ursäkta',
        };
        expect(
          result.trace.notUnderstood.where(
            (w) => noiseWords.contains(w.toLowerCase()),
          ),
          isEmpty,
          reason:
              'filler/correction noise leaked into notUnderstood for '
              '"${c.transcript}"',
        );
      });
    }

    test('a hallucinated silence transcript parses to empty, not garbage', () {
      // Whisper's classic silence hallucinations must not generate a menu.
      for (final ghost in ['Tack för att du tittade.', 'Textning av ...']) {
        final result = MenuConstraintParser.parse(ghost, _lex);
        expect(
          result.slotRequests,
          isEmpty,
          reason: 'silence hallucination "$ghost" produced slots',
        );
      }
    });
  });
}
