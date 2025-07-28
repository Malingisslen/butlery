// lib/viewmodels/url_import_viewmodel.dart

import 'package:http/http.dart' as http;
import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// ViewModel för URL-baserad receptimport
/// Refactored to use ImportBaseViewModel with UrlImportMixin for consistency
class UrlImportViewModel extends ImportBaseViewModel with UrlImportMixin {

  UrlImportViewModel({required super.importManager});

  // ===== URL-SPECIFIC METHODS =====

  /// Fetch content from URL and parse it into a recipe
  Future<void> fetchAndParse() async {
    if (!canFetch) {
      setError('Please provide a valid URL');
      return;
    }

    // First fetch content from URL
    await fetchFromUrl();

    // If successful, perform import
    if (hasExtractedText && !hasError) {
      await performImport();
    }
  }

  /// Complete the import process: fetch, parse, and save recipe
  Future<bool> importAndSave() async {
    return await completeImport();
  }

  @override
  Future<String> fetchContentFromUrl(String url) async {
    try {
      // Fetch the HTML content
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch content from URL: ${response.statusCode}');
      }
      
      final htmlContent = response.body;
      
      if (htmlContent.isEmpty) {
        throw Exception('No content found on this page');
      }
      
      return htmlContent;
    } catch (e) {
      // Fallback to basic HTTP fetch if scraping fails
      return await _basicHttpFetch(url);
    }
  }

  /// Basic HTTP fetch fallback when specialized scraping fails
  Future<String> _basicHttpFetch(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch content: HTTP ${response.statusCode}');
    }

    // Basic HTML content extraction
    String content = response.body;
    
    // Remove HTML tags for basic text extraction
    content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
    content = content.replaceAll(RegExp(r'\s+'), ' ');
    content = content.trim();

    if (content.length < 100) {
      throw Exception('Content too short to contain a recipe');
    }

    return content;
  }

  // ===== URL VALIDATION =====

  /// Get validation errors for current URL
  List<String> getUrlValidationErrors() {
    if (url.trim().isEmpty) {
      return ['URL is required'];
    }

    final errors = <String>[];
    final trimmedUrl = url.trim();

    try {
      final uri = Uri.parse(trimmedUrl);
      
      if (!uri.hasScheme) {
        errors.add('URL must include http:// or https://');
      } else if (uri.scheme != 'http' && uri.scheme != 'https') {
        errors.add('Only HTTP and HTTPS URLs are supported');
      }

      if (!uri.hasAuthority) {
        errors.add('URL must include a domain name');
      }
    } catch (e) {
      errors.add('Invalid URL format');
    }

    return errors;
  }

  /// Check if URL points to a known recipe site
  bool isKnownRecipeSite() {
    if (!canFetch) return false;

    final domain = Uri.parse(url.trim()).host.toLowerCase();
    final knownSites = [
      'allrecipes.com',
      'food.com',
      'epicurious.com',
      'foodnetwork.com',
      'delish.com',
      'tasty.co',
      'ica.se',
      'arla.se',
      'koket.se',
      'recepten.se',
    ];

    return knownSites.any((site) => domain.contains(site));
  }

  /// Get suggestions for better URL processing
  List<String> getUrlSuggestions() {
    if (!canFetch) {
      return getUrlValidationErrors();
    }

    final suggestions = <String>[];

    if (isKnownRecipeSite()) {
      suggestions.add('✅ URL from known recipe site - should work well');
    } else {
      suggestions.add('ℹ️ Unknown site - content extraction may vary');
    }

    if (url.contains('recipe') || url.contains('recept')) {
      suggestions.add('✅ URL contains recipe keywords');
    }

    if (url.length > 200) {
      suggestions.add('⚠️ Very long URL - try copying the main recipe page URL');
    }

    return suggestions;
  }

  // ===== CONTENT ANALYSIS =====

  /// Analyze extracted content quality
  Map<String, dynamic> analyzeExtractedContent() {
    if (!hasExtractedText) {
      return {
        'quality': 'none',
        'score': 0,
        'issues': ['No content extracted'],
      };
    }

    final text = extractedText.toLowerCase();
    int score = 0;
    final issues = <String>[];
    final positives = <String>[];

    // Check for recipe indicators
    if (text.contains('ingredient')) {
      score += 25;
      positives.add('Contains ingredients');
    } else {
      issues.add('No ingredients section found');
    }

    if (text.contains('instruction') || text.contains('step') || text.contains('method')) {
      score += 25;
      positives.add('Contains instructions');
    } else {
      issues.add('No instructions section found');
    }

    if (text.contains('minute') || text.contains('hour') || text.contains('time')) {
      score += 15;
      positives.add('Contains timing information');
    }

    if (text.contains('serve') || text.contains('portion') || text.contains('yield')) {
      score += 10;
      positives.add('Contains serving information');
    }

    // Check content length
    if (extractedText.length > 500) {
      score += 15;
      positives.add('Good content length');
    } else if (extractedText.length < 200) {
      issues.add('Content seems too short');
    }

    // Check for recipe title patterns
    if (text.contains('recipe') || text.contains('recept')) {
      score += 10;
      positives.add('Contains recipe keywords');
    }

    String quality;
    if (score >= 75) {
      quality = 'excellent';
    } else if (score >= 50) {
      quality = 'good';
    } else if (score >= 25) {
      quality = 'fair';
    } else {
      quality = 'poor';
    }

    return {
      'quality': quality,
      'score': score,
      'issues': issues,
      'positives': positives,
    };
  }

  // ===== DEBUGGING SUPPORT =====

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'urlValidationErrors': getUrlValidationErrors(),
    'isKnownRecipeSite': isKnownRecipeSite(),
    'urlSuggestions': getUrlSuggestions(),
    'contentAnalysis': analyzeExtractedContent(),
  };
}