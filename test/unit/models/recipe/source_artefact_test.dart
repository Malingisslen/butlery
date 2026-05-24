// BUT-1045: serialization roundtrip + nullable behaviour on RecipeCore.
// Pins the JSON shape so future fromJson/toJson changes don't silently
// break the re-extract artefact field.

import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceArtefact (BUT-1045)', () {
    test('JSON roundtrip preserves type, payload, fetchedAt', () {
      final original = SourceArtefact(
        type: SourceArtefactType.youtubeTranscript,
        payload: 'Transcript content goes here\nMultiple lines.',
        fetchedAt: DateTime.utc(2026, 5, 24, 12, 0, 0),
      );

      final roundtripped = SourceArtefact.fromJson(original.toJson());

      expect(roundtripped, equals(original));
    });

    test('fromJson with unknown type falls back to url', () {
      final json = {
        'type': 'someFutureTypeThatDoesNotExist',
        'payload': 'whatever',
        'fetchedAt': DateTime.utc(2026, 5, 24).toIso8601String(),
      };

      final result = SourceArtefact.fromJson(json);

      expect(result.type, equals(SourceArtefactType.url));
      expect(result.payload, equals('whatever'));
    });

    test('every enum case serialises to its name string', () {
      // Pin the wire format so a future enum reorder doesn't change the
      // stored value for already-saved recipes.
      for (final type in SourceArtefactType.values) {
        final artefact = SourceArtefact(
          type: type,
          payload: 'x',
          fetchedAt: DateTime.utc(2026, 5, 24),
        );
        expect(artefact.toJson()['type'], equals(type.name));
      }
    });
  });

  group('RecipeCore.sourceArtefact (BUT-1045)', () {
    test('null on legacy recipes, preserved through copyWith', () {
      final core = RecipeCore(
        title: 'Test',
        description: '',
        ingredients: [],
        instructions: [],
        mealType: 'Lunch',
      );
      expect(core.sourceArtefact, isNull);

      final updated = core.copyWith(
        sourceArtefact: SourceArtefact(
          type: SourceArtefactType.textPaste,
          payload: 'pasted text',
          fetchedAt: DateTime.utc(2026, 5, 24),
        ),
      );
      expect(updated.sourceArtefact, isNotNull);
      expect(updated.sourceArtefact!.type, SourceArtefactType.textPaste);

      // copyWith without explicit sourceArtefact preserves it (sentinel).
      final unchanged = updated.copyWith(title: 'Renamed');
      expect(unchanged.sourceArtefact, equals(updated.sourceArtefact));

      // Explicit null clears it.
      final cleared = updated.copyWith(sourceArtefact: null);
      expect(cleared.sourceArtefact, isNull);
    });

    test('toJson/fromJson roundtrip preserves the field', () {
      final artefact = SourceArtefact(
        type: SourceArtefactType.tiktokCaption,
        payload: 'Caption with 🥘 emoji',
        fetchedAt: DateTime.utc(2026, 5, 24, 12, 0, 0),
      );
      final core = RecipeCore(
        title: 'T',
        description: '',
        ingredients: [],
        instructions: [],
        mealType: 'Lunch',
        sourceArtefact: artefact,
      );

      final json = core.toJson();
      expect(json['sourceArtefact'], isA<Map<String, dynamic>>());

      final restored = RecipeCore.fromJson(json);
      expect(restored.sourceArtefact, equals(artefact));
    });

    test('legacy JSON without sourceArtefact still parses (backcompat)', () {
      // Pre-prod simplification: no migration needed, but recipes
      // serialized before the field shipped must still parse cleanly.
      final json = {
        'id': 'r1',
        'title': 'Pre-1045 recipe',
        'description': '',
        'ingredients': <String>[],
        'instructions': <String>[],
        'mealType': 'Lunch',
        'imageUrls': <String>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        // sourceArtefact intentionally omitted
      };

      final core = RecipeCore.fromJson(json);
      expect(core.sourceArtefact, isNull);
    });
  });
}
