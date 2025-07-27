// lib/services/social_media_extractor.dart

import 'package:butlery/services/extraction/extraction_manager.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

// Export extraction components for external usage
export 'extraction/platform_detector.dart';
export 'extraction/web_scraper.dart';
export 'extraction/extraction_manager.dart';

/// Resultat från extraktion
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

/// 🚀 SocialMediaExtractor - Facade for social media content extraction
///
/// Provides a unified API for extracting text from social media platforms:
/// - ✅ Platform detection (delegates to PlatformDetector)
/// - ✅ Web scraping with headless browser (delegates to WebScraper)
/// - ✅ Content parsing and extraction (delegates to ExtractionManager)
/// - ✅ 100% backward compatibility with existing code
///
/// MIGRATION GUIDE:
/// ```dart
/// // Before: (still works)
/// final extractor = SocialMediaExtractor();
/// final result = await extractor.extractFromUrl(url);
///
/// // After: (more explicit, same result)
/// final manager = ExtractionManager();
/// final result = await manager.extractFromUrl(url);
/// ```
class SocialMediaExtractor with SingletonServiceMixin<SocialMediaExtractor> {
  // Private constructor for singleton
  SocialMediaExtractor._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory SocialMediaExtractor() => SingletonServiceMixin.createSingleton(() => SocialMediaExtractor._internal());

  final ExtractionManager _manager = ExtractionManager();

  /// Extract text from URL - delegates to ExtractionManager
  Future<ExtractionResult> extractFromUrl(String url) async {
    return _manager.extractFromUrl(url);
  }


  /// Dispose method to clean up resources - delegates to ExtractionManager
  void dispose() {
    _manager.dispose();
  }
}
