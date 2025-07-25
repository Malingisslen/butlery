// lib/services/extraction/platform_detector.dart

import '../content_detector_service.dart';
import '../../core/mixins/singleton_service_mixin.dart';

/// Platform detection for social media URLs
/// Now using SingletonServiceMixin for standardized singleton pattern
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
