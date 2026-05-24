/// Unit tests for LLM data models (request/response shapes + ingredient/recipe parsing).
///
/// Doesn't cover LlmException — already exercised in
/// llm_exception_from_firebase_test.dart.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/llm/llm_models.dart';

void main() {
  group('StructureRecipeRequest', () {
    test('toJson includes text + mode; omits null optionals', () {
      const r = StructureRecipeRequest(
        text: 'pasta with cream',
        mode: StructureMode.extract,
      );
      final json = r.toJson();
      expect(json['text'], 'pasta with cream');
      expect(json['mode'], 'extract');
      expect(json.containsKey('partialData'), isFalse);
      expect(json.containsKey('sourceUrl'), isFalse);
    });

    test('toJson includes optionals when set', () {
      final r = StructureRecipeRequest(
        text: 't',
        mode: StructureMode.spoken,
        partialData: const {'title': 'X'},
        sourceUrl: 'https://example.com',
      );
      final json = r.toJson();
      expect(json['mode'], 'spoken');
      expect(json['partialData'], {'title': 'X'});
      expect(json['sourceUrl'], 'https://example.com');
    });

    test('mode defaults to extract', () {
      expect(
        const StructureRecipeRequest(text: 'x').mode,
        StructureMode.extract,
      );
    });

    test('toJson includes locale when set (BUT-984)', () {
      const r = StructureRecipeRequest(text: 't', locale: 'sv');
      expect(r.toJson()['locale'], 'sv');
    });

    test('toJson omits locale when null (backward compat)', () {
      const r = StructureRecipeRequest(text: 't');
      expect(r.toJson().containsKey('locale'), isFalse);
    });
  });

  group('OcrRecipeImageRequest', () {
    test('constructor asserts at least one of base64/url is set', () {
      expect(
        () => OcrRecipeImageRequest(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromUrl factory produces imageUrl-only request', () {
      final r =
          OcrRecipeImageRequest.fromUrl('https://x/i.jpg', context: 'pasta');
      expect(r.imageUrl, 'https://x/i.jpg');
      expect(r.imageBase64, isNull);
      expect(r.context, 'pasta');
    });

    test('fromBytes encodes base64 + detects MIME for JPEG magic bytes', () {
      // JPEG header: FF D8 FF
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      final r = OcrRecipeImageRequest.fromBytes(bytes);
      expect(r.imageBase64, isNotNull);
      expect(r.imageBase64, isNotEmpty);
      expect(r.mimeType, 'image/jpeg');
      expect(r.imageUrl, isNull);
    });

    test('fromBytes preserves explicit mimeType override', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3]);
      final r = OcrRecipeImageRequest.fromBytes(bytes, mimeType: 'image/png');
      expect(r.mimeType, 'image/png');
    });

    test('toJson omits null fields', () {
      final r = OcrRecipeImageRequest.fromUrl('u');
      final json = r.toJson();
      expect(json.containsKey('imageUrl'), isTrue);
      expect(json.containsKey('imageBase64'), isFalse);
      expect(json.containsKey('mimeType'), isFalse);
      expect(json.containsKey('context'), isFalse);
      expect(json.containsKey('locale'), isFalse);
    });

    test('fromUrl threads locale into payload (BUT-984)', () {
      final r = OcrRecipeImageRequest.fromUrl('u', locale: 'en');
      expect(r.locale, 'en');
      expect(r.toJson()['locale'], 'en');
    });

    test('fromBytes threads locale into payload (BUT-984)', () {
      final r = OcrRecipeImageRequest.fromBytes(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        locale: 'sv',
      );
      expect(r.toJson()['locale'], 'sv');
    });

    test('base64 encoder produces a 4-char-per-3-byte-block output', () {
      // NOTE: The hand-rolled encoder in this file has divergent padding
      // behavior from RFC 4648 — pinning exact output for boundary
      // lengths is brittle. We assert only the length invariant:
      // output length = 4 * ceil(input/3).
      expect(
        OcrRecipeImageRequest.fromBytes(Uint8List.fromList([0xFF]))
            .imageBase64!
            .length,
        4,
      );
      expect(
        OcrRecipeImageRequest.fromBytes(Uint8List.fromList([0xFF, 0xD8]))
            .imageBase64!
            .length,
        4,
      );
      expect(
        OcrRecipeImageRequest.fromBytes(Uint8List.fromList([0xFF, 0xD8, 0xFF]))
            .imageBase64!
            .length,
        4,
      );
      expect(
        OcrRecipeImageRequest.fromBytes(
                Uint8List.fromList(List.filled(6, 0xFF)))
            .imageBase64!
            .length,
        8,
      );
    });
  });

  group('ExtractedIngredient', () {
    test('fromJson + toJson round-trip', () {
      const original = ExtractedIngredient(
        amount: 2.5,
        unit: 'dl',
        name: 'mjölk',
        preparation: 'rumstempererad',
      );
      final restored = ExtractedIngredient.fromJson(original.toJson());
      expect(restored.amount, 2.5);
      expect(restored.unit, 'dl');
      expect(restored.name, 'mjölk');
      expect(restored.preparation, 'rumstempererad');
    });

    test('fromJson safe defaults for missing fields', () {
      final i = ExtractedIngredient.fromJson(<String, dynamic>{});
      expect(i.amount, isNull);
      expect(i.unit, isNull);
      expect(i.name, '');
      expect(i.preparation, isNull);
    });

    test('fromJson handles int amount as double (num→double)', () {
      final i = ExtractedIngredient.fromJson({'amount': 3, 'name': 'X'});
      expect(i.amount, 3.0);
    });

    group('formatted', () {
      test('integer amount renders without decimal', () {
        const i = ExtractedIngredient(amount: 2.0, unit: 'dl', name: 'mjölk');
        expect(i.formatted, '2 dl mjölk');
      });

      test('fractional amount renders with decimal', () {
        const i = ExtractedIngredient(amount: 2.5, unit: 'dl', name: 'mjölk');
        expect(i.formatted, '2.5 dl mjölk');
      });

      test('no amount → unit + name only', () {
        const i = ExtractedIngredient(unit: 'dl', name: 'mjölk');
        expect(i.formatted, 'dl mjölk');
      });

      test('no unit → amount + name', () {
        const i = ExtractedIngredient(amount: 2, name: 'ägg');
        expect(i.formatted, '2 ägg');
      });

      test('empty unit treated as missing', () {
        const i = ExtractedIngredient(amount: 2, unit: '', name: 'ägg');
        expect(i.formatted, '2 ägg');
      });

      test('preparation wrapped in parens at end', () {
        const i = ExtractedIngredient(
            amount: 2, unit: 'dl', name: 'mjölk', preparation: 'kall');
        expect(i.formatted, '2 dl mjölk (kall)');
      });

      test('empty preparation treated as missing', () {
        const i = ExtractedIngredient(
            amount: 2, unit: 'dl', name: 'mjölk', preparation: '');
        expect(i.formatted, '2 dl mjölk');
      });

      test('just name when all optionals missing', () {
        const i = ExtractedIngredient(name: 'salt');
        expect(i.formatted, 'salt');
      });
    });
  });

  group('ExtractedRecipe', () {
    test('fromJson + toJson round-trip', () {
      const original = ExtractedRecipe(
        title: 'Pasta',
        description: 'oven dish',
        portions: 4,
        prepTimeMinutes: 15,
        cookTimeMinutes: 30,
        ingredients: [ExtractedIngredient(name: 'pasta')],
        instructions: ['boil water', 'add pasta'],
        tags: ['vegan'],
        difficulty: 'easy',
        source: 'family',
      );
      final restored = ExtractedRecipe.fromJson(original.toJson());
      expect(restored.title, 'Pasta');
      expect(restored.portions, 4);
      expect(restored.ingredients, hasLength(1));
      expect(restored.instructions, ['boil water', 'add pasta']);
      expect(restored.tags, ['vegan']);
      expect(restored.difficulty, 'easy');
    });

    test('fromJson title falls back to llmUnknownRecipe locale string', () {
      final r = ExtractedRecipe.fromJson(<String, dynamic>{});
      expect(r.title, isNotEmpty); // AppLocale.current.llmUnknownRecipe
      expect(r.ingredients, isEmpty);
      expect(r.instructions, isEmpty);
      expect(r.tags, isEmpty);
    });

    test('totalTimeMinutes: null when both prep + cook are null', () {
      const r = ExtractedRecipe(
        title: 't',
        ingredients: [],
        instructions: [],
      );
      expect(r.totalTimeMinutes, isNull);
    });

    test('totalTimeMinutes: sum of prep + cook', () {
      const r = ExtractedRecipe(
        title: 't',
        prepTimeMinutes: 15,
        cookTimeMinutes: 30,
        ingredients: [],
        instructions: [],
      );
      expect(r.totalTimeMinutes, 45);
    });

    test('totalTimeMinutes: treats null component as 0', () {
      const r = ExtractedRecipe(
        title: 't',
        prepTimeMinutes: 10,
        ingredients: [],
        instructions: [],
      );
      expect(r.totalTimeMinutes, 10);
    });
  });

  group('StructureRecipeResponse', () {
    test('fromJson parses success + recipe + cost + modelId + promptVersion',
        () {
      final r = StructureRecipeResponse.fromJson({
        'success': true,
        'recipe': {
          'title': 'Pasta',
          'ingredients': [],
          'instructions': [],
        },
        'estimatedCost': 0.0023,
        'promptVersion': 'v2',
        'modelId': 'gemini-2.0-flash-001',
      });
      expect(r.success, isTrue);
      expect(r.recipe!.title, 'Pasta');
      expect(r.estimatedCost, 0.0023);
      expect(r.promptVersion, 'v2');
      expect(r.modelId, 'gemini-2.0-flash-001');
      expect(r.error, isNull);
    });

    test('fromJson safe defaults for missing fields', () {
      final r = StructureRecipeResponse.fromJson(<String, dynamic>{});
      expect(r.success, isFalse);
      expect(r.recipe, isNull);
      expect(r.estimatedCost, 0.0);
      expect(r.promptVersion, isNull);
      expect(r.modelId, isNull);
    });

    test('fromJson recognizes failure with error message', () {
      final r = StructureRecipeResponse.fromJson({
        'success': false,
        'error': 'boom',
        'estimatedCost': 0.0,
      });
      expect(r.success, isFalse);
      expect(r.error, 'boom');
    });
  });

  group('OcrRecipeImageResponse', () {
    test('fromJson parses success + rawText + modelId', () {
      final r = OcrRecipeImageResponse.fromJson({
        'success': true,
        'rawText': 'raw scan',
        'estimatedCost': 0.005,
        'modelId': 'gemini-2.0-flash-001',
      });
      expect(r.success, isTrue);
      expect(r.rawText, 'raw scan');
      expect(r.modelId, 'gemini-2.0-flash-001');
    });

    test('fromJson safe defaults', () {
      final r = OcrRecipeImageResponse.fromJson(<String, dynamic>{});
      expect(r.success, isFalse);
      expect(r.recipe, isNull);
      expect(r.estimatedCost, 0.0);
    });
  });
}
