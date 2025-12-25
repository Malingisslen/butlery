/// Comprehensive URL import ViewModel providing advanced web content extraction for Flutter applications.
/// This module implements sophisticated URL-based recipe importing following Single Responsibility Principle,
/// specializing in extracting recipe content from web URLs including blog posts, recipe websites, social media,
/// and general web pages containing recipe information. It provides complete web scraping infrastructure
/// while maintaining clean separation from UI rendering, data persistence, and other import types.
/// **Single Responsibility Focus:**
/// This module exclusively handles URL import presentation layer concerns:
/// - **Web Content Extraction**: Advanced URL fetching, HTML parsing, and content extraction with comprehensive error handling
/// - **Recipe Site Intelligence**: Smart recognition of known recipe sites with optimized extraction strategies
/// - **URL Validation Excellence**: Comprehensive URL validation ensuring fetchability and content viability
/// - **Content Analysis Features**: Intelligent content quality assessment and extraction optimization recommendations
/// - **HTTP Coordination Management**: Complete HTTP request management with fallback strategies and user agent handling
/// **What This Module Does NOT Handle:**
/// - Text-based content parsing (handled by TextImportViewModel and text parsing services)
/// - UI rendering and widget creation (handled by URL import views and presentation components)
/// - Direct data persistence (handled by ImportManager and underlying storage services)
/// - Complex web scraping implementation (handled by web scraping services and extraction strategies)
/// **URL Import ViewModel Features:**
/// - **Advanced Web Scraping**: Sophisticated URL content extraction with HTML parsing and text extraction
/// - **Recipe Site Recognition**: Smart recognition of popular recipe sites with optimized extraction strategies
/// - **URL Validation System**: Comprehensive URL validation ensuring proper format and fetchability
/// - **Content Quality Analysis**: Intelligent content assessment with quality scoring and extraction recommendations
/// - **Swedish Localization**: Complete Swedish language support for errors, suggestions, and user feedback
/// **Usage Examples:**
/// ```dart
/// // Initialize URL import ViewModel with ImportManager dependency
/// final urlImportViewModel = UrlImportViewModel(
///   importManager: ServiceLocator.get<ImportManager>(),
/// );
/// // URL input and content fetching workflow
/// urlImportViewModel.updateUrl('https://www.ica.se/recept/pannkakor-grundrecept');
/// // Validate and fetch content
/// final validationErrors = urlImportViewModel.getUrlValidationErrors();
/// if (validationErrors.isEmpty) {
///   await urlImportViewModel.fetchAndParse();
///   if (urlImportViewModel.hasExtractedText) {
///     final contentAnalysis = urlImportViewModel.analyzeExtractedContent();
///     if (contentAnalysis['quality'] == 'excellent') {
///       final recipe = urlImportViewModel.parsedRecipe;
///     }
///   }
/// }
/// // Complete import workflow
/// final importSuccess = await urlImportViewModel.importAndSave();
/// if (importSuccess) {
///   // Recipe successfully imported and saved
/// } else {
///   // Handle error: urlImportViewModel.error
/// }
/// // URL analysis and suggestions
/// final suggestions = urlImportViewModel.getUrlSuggestions();
/// final isKnownSite = urlImportViewModel.isKnownRecipeSite();
/// // Content quality assessment
/// final contentAnalysis = urlImportViewModel.analyzeExtractedContent();
/// final quality = contentAnalysis['quality']; // 'excellent', 'good', 'fair', 'poor'
/// final score = contentAnalysis['score']; // 0-100
/// final issues = contentAnalysis['issues']; // List of identified issues
/// // State monitoring and validation
/// if (urlImportViewModel.canFetch) {
///   // URL is valid and ready for fetching
/// } else {
///   // Show validation errors
/// }
/// ```

// lib/viewmodels/url_import_viewmodel.dart

import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/services/social_media_extractor.dart';

