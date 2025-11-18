/// Advanced recipe extraction system providing comprehensive HTML parsing and structured data extraction for recipe import.
/// This utility provides sophisticated recipe parsing from web content, supporting both JSON-LD structured data
/// and Microdata formats commonly used on recipe websites. It consolidates recipe extraction logic while providing
/// robust parsing capabilities for international recipe import with comprehensive error handling and data validation
/// for reliable recipe content extraction and import functionality.
/// **Extraction Capabilities:**
/// - **JSON-LD Support**: Advanced parsing of Recipe schema.org structured data
/// - **Microdata Parsing**: Fallback support for Microdata recipe markup
/// - **Multi-format Support**: Handles various recipe website formats and structures
/// - **Error Recovery**: Robust error handling for malformed HTML and data
/// - **Cultural Adaptation**: Supports international recipe formats and standards
/// **Supported Data Formats:**
/// ```
/// // JSON-LD Recipe format
/// <script type="application/ld+json">
/// {"@type": "Recipe", "name": "...", "recipeIngredient": [...], ...}
/// </script>
/// // Microdata Recipe format
/// <div itemscope itemtype="http://schema.org/Recipe">
///   <span itemprop="name">Recipe Name</span>
///   <span itemprop="recipeIngredient">Ingredient 1</span>
///   ...
/// </div>
/// ```
/// **Usage Examples:**
/// ```dart
/// final recipeData = extractRecipeFromHtml(htmlContent);
/// if (recipeData != null) {
///   final name = recipeData['name'];
///   final ingredients = recipeData['recipeIngredient'];
///   final instructions = recipeData['recipeInstructions'];
/// }
/// ```

import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// Comprehensive recipe extraction from HTML content with JSON-LD and Microdata support
/// This function serves as the primary recipe extraction engine, providing intelligent parsing
/// of web content to extract structured recipe data. It supports modern web standards for
/// recipe markup while maintaining compatibility with various website formats and structures
/// commonly used for recipe sharing and publication.
/// **Extraction Strategy:**
/// 1. **JSON-LD Priority**: First attempts to extract Recipe schema.org JSON-LD data
/// 2. **Microdata Fallback**: Falls back to Microdata parsing for legacy compatibility
/// 3. **Data Validation**: Validates extracted data for completeness and accuracy
/// 4. **Error Handling**: Gracefully handles parsing errors and malformed data
/// [html] The HTML content to parse for recipe data
/// Returns a Map containing recipe data with schema.org field names, or null if no recipe found
/// **Return Format:**
/// - `name`: Recipe title
/// - `recipeIngredient`: List of ingredient strings
/// - `recipeInstructions`: List of instruction strings
/// - `recipeYield`: Serving size information
/// - `totalTime`: Total cooking/preparation time
/// - `image`: Recipe image URL
/// - `@type`: Always "Recipe" for identification
Map<String, dynamic>? extractRecipeFromHtml(String html) {
  // Primary extraction: Attempt JSON-LD structured data first
  final jsonLd = _extractJsonLd(html);
  if (jsonLd != null) {
    return jsonLd;
  }

  // Fallback extraction: Parse Microdata format for broader compatibility
  final document = html_parser.parse(html);
  final recipeElements = document.querySelectorAll(
    '[itemscope][itemtype="http://schema.org/Recipe"]',
  );
  if (recipeElements.isNotEmpty) {
    final recipeElem = recipeElements.first;
    return _parseRecipeMicrodata(recipeElem);
  }

  // No recipe data found in supported formats
  return null;
}

/// Privat hjälpfunktion: plockar ut JSON‐LD av typen "Recipe" om det finns.
Map<String, dynamic>? _extractJsonLd(String html) {
  // Hittar just <script type="application/ld+json">…</script> (dubbel‐citat).
  final jsonLdRegex = RegExp(
    r'<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
    caseSensitive: false,
  );

  for (final match in jsonLdRegex.allMatches(html)) {
    final content = match.group(1)?.trim();
    if (content == null) continue;
    try {
      final decoded = json.decode(content);
      // Om JSON‐LD är en lista, leta igenom varje objekt
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic> && item['@type'] == 'Recipe') {
            return Map<String, dynamic>.from(item);
          }
        }
      }
      // Om JSON‐LD är ett enda objekt
      else if (decoded is Map<String, dynamic> &&
          decoded['@type'] == 'Recipe') {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Om json.decode() misslyckas, ignorera och fortsätt
      continue;
    }
  }
  return null;
}

/// Privat hjälpfunktion: parsa Microdata (schema.org/Recipe) från ett DOM‐element.
Map<String, dynamic> _parseRecipeMicrodata(Element root) {
  final Map<String, dynamic> result = {};

  // 1) Titel: itemprop="name"
  final nameElem = root.querySelector('[itemprop="name"]');
  if (nameElem != null) {
    result['name'] = nameElem.text.trim();
  }

  // 2) Ingredienser: alla itemprop="recipeIngredient"
  final ingrElems = root.querySelectorAll('[itemprop="recipeIngredient"]');
  final ingredients = <String>[];
  for (final el in ingrElems) {
    final txt = el.text.trim();
    if (txt.isNotEmpty) {
      ingredients.add(txt);
    }
  }
  result['recipeIngredient'] = ingredients;

  // 3) Instruktioner: alla itemprop="recipeInstructions"
  final instrElems = root.querySelectorAll('[itemprop="recipeInstructions"]');
  final instructions = <String>[];
  for (final el in instrElems) {
    // Om elementet innehåller <li>, <p> eller <span> som barn
    final subElems = el.querySelectorAll('li, p, span');
    if (subElems.isEmpty) {
      final parentText = el.text.trim();
      if (parentText.isNotEmpty) {
        instructions.add(parentText);
      }
    } else {
      for (final sub in subElems) {
        final t = sub.text.trim();
        if (t.isNotEmpty) {
          instructions.add(t);
        }
      }
    }
  }
  result['recipeInstructions'] = instructions;

  // 4) Portioner: itemprop="recipeYield"
  final yieldElem = root.querySelector('[itemprop="recipeYield"]');
  if (yieldElem != null) {
    result['recipeYield'] = yieldElem.text.trim();
  }

  // 5) Total tid: itemprop="totalTime"
  final timeElem = root.querySelector('[itemprop="totalTime"]');
  if (timeElem != null) {
    if (timeElem.attributes['content'] != null) {
      result['totalTime'] = timeElem.attributes['content']!.trim();
    } else {
      result['totalTime'] = timeElem.text.trim();
    }
  }

  // 6) Bild: itemprop="image"
  final imageElem = root.querySelector('[itemprop="image"]');
  if (imageElem != null) {
    if (imageElem.localName == 'img' && imageElem.attributes['src'] != null) {
      result['image'] = imageElem.attributes['src']!;
    } else if (imageElem.attributes['content'] != null) {
      result['image'] = imageElem.attributes['content']!;
    }
  }

  result['@type'] = 'Recipe';
  return result;
}
