// lib/services/extraction/platform_detector.dart

import '../content_detector_service.dart';

/// Platform detection for social media URLs
class PlatformDetector {
  static final PlatformDetector _instance = PlatformDetector._internal();
  factory PlatformDetector() => _instance;
  PlatformDetector._internal();

  final ContentDetectorService _detector = ContentDetectorService();

  /// Detect platform from URL
  ContentDetectionResult detectPlatform(String url) {
    return _detector.detectContent(url);
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
