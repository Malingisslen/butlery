/// Intelligent platform detection service providing comprehensive social media and website recognition capabilities.
/// This service implements sophisticated platform detection algorithms for identifying content sources
/// and optimizing extraction strategies. It provides URL conversion, platform recognition, and support
/// validation with comprehensive mapping for major social media platforms and cooking websites.
/// **Architecture Integration:**
/// - Uses [SingletonServiceMixin] for standardized singleton pattern with efficient resource management
/// - Delegates to [ContentDetectorService] for comprehensive platform analysis and content type detection
/// - Implements URL conversion algorithms for platform-specific optimization and accessibility
/// **Detection Capabilities:**
/// - **Platform Recognition**: Identifies Instagram, Facebook, TikTok, YouTube, Pinterest, and cooking websites
/// - **URL Conversion**: Transforms mobile app URLs to web-accessible versions for optimal scraping
/// - **Support Validation**: Determines platform support level and extraction strategy availability
/// - **Content Analysis**: Analyzes URL structure and content patterns for accurate platform identification
/// **Usage Examples:**
/// ```dart
/// final detector = PlatformDetector();
/// // Convert mobile app URL to web version
/// final webUrl = detector.convertToWebUrl('instagram://shortcode=ABC123');
/// // Returns: 'https://www.instagram.com/p/ABC123/'
/// // Detect platform and analyze support
/// final result = await detector.detectPlatform(webUrl);
/// if (detector.isSupportedPlatform(result.platform)) {
///   performExtractionWithPlatform(result.platform);
/// }
/// ```

/// Enum for supported social media platforms and recipe sites
enum SourcePlatform {
  instagram,
  facebook,
  tiktok,
  youtube,
  pinterest,
  recipesite, // Generic recipe sites (ICA, Arla, etc.)
  unknown,
}

class PlatformDetector {
  // Singleton implementation
  static final PlatformDetector _instance = PlatformDetector._internal();
  factory PlatformDetector() => _instance;
  PlatformDetector._internal();

  /// Detect platform from URL
  SourcePlatform detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();

    // Social media platforms
    if (lowerUrl.contains('instagram.com')) return SourcePlatform.instagram;
    if (lowerUrl.contains('facebook.com')) return SourcePlatform.facebook;
    if (lowerUrl.contains('tiktok.com')) return SourcePlatform.tiktok;
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return SourcePlatform.youtube;
    }
    if (lowerUrl.contains('pinterest.com')) return SourcePlatform.pinterest;

    // Swedish recipe sites
    if (lowerUrl.contains('ica.se')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('arla.se')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('koket.se')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('recepten.se')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('tasteline.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('mittkok.expressen.se')) {
      return SourcePlatform.recipesite;
    }

    // International recipe sites
    if (lowerUrl.contains('allrecipes.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('food.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('epicurious.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('foodnetwork.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('delish.com')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('tasty.co')) return SourcePlatform.recipesite;
    if (lowerUrl.contains('recipetineats.com')) {
      return SourcePlatform.recipesite;
    }
    if (lowerUrl.contains('simplyrecipes.com')) {
      return SourcePlatform.recipesite;
    }

    return SourcePlatform.unknown;
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
