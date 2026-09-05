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
import 'package:flutter/foundation.dart';
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
/// Result of recipe extraction, distinguishing "no structured data found"
/// from "structured data found but no recipe in it".
class RecipeExtractionResult {
  final Map<String, dynamic>? data;

  /// Whether any JSON-LD or Microdata blocks were found at all.
  final bool hadStructuredData;

  const RecipeExtractionResult({this.data, this.hadStructuredData = false});
}

Map<String, dynamic>? extractRecipeFromHtml(String html) {
  return extractRecipeFromHtmlDetailed(html).data;
}

/// Detailed extraction that reports whether structured data blocks existed.
RecipeExtractionResult extractRecipeFromHtmlDetailed(String html) {
  // Primary extraction: Attempt JSON-LD structured data first
  final jsonLdResult = _extractJsonLd(html);
  if (jsonLdResult.data != null) {
    return RecipeExtractionResult(
      data: jsonLdResult.data,
      hadStructuredData: true,
    );
  }

  // Fallback extraction: Parse Microdata format for broader compatibility
  final document = html_parser.parse(html);
  final recipeElements = document.querySelectorAll(
    '[itemscope][itemtype="http://schema.org/Recipe"], '
    '[itemscope][itemtype="https://schema.org/Recipe"]',
  );
  if (recipeElements.isNotEmpty) {
    final recipeElem = recipeElements.first;
    return RecipeExtractionResult(
      data: _parseRecipeMicrodata(recipeElem),
      hadStructuredData: true,
    );
  }

  // No recipe data found — report whether any JSON-LD existed at all
  return RecipeExtractionResult(
    hadStructuredData: jsonLdResult.hadJsonLdBlocks,
  );
}

/// Internal result from JSON-LD extraction.
class _JsonLdResult {
  final Map<String, dynamic>? data;
  final bool hadJsonLdBlocks;
  const _JsonLdResult({this.data, this.hadJsonLdBlocks = false});
}

/// Checks whether a JSON-LD @type value represents a Recipe.
/// Handles plain string ("Recipe"), URL-format ("https://schema.org/Recipe"),
/// and array-wrapped variants (["Recipe"]).
bool _isRecipeType(dynamic type) {
  if (type is String) {
    return type == 'Recipe' || type.endsWith('/Recipe');
  }
  if (type is List) {
    return type.any((item) => item is String && _isRecipeType(item));
  }
  return false;
}

/// Whether a `type` attribute value denotes JSON-LD.
///
/// Compares the media type's ESSENCE, so `application/ld+json; charset=utf-8`
/// counts. Callers pass the value as the HTML parser resolved it, which is
/// what makes an entity-encoded `+` (Arla.se writes `application/ld&#x2B;json`)
/// arrive here already decoded.
bool isJsonLdMediaType(String? typeAttribute) {
  if (typeAttribute == null) return false;
  return typeAttribute.split(';').first.trim().toLowerCase() ==
      'application/ld+json';
}

/// Matches a `<script>` OPENING TAG whose `type` attribute is JSON-LD, for
/// callers that must work on raw source rather than a parsed document —
/// `HtmlSanitizer`, whose whole point is to run before anything trusts the
/// markup.
///
/// It answers the same QUESTION as [isJsonLdMediaType] but is not the same
/// test, and the difference is deliberate: this one must enumerate the
/// encodings of `+` a parser would have resolved (`&#x2B;` as Arla.se writes
/// it, and the decimal `&#43;`). Any other character encoded that way fails
/// to match, which drops the tag — the safe direction.
///
/// Both bounds are load-bearing, and each was measured against a tag that
/// exempted itself from sanitisation without it:
/// - The lookbehind requires the attribute to START here. A `\b` does not:
///   `-` is a non-word character, so a word boundary sits inside
///   `data-type=`, and `<script data-type="application/ld+json">` survived.
/// - The lookahead requires the media type to END here, so
///   `type="application/ld+jsonx" src="evil.js"` is not read as JSON-LD.
final RegExp jsonLdScriptOpeningTagPattern = RegExp(
  r'''(?<=[\s/])type\s*=\s*["']?\s*application/ld(?:\+|&#x2b;|&#43;)json(?=["'\s;>]|$)''',
  caseSensitive: false,
);

