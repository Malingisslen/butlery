/// Scrapes ingredient lines from Swedish recipe sites using JSON-LD markup.
///
/// Reads recipe URLs from stdin (one per line) and outputs raw ingredient
/// lines to stdout. Uses schema.org Recipe.recipeIngredient from JSON-LD.
///
/// Usage: dart run scripts/crf/scrape_ingredients.dart < urls.txt > ingredients.txt
library;

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final client = HttpClient();
  var totalRecipes = 0;
  var totalIngredients = 0;

  // Read URLs from stdin
  final urls = <String>[];
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty && trimmed.startsWith('http')) {
      urls.add(trimmed);
    }
  }

  stderr.writeln('Processing ${urls.length} URLs...');

  for (final url in urls) {
    try {
      final ingredients = await _scrapeIngredients(client, url);
      if (ingredients.isNotEmpty) {
        totalRecipes++;
        for (final line in ingredients) {
          stdout.writeln(line);
          totalIngredients++;
        }
        // Blank line between recipes
        stdout.writeln();
      }
    } catch (e) {
      stderr.writeln('Error processing $url: $e');
    }

    // Rate limit
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  stderr.writeln(
      'Done: $totalRecipes recipes, $totalIngredients ingredient lines');
  client.close();
}

Future<List<String>> _scrapeIngredients(HttpClient client, String url) async {
  final uri = Uri.parse(url);
  final request = await client.getUrl(uri);
  request.headers.set('User-Agent', 'ButleryCRFScraper/1.0');
  request.headers.set('Accept', 'text/html');

  final response = await request.close();
  if (response.statusCode != 200) {
    stderr.writeln('HTTP ${response.statusCode} for $url');
    await response.drain<void>();
    return [];
  }

  final html = await response.transform(utf8.decoder).join();

  // Extract JSON-LD blocks
  final jsonLdPattern = RegExp(
    r"""<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>""",
    dotAll: true,
  );

  for (final match in jsonLdPattern.allMatches(html)) {
    final jsonText = match.group(1)?.trim();
    if (jsonText == null || jsonText.isEmpty) continue;

    try {
      final parsed = json.decode(jsonText);
      final ingredients = _extractIngredients(parsed);
      if (ingredients.isNotEmpty) return ingredients;
    } catch (_) {
      // Invalid JSON-LD, try next block
    }
  }

  return [];
}

List<String> _extractIngredients(dynamic data) {
  if (data is List) {
    for (final item in data) {
      final result = _extractIngredients(item);
      if (result.isNotEmpty) return result;
    }
    return [];
  }

  if (data is! Map<String, dynamic>) return [];

  // Check @type for Recipe
  final type = data['@type'];
  final isRecipe =
      type == 'Recipe' || (type is List && type.contains('Recipe'));

  if (isRecipe) {
    final ingredients = data['recipeIngredient'];
    if (ingredients is List) {
      return ingredients
          .whereType<String>()
          .map((s) => _cleanText(s))
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }

  // Check @graph
  final graph = data['@graph'];
  if (graph is List) {
    return _extractIngredients(graph);
  }

  return [];
}

String _cleanText(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
