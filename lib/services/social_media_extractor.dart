/// Comprehensive social media content extraction service providing unified API for multi-platform recipe discovery.
/// This service serves as a facade for sophisticated content extraction capabilities enabling users to discover
/// and import recipes from various social media platforms and cooking websites. It implements a modular architecture
/// with specialized extraction components while providing backward compatibility and a simplified API surface
/// for seamless integration throughout the application.
/// **Architecture Integration:**
/// - Uses [SingletonServiceMixin] for standardized singleton pattern with proper lifecycle management
/// - Delegates to [ExtractionManager] for comprehensive extraction orchestration and platform coordination
/// - Exports specialized extraction components for advanced usage scenarios
/// - Implements facade pattern providing simplified API while maintaining full feature access
/// **Extraction Capabilities:**
/// - **Multi-Platform Support**: Instagram, Facebook, TikTok, YouTube, Pinterest, and cooking websites
/// - **Intelligent Detection**: Automatic platform recognition and optimal extraction strategy selection
/// - **Content Parsing**: Advanced parsing for recipe titles, ingredients, instructions, and metadata
/// - **Error Recovery**: Comprehensive error handling with graceful degradation for failed extractions
/// - **Metadata Preservation**: Extraction of cooking times, serving sizes, ratings, and source attribution
/// **Backward Compatibility:**
/// Maintains 100% backward compatibility with existing code while providing migration path to more
/// explicit component usage. Legacy API calls continue to work seamlessly while new implementations
/// can leverage the modular architecture for enhanced functionality and testing.
/// **Usage Examples:**
/// ```dart
/// final extractor = SocialMediaExtractor();
/// // Extract recipe from social media URL
/// final result = await extractor.extractFromUrl('https://instagram.com/p/recipe-post');
/// if (result.success) {
///   final recipeText = result.extractedText;
///   final platform = result.metadata['platform'];
///   final sourceUrl = result.metadata['sourceUrl'];
/// } else {
///   showError(result.error ?? 'Extraction failed');
/// }
/// // Clean up resources
/// extractor.dispose();
/// ```

import 'package:butlery/services/extraction/extraction_manager.dart';
import 'package:butlery/core/base/base_service.dart';

// Export extraction components for external usage
export 'extraction/platform_detector.dart';
export 'extraction/web_scraper.dart';
export 'extraction/extraction_manager.dart';

/// Comprehensive extraction result container providing detailed extraction outcomes and metadata.
/// This class encapsulates the complete result of content extraction operations including success status,
/// extracted content, error information, and comprehensive metadata about the extraction process.
/// It provides structured access to extraction results enabling proper error handling and content processing.
/// **Result Components:**
/// - [success] Boolean indicator of extraction operation success for conditional processing
/// - [extractedText] Optional extracted content text containing recipe information
/// - [error] Optional error message providing detailed failure information for debugging
/// - [metadata] Comprehensive metadata map containing platform information, URLs, and extraction details
/// **Metadata Information:**
/// The metadata map typically contains:
/// - 'platform': Detected social media platform or website type
/// - 'sourceUrl': Original URL that was processed for extraction
/// - 'extractionMethod': Technique used for content extraction (scraping, API, etc.)
/// - 'timestamp': When the extraction was performed
/// - 'contentType': Type of content detected (recipe, video, image, etc.)
/// **Usage Examples:**
/// ```dart
/// final result = await extractor.extractFromUrl(url);
/// if (result.success && result.extractedText != null) {
///   processRecipeText(result.extractedText!);
///   logAnalytics('extraction_success', result.metadata);
/// } else {
///   handleExtractionError(result.error, result.metadata);
/// }
/// ```
class ExtractionResult {
  final bool success;
  final String? extractedText;
  final String? error;
  final Map<String, dynamic> metadata;

  ExtractionResult({
    required this.success,
    this.extractedText,
    this.error,
    this.metadata = const {},
  });
}