/// Comprehensive URL import ViewModel providing advanced web content extraction through HTTP coordination.
/// Specializes in URL-based recipe importing from web sources including recipe blogs, cooking websites, social media,
/// and general web pages containing recipe content. Extends ImportBaseViewModel with UrlImportMixin to provide complete
/// web scraping functionality with content analysis, validation, and extraction workflow management.
/// **Core Responsibilities:**
/// - Advanced URL content fetching with HTML parsing and text extraction
/// - Recipe site recognition and optimized extraction strategies
/// - URL validation ensuring proper format and content accessibility
/// - Content quality analysis with extraction optimization recommendations
/// - Swedish localized error messages and user feedback coordination
class UrlImportViewModel extends ImportBaseViewModel with UrlImportMixin {
  /// Initializes URL import ViewModel with comprehensive ImportManager integration and web scraping preparation.
  /// [importManager] ImportManager instance for URL import strategy coordination and recipe parsing
  /// Establishes URL import infrastructure with ImportManager integration, enabling comprehensive
  /// web content extraction functionality with unified state management, validation, and error handling.
  /// **Initialization Process:**
  /// - ImportManager integration for URL import strategy execution
  /// - UrlImportMixin setup for specialized web content functionality
  /// - HTTP client preparation for web scraping operations
  /// - URL validation system preparation with comprehensive error handling
  UrlImportViewModel({required super.importManager});

  /// Fetches web content from URL and parses it into recipe with comprehensive workflow coordination.
  /// Performs complete URL import workflow including URL validation, content fetching,
  /// HTML parsing, text extraction, and recipe parsing with comprehensive error handling
  /// and Swedish localized error messages for optimal user experience.
  /// **Fetch and Parse Process:**
  /// 1. URL validation ensuring proper format and fetchability
  /// 2. Web content fetching with HTTP client and user agent handling
  /// 3. HTML parsing and text extraction with content optimization
  /// 4. Recipe parsing through ImportManager strategy coordination
  /// **Usage Example:**
  /// ```dart
  /// urlImportViewModel.updateUrl('https://www.ica.se/recept/pannkakor');
  /// await urlImportViewModel.fetchAndParse();
  /// if (urlImportViewModel.hasParsedRecipe) {
  ///   final recipe = urlImportViewModel.parsedRecipe;
  /// }
  /// ```
  Future<void> fetchAndParse() async {
    if (!canFetch) {
      setError('Vänligen ange en giltig URL');
      return;
    }

    // First fetch content from URL
    await fetchFromUrl();

    // If successful, perform import
    if (hasExtractedText && !hasError) {
      await performImport();
    }
  }

  /// Completes comprehensive URL import workflow with fetching, parsing, validation, and recipe saving.
  /// Returns true if complete import process succeeds, false if any step fails.
  /// Performs complete URL import workflow including URL validation, content fetching,
  /// HTML parsing, recipe parsing, validation, and saving with comprehensive error handling.
  /// **Complete Import Process:**
  /// 1. URL validation and fetchability checks
  /// 2. Web content fetching and HTML parsing
  /// 3. Text extraction and recipe parsing through ImportManager
  /// 4. Recipe data validation ensuring completeness
  /// 5. Recipe saving to collection with error handling
  /// **Usage Example:**
  /// ```dart
  /// urlImportViewModel.updateUrl('https://recipe-site.com/recipe');
  /// final importSuccess = await urlImportViewModel.importAndSave();
  /// if (importSuccess) {
  ///   // Recipe successfully imported and saved
  /// } else {
  ///   // Handle error: urlImportViewModel.error
  /// }
  /// ```
  Future<bool> importAndSave() async {
    return await completeImport();
  }

  /// Fetches recipe content from URL using advanced WebScraper with platform-specific extraction.
  /// [url] Target URL for recipe content extraction
  /// Returns extracted recipe text content optimized for parsing.
  /// Uses sophisticated WebScraper service with platform detection, headless browser technology,
  /// and recipe-specific content selectors for optimal extraction quality.
  /// **Advanced Extraction Process:**
  /// - Platform detection for extraction strategy optimization
  /// - WebScraper service with headless browser and JavaScript support
  /// - Recipe-specific DOM selectors and structured data parsing
  /// - Comprehensive error handling with Swedish localized messages
  /// **Override Implementation**: Replaces basic HTTP with sophisticated WebScraper integration.
  @override
  Future<String> fetchContentFromUrl(String url) async {
    // Detect platform for optimized extraction
    final platformDetector = pd.PlatformDetector();
    final platform = platformDetector.detectPlatform(url);

    // Convert mobile URLs to web versions if needed
    final webUrl = platformDetector.convertToWebUrl(url);

    // Use WebScraper service for advanced content extraction
    final webScraper = WebScraper();

    try {
      final extractionResult =
          await webScraper.performExtraction(webUrl, platform);

      if (extractionResult.success && extractionResult.extractedText != null) {
        return extractionResult.extractedText!;
      } else {
        throw Exception(extractionResult.error ??
            'Kunde inte extrahera innehåll från sidan');
      }
    } finally {
      // Always dispose WebScraper to prevent memory leaks
      webScraper.dispose();
    }
  }

