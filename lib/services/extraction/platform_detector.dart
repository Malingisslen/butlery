/// Intelligent platform detection service providing comprehensive social media and website recognition capabilities.
///
/// This service implements sophisticated platform detection algorithms for identifying content sources
/// and optimizing extraction strategies. It provides URL conversion, platform recognition, and support
/// validation with comprehensive mapping for major social media platforms and cooking websites.
///
/// **Architecture Integration:**
/// - Uses [SingletonServiceMixin] for standardized singleton pattern with efficient resource management
/// - Delegates to [ContentDetectorService] for comprehensive platform analysis and content type detection
/// - Implements URL conversion algorithms for platform-specific optimization and accessibility
///
/// **Detection Capabilities:**
/// - **Platform Recognition**: Identifies Instagram, Facebook, TikTok, YouTube, Pinterest, and cooking websites
/// - **URL Conversion**: Transforms mobile app URLs to web-accessible versions for optimal scraping
/// - **Support Validation**: Determines platform support level and extraction strategy availability
/// - **Content Analysis**: Analyzes URL structure and content patterns for accurate platform identification
///
/// **Usage Examples:**
/// ```dart
/// final detector = PlatformDetector();
/// 
/// // Convert mobile app URL to web version
/// final webUrl = detector.convertToWebUrl('instagram://shortcode=ABC123');
/// // Returns: 'https://www.instagram.com/p/ABC123/'
/// 
/// // Detect platform and analyze support
/// final result = await detector.detectPlatform(webUrl);
/// if (detector.isSupportedPlatform(result.platform)) {
///   performExtractionWithPlatform(result.platform);
/// }
/// ```
class PlatformDetector with SingletonServiceMixin<PlatformDetector> {
  // Private constructor for singleton
  PlatformDetector._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory PlatformDetector() => SingletonServiceMixin.createSingleton(() => PlatformDetector._internal());

  final ContentDetectorService _detector = ContentDetectorService();

  /// Detect platform from URL
  Future<ContentDetectionResult> detectPlatform(String url) async {
    return await _detector.detectContent(url);
  }

  /// Convert Instagram app links to web URLs
  String convertToWebUrl(String url) {
    if (url.startsWith('instagram://')) {
      final shortcodeMatch = RegExp(r'shortcode=([^&]+)').firstMatch(url);
      if (shortcodeMatch != null) {
        final shortcode = shortcodeMatch.group(1);
        return 'https://www.instagram.com/p/$shortcode/';
      }
    }
    return url;
  }

  /// Check if platform is supported
  bool isSupportedPlatform(SourcePlatform? platform) {
    return platform != null && platform != SourcePlatform.unknown;
  }
}
