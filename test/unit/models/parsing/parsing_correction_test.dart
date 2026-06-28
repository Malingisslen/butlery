/// Direct unit tests for [ParsingCorrection] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Aggregate diff between parser output and the user's final recipe (feeds
/// parser-improvement analytics). Covers the create factory (totalCorrections
/// tally, clock-pinned timestamp, generated id), hasCorrections, the
/// isReorderingOnly classifier, correctionTypeSummary, and the
/// toFirestore→fromJson round-trip with the unknown-source fallback.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/instruction_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';

void main() {
  ParsingCorrection make({
    FieldCorrection? title,
    List<IngredientCorrection> ingredients = const [],
    List<InstructionCorrection> instructions = const [],
  }) => ParsingCorrection.create(
    recipeId: 'r1',
    userId: 'u1',
    source: ImportSource.url,
    domain: 'ica.se',
    successfulTier: 'SchemaOrg',
    originalQuality: 0.8,
    titleCorrection: title,
    ingredientCorrections: ingredients,
    instructionCorrections: instructions,
  );

  group('create factory', () {
    test('tallies totalCorrections, pins timestamp, generates an id', () {
      final t = DateTime.utc(2026, 1, 1);
      late ParsingCorrection c;
      withClock(Clock.fixed(t), () {
        c = make(
          title: const FieldCorrection(
            originalValue: 'a',
            correctedValue: 'b',
          ),
          ingredients: [
            IngredientCorrection.added(
              correctedIndex: 0,
              correctedLine: 'salt',
            ),
            IngredientCorrection.added(
              correctedIndex: 1,
              correctedLine: 'pepper',
            ),
          ],
          instructions: [
            InstructionCorrection.added(
              correctedIndex: 0,
              correctedText: 'Mix',
            ),
          ],
        );
      });
      expect(c.totalCorrections, 4); // 1 title + 2 ingredient + 1 instruction
      expect(c.timestamp, t);
      expect(c.id, isNotEmpty);
      expect(c.hasCorrections, isTrue);
    });

    test('an empty correction has no corrections', () {
      final c = make();
      expect(c.totalCorrections, 0);
      expect(c.hasCorrections, isFalse);
    });
  });

  group('isReorderingOnly', () {
    test('true when only reorder-type list corrections exist', () {
      final c = make(
        ingredients: const [
          IngredientCorrection(type: IngredientCorrectionType.reordered),
        ],
        instructions: const [
          InstructionCorrection(type: InstructionCorrectionType.reordered),
        ],
      );
      expect(c.isReorderingOnly, isTrue);
    });

    test('false when a field correction is present', () {
      final c = make(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        ingredients: const [
          IngredientCorrection(type: IngredientCorrectionType.reordered),
        ],
      );
      expect(c.isReorderingOnly, isFalse);
    });

    test('false when a non-reorder list correction is present', () {
      final c = make(
        ingredients: [
          IngredientCorrection.added(correctedIndex: 0, correctedLine: 'salt'),
        ],
      );
      expect(c.isReorderingOnly, isFalse);
    });
  });

  group('correctionTypeSummary', () {
    test('counts field + per-type list corrections', () {
      final c = make(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        ingredients: [
          IngredientCorrection.added(correctedIndex: 0, correctedLine: 'salt'),
          IngredientCorrection.added(
            correctedIndex: 1,
            correctedLine: 'pepper',
          ),
        ],
        instructions: const [
          InstructionCorrection(type: InstructionCorrectionType.reordered),
        ],
      );
      expect(c.correctionTypeSummary, {
        'title': 1,
        'ingredient_added': 2,
        'instruction_reordered': 1,
      });
    });
  });

  group('serialization', () {
    test('toFirestore carries core fields and omits null corrections', () {
      final json = make().toFirestore();
      expect(json['recipeId'], 'r1');
      expect(json['source'], 'url');
      expect(json['originalQuality'], 0.8);
      expect(json.containsKey('titleCorrection'), isFalse);
      expect(json['ingredientCorrections'], isEmpty);
    });

    test('toFirestore → fromJson round-trips', () {
      final original = make(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        ingredients: [
          IngredientCorrection.added(correctedIndex: 0, correctedLine: 'salt'),
        ],
      );
      final restored = ParsingCorrection.fromJson(original.toFirestore());
      expect(restored.recipeId, 'r1');
      expect(restored.source, ImportSource.url);
      expect(restored.totalCorrections, original.totalCorrections);
      expect(restored.ingredientCorrections, hasLength(1));
      expect(restored.titleCorrection, isNotNull);
    });

    test('fromJson falls back to unknown source for a bad value', () {
      final restored = ParsingCorrection.fromJson({
        'source': 'bogus',
        'timestamp': '2026-01-01T00:00:00.000Z',
      });
      expect(restored.source, ImportSource.unknown);
    });
  });
}