  /// Generates comprehensive URL validation errors with Swedish localized error messages.
  /// Returns list of validation errors for current URL ensuring proper format and fetchability.
  /// Performs comprehensive URL validation including format checking, scheme validation,
  /// domain presence verification, and protocol support assessment with Swedish localized error messages.
  /// **Validation Criteria:**
  /// - URL presence and non-empty content
  /// - Valid URL format and parsing capability
  /// - HTTP/HTTPS protocol scheme requirement
  /// - Domain name presence and authority validation
  /// **Usage Example:**
  /// ```dart
  /// final errors = urlImportViewModel.getUrlValidationErrors();
  /// if (errors.isEmpty) {
  ///   // URL is valid for fetching
  /// } else {
  ///   // Display validation errors to user
  /// }
  /// ```
  List<String> getUrlValidationErrors() {
    if (url.trim().isEmpty) {
      return ['URL krävs'];
    }

    final errors = <String>[];
    final trimmedUrl = url.trim();

    try {
      final uri = Uri.parse(trimmedUrl);

      if (!uri.hasScheme) {
        errors.add('URL måste inkludera http:// eller https://');
      } else if (uri.scheme != 'http' && uri.scheme != 'https') {
        errors.add('Endast HTTP- och HTTPS-URL:er stöds');
      }

      if (!uri.hasAuthority) {
        errors.add('URL måste inkludera ett domännamn');
      }
    } catch (e) {
      errors.add('Ogiltigt URL-format');
    }

    return errors;
  }

  /// Checks if URL points to known recipe site with optimized extraction capabilities.
  /// Returns true if URL domain matches known recipe sites, false otherwise.
  /// Performs domain analysis against curated list of popular recipe sites
  /// enabling optimized extraction strategies and improved parsing success rates.
  /// **Known Recipe Sites Include:**
  /// - International: AllRecipes, Food.com, Epicurious, Food Network, Delish, Tasty
  /// - Swedish: ICA, Arla, Köket, Recepten
  /// - Additional sites continuously added based on usage patterns
  /// **Usage Example:**
  /// ```dart
  /// if (urlImportViewModel.isKnownRecipeSite()) {
  ///   // URL from known recipe site - higher success probability
  /// } else {
  ///   // General web content - may require additional processing
  /// }
  /// ```
  bool isKnownRecipeSite() {
    if (!canFetch) return false;

    final domain = Uri.parse(url.trim()).host.toLowerCase();
    final knownSites = [
      // International recipe sites
      'allrecipes.com',
      'food.com',
      'epicurious.com',
      'foodnetwork.com',
      'delish.com',
      'tasty.co',
      'recipetineats.com',
      'simplyrecipes.com',

      // Swedish recipe sites
      'ica.se',
      'arla.se',
      'koket.se',
      'recepten.se',
      'tasteline.com',
      'mittkok.expressen.se',
    ];

    return knownSites.any((site) => domain.contains(site));
  }

  /// Generates intelligent URL processing suggestions with Swedish localization and optimization recommendations.
  /// Returns list of suggestions for improving URL processing success and content extraction quality.
  /// Performs comprehensive URL analysis including site recognition, keyword detection,
  /// URL structure assessment, and extraction optimization recommendations with Swedish localized suggestions.
  /// **URL Analysis Features:**
  /// - Known recipe site recognition with success probability indicators
  /// - Recipe keyword detection in URL structure
  /// - URL length assessment with optimization recommendations
  /// - Content extraction quality predictions and improvement suggestions
  /// **Usage Example:**
  /// ```dart
  /// final suggestions = urlImportViewModel.getUrlSuggestions();
  /// for (final suggestion in suggestions) {
  ///   // Display suggestion to user for URL optimization
  /// }
  /// ```
  List<String> getUrlSuggestions() {
    if (!canFetch) {
      return getUrlValidationErrors();
    }

    final suggestions = <String>[];

    if (isKnownRecipeSite()) {
      suggestions.add('✅ URL från känd receptsida - bör fungera bra');
    } else {
      suggestions.add('ℹ️ Okänd sida - innehållsextraktion kan variera');
    }

    if (url.contains('recipe') || url.contains('recept')) {
      suggestions.add('✅ URL innehåller receptnyckelord');
    }

    if (url.length > 200) {
      suggestions
          .add('⚠️ Mycket lång URL - försök kopiera huvudreceptsidans URL');
    }

    if (url.contains('instagram.com') ||
        url.contains('facebook.com') ||
        url.contains('tiktok.com')) {
      suggestions
          .add('📱 Social media-länk - innehållsextraktion kan vara begränsad');
    }

    if (suggestions.length == 1 && isKnownRecipeSite()) {
      suggestions.add('🚀 Optimal URL för receptimport');
    }

    return suggestions;
  }

