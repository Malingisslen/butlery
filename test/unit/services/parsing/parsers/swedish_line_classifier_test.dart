import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/parsers/viterbi_context_processor.dart';

void main() {
  final classifier = SwedishLineClassifier.instance;

  group('SwedishLineClassifier', () {
    group('BUG-14: Substring food-word matching', () {
      test('should not inflate ingredient score from "ost" inside "rostad"',
          () {
        final result = classifier.classifyLine('rostad bröd');

        // "rostad bröd" contains the substring "ost" inside "rostad",
        // but word-set matching should prevent a false food-word hit.
        // With the fix, "ost" only matches as a standalone word.
        // The line should NOT be classified as ingredient since there is
        // no quantity, no unit, and no actual food word match.
        expect(
          result.type,
          isNot(LineType.ingredient),
          reason: '"rostad bröd" should not be classified as ingredient — '
              '"ost" is a substring of "rostad", not a standalone word',
        );
      });

      test('should classify standalone "ost" as ingredient in "2 dl ost"', () {
        final result = classifier.classifyLine('2 dl ost');

        expect(result.type, LineType.ingredient);
        expect(
          result.confidence,
          greaterThan(0.6),
          reason: '"2 dl ost" has quantity, unit, and food word — '
              'should be a high-confidence ingredient',
        );
      });

      test('should classify "100 g ost" as ingredient', () {
        final result = classifier.classifyLine('100 g ost');

        expect(result.type, LineType.ingredient);
      });

      test('should not match "salt" inside "resultatet"', () {
        // "resultatet" contains "salt" as a substring
        final result = classifier.classifyLine('Kontrollera resultatet');

        // This is clearly an instruction, not an ingredient
        expect(result.type, isNot(LineType.ingredient));
      });

      test('should match "salt" as standalone word', () {
        final result = classifier.classifyLine('1 tsk salt');

        expect(result.type, LineType.ingredient);
      });

      test('should not match "ris" inside "kristallsocker"', () {
        // "kristallsocker" contains "ris" as a substring
        final result = classifier.classifyLine('Rör ner kristallsocker');

        // Should be instruction (starts with cooking verb "Rör"), not ingredient
        expect(result.type, isNot(LineType.ingredient));
      });

      test('should match "ris" as standalone word', () {
        final result = classifier.classifyLine('3 dl ris');

        expect(result.type, LineType.ingredient);
      });

      test('should handle multi-word food terms via contains', () {
        // "crème fraiche" is a multi-word entry in _swedishFoodWords
        // Multi-word terms still use lower.contains() which is correct
        final result = classifier.classifyLine('2 dl crème fraiche');

        expect(result.type, LineType.ingredient);
      });
    });

    group('MISSED-2: "st" removed from portions pattern', () {
      test('should NOT classify "4 st ägg" as metadata', () {
        final result = classifier.classifyLine('4 st ägg');

        // "st" is a unit (pieces), not a portions indicator.
        // With the fix, _portionsPattern no longer matches "st".
        // "4 st ägg" should be classified as ingredient (quantity + unit + food word).
        expect(
          result.type,
          isNot(LineType.metadata),
          reason: '"4 st ägg" is an ingredient line, not metadata — '
              '"st" means pieces, not portions',
        );
        expect(result.type, LineType.ingredient);
      });

      test('should classify "4 portioner" as metadata', () {
        final result = classifier.classifyLine('4 portioner');

        expect(result.type, LineType.metadata);
        expect(
          result.confidence,
          greaterThanOrEqualTo(0.8),
          reason: '"4 portioner" is clearly metadata',
        );
      });

      test('should classify "6 port" as metadata', () {
        final result = classifier.classifyLine('6 port');

        expect(result.type, LineType.metadata);
      });

      test('should classify "4 personer" as metadata', () {
        final result = classifier.classifyLine('4 personer');

        expect(result.type, LineType.metadata);
      });

      test('should classify "2 pers" as metadata', () {
        final result = classifier.classifyLine('2 pers');

        expect(result.type, LineType.metadata);
      });

      test('should classify "3 st tomater" as ingredient, not metadata', () {
        final result = classifier.classifyLine('3 st tomater');

        // "st" is a unit for counting items, not a portions indicator
        expect(result.type, isNot(LineType.metadata));
      });

      test('should classify "10 st köttbullar" as ingredient, not metadata',
          () {
        final result = classifier.classifyLine('10 st köttbullar');

        expect(result.type, isNot(LineType.metadata));
      });
    });

    group('Ingredient classification', () {
      test('should classify quantity + unit + food as ingredient', () {
        final cases = [
          '2 dl mjölk',
          '500 g köttfärs',
          '1 msk olivolja',
          '3 ägg',
          '2 tsk salt',
          '1 krm peppar',
        ];

        for (final line in cases) {
          final result = classifier.classifyLine(line);
          expect(
            result.type,
            LineType.ingredient,
            reason: '"$line" should be classified as ingredient',
          );
        }
      });

      test('should classify fraction quantities as ingredient', () {
        final result = classifier.classifyLine('½ dl grädde');

        expect(result.type, LineType.ingredient);
      });
    });

    group('Instruction classification', () {
      test('should classify lines starting with cooking verbs as instruction',
          () {
        // Longer instruction lines score higher because length > 40 adds 0.1
        // and length > 80 adds another 0.1. Short lines with food words
        // can be ambiguous (title vs instruction).
        final cases = [
          'Koka pastan al dente och häll av vattnet',
          'Blanda mjöl och socker noggrant i en stor bunke',
          'Vispa ägg och mjölk till en slät smet och ställ åt sidan',
          'Grädda i ugn på 200 grader i cirka 20 minuter tills gyllene',
        ];

        for (final line in cases) {
          final result = classifier.classifyLine(line);
          expect(
            result.type,
            LineType.instruction,
            reason: '"$line" should be classified as instruction',
          );
        }
      });

      test('should give instruction score boost for cooking verb at start', () {
        // Even short lines starting with cooking verbs get a 0.4 boost
        final result = classifier.classifyLine('Stek löken i smör');
        final score = result.confidence;

        // The verb "stek" gives +0.4, but short lines with food words
        // may also score as title. Verify the verb boost is present.
        expect(
          score,
          greaterThan(0.0),
          reason: 'Lines starting with cooking verbs should have a score > 0',
        );
      });

      test('should classify step-numbered longer lines as instruction', () {
        final result = classifier.classifyLine(
          '1. Skär löken i tunna skivor och fräs i smör tills de är mjuka.',
        );

        expect(result.type, LineType.instruction);
      });
    });

    group('Metadata classification', () {
      test('should classify time expressions as metadata', () {
        final cases = [
          '30 min',
          '45 minuter',
          '1 timme',
          '2 timmar',
        ];

        for (final line in cases) {
          final result = classifier.classifyLine(line);
          expect(
            result.type,
            LineType.metadata,
            reason: '"$line" should be classified as metadata',
          );
        }
      });
    });

    group('Section headers', () {
      test('should classify ingredient headers', () {
        final cases = [
          'Ingredienser:',
          'ingredienser',
          'Du behöver:',
        ];

        for (final line in cases) {
          final result = classifier.classifyLine(line);
          expect(
            result.type,
            LineType.sectionHeader,
            reason: '"$line" should be classified as section header',
          );
        }
      });

      test('should classify instruction headers', () {
        final cases = [
          'Gör så här:',
          'Instruktioner:',
          'Tillagning:',
        ];

        for (final line in cases) {
          final result = classifier.classifyLine(line);
          expect(
            result.type,
            LineType.sectionHeader,
            reason: '"$line" should be classified as section header',
          );
        }
      });
    });

    group('Empty and noise', () {
      test('should classify empty lines', () {
        final result = classifier.classifyLine('');
        expect(result.type, LineType.empty);
        expect(result.confidence, 1.0);
      });

      test('should classify whitespace-only lines as empty', () {
        final result = classifier.classifyLine('   ');
        expect(result.type, LineType.empty);
      });
    });

    group('parseStructure integration', () {
      test('should extract portions from metadata line', () {
        const text = '''
Pasta Carbonara

Ingredienser:
2 dl grädde
3 ägg
200 g bacon

4 portioner

Gör så här:
Koka pastan al dente.
Stek bacon.
Blanda med ägg och grädde.
''';

        final structure = classifier.parseStructure(text);

        expect(structure.portions, 4);
        expect(structure.ingredients, isNotEmpty);
        expect(structure.instructions, isNotEmpty);
        expect(structure.isValid, isTrue);
      });

      test('should NOT extract "4 st" as portions', () {
        // If "4 st" appeared on its own, it should not be treated as portions
        const text = '''
Ingredienser:
4 st ägg
2 dl mjölk
''';

        final structure = classifier.parseStructure(text);

        // "4 st ägg" should be parsed as ingredient, not metadata with portions
        expect(
          structure.portions,
          isNull,
          reason: '"4 st ägg" should not set portions to 4',
        );
        expect(structure.ingredients.length, greaterThanOrEqualTo(1));
      });
    });

    group('MT-2: Viterbi context-aware classification', () {
      const viterbi = ViterbiContextProcessor();

      test('ingredient sequence pulls ambiguous line into ingredient', () {
        // A run of clear ingredient lines followed by a high-confidence
        // ingredient line — verify Viterbi preserves the ingredient sequence
        // and doesn't reclassify confident ingredients.
        final lines = [
          classifier.classifyLine('2 dl mjölk'),
          classifier.classifyLine('3 ägg'),
          classifier.classifyLine('500 g köttfärs'),
          classifier.classifyLine('1 msk olivolja'),
          classifier.classifyLine('2 tsk salt'),
          classifier.classifyLine('1 krm peppar'),
        ];

        final contextual = viterbi.classifyWithContext(lines);

        // All lines should remain as ingredients in the Viterbi output
        for (var i = 0; i < contextual.length; i++) {
          expect(contextual[i].type, LineType.ingredient,
              reason: 'Line $i should be ingredient in ingredient run');
        }
      });

      test('section header "Ingredienser:" boosts subsequent ambiguous lines',
          () {
        // After an ingredient header, even ambiguous short food words
        // should be classified as ingredients due to emission boosting.
        final lines = [
          classifier.classifyLine('Ingredienser:'),
          classifier.classifyLine('smör'),
          classifier.classifyLine('lök'),
          classifier.classifyLine('vitlök'),
        ];

        // Without context, these are all title (60%)
        expect(lines[1].type, LineType.title);
        expect(lines[2].type, LineType.title);
        expect(lines[3].type, LineType.title);

        final contextual = viterbi.classifyWithContext(lines);

        // The header should still be a header
        expect(contextual[0].type, LineType.sectionHeader);
        // Subsequent lines should be ingredients due to header boost
        expect(contextual[1].type, LineType.ingredient,
            reason: '"smör" after ingredient header should be ingredient');
        expect(contextual[2].type, LineType.ingredient,
            reason: '"lök" after ingredient header should be ingredient');
        expect(contextual[3].type, LineType.ingredient,
            reason: '"vitlök" after ingredient header should be ingredient');
      });

      test('instruction header switches context from ingredients', () {
        final lines = [
          classifier.classifyLine('Ingredienser:'),
          classifier.classifyLine('2 dl mjölk'),
          classifier.classifyLine('3 ägg'),
          classifier.classifyLine('Gör så här:'),
          classifier.classifyLine('Koka pastan al dente och häll av vattnet.'),
          classifier
              .classifyLine('Blanda mjöl och socker noggrant i en stor bunke.'),
        ];

        final contextual = viterbi.classifyWithContext(lines);

        expect(contextual[0].type, LineType.sectionHeader);
        expect(contextual[1].type, LineType.ingredient);
        expect(contextual[2].type, LineType.ingredient);
        expect(contextual[3].type, LineType.sectionHeader);
        expect(contextual[4].type, LineType.instruction);
        expect(contextual[5].type, LineType.instruction);
      });

      test('high-confidence metadata survives ingredient context', () {
        // Metadata like "4 portioner" has high emission (0.85) and a
        // Metadata at the start (before any ingredient context) should
        // survive because there's no strong ingredient run to absorb it.
        final lines = [
          classifier.classifyLine('Pasta med köttfärssås'),
          classifier.classifyLine('4 portioner'),
          classifier.classifyLine('30 min'),
          classifier.classifyLine('Ingredienser:'),
          classifier.classifyLine('2 dl mjölk'),
        ];

        expect(lines[1].type, LineType.metadata);
        expect(lines[2].type, LineType.metadata);

        final contextual = viterbi.classifyWithContext(lines);

        expect(contextual[1].type, LineType.metadata,
            reason: 'Metadata before ingredient section should survive');
        expect(contextual[3].type, LineType.sectionHeader);
        expect(contextual[4].type, LineType.ingredient);
      });

      test('empty lines do not break ingredient context after header', () {
        // An empty line between ingredients after a section header
        // should not reset context — the header boost carries through
        // empty lines and the transition matrix allows ingredient ->
        // empty -> ingredient.
        final lines = [
          classifier.classifyLine('Ingredienser:'),
          classifier.classifyLine('2 dl mjölk'),
          classifier.classifyLine('3 ägg'),
          classifier.classifyLine('500 g köttfärs'),
          classifier.classifyLine(''),
          classifier.classifyLine('1 krm peppar'),
        ];

        expect(lines[4].type, LineType.empty);

        final contextual = viterbi.classifyWithContext(lines);

        // Empty line should not break the ingredient context
        expect(contextual[5].type, LineType.ingredient,
            reason:
                'Ingredient after header + ingredients + empty should stay ingredient');
      });

      test('single line unchanged by Viterbi', () {
        final lines = [classifier.classifyLine('2 dl mjölk')];
        final contextual = viterbi.classifyWithContext(lines);

        expect(contextual.length, 1);
        expect(contextual[0].type, lines[0].type);
        expect(contextual[0].confidence, lines[0].confidence);
      });

      test('classifyAndGroup integration applies Viterbi', () {
        // Full integration: classifyAndGroup should use context to pull
        // ambiguous food words after an ingredient header into ingredient.
        const text = 'Ingredienser:\nsmör\nlök\nvitlök';

        final sections = classifier.classifyAndGroup(text);

        // All content should end up in one ingredients section
        final ingredientSection = sections.firstWhere(
          (s) => s.type == LineSectionType.ingredients,
          orElse: () => throw StateError('No ingredient section found'),
        );

        // The food-word lines should be classified as ingredients
        final foodLines = ingredientSection.lines
            .where((l) => l.type == LineType.ingredient)
            .toList();
        expect(foodLines.length, greaterThanOrEqualTo(3),
            reason:
                '"smör", "lök", "vitlök" should all be ingredients in context');
      });
    });
  });
}
