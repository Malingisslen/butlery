/// Intelligent content detection service for recipe and social media content analysis with multi-platform support.
/// This service provides sophisticated content analysis capabilities for detecting and classifying shared
/// content from various sources including social media platforms, recipe websites, and plain text. It implements
/// advanced pattern recognition, keyword analysis, and platform identification to enable intelligent content
/// processing workflows throughout the application with comprehensive support for Swedish and English content.
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns and error handling
/// - Uses [SingletonServiceMixin] for standardized singleton implementation and lifecycle management
/// - Integrates with content import workflows for automated recipe detection and processing
/// - Provides comprehensive analysis results with detailed metadata for content processing decisions
/// **Content Detection Capabilities:**
/// - **Multi-Platform URL Detection**: Advanced pattern recognition for Instagram, Facebook, TikTok, YouTube
/// - **Recipe Text Analysis**: Intelligent keyword-based detection for Swedish and English recipe content
/// - **Social Media Integration**: Specialized handling for social media content requiring WebView extraction
/// - **Website Classification**: Automatic identification of recipe websites versus social media platforms
/// - **Content Validation**: URL validation and accessibility checking for content processing reliability
/// - **Metadata Extraction**: Comprehensive metadata generation for content processing optimization
/// **Pattern Recognition and Classification:**
/// - **Platform-Specific Patterns**: Regex-based pattern matching for accurate platform identification
/// - **Multilingual Keyword Detection**: Swedish and English recipe keyword recognition with cooking terminology
/// - **Content Type Classification**: Sophisticated classification into recipe text, URLs, social media, and plain text
/// - **Modular Pattern System**: Easy extension and maintenance of platform patterns and detection rules

import 'package:flutter/material.dart';
import 'package:butlery/core/base/base_service.dart';

/// Enumeration defining the types of content that can be detected and classified by the content detection system.
/// This enum provides comprehensive content type classification enabling the application to handle
/// different content sources appropriately with specialized processing workflows for each content type.
/// **Content Type Categories:**
/// - [recipeText] Direct recipe text content (copied from apps or notes)
/// - [recipeUrl] URL links to recipe websites requiring standard web scraping
/// - [socialMediaUrl] Social media URLs requiring WebView-based content extraction
/// - [plainText] Regular text content without recipe-related information
/// - [unknown] Unidentifiable content requiring manual handling or fallback processing
enum ContentType {
  /// Direct recipe text content (copied from apps or notes).
  recipeText,

  /// URL links to recipe websites requiring standard web scraping.
  recipeUrl,

  /// Social media URLs requiring WebView-based content extraction.
  socialMediaUrl,

  /// Regular text content without recipe-related information.
  plainText,

  /// Unidentifiable content requiring manual handling or fallback processing.
  unknown,
}

/// Enumeration defining the source platforms supported by the content detection system.
/// This enum enables platform-specific content processing strategies and extraction methods,
/// allowing the application to handle each platform's unique content structure and access requirements.
/// **Supported Platforms:**
/// - [instagram] Instagram posts and reels requiring WebView extraction
/// - [facebook] Facebook posts and videos with specialized parsing needs
/// - [tiktok] TikTok videos requiring mobile-optimized content extraction
/// - [youtube] YouTube videos and YouTube Shorts with video content processing
/// - [website] General recipe websites supporting standard web scraping
/// - [unknown] Unidentified platforms requiring fallback processing strategies
enum SourcePlatform {
  /// Instagram posts and reels requiring WebView extraction.
  instagram,

  /// Facebook posts and videos with specialized parsing needs.
  facebook,

  /// TikTok videos requiring mobile-optimized content extraction.
  tiktok,

  /// YouTube videos and YouTube Shorts with video content processing.
  youtube,

  /// General recipe websites supporting standard web scraping.
  website,

  /// Unidentified platforms requiring fallback processing strategies.
  unknown,
}

