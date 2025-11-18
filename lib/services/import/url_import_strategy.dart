/// URL Import Strategy - Extracts recipes from web URLs using structured data or text parsing.
/// Implements a multi-tier extraction workflow:
/// 1. Fetch HTML from URL
/// 2. Try RecipeScraper (JSON-LD/Microdata structured data)
/// 3. Fallback to WebScraper (for JavaScript-heavy sites)
/// 4. Final fallback to TextImportStrategy (parse as plain text)

import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';
import 'package:butlery/utils/recipe_scraper.dart';

/// Strategy for importing recipes from web URLs (recipe sites, blogs, etc.).
/// **Extraction Workflow:**
/// 1. **Static HTML Fetch**: Fast direct HTTP fetch for most recipe sites
/// 2. **Structured Data Parse**: RecipeScraper extracts JSON-LD/Microdata
/// 3. **Dynamic Content Fallback**: WebScraper for JavaScript-rendered sites
/// 4. **Text Parsing Fallback**: TextImportStrategy parses plain text
/// **Supported Sites:**
/// - Recipe sites with schema.org markup (ICA.se, Arla.se, Köket.se, AllRecipes, etc.)
/// - General blogs with structured data
/// - Social media posts (via WebScraper)
/// - Any site with recognizable recipe text
class UrlImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  // HTTP timeout for static HTML fetching
  static const _fetchTimeout = Duration(seconds: 10);

  // User agent for HTTP requests (identifies as mobile browser)
  static const _userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';

  // Dependency injection for testing
  final http.Client? _httpClient;
  final WebScraper Function()? _webScraperFactory;

  /// Creates a URL import strategy with optional dependency injection for testing.
  /// [httpClient] - Optional HTTP client for mocking network requests
  /// [webScraperFactory] - Optional factory for creating WebScraper instances (for mocking)
  UrlImportStrategy({
    http.Client? httpClient,
    WebScraper Function()? webScraperFactory,
  })  : _httpClient = httpClient,
        _webScraperFactory = webScraperFactory;

  @override
  String get strategyName => 'URL Import';

  @override
  String get description =>
      'Import recipes from web URLs (recipe sites, blogs, social media)';

  @override
  String get inputExample => 'https://www.ica.se/recept/pannkakor-123';

  @override
  bool canHandle(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    try {
      final uri = Uri.parse(trimmed);
      // Must have HTTP or HTTPS scheme, a host, and the host must not be empty
      return uri.hasScheme &&
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  bool validateInput(String input) {
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) async {
    try {
      final url = input.trim();

      // Step 1: Try static HTML fetch + structured data extraction (fast path)
      final htmlResult = await _fetchHtmlWithTimeout(url);

      if (htmlResult != null) {
        // Check for site-specific parser
        final siteParser = SiteParserRegistry.getParser(url);

        Map<String, dynamic>? recipeData;
        String extractionMethod;
        String? siteParserDomain;

        if (siteParser != null) {
          // Use site-specific parser (includes enhancements and fallbacks)
          recipeData = siteParser.parseRecipe(htmlResult);
          extractionMethod = 'site_specific';
          siteParserDomain = siteParser.domain;
        } else {
          // Use generic RecipeScraper for structured data (JSON-LD/Microdata)
          recipeData = extractRecipeFromHtml(htmlResult);
          extractionMethod = 'schema.org';
        }

        if (recipeData != null) {
          // Success! Create recipe from structured data
          final recipe = _createRecipeFromSchemaOrg(recipeData, url);

          // Extract site-specific enhancements from recipeData
          final metadata = <String, dynamic>{
            'strategy': strategyName,
            'extraction_method': extractionMethod,
            'data_format': recipeData['@type'] ?? 'Recipe',
            'url': url,
            if (siteParserDomain != null) 'site_parser': siteParserDomain,
          };

          // Only core recipe fields extracted (ingredients, instructions, portions, time)
          // No additional site-specific fields

          return ImportResult.success(recipe, metadata: metadata);
        }
      }

      // Step 2: Fallback to WebScraper for JavaScript-heavy sites
      final webScraperResult = await _tryWebScraper(url);

      if (webScraperResult != null) {
        // Parse extracted text with TextImportStrategy
        final textStrategy = TextImportStrategy();
        final textResult = await textStrategy.import(webScraperResult);

        if (textResult.isSuccess && textResult.recipe != null) {
          // Add source URL to recipe
          final recipe = textResult.recipe!.copyWith(
            sourceUrl: url,
          );

          final warnings = [
            ...?(textResult.warnings),
            'No structured data found - parsed as plain text',
          ];

          return ImportResult.success(
            recipe,
            warnings: warnings,
            metadata: {
              'strategy': strategyName,
              'extraction_method': 'text_fallback',
              'url': url,
            },
          );
        }
      }

      // Step 3: Final fallback - try parsing HTML as text
      if (htmlResult != null && htmlResult.length > 100) {
        final textStrategy = TextImportStrategy();

        // Strip HTML tags and parse as text
        final plainText = _stripHtmlTags(htmlResult);

        if (plainText.length > 100) {
          final textResult = await textStrategy.import(plainText);

          if (textResult.isSuccess && textResult.recipe != null) {
            final recipe = textResult.recipe!.copyWith(
              sourceUrl: url,
            );

            final warnings = [
              ...?(textResult.warnings),
              'Extracted from HTML text - quality may vary',
            ];

            return ImportResult.success(
              recipe,
              warnings: warnings,
              metadata: {
                'strategy': strategyName,
                'extraction_method': 'html_text_parse',
                'url': url,
              },
            );
          }
        }
      }

      // All extraction methods failed
      return ImportResult.failure(
        'Could not extract recipe from URL. The page may not contain a valid recipe or may require manual input.',
        metadata: {
          'strategy': strategyName,
          'url': url,
          'html_fetched': htmlResult != null,
          'html_length': htmlResult?.length ?? 0,
        },
      );

    } catch (e) {
      return ImportResult.failure(
        'Error importing from URL: ${e.toString()}',
        metadata: {
          'strategy': strategyName,
          'error_type': e.runtimeType.toString(),
        },
      );
    }
  }

  /// Fetch HTML from URL with timeout (fast static fetch)
  Future<String?> _fetchHtmlWithTimeout(String url) async {
    try {
      final client = _httpClient ?? http.Client();
      final shouldCloseClient = _httpClient == null;

      try {
        final response = await client.get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
        ).timeout(_fetchTimeout);

        if (response.statusCode == 200) {
          return response.body;
        }

        return null;
      } finally {
        if (shouldCloseClient) {
          client.close();
        }
      }
    } catch (e) {
      // Timeout or network error - return null to try WebScraper
      return null;
    }
  }

  /// Try WebScraper as fallback for JavaScript-heavy sites
  Future<String?> _tryWebScraper(String url) async {
    try {
      final detector = pd.PlatformDetector();
      final platform = detector.detectPlatform(url);
      final webUrl = detector.convertToWebUrl(url);

      final webScraper = _webScraperFactory?.call() ?? WebScraper();

      try {
        final extractionResult = await webScraper.performExtraction(webUrl, platform);

        if (extractionResult.success && extractionResult.extractedText != null) {
          return extractionResult.extractedText;
        }

        return null;
      } finally {
        webScraper.dispose();
      }
    } catch (e) {
      return null;
    }
  }

  /// Strip HTML tags from content (basic text extraction)
  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', multiLine: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', multiLine: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Create Recipe from schema.org structured data
  Recipe _createRecipeFromSchemaOrg(Map<String, dynamic> data, String sourceUrl) {
    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: _extractTitle(data),
        description: _extractDescription(data),
        ingredients: _extractIngredients(data),
        instructions: _extractInstructions(data),
        portions: _extractYield(data),
        timeMinutes: _extractTime(data),
        mealType: 'Lunch', // Default meal type
        imageUrls: _extractImages(data),
        sourceUrl: sourceUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '', // Will be set by PersonalRecipeOperations
      ),
      type: RecipeType.personal,
    );
  }

  /// Extract title from schema.org data
  String _extractTitle(Map<String, dynamic> data) {
    final name = data['name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }
    return 'Imported Recipe';
  }

  /// Extract description from schema.org data
  String _extractDescription(Map<String, dynamic> data) {
    final desc = data['description'];
    return desc?.toString().trim() ?? '';
  }

  /// Extract ingredients from schema.org data
  List<String> _extractIngredients(Map<String, dynamic> data) {
    final ingredients = data['recipeIngredient'];

    if (ingredients == null) return [];

    if (ingredients is List) {
      return ingredients
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (ingredients is String && ingredients.trim().isNotEmpty) {
      return [ingredients.trim()];
    }

    return [];
  }

  /// Extract instructions from schema.org data (handles multiple formats)
  List<String> _extractInstructions(Map<String, dynamic> data) {
    final instructions = data['recipeInstructions'];

    if (instructions == null) return [];

    // Format 1: List of strings
    if (instructions is List) {
      final steps = <String>[];

      for (final instruction in instructions) {
        if (instruction is String) {
          steps.add(instruction.trim());
        } else if (instruction is Map) {
          // Format 2: HowToStep objects with 'text' property
          final text = instruction['text'];
          if (text != null && text.toString().trim().isNotEmpty) {
            steps.add(text.toString().trim());
          }
        }
      }

      return steps.where((s) => s.isNotEmpty).toList();
    }

    // Format 3: Single string (split by sentences or newlines)
    if (instructions is String && instructions.trim().isNotEmpty) {
      // Try splitting by periods followed by capital letters
      final steps = instructions
          .split(RegExp(r'\.\s+(?=[A-Z])'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (steps.length > 1) {
        return steps.map((s) => s.endsWith('.') ? s : '$s.').toList();
      }

      return [instructions.trim()];
    }

    return [];
  }

  /// Extract yield/servings from schema.org data
  int? _extractYield(Map<String, dynamic> data) {
    final yield_ = data['recipeYield'];

    if (yield_ == null) return null;

    // Try to extract number from yield string
    final yieldStr = yield_.toString();
    final match = RegExp(r'\d+').firstMatch(yieldStr);

    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// Extract total time from schema.org data (ISO 8601 duration)
  int? _extractTime(Map<String, dynamic> data) {
    // Try totalTime first
    final duration = data['totalTime'];

    // Fallback to prepTime + cookTime
    if (duration == null) {
      final prepTime = _parseDuration(data['prepTime']);
      final cookTime = _parseDuration(data['cookTime']);

      if (prepTime != null || cookTime != null) {
        return (prepTime ?? 0) + (cookTime ?? 0);
      }

      return null;
    }

    return _parseDuration(duration);
  }

  /// Parse ISO 8601 duration (e.g., "PT30M" → 30 minutes)
  int? _parseDuration(dynamic duration) {
    if (duration == null) return null;

    final durationStr = duration.toString().trim();

    // ISO 8601 format: PT{hours}H{minutes}M{seconds}S
    if (!durationStr.startsWith('PT')) return null;

    int totalMinutes = 0;

    // Extract hours
    final hoursMatch = RegExp(r'(\d+)H').firstMatch(durationStr);
    if (hoursMatch != null) {
      totalMinutes += (int.tryParse(hoursMatch.group(1)!) ?? 0) * 60;
    }

    // Extract minutes
    final minutesMatch = RegExp(r'(\d+)M').firstMatch(durationStr);
    if (minutesMatch != null) {
      totalMinutes += int.tryParse(minutesMatch.group(1)!) ?? 0;
    }

    return totalMinutes > 0 ? totalMinutes : null;
  }

  /// Extract image URLs from schema.org data
  List<String> _extractImages(Map<String, dynamic> data) {
    final image = data['image'];

    if (image == null) return [];

    // Format 1: Single URL string
    if (image is String && image.trim().isNotEmpty) {
      return [image.trim()];
    }

    // Format 2: List of URLs
    if (image is List) {
      return image
          .map((e) {
            // Handle both string URLs and objects with 'url' property
            if (e is String) return e.trim();
            if (e is Map && e['url'] != null) return e['url'].toString().trim();
            return null;
          })
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();
    }

    // Format 3: Object with 'url' property
    if (image is Map && image['url'] != null) {
      final url = image['url'].toString().trim();
      if (url.isNotEmpty) {
        return [url];
      }
    }

    return [];
  }
}
