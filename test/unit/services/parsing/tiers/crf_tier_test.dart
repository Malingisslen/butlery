import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/tiers/crf_tier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';

/// Stub CRF parser that returns predictable results.
class StubCrfIngredientParser extends CrfIngredientParser {
  final List<ParsedIngredient> _results;

  StubCrfIngredientParser(this._results)
      : super(CrfViterbiDecoder(
          weights: const CrfWeights(
            featureWeights: {},
            transitionWeights: {},
          ),
        ));

  @override
  List<ParsedIngredient> parseLines(List<String> lines) => _results;

  @override
  ParsedIngredient parseLine(String line) =>
      _results.isNotEmpty ? _results.first : ParsedIngredient.simple(line);
}

void main() {
  ParsingContext createContext({String content = ''}) {
    final text = content.isNotEmpty
        ? content
        : '''Ingredienser
2 dl mjölk
1 msk smör
3 ägg

Gör så här
Blanda allt.
Stek i panna.
Servera.''';

    return ParsingContext.fromText(
      text: text,
      source: ImportSource.text,
      userId: 'test-user',
      parserVersion: '2.0.0',
    );
  }

  group('CrfTier', () {
    test('shouldSkip returns true when content is empty', () {
      final tier = CrfTier();
      final context = ParsingContext.fromText(
        text: '',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(context), true);
    });

    test('shouldSkip returns false when content is available', () {
      final tier = CrfTier();
      final context = createContext();
      expect(tier.shouldSkip(context), false);
    });

    test('tierName is CRF', () {
      expect(CrfTier().tierName, 'CRF');
    });

    test('priority is 4', () {
      expect(CrfTier().priority, 4);
    });

    test('parses ingredients with injected parser', () async {
      final stubIngredients = [
        ParsedIngredient.structured(
          name: 'mjölk',
          originalLine: '2 dl mjölk',
          quantity: '2',
          unit: 'dl',
        ),
        ParsedIngredient.structured(
          name: 'smör',
          originalLine: '1 msk smör',
          quantity: '1',
          unit: 'msk',
        ),
        ParsedIngredient(
          name: 'ägg',
          originalLine: '3 ägg',
          quantity: '3',
          confidence: ParseConfidence.high,
        ),
      ];

      final parser = StubCrfIngredientParser(stubIngredients);
      final tier = CrfTier(parser: parser);
      final context = createContext();

      final result = await tier.parseWithTimeout(context);

      expect(result.success, true);
      expect(result.recipe, isNotNull);
      expect(result.recipe!.ingredients.value, isNotNull);
      expect(result.recipe!.ingredients.value!.length, 3);
    });

    test('returns noData when structure is invalid', () async {
      final tier = CrfTier(
        parser: StubCrfIngredientParser([]),
      );
      final context = createContext(
          content: 'just some random text without any recipe structure at all');

      final result = await tier.parseWithTimeout(context);

      expect(result.success, false);
    });

    test('returns noData when parser returns empty', () async {
      final tier = CrfTier(
        parser: StubCrfIngredientParser([]),
      );
      final context = createContext();

      final result = await tier.parseWithTimeout(context);

      expect(result.success, false);
    });
  });
}
