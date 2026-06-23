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

/// Private helper: extracts JSON-LD of type "Recipe" if present.
_JsonLdResult _extractJsonLd(String html) {
  final jsonLdRegex = RegExp(
    r"""<script[^>]*type=["']?application/ld\+json["']?[^>]*>([\s\S]*?)</script>""",
    caseSensitive: false,
  );

  final matches = jsonLdRegex.allMatches(html);
  final hadBlocks = matches.isNotEmpty;

  for (final match in matches) {
    final content = match.group(1)?.trim();
    if (content == null) continue;
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