/// Private helper: extracts JSON-LD of type "Recipe" if present.
_JsonLdResult _extractJsonLd(String html) {
  // Read the attribute off the PARSED document rather than matching raw
  // source. Arla.se writes `type="application/ld&#x2B;json"` — the plus sign
  // as a character reference — which a regex over the source never matches
  // while a compliant parser resolves it (BUT-2020).
  final scripts = html_parser
      .parse(html)
      .querySelectorAll('script')
      .where((e) => isJsonLdMediaType(e.attributes['type']))
      .toList();

  final hadBlocks = scripts.isNotEmpty;

  for (final script in scripts) {
    final content = script.text.trim();
    if (content.isEmpty) continue;
    try {
      final decoded = json.decode(content);
      // If JSON-LD is a list, search through each object
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic> && _isRecipeType(item['@type'])) {
            return _JsonLdResult(
              data: Map<String, dynamic>.from(item),
              hadJsonLdBlocks: true,
            );
          }
        }
      }
      // If JSON-LD is a single object
      else if (decoded is Map<String, dynamic> &&
          _isRecipeType(decoded['@type'])) {
        return _JsonLdResult(
          data: Map<String, dynamic>.from(decoded),
          hadJsonLdBlocks: true,
        );
      }
      // Handle @graph pattern (common in WordPress/Yoast SEO)
      else if (decoded is Map<String, dynamic> && decoded['@graph'] is List) {
        for (final item in (decoded['@graph'] as List)) {
          if (item is Map<String, dynamic> && _isRecipeType(item['@type'])) {
            return _JsonLdResult(
              data: Map<String, dynamic>.from(item),
              hadJsonLdBlocks: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('JSON-LD parse error: $e');
      continue;
    }
  }
  return _JsonLdResult(hadJsonLdBlocks: hadBlocks);
}

/// Private helper: parse Microdata (schema.org/Recipe) from a DOM element.
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
    // If the element contains <li>, <p> or <span> as children
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

/// Flattens a schema.org `recipeInstructions` value into the step maps a
/// caller can read a `text` off.
///
/// The list may hold `HowToStep` maps, plain strings, or `HowToSection` maps
/// whose steps sit one level down in `itemListElement`. Arla.se serves the
/// last shape, and every reader that kept only maps carrying a top-level
/// `text` silently dropped every step on the page (BUT-2020).
///
/// A section's own `name` is a heading, not a step, so it is skipped when the
/// section carries a non-empty `itemListElement`. A section with an empty or
/// absent one is kept whole, because there is nothing to lift out and its own
/// `text` would otherwise be lost.
///
/// Two other readers of the same schema shape disagree with this one, and
/// with each other. Neither is reached by the five callers here, and both are
/// named rather than left to be discovered:
/// - `schema_org_tier.dart` emits a section's `name` as a step, so its output
///   for a sectioned page has one extra leading entry.
/// - `SchemaOrgRecipeExtractor._collectInstructionSteps` drops a section whose
///   `itemListElement` is an empty list, where this keeps it.
///
/// Three implementations of one schema decision is how they drift; folding
/// them together is its own change, because that reader returns strings while
/// this returns the step maps its callers still filter.
List<dynamic> flattenRecipeInstructions(dynamic value) {
  if (value is! List) return const [];

  final flattened = <dynamic>[];
  for (final entry in value) {
    if (entry is! Map) {
      flattened.add(entry);
      continue;
    }

    final nested = entry['itemListElement'];
    if (nested is List && nested.isNotEmpty) {
      flattened.addAll(flattenRecipeInstructions(nested));
      continue;
    }

    flattened.add(entry);
  }
  return flattened;
}
