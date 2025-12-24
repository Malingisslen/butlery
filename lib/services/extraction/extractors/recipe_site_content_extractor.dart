// lib/services/extraction/extractors/recipe_site_content_extractor.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Recipe site content extraction with structured data parsing (JSON-LD, microdata).
class RecipeSiteContentExtractor {
  final bool Function() isDisposed;
  final List<String> selectors;

  RecipeSiteContentExtractor({
    required this.isDisposed,
    required this.selectors,
  });

  /// Extract recipe content with structured data parsing and fallback strategies
  Future<String?> extract(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    debugPrint('🍽️ Extracting from recipe site...');

    // Strategy 1: JSON-LD structured data
    final jsonLdResult = await _extractJsonLd(controller);
    if (jsonLdResult != null) return jsonLdResult;

    // Strategy 2: Microdata
    final microdataResult = await _extractMicrodata(controller);
    if (microdataResult != null) return microdataResult;

    // Strategy 3: Content-based extraction
    return await _extractRecipeContent(controller);
  }

  /// Extract structured recipe data from JSON-LD
  Future<String?> _extractJsonLd(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            const scripts = document.querySelectorAll('script[type="application/ld+json"]');
            for (const script of scripts) {
              const data = JSON.parse(script.textContent);

              // Handle single recipe or array of recipes
              const recipes = Array.isArray(data) ? data : [data];

              for (const item of recipes) {
                if (item['@type'] === 'Recipe' || (item['@graph'] && item['@graph'].some(g => g['@type'] === 'Recipe'))) {
                  const recipe = item['@type'] === 'Recipe' ? item : item['@graph'].find(g => g['@type'] === 'Recipe');

                  let recipeText = '';

                  if (recipe.name) recipeText += recipe.name + '\\n\\n';
                  if (recipe.description) recipeText += recipe.description + '\\n\\n';

                  if (recipe.recipeIngredient) {
                    recipeText += 'Ingredienser:\\n';
                    recipe.recipeIngredient.forEach(ing => recipeText += '- ' + ing + '\\n');
                    recipeText += '\\n';
                  }

                  if (recipe.recipeInstructions) {
                    recipeText += 'Instruktioner:\\n';
                    recipe.recipeInstructions.forEach((inst, i) => {
                      const text = typeof inst === 'string' ? inst : inst.text;
                      recipeText += (i + 1) + '. ' + text + '\\n';
                    });
                    recipeText += '\\n';
                  }

                  if (recipe.nutrition && recipe.nutrition.calories) {
                    recipeText += 'Kalorier: ' + recipe.nutrition.calories + '\\n';
                  }

                  if (recipe.totalTime || recipe.prepTime || recipe.cookTime) {
                    recipeText += 'Tid: ';
                    if (recipe.totalTime) recipeText += 'Total: ' + recipe.totalTime + ' ';
                    if (recipe.prepTime) recipeText += 'Förberedelse: ' + recipe.prepTime + ' ';
                    if (recipe.cookTime) recipeText += 'Tillagning: ' + recipe.cookTime;
                    recipeText += '\\n';
                  }

                  if (recipe.recipeYield) {
                    recipeText += 'Portioner: ' + recipe.recipeYield + '\\n';
                  }

                  return recipeText.trim();
                }
              }
            }
            return null;
          } catch (e) {
            console.error('JSON-LD parsing error:', e);
            return null;
          }
        })()
        ''',
      );

      if (result != null &&
          result.toString().isNotEmpty &&
          result.toString() != 'null') {
        debugPrint('✅ Recipe structured data found!');
        return result.toString();
      }
    } catch (e) {
      debugPrint('❌ JSON-LD extraction error: $e');
    }

    return null;
  }

  /// Extract recipe data from microdata attributes
  Future<String?> _extractMicrodata(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            const recipeElement = document.querySelector('[itemtype*="Recipe"]');
            if (!recipeElement) return null;

            let recipeText = '';

            const name = recipeElement.querySelector('[itemprop="name"]');
            if (name) recipeText += name.textContent.trim() + '\\n\\n';

            const description = recipeElement.querySelector('[itemprop="description"]');
            if (description) recipeText += description.textContent.trim() + '\\n\\n';

            const ingredients = recipeElement.querySelectorAll('[itemprop="recipeIngredient"]');
            if (ingredients.length > 0) {
              recipeText += 'Ingredienser:\\n';
              ingredients.forEach(ing => recipeText += '- ' + ing.textContent.trim() + '\\n');
              recipeText += '\\n';
            }

            const instructions = recipeElement.querySelectorAll('[itemprop="recipeInstructions"]');
            if (instructions.length > 0) {
              recipeText += 'Instruktioner:\\n';
              instructions.forEach((inst, i) => {
                recipeText += (i + 1) + '. ' + inst.textContent.trim() + '\\n';
              });
              recipeText += '\\n';
            }

            return recipeText.trim() || null;
          } catch (e) {
            console.error('Microdata parsing error:', e);
            return null;
          }
        })()
        ''',
      );

      if (result != null &&
          result.toString().isNotEmpty &&
          result.toString() != 'null') {
        debugPrint('✅ Recipe microdata found!');
        return result.toString();
      }
    } catch (e) {
      debugPrint('❌ Microdata extraction error: $e');
    }

    return null;
  }

  /// Extract recipe content using CSS selectors with validation
  Future<String?> _extractRecipeContent(
      InAppWebViewController controller) async {
    // Skip structured data selectors (first 3 in the list)
    for (final selector in selectors.skip(3)) {
      if (isDisposed()) break;

      try {
        final result = await controller.evaluateJavascript(
          source: '''
          (function() {
            try {
              const element = document.querySelector('$selector');
              if (element) {
                // Filter out common non-recipe content
                const text = element.innerText || element.textContent || '';
                if (text.length > 300 &&
                    !text.includes('cookie') &&
                    !text.includes('gdpr') &&
                    !text.includes('OneTrust') &&
                    !text.includes('window.') &&
                    (text.toLowerCase().includes('ingrediens') ||
                     text.toLowerCase().includes('ingredient') ||
                     text.toLowerCase().includes('recept') ||
                     text.toLowerCase().includes('recipe'))) {
                  return text;
                }
              }
              return null;
            } catch (e) {
              return null;
            }
          })()
          ''',
        );

        if (result != null &&
            result.toString().isNotEmpty &&
            result.toString() != 'null') {
          debugPrint('✅ Recipe content found with selector: $selector');
          return result.toString();
        }
      } catch (e) {
        // Continue to next selector
      }
    }

    debugPrint('⚠️ No recipe content found');
    return null;
  }
}
