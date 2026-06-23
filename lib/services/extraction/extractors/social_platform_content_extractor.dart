// lib/services/extraction/extractors/social_platform_content_extractor.dart

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;

/// Social platform content extraction (Facebook, TikTok, generic sites).
class SocialPlatformContentExtractor {
  final bool Function() isDisposed;
  final Map<pd.SourcePlatform, List<String>> platformSelectors;

  SocialPlatformContentExtractor({
    required this.isDisposed,
    required this.platformSelectors,
  });

  /// Extract content from Facebook post
  Future<String?> extractFacebook(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    final selectors = platformSelectors[pd.SourcePlatform.facebook] ?? [];

    for (final selector in selectors) {
      if (isDisposed()) break;

      final result = await controller.evaluateJavascript(
        source:
            '''
        (function() {
          const element = document.querySelector('$selector');
          if (element) {
            return element.textContent || element.content || '';
          }
          return null;
        })()
      ''',
      );

      if (result != null && result.toString().isNotEmpty) {
        return result.toString();
      }
    }

    return null;
  }

  /// Extract content from TikTok video
  Future<String?> extractTikTok(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    final selectors = platformSelectors[pd.SourcePlatform.tiktok] ?? [];

    for (final selector in selectors) {
      if (isDisposed()) break;

      final result = await controller.evaluateJavascript(
        source:
            '''
        (function() {
          const element = document.querySelector('$selector');
          if (element) {
            return element.textContent || element.content || '';
          }
          return null;
        })()
      ''',
      );

      if (result != null && result.toString().isNotEmpty) {
        return result.toString();
      }
    }

    return null;
  }

  /// Extract content from generic website
  Future<String?> extractGeneric(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    final result = await controller.evaluateJavascript(
      source: '''
      (function() {
        // Look for structured recipe data
        const recipe = document.querySelector('[itemtype*="Recipe"]');
        if (recipe) {
          return recipe.innerText;
        }

        // Fallback to article content
        const article = document.querySelector('article, main, [role="main"]');
        if (article) {
          return article.innerText;
        }

        // Last resort - body text
        return document.body.innerText;
      })()
    ''',
    );

    return result?.toString();
  }
}
