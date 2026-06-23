/// Comprehensive extraction management service orchestrating multi-platform content extraction pipelines.
/// This service serves as the central coordinator for content extraction operations, managing the complex
/// pipeline of platform detection, URL conversion, web scraping, and content parsing. It provides a unified
/// interface for extracting recipe content from various social media platforms and cooking websites with
/// intelligent platform-specific optimization and comprehensive error handling.
/// **Architecture Integration:**
/// - Extends [BaseService] for standardized error handling, logging, and lifecycle management
/// - Coordinates [PlatformDetector] for intelligent platform recognition and URL optimization
/// - Manages [WebScraper] for headless browser-based content extraction and parsing
/// - Integrates with [ExtractionResult] for structured result management and error reporting
/// - Registered as singleton in DI container for consistent instance management
/// **Extraction Pipeline:**
/// - **URL Conversion**: Intelligent URL conversion for platform-specific optimization (e.g., Instagram app URLs to web URLs)
/// - **Platform Detection**: Comprehensive platform recognition with support for major social media and cooking sites
/// - **Content Extraction**: Platform-optimized scraping strategies with fallback mechanisms
/// - **Result Processing**: Structured result formatting with comprehensive metadata and error information
/// **Supported Platforms:**
/// - **Social Media**: Instagram, Facebook, TikTok, YouTube, Pinterest with platform-specific parsing
/// - **Cooking Websites**: Recipe-focused sites with structured data extraction and ingredient parsing
/// - **Generic Content**: Fallback extraction for unsupported but recipe-containing websites
/// - **Mobile Apps**: Intelligent conversion from mobile app URLs to web-accessible versions
/// **Usage Examples:**
/// ```dart
/// final extractionManager = ExtractionManager();
/// // Extract recipe from Instagram post
/// final result = await extractionManager.extractFromUrl('https://instagram.com/p/recipe-post');
/// if (result.success) {
///   final recipeText = result.extractedText;
///   final platform = result.metadata['platform'];
///   processExtractedRecipe(recipeText, platform);
/// } else {
///   handleExtractionError(result.error);
/// }
/// // Clean up resources when done
/// extractionManager.dispose();
/// ```

import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/utils/retry_policy.dart';

/// Central extraction coordinator managing multi-platform content extraction with intelligent pipeline orchestration.
/// This service orchestrates the complete content extraction process from platform detection through
/// content parsing, providing a unified interface for extracting recipe content from diverse sources
/// with platform-specific optimization and comprehensive error handling capabilities.
class ExtractionManager extends BaseService {
  final PlatformDetector _platformDetector;
  final WebScraper _webScraper;

  ExtractionManager({
    PlatformDetector? platformDetector,
    WebScraper? webScraper,
  }) : _platformDetector = platformDetector ?? PlatformDetector(),
       _webScraper = webScraper ?? WebScraper();

  @override
  String get serviceName => 'ExtractionManager';

  /// Extracts recipe content from URL using comprehensive multi-stage extraction pipeline with platform optimization.
  /// This method implements the complete extraction workflow including URL conversion, platform detection,
  /// content scraping, and result processing. It provides intelligent platform-specific optimization while
  /// maintaining comprehensive error handling and detailed logging for debugging and analytics purposes.
  /// [url] Source URL from social media platform or cooking website to extract recipe content from
  /// Returns [ExtractionResult] with success status, extracted content, and comprehensive metadata
  /// **Extraction Pipeline Stages:**
  /// 1. **URL Conversion**: Transforms mobile app URLs to web-accessible versions for optimal scraping
  /// 2. **Platform Detection**: Identifies source platform and selects appropriate extraction strategy
  /// 3. **Platform Validation**: Verifies platform support and provides detailed error feedback
  /// 4. **Content Extraction**: Executes platform-optimized scraping with fallback mechanisms
  /// 5. **Result Processing**: Formats extraction results with comprehensive metadata and error information
  /// **Platform-Specific Optimizations:**
  /// - **Instagram**: Converts app URLs to web versions, handles story and post formats
  /// - **TikTok**: Processes video descriptions and overlay text for recipe information
  /// - **YouTube**: Extracts description content and video metadata for cooking tutorials
  /// - **Pinterest**: Handles recipe pins with structured data extraction
  /// - **Cooking Sites**: Utilizes structured recipe markup and content parsing
  /// **Error Handling:**
  /// - Comprehensive error categorization with platform-specific error messages
  /// - Detailed logging for debugging and extraction pipeline optimization
  /// - Graceful degradation for partially supported platforms
  /// - Informative error messages for unsupported content types
  /// **Usage Examples:**
  /// ```dart
  /// // Extract from Instagram recipe post
  /// final instagramResult = await manager.extractFromUrl('https://instagram.com/p/recipe123');
  /// // Extract from cooking website
  /// final websiteResult = await manager.extractFromUrl('https://cooking-site.com/recipe');
  /// // Handle results with error checking
  /// if (result.success && result.extractedText != null) {
  ///   createRecipeFromExtraction(result.extractedText!, result.metadata);
  /// } else {
  ///   showExtractionError(result.error ?? 'Unknown extraction error');
  /// }
  /// ```
  Future<ExtractionResult> extractFromUrl(String url) async {
    final result = await executeServiceOperation<ExtractionResult>(
      () async {
        // Step 1: Convert URLs and detect platform
        final webUrl = _platformDetector.convertToWebUrl(url);

        // Step 2: Detect platform
        final platform = _platformDetector.detectPlatform(webUrl);

        if (!_platformDetector.isSupportedPlatform(platform)) {
          return ExtractionResult(
            success: false,
            error: 'Unknown platform for URL: $webUrl',
            metadata: const {'reason': 'unknown_platform'},
          );
        }

        // Step 3: Perform extraction with retry — share-extract is read-only
        // (idempotent), so it's safe to retry transient network failures.
        return withRetry<ExtractionResult>(
          () => _webScraper.performExtraction(webUrl, platform),
          maxAttempts: 3,
        );
      },
      operationName: 'Extract from URL',
    );

    // executeServiceOperation returns nullable, provide fallback error result
    return result ??
        ExtractionResult(
          success: false,
          error: 'Extraction operation failed',
          metadata: {'url': url, 'reason': 'network'},
        );
  }

  /// Custom cleanup logic for extraction resources called by BaseService.dispose().
  /// This method ensures comprehensive cleanup of all extraction resources including headless browser
  /// instances, platform detection caches, and web scraping resources. Called automatically by the
  /// BaseService disposal lifecycle.
  /// **Resource Cleanup:**
  /// - Terminates headless browser instances and WebDriver connections
  /// - Clears platform detection caches and URL conversion mappings
  /// - Releases web scraping resources and network connections
  /// - Cancels any pending extraction operations and background processes
  /// **Usage Guidelines:**
  /// - Called automatically by BaseService.dispose()
  /// - Part of standardized service lifecycle management
  /// - No direct calls needed - use inherited dispose() method instead
  @override
  Future<void> onDispose() async {
    _webScraper.dispose();
  }
}