/// Comprehensive result data structure containing detailed content analysis and classification information.
/// This class encapsulates all relevant information discovered during content detection analysis,
/// providing comprehensive metadata and classification results for intelligent content processing
/// decisions. It includes content type classification, platform identification, URL extraction,
/// and detailed metadata for processing optimization.
/// **Key Analysis Results:**
/// - [type] Content type classification enabling appropriate processing workflows
/// - [platform] Source platform identification for platform-specific processing strategies
/// - [extractedUrl] Clean URL extraction for content fetching and validation
/// - [originalContent] Complete original content preservation for fallback processing
/// - [metadata] Detailed metadata including detected keywords, processing hints, and analysis insights
/// **Processing Integration:**
/// This result enables the application to choose appropriate content processing strategies:
/// - Social media URLs trigger WebView-based extraction workflows
/// - Recipe URLs enable standard web scraping approaches
/// - Recipe text initiates direct text processing and parsing
/// - Plain text provides fallback options and user guidance
class ContentDetectionResult {
  /// Content type classification enabling appropriate processing workflows.
  final ContentType type;

  /// Source platform identification for platform-specific processing strategies.
  final SourcePlatform? platform;

  /// Clean URL extraction for content fetching and validation.
  final String? extractedUrl;

  /// Complete original content preservation for fallback processing.
  final String originalContent;

  /// Detailed metadata including detected keywords, processing hints, and analysis insights.
  final Map<String, dynamic> metadata;

  /// Creates a ContentDetectionResult with comprehensive content analysis information.
  /// [type] Content type classification result from analysis
  /// [platform] Identified source platform (null for non-URL content)
  /// [extractedUrl] Clean extracted URL (null for text-only content)
  /// [originalContent] Complete original content for reference and fallback processing
  /// [metadata] Additional analysis metadata and processing hints (defaults to empty map)
  ContentDetectionResult({
    required this.type,
    this.platform,
    this.extractedUrl,
    required this.originalContent,
    this.metadata = const {},
  });
}

/// Intelligent content detection service providing comprehensive analysis and classification of shared content.
/// This singleton service implements sophisticated content analysis capabilities using advanced pattern
/// recognition, multilingual keyword detection, and platform-specific identification strategies. It provides
/// modular and extensible content classification that can easily be updated to support new platforms,
/// content types, and detection patterns as the application evolves.
/// **Singleton Architecture:**
/// Uses the SingletonServiceMixin pattern for:
/// - Consistent singleton implementation across the application
/// - Memory-efficient single instance management with standardized lifecycle
/// - Integrated error handling and service operation management through BaseService
/// **Content Analysis Engine:**
/// Implements multi-layered content analysis including:
/// - URL extraction and validation with robust pattern matching
/// - Platform identification using comprehensive regex pattern libraries
/// - Recipe content detection through multilingual keyword analysis
/// - Metadata extraction for processing optimization and user feedback
/// **Modular Pattern System:**
/// Designed for easy maintenance and extension:
/// - Platform patterns stored in configurable data structures
/// - Keyword libraries supporting Swedish and English content
/// - Extensible classification system for new content types
/// - Comprehensive debugging and logging capabilities for pattern validation
/// **Usage Examples:**
/// ```dart
/// final detector = ContentDetectorService();
/// // Analyze shared content
/// final result = await detector.detectContent('https://instagram.com/p/ABC123');
/// if (result.type == ContentType.socialMediaUrl) {
///   // Handle social media content with WebView extraction
///   processSocialMediaContent(result);
/// }
/// // Analyze recipe text
/// final textResult = await detector.detectContent('Ingredients: 2 cups flour...');
/// if (textResult.type == ContentType.recipeText) {
///   // Process direct recipe text
///   processRecipeText(textResult);
/// }
/// ```
class ContentDetectorService extends BaseService {
  ContentDetectorService();

  @override
  String get serviceName => 'ContentDetectorService';

