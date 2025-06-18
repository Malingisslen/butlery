// lib/services/social_media_extractor_interface.dart

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

/// Interface för social media extractor
/// Implementeras olika för mobil och webb
abstract class SocialMediaExtractorInterface {
  /// Extraherar text från URL
  Future<ExtractionResult> extractFromUrl(String url);

  /// Städa upp resurser
  void dispose();
}
