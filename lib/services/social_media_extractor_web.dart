// lib/services/social_media_extractor_web.dart

import 'package:flutter/foundation.dart';
import 'social_media_extractor_interface.dart';

/// Web implementation av SocialMediaExtractor
///
/// På webben kan vi inte använda headless WebView, så vi returnerar
/// ett felmeddelande som uppmanar användaren att kopiera texten manuellt
class SocialMediaExtractor implements SocialMediaExtractorInterface {
  // Singleton pattern
  static final SocialMediaExtractor _instance =
      SocialMediaExtractor._internal();
  factory SocialMediaExtractor() => _instance;
  SocialMediaExtractor._internal();

  @override
  Future<ExtractionResult> extractFromUrl(String url) async {
    debugPrint('🌐 Social media extraction anropad på webben för: $url');

    // På webben kan vi inte extrahera automatiskt pga CORS och säkerhetsbegränsningar
    return ExtractionResult(
      success: false,
      error: '''
Automatisk textextraktion är inte tillgänglig i webbläsaren.

För att importera recept:
1. Öppna länken i en ny flik
2. Kopiera recepttexten manuellt
3. Klistra in den i Butlery

Detta är en säkerhetsbegränsning i webbläsare som förhindrar att webbsidor läser innehåll från andra domäner.
''',
      metadata: {'platform': 'web', 'url': url, 'reason': 'CORS policy'},
    );
  }

  @override
  void dispose() {
    // Inget att städa upp på webben
    debugPrint('🧹 SocialMediaExtractor web dispose');
  }
}
