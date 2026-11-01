/// BUT-1508: the two places a URL import falls back to reading a page as plain
/// text (the web-scraper text tier and the page-text tier) each build their own
/// text parser. Each must be handed the shared ingredient reader, or the
/// recipe quietly loses the CRF/BERT read and gets the regex deriver.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/social_media_extractor.dart';

const _url = 'https://8.8.8.8/recept/pannkakor';

const _recipeText =
    'Pannkakor\n'
    'Ingredienser:\n'
    '3 ägg\n'
    '5 dl mjölk\n'
    '2 dl vetemjöl\n'
    'Gör så här:\n'
    'Vispa ihop och stek i smör.';

final _plainTextPage =
    '<html><head><title>Pannkakor</title></head><body>'
    '${_recipeText.split('\n').map((l) => '<p>$l</p>').join()}'
    '</body></html>';

class _CountingReader extends IngredientParsingStrategy {
  int calls = 0;

  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) {
    calls++;
    return super.parseLines(lines, ocrCorrection: ocrCorrection);
  }
}

class _Scraper extends Fake implements WebScraper {
  _Scraper(this.extractedText);

  final String? extractedText;

  @override
  Future<String?> fetchRawHtml(String url, pd.SourcePlatform platform) async =>
      null;

  @override
  Future<ExtractionResult> performExtraction(
    String url,
    pd.SourcePlatform platform,
  ) async => extractedText == null
      ? ExtractionResult(success: false)
      : ExtractionResult(success: true, extractedText: extractedText);

  @override
  void dispose() {}
}

Future<int> _readerCallsFor({
  required String? scraperText,
  required String html,
}) async {
  final reader = _CountingReader();
  final strategy = UrlImportStrategy(
    httpClient: MockClient(
      (_) async => http.Response(
        html,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    ),
    webScraperFactory: () => _Scraper(scraperText),
    ingredientStrategy: () => reader,
    dnsLookup: (_) async => [InternetAddress('8.8.8.8')],
  );
  final result = await strategy.import(_url);
  expect(result.isSuccess, isTrue, reason: 'premise: the fallback read it');
  return reader.calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'the web-scraper text tier parses ingredients with the reader',
    () async {
      final calls = await _readerCallsFor(
        scraperText: _recipeText,
        html: '<html><body>tom</body></html>',
      );
      expect(calls, greaterThan(0));
    },
  );

  test('the page-text tier parses ingredients with the reader', () async {
    final calls = await _readerCallsFor(
      scraperText: null,
      html: _plainTextPage,
    );
    expect(calls, greaterThan(0));
  });
}
