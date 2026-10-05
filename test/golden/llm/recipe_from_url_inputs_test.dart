// BUT-2239: inputs for the nightly `recipe_from_url` AI corpus.
//
// Builds, from the import gate's own site pages, exactly the text the app's
// AI fallback would send for each page: the HTML stripped by the same
// sanitizer Tier 6 uses and cut to the server's limit. The paid call itself
// runs in Node (functions/src/admin/golden-recipe-from-url.ts), through the
// server code the callable runs.
//
//   flutter test test/golden/llm/recipe_from_url_inputs_test.dart
//
// writes build/golden-llm/recipe_from_url_inputs.json.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/fallbacks/llm_extraction_fallback.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';

import '../../import_gate/site_pages.dart';

const _outPath = 'build/golden-llm/recipe_from_url_inputs.json';

void main() {
  test('every gate site page becomes the text Tier 6 would send', () {
    final gold =
        jsonDecode(File(siteGoldPath).readAsStringSync())
            as Map<String, dynamic>;
    final inputs = <Map<String, dynamic>>[];

    for (final entry in gold.entries) {
      final j = entry.value as Map<String, dynamic>;
      final text = LlmExtractionFallback.serverInput(
        HtmlSanitizer.stripToPlainText(sitePageHtml(j['source'] as String)),
      );

      expect(text, isNot(contains('<')), reason: '${entry.key}: markup left');
      expect(text.trim(), isNotEmpty, reason: '${entry.key}: nothing to send');

      inputs.add({
        'id': entry.key,
        'url': j['url'],
        'text': text,
        'goldTitle': j['title'],
        'goldIngredientKeys': [
          for (final i in j['ingredients'] as List)
            (i as Map<String, dynamic>)['key'],
        ],
      });
    }

    expect(inputs, hasLength(gold.length));
    File(_outPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(inputs));
  });
}
