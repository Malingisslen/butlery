import 'package:butlery/core/l10n/app_locale.dart';

/// Heuristically scores extracted import text by recipe indicators and length.
///
/// Extracted from [UrlImportViewModel] (BUT-1273) to keep that VM under the
/// 500-line limit. Pure-compute, no state — returns
/// `{quality, score, issues, positives}` for UI feedback. Behaviour is
/// byte-for-byte identical to the former in-VM method.
class ExtractedContentAnalyzer {
  ExtractedContentAnalyzer._();

  static Map<String, dynamic> analyze(String? extractedText) {
    if (extractedText == null || extractedText.isEmpty) {
      return {
        'quality': 'none',
        'score': 0,
        'issues': [AppLocale.current.analysisNoContentExtracted],
      };
    }

    final text = extractedText.toLowerCase();
    int score = 0;
    final issues = <String>[];
    final positives = <String>[];

    if (text.contains('ingrediens') || text.contains('ingredient')) {
      score += 25;
      positives.add(AppLocale.current.analysisContainsIngredients);
    } else {
      issues.add(AppLocale.current.analysisNoIngredientsFound);
    }

    if (text.contains('instruktion') ||
        text.contains('instruction') ||
        text.contains('steg') ||
        text.contains('step') ||
        text.contains('gör så här') ||
        text.contains('method')) {
      score += 25;
      positives.add(AppLocale.current.analysisContainsInstructions);
    } else {
      issues.add(AppLocale.current.analysisNoInstructionsFound);
    }

    if (text.contains('minut') ||
        text.contains('minute') ||
        text.contains('timme') ||
        text.contains('hour') ||
        text.contains('tid') ||
        text.contains('time')) {
      score += 15;
      positives.add(AppLocale.current.analysisContainsTimeInfo);
    }

    if (text.contains('portion') ||
        text.contains('serve') ||
        text.contains('servering') ||
        text.contains('yield')) {
      score += 10;
      positives.add(AppLocale.current.analysisContainsPortionInfo);
    }

    if (extractedText.length > 500) {
      score += 15;
      positives.add(AppLocale.current.analysisGoodContentLength);
    } else if (extractedText.length < 200) {
      issues.add(AppLocale.current.analysisContentTooShort);
    }

    if (text.contains('recipe') || text.contains('recept')) {
      score += 10;
      positives.add(AppLocale.current.analysisContainsRecipeKeywords);
    }

    String quality;
    if (score >= 75) {
      quality = 'excellent';
    } else if (score >= 50) {
      quality = 'good';
    } else if (score >= 25) {
      quality = 'fair';
    } else {
      quality = 'poor';
    }

    return {
      'quality': quality,
      'score': score,
      'issues': issues,
      'positives': positives,
    };
  }
}