/// Unified social media content extraction facade providing simplified API for multi-platform recipe discovery.
/// This service implements the facade pattern to provide a clean, simplified interface for content extraction
/// while delegating to sophisticated specialized components. It maintains backward compatibility with existing
/// implementations while offering a migration path to more explicit component usage for advanced scenarios.
/// **Facade Pattern Implementation:**
/// Delegates to specialized extraction components:
/// - **Platform Detection**: [PlatformDetector] for intelligent social media platform recognition
/// - **Web Scraping**: [WebScraper] for headless browser-based content extraction
/// - **Content Parsing**: [ExtractionManager] for comprehensive extraction orchestration and coordination
/// - **Resource Management**: Proper cleanup and disposal of extraction resources
/// **Backward Compatibility Strategy:**
/// Maintains 100% API compatibility with existing code while providing clear migration paths:
/// - Legacy method calls continue to work without modification
/// - New implementations can gradually migrate to explicit component usage
/// - Comprehensive documentation guides migration strategy for enhanced functionality
/// - Testing compatibility ensures no breaking changes in existing integrations
/// **BaseService Architecture:**
/// - Extends [BaseService] for standardized error handling, logging, and lifecycle management
/// - Registered as singleton in DI container for consistent instance management
/// - Provides proper resource management and cleanup capabilities
/// - Part of Content Module dependency injection system
/// **Migration Guide:**
/// ```dart
/// // Get from DI (recommended)
/// final extractor = ServiceLocator.get<SocialMediaExtractor>();
/// final result = await extractor.extractFromUrl(url);
/// // Enhanced approach (for new implementations)
/// final manager = ExtractionManager();
/// final result = await manager.extractFromUrl(url);
/// // Advanced usage (direct component access)
/// final detector = PlatformDetector();
/// final platform = detector.detectPlatform(url);
/// final scraper = WebScraper();
/// final content = await scraper.scrapeContent(url, platform);
/// ```
class SocialMediaExtractor extends BaseService {
  final ExtractionManager _manager;

  SocialMediaExtractor({
    ExtractionManager? manager,
  }) : _manager = manager ?? ExtractionManager();

  @override
  String get serviceName => 'SocialMediaExtractor';

  /// Extracts recipe content from social media URL with comprehensive platform support and error handling.
  /// This method provides the primary extraction functionality by delegating to the ExtractionManager
  /// while maintaining a simplified API surface. It handles platform detection, content scraping,
  /// and result formatting automatically while providing detailed error information for debugging.
  /// Uses BaseService's [executeServiceOperation] for standardized error handling, logging, and retry logic.
  /// [url] Social media or cooking website URL to extract recipe content from
  /// Returns [ExtractionResult] with success status, extracted content, and comprehensive metadata
  /// **Extraction Process:**
  /// 1. **Platform Detection**: Automatically identifies the social media platform or website type
  /// 2. **Content Scraping**: Uses appropriate extraction strategy based on detected platform
  /// 3. **Content Parsing**: Parses extracted HTML/text for recipe-specific information
  /// 4. **Result Formatting**: Structures results with success status and comprehensive metadata
  /// 5. **Error Handling**: Provides detailed error information for failed extractions
  /// **Supported Platforms:**
  /// - Instagram recipe posts and stories with ingredient extraction
  /// - Facebook cooking videos and recipe shares with metadata preservation
  /// - TikTok cooking videos with description parsing and ingredient recognition
  /// - YouTube cooking tutorials with description analysis and timestamp extraction
  /// - Pinterest recipe pins with comprehensive metadata extraction
  /// - Cooking websites with structured recipe markup support
  /// **Usage Examples:**
  /// ```dart
  /// // Extract from Instagram recipe post
  /// final instagramResult = await extractor.extractFromUrl('https://instagram.com/p/recipe123');
  /// // Extract from cooking website
  /// final websiteResult = await extractor.extractFromUrl('https://cooking-site.com/recipe');
  /// // Handle extraction results
  /// if (result.success) {
  ///   final recipeText = result.extractedText!;
  ///   final sourceUrl = result.metadata['sourceUrl'];
  ///   createRecipeFromExtraction(recipeText, sourceUrl);
  /// }
  /// ```
  Future<ExtractionResult> extractFromUrl(String url) async {
    final result = await executeServiceOperation(
      () => _manager.extractFromUrl(url),
      operationName: 'Extract from URL',
    );

    // executeServiceOperation returns nullable, provide fallback error result
    return result ??
        ExtractionResult(
          success: false,
          error: 'Extraction operation failed',
          metadata: {'url': url},
        );
  }

  /// Custom cleanup logic for extraction resources called by BaseService.dispose().
  /// This method ensures proper cleanup of all extraction resources including headless browser instances,
  /// network connections, and cached content. Called automatically by the BaseService disposal lifecycle.
  /// **Resource Cleanup:**
  /// - Closes headless browser instances and WebDriver connections
  /// - Clears cached extraction results and temporary content storage
  /// - Terminates background extraction processes and network requests
  /// - Releases platform-specific extraction resources and native integrations
  /// **Usage Guidelines:**
  /// - Called automatically by BaseService.dispose()
  /// - Part of standardized service lifecycle management
  /// - No direct calls needed - use inherited dispose() method instead
  @override
  Future<void> onDispose() async {
    _manager.dispose();
  }
}