  /// Regex-mönster för olika plattformar (lätt att uppdatera)
  static final Map<SourcePlatform, List<RegExp>> _platformPatterns = {
    SourcePlatform.instagram: [
      RegExp(r'instagram\.com/p/[A-Za-z0-9_-]+'),
      RegExp(r'instagram\.com/reel/[A-Za-z0-9_-]+'),
      RegExp(r'instagr\.am/p/[A-Za-z0-9_-]+'),
    ],
    SourcePlatform.facebook: [
      RegExp(r'facebook\.com/[^/]+/posts/\d+'),
      RegExp(r'fb\.com/[^/]+/posts/\d+'),
      RegExp(r'facebook\.com/watch/\?v=\d+'),
      RegExp(r'fb\.watch/[A-Za-z0-9_-]+'),
    ],
    SourcePlatform.tiktok: [
      RegExp(r'tiktok\.com/@[^/]+/video/\d+'),
      RegExp(r'vm\.tiktok\.com/[A-Za-z0-9]+'),
    ],
    SourcePlatform.youtube: [
      RegExp(r'youtube\.com/watch\?v=[A-Za-z0-9_-]+'),
      RegExp(r'youtu\.be/[A-Za-z0-9_-]+'),
      RegExp(r'youtube\.com/shorts/[A-Za-z0-9_-]+'),
    ],
  };

  /// Nyckelord som indikerar recept (från TextImportViewModel)
  static final List<String> _recipeKeywords = [
    // Svenska
    'recept', 'ingredienser', 'instruktioner', 'tillredning',
    'portioner', 'tillagning', 'ugn', 'grader', 'minuter',
    'matsked', 'tesked', 'deciliter', 'liter', 'gram',
    'servera', 'blanda', 'vispa', 'häll', 'stek',

    // Engelska (för internationella recept)
    'recipe', 'ingredients', 'instructions', 'directions',
    'servings', 'cooking', 'oven', 'degrees', 'minutes',
    'tablespoon', 'teaspoon', 'cup', 'cups', 'grams',
    'serve', 'mix', 'whisk', 'pour', 'fry',
  ];

  /// Performs comprehensive content analysis and classification of shared text with intelligent pattern recognition.
  /// This method executes sophisticated content analysis using multi-layered detection strategies including
  /// URL extraction, platform identification, recipe keyword analysis, and content type classification.
  /// It provides comprehensive results with detailed metadata for optimal content processing decisions.
  /// [content] The shared text content to analyze and classify
  /// Returns [ContentDetectionResult] with comprehensive analysis results including:
  /// - Content type classification (social media URL, recipe text, plain text, etc.)
  /// - Platform identification for URL content with specialized processing requirements
  /// - Extracted URLs with validation and accessibility information
  /// - Detected keywords and metadata for processing optimization
  /// - Processing hints and recommendations for optimal content handling
  /// **Analysis Process:**
  /// 1. **URL Detection**: Extracts URLs and identifies source platforms using regex patterns
  /// 2. **Platform Classification**: Determines platform-specific processing requirements
  /// 3. **Content Analysis**: Analyzes text content for recipe keywords and cooking terminology
  /// 4. **Metadata Generation**: Creates comprehensive metadata for processing optimization
  /// 5. **Result Compilation**: Assembles complete analysis results with processing recommendations
  /// **Supported Content Types:**
  /// - Social media URLs (Instagram, Facebook, TikTok) requiring WebView extraction
  /// - Recipe website URLs supporting standard web scraping approaches
  /// - Direct recipe text with multilingual keyword detection
  /// - Plain text content with fallback processing options
  /// **Error Handling:**
  /// - Comprehensive error handling with graceful fallback to unknown content type
  /// - Detailed logging for debugging and pattern validation
  /// - Service operation management through BaseService integration
  Future<ContentDetectionResult> detectContent(String content) async {
    return await executeServiceOperation(
          () async {
            return _detectContentInternal(content);
          },
          operationName: 'Detect content type',
          defaultValue: ContentDetectionResult(
            type: ContentType.unknown,
            originalContent: content,
          ),
          requiresAuth: false,
        ) ??
        ContentDetectionResult(
          type: ContentType.unknown,
          originalContent: content,
        );
  }

