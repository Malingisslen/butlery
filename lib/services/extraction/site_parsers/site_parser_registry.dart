/// Central registry for site-specific recipe parsers
/// Maps recipe website domains to their corresponding parsers.
/// Used by UrlImportStrategy to route URLs to site-specific extraction logic.

import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';

/// Registry of site-specific recipe parsers
class SiteParserRegistry {
  /// Map of domain → parser
  /// **Example:**
  /// ```dart
  /// 'ica.se' → IcaRecipeParser()
  /// 'arla.se' → ArlaRecipeParser()
  /// 'koket.se' → KoketRecipeParser()
  /// ```
  static final Map<String, RecipeSiteParser> _parsers = {};

  /// Register a site parser
  /// **Example:**
  /// ```dart
  /// SiteParserRegistry.register(IcaRecipeParser());
  /// ```
  static void register(RecipeSiteParser parser) {
    _parsers[parser.domain.toLowerCase()] = parser;
  }

  /// Get parser for a URL
  /// **Matching logic:**
  /// 1. Extract domain from URL
  /// 2. Try exact match (e.g., "ica.se")
  /// 3. Try without "www." prefix (e.g., "www.ica.se" → "ica.se")
  /// 4. Return null if no parser found
  /// **Example:**
  /// ```dart
  /// final parser = SiteParserRegistry.getParser('https://www.ica.se/recept/kottbullar');
  /// // Returns IcaRecipeParser instance
  /// ```
  static RecipeSiteParser? getParser(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host.toLowerCase();

      // Try exact match
      if (_parsers.containsKey(domain)) {
        return _parsers[domain];
      }

      // Try without www. prefix
      final withoutWww = domain.startsWith('www.')
          ? domain.substring(4)
          : domain;

      if (_parsers.containsKey(withoutWww)) {
        return _parsers[withoutWww];
      }

      // No parser found
      return null;
    } catch (e) {
      // Invalid URL
      return null;
    }
  }

  /// Check if a parser exists for a URL
  static bool hasParser(String url) {
    return getParser(url) != null;
  }

  /// Get all registered domains
  static List<String> get registeredDomains {
    return _parsers.keys.toList();
  }

  /// Clear all registered parsers (for testing)
  static void clear() {
    _parsers.clear();
  }

  /// Get count of registered parsers
  static int get count => _parsers.length;
}
