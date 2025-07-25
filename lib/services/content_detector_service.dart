// lib/services/content_detector_service.dart

import 'package:flutter/material.dart';
import '../core/base/base_service.dart';
import '../core/mixins/singleton_service_mixin.dart';

/// Typ av innehåll som detekterats
enum ContentType {
  recipeText, // Direkt recepttext
  recipeUrl, // URL till recept
  socialMediaUrl, // URL från sociala medier
  plainText, // Vanlig text utan recept
  unknown, // Okänt innehåll
}

/// Plattform som innehållet kommer från
enum SourcePlatform { instagram, facebook, tiktok, youtube, website, unknown }

/// Resultat från innehållsdetektering
class ContentDetectionResult {
  final ContentType type;
  final SourcePlatform? platform;
  final String? extractedUrl;
  final String originalContent;
  final Map<String, dynamic> metadata;

  ContentDetectionResult({
    required this.type,
    this.platform,
    this.extractedUrl,
    required this.originalContent,
    this.metadata = const {},
  });
}

/// Service för att identifiera och klassificera delat innehåll
///
/// Denna service är modulär och lätt att uppdatera när nya
/// plattformar eller mönster behöver stödjas.
/// Now using SingletonServiceMixin for standardized singleton pattern
class ContentDetectorService extends BaseService with SingletonServiceMixin<ContentDetectorService> {
  // Private constructor for singleton
  ContentDetectorService._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory ContentDetectorService() => SingletonServiceMixin.createSingleton(() => ContentDetectorService._internal());
  
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

  /// Detekterar typ av innehåll från delad text
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
    ) ?? ContentDetectionResult(
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