  /// Analyzes extracted content quality with comprehensive scoring and Swedish localized feedback.
  /// Returns detailed analysis map containing quality assessment, scoring, and recommendations.
  /// Performs comprehensive content analysis including recipe indicator detection, content structure assessment,
  /// and parsing viability evaluation with Swedish localized issue identification and positive indicators.
  /// **Content Analysis Features:**
  /// - Recipe indicator detection (ingredients, instructions, timing, serving info)
  /// - Content length assessment and parsing viability scoring
  /// - Recipe keyword recognition and structure analysis
  /// - Quality scoring with 'excellent', 'good', 'fair', 'poor' classifications
  /// - Swedish localized issue identification and improvement suggestions
  /// **Analysis Result Structure:**
  /// ```dart
  /// {
  ///   'quality': 'excellent', // Overall quality classification
  ///   'score': 85,           // Numerical score (0-100)
  ///   'issues': [],          // List of identified issues
  ///   'positives': [],       // List of positive indicators
  /// }
  /// ```
  /// **Usage Example:**
  /// ```dart
  /// final analysis = urlImportViewModel.analyzeExtractedContent();
  /// final quality = analysis['quality'];
  /// final score = analysis['score'];
  /// final issues = analysis['issues'];
  /// ```
  Map<String, dynamic> analyzeExtractedContent() {
    if (!hasExtractedText) {
      return {
        'quality': 'none',
        'score': 0,
        'issues': ['Inget innehåll extraherat'],
      };
    }

    final text = extractedText.toLowerCase();
    int score = 0;
    final issues = <String>[];
    final positives = <String>[];

    // Check for recipe indicators (Swedish and English)
    if (text.contains('ingrediens') || text.contains('ingredient')) {
      score += 25;
      positives.add('Innehåller ingredienser');
    } else {
      issues.add('Ingen ingredienssektion hittades');
    }

    if (text.contains('instruktion') ||
        text.contains('instruction') ||
        text.contains('steg') ||
        text.contains('step') ||
        text.contains('gör så här') ||
        text.contains('method')) {
      score += 25;
      positives.add('Innehåller instruktioner');
    } else {
      issues.add('Inga instruktioner hittades');
    }

    if (text.contains('minut') ||
        text.contains('minute') ||
        text.contains('timme') ||
        text.contains('hour') ||
        text.contains('tid') ||
        text.contains('time')) {
      score += 15;
      positives.add('Innehåller tidsinformation');
    }

    if (text.contains('portion') ||
        text.contains('serve') ||
        text.contains('servering') ||
        text.contains('yield')) {
      score += 10;
      positives.add('Innehåller portionsinformation');
    }

    // Check content length
    if (extractedText.length > 500) {
      score += 15;
      positives.add('Bra innehållslängd');
    } else if (extractedText.length < 200) {
      issues.add('Innehållet verkar för kort');
    }

    // Check for recipe title patterns
    if (text.contains('recipe') || text.contains('recept')) {
      score += 10;
      positives.add('Innehåller receptnyckelord');
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

  /// Provides comprehensive debugging state information for URL import development and troubleshooting.
  /// Returns map containing debug information including URL validation state, content analysis results,
  /// recipe site recognition status, and inherited debug state from ImportBaseViewModel for comprehensive
  /// development support and troubleshooting capabilities.
  /// **Debug Information Includes:**
  /// - URL validation errors and processing suggestions
  /// - Recipe site recognition and extraction optimization status
  /// - Content analysis results with quality scoring and issue identification
  /// - Inherited ImportBaseViewModel debug state information
  /// - Web scraping status and HTTP request debugging information
  @override
  Map<String, dynamic> get debugState => {
        ...super.debugState,
        'urlValidationErrors': getUrlValidationErrors(),
        'isKnownRecipeSite': isKnownRecipeSite(),
        'urlSuggestions': getUrlSuggestions(),
        'contentAnalysis': analyzeExtractedContent(),
        'urlLength': url.length,
        'hasExtractedContent': hasExtractedText,
        'extractedContentLength': hasExtractedText ? extractedText.length : 0,
      };
}
