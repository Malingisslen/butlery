// lib/services/extraction/extraction_manager.dart

import 'package:flutter/material.dart';
import '../social_media_extractor.dart';
import '../../core/mixins/singleton_service_mixin.dart';

/// Main extraction coordinator that manages the extraction process
/// Now using SingletonServiceMixin for standardized singleton pattern
class ExtractionManager with SingletonServiceMixin<ExtractionManager> {
  // Private constructor for singleton
  ExtractionManager._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory ExtractionManager() => SingletonServiceMixin.createSingleton(() => ExtractionManager._internal());

  final PlatformDetector _platformDetector = PlatformDetector();
  final WebScraper _webScraper = WebScraper();

  /// Extract text from URL using the complete extraction pipeline
  Future<ExtractionResult> extractFromUrl(String url) async {
    debugPrint('🌐 Starting extraction from: $url');

    // Step 1: Convert URLs and detect platform
    final webUrl = _platformDetector.convertToWebUrl(url);
    if (webUrl != url) {
      debugPrint('📸 Converted Instagram link to: $webUrl');
    }

    // Step 2: Detect platform
    final detectionResult = await _platformDetector.detectPlatform(webUrl);
    final platform = detectionResult.platform;

    if (!_platformDetector.isSupportedPlatform(platform)) {
      return ExtractionResult(
        success: false,
        error: 'Unknown platform for URL: $webUrl',
      );
    }

    // Step 3: Perform extraction
    final result = await _webScraper.performExtraction(webUrl, platform!);

    return result;
  }

  /// Dispose method to clean up resources
  void dispose() {
    _webScraper.dispose();
  }
}
