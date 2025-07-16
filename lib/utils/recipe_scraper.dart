// lib/utils/recipe_scraper.dart

import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// Försöker extrahera ett JSON‐LD‐block av typen "Recipe" från HTML.
/// Returnerar en Map med nycklarna "recipeIngredient", "recipeInstructions", etc.,
/// eller null om inget JSON‐LD hittas.
Map<String, dynamic>? extractRecipeFromHtml(String html) {
  // 1) Försök JSON‐LD först
  final jsonLd = _extractJsonLd(html);
  if (jsonLd != null) {
    return jsonLd;
  }

  // 2) Om inget JSON‐LD, försök Microdata (schema.org/Recipe)
  final document = html_parser.parse(html);
  final recipeElements = document.querySelectorAll(
    '[itemscope][itemtype="http://schema.org/Recipe"]',
  );
  if (recipeElements.isNotEmpty) {
    final recipeElem = recipeElements.first;
    return _parseRecipeMicrodata(recipeElem);
  }

  // 3) Hittar inget
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