  ContentDetectionResult _detectContentInternal(String content) {
    debugPrint(
      '🔍 Analyserar innehåll: ${content.substring(0, content.length.clamp(0, 100))}...',
    );

    // Trimma och normalisera
    final normalizedContent = content.trim().toLowerCase();

    // 1. Kolla om det är en URL (VANLIGAST från social media shares)
    final urlMatch = _extractUrl(content);
    if (urlMatch != null) {
      // Identifiera plattform
      final platform = _identifyPlatform(urlMatch);

      debugPrint('✅ URL detekterad: $urlMatch från $platform');

      // Om det är social media, behöver vi alltid WebView för att extrahera
      if (platform == SourcePlatform.instagram ||
          platform == SourcePlatform.facebook ||
          platform == SourcePlatform.tiktok) {
        return ContentDetectionResult(
          type: ContentType.socialMediaUrl,
          platform: platform,
          extractedUrl: urlMatch,
          originalContent: content,
          metadata: {
            'requiresWebView': true,
            'hasAdditionalText': content.length > urlMatch.length + 10,
          },
        );
      }

      // Vanlig receptwebbsida (t.ex. Arla, ICA, etc)
      return ContentDetectionResult(
        type: ContentType.recipeUrl,
        platform: SourcePlatform.website,
        extractedUrl: urlMatch,
        originalContent: content,
      );
    }

    // 2. Ingen URL = troligen kopierad text eller delad från notes-app
    if (_containsRecipeKeywords(normalizedContent)) {
      debugPrint('✅ Recepttext detekterad (troligen kopierad från app)');

      return ContentDetectionResult(
        type: ContentType.recipeText,
        originalContent: content,
        metadata: {
          'detectedKeywords': _getDetectedKeywords(normalizedContent),
          'source': 'Troligen kopierad text eller notes-app',
        },
      );
    }

    // 3. Vanlig text utan recept
    debugPrint('ℹ️ Vanlig text utan recept');

    return ContentDetectionResult(
      type: ContentType.plainText,
      originalContent: content,
    );
  }

  /// Extraherar URL från text
  String? _extractUrl(String content) {
    // Generellt URL-mönster
    final urlRegex = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );

    final match = urlRegex.firstMatch(content);
    return match?.group(0);
  }

  /// Identifierar plattform från URL
  SourcePlatform _identifyPlatform(String url) {
    final normalizedUrl = url.toLowerCase();

    for (final entry in _platformPatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(normalizedUrl)) {
          return entry.key;
        }
      }
    }

    // Kolla om det är en generisk webbsida
    if (normalizedUrl.startsWith('http')) {
      return SourcePlatform.website;
    }

    return SourcePlatform.unknown;
  }

  /// Kontrollerar om text innehåller recept-nyckelord
  bool _containsRecipeKeywords(String text) {
    return _recipeKeywords.any((keyword) => text.contains(keyword));
  }

  /// Returnerar vilka nyckelord som hittades
  List<String> _getDetectedKeywords(String text) {
    return _recipeKeywords.where((keyword) => text.contains(keyword)).toList();
  }

  /// Validerar om en URL är giltig och nåbar
  /// (Kan utökas med faktisk nätverkskontroll i framtiden)
  bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Debug-metod för att logga detekterade mönster
  void debugPatterns() {
    debugPrint('📋 Registrerade plattformsmönster:');
    _platformPatterns.forEach((platform, patterns) {
      debugPrint('  $platform: ${patterns.length} mönster');
    });
    debugPrint('📋 Registrerade nyckelord: ${_recipeKeywords.length}');
  }
}
