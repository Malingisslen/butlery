// lib/services/extraction/extractors/instagram_content_extractor.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Result of Instagram extraction.
class InstagramExtractionResult {
  /// Extracted text content (caption).
  final String? text;

  /// Whether the extraction was successful.
  final bool isSuccess;

  /// Whether the content appears to contain a recipe.
  final bool hasRecipeContent;

  /// Thumbnail URL if available.
  final String? thumbnailUrl;

  /// Error message if extraction failed.
  final String? error;

  const InstagramExtractionResult({
    this.text,
    this.isSuccess = false,
    this.hasRecipeContent = false,
    this.thumbnailUrl,
    this.error,
  });

  factory InstagramExtractionResult.success(
    String text, {
    bool hasRecipeContent = false,
    String? thumbnailUrl,
  }) {
    return InstagramExtractionResult(
      text: text,
      isSuccess: true,
      hasRecipeContent: hasRecipeContent,
      thumbnailUrl: thumbnailUrl,
    );
  }

  factory InstagramExtractionResult.failure(String error) {
    return InstagramExtractionResult(
      isSuccess: false,
      error: error,
    );
  }

  factory InstagramExtractionResult.needsScreenshot({
    String? thumbnailUrl,
    String? partialText,
  }) {
    return InstagramExtractionResult(
      isSuccess: false,
      hasRecipeContent: false,
      thumbnailUrl: thumbnailUrl,
      text: partialText,
      error: 'Kunde inte hitta recept i inlagget. Ta en skarmbild av receptet.',
    );
  }
}

/// Instagram-specific content extraction with "mer" button expansion and multi-strategy parsing.
class InstagramContentExtractor {
  final bool Function() isDisposed;

  /// Swedish recipe keywords for content detection.
  static const _recipeKeywords = [
    'recept',
    'ingrediens',
    'tillagning',
    'portion',
    'servering',
    'dl ',
    'msk ',
    'tsk ',
    'gram ',
    ' g ',
    'matsked',
    'tesked',
    'kryddmatt',
    'mjol',
    'socker',
    'smor',
    'agg',
    'gradda',
    'koka',
    'stek',
    'blanda',
    'vispa',
    'hall',
  ];

  InstagramContentExtractor({
    required this.isDisposed,
  });

  /// Extract content from Instagram post with multi-strategy approach
  Future<String?> extract(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    debugPrint('📸 Extracting from Instagram...');

    // Step 1: Click "more" button to expand text
    await _expandContent(controller);

    if (isDisposed()) return null;

    // Step 2: Extract all text after expansion
    return await _extractExpandedContent(controller);
  }

  /// Click "mer"/"more" button to expand Instagram caption
  Future<void> _expandContent(InAppWebViewController controller) async {
    try {
      final clickResult = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            const allElements = document.querySelectorAll('article *');
            let merButton = null;

            for (const element of allElements) {
              const text = (element.textContent || '').trim();
              if (text === 'mer' ||
                  text === '... mer' ||
                  text === 'more' ||
                  text === '... more') {
                merButton = element;
                console.log('Found more button:', text, element.tagName);
                break;
              }
            }

            if (merButton) {
              merButton.click();
              console.log('Clicked more button');
              return true;
            }

            console.log('No more button found');
            return false;
          } catch (e) {
            console.error('Click error:', e);
            return false;
          }
        })()
        ''',
      );

      debugPrint('Click result: $clickResult');
      await Future.delayed(AppDimensions.animationDurationSlow);
    } catch (e) {
      debugPrint('⚠️ Could not click more button: $e');
    }
  }

  /// Extract content using multi-strategy approach (h1 → spans → article text)
  Future<String?> _extractExpandedContent(
      InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            // Method 1: Look for h1 elements that often contain full caption
            const h1Elements = document.querySelectorAll('article h1');
            for (const h1 of h1Elements) {
              const text = h1.textContent || '';
              if (text.length > 200 &&
                  (text.toLowerCase().includes('jäst') ||
                   text.toLowerCase().includes('mjöl') ||
                   text.toLowerCase().includes('recept') ||
                   text.includes('dl ') ||
                   text.includes('msk '))) {
                console.log('Found recipe in h1:', text.substring(0, 100) + '...');
                return text;
              }
            }

            // Method 2: Look in all span elements
            const article = document.querySelector('article');
            if (!article) return null;

            let longestText = '';
            const spans = article.querySelectorAll('span');

            for (const span of spans) {
              const text = span.textContent || '';
              if (text.length > longestText.length &&
                  text.length > 200 &&
                  !text.includes('Följ') &&
                  !text.includes('gilla-markeringar')) {
                longestText = text;
              }
            }

            if (longestText) {
              console.log('Found long text:', longestText.substring(0, 100) + '...');
              return longestText;
            }

            // Method 3: Take all visible text from article
            const visibleText = article.innerText || '';
            const lines = visibleText.split('\\n');
            let captionText = '';
            let inCaption = false;

            for (const line of lines) {
              if (line.includes('Här kommer') ||
                  line.toLowerCase().includes('recept') ||
                  inCaption) {
                inCaption = true;
                captionText += line + ' ';

                if (line.includes('gilla-markeringar') ||
                    line.includes('kommentarer') ||
                    line.includes('timmar sedan') ||
                    line.includes('dagar sedan')) {
                  break;
                }
              }
            }

            return captionText.trim() || visibleText;

          } catch (e) {
            console.error('Text extraction error:', e);
            return null;
          }
        })()
        ''',
      );

      if (result != null &&
          result.toString().isNotEmpty &&
          result.toString() != 'null') {
        final extractedText = result.toString();
        debugPrint('✅ Instagram text found!');
        debugPrint('📝 Extracted text (${extractedText.length} characters):');
        debugPrint(
            '${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}...');

        return extractedText;
      }
    } catch (e) {
      debugPrint('⚠️ Instagram extraction error: $e');
    }

    return null;
  }

  /// Extract content with recipe detection and result wrapper.
  Future<InstagramExtractionResult> extractWithResult(
    InAppWebViewController controller, {
    String? thumbnailUrl,
  }) async {
    final text = await extract(controller);

    if (text == null || text.isEmpty) {
      return InstagramExtractionResult.needsScreenshot(
        thumbnailUrl: thumbnailUrl,
      );
    }

    final hasRecipe = _containsRecipeContent(text);

    if (!hasRecipe && text.length < 100) {
      // Short text with no recipe keywords
      return InstagramExtractionResult.needsScreenshot(
        thumbnailUrl: thumbnailUrl,
        partialText: text,
      );
    }

    return InstagramExtractionResult.success(
      text,
      hasRecipeContent: hasRecipe,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Check if text contains recipe-related content.
  bool _containsRecipeContent(String text) {
    final lowerText = text.toLowerCase();
    int keywordCount = 0;

    for (final keyword in _recipeKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        keywordCount++;
        if (keywordCount >= 3) {
          return true; // At least 3 recipe keywords found
        }
      }
    }

    return false;
  }

  /// Extract thumbnail URL from page if available.
  Future<String?> extractThumbnailUrl(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          // Try meta og:image first
          const ogImage = document.querySelector('meta[property="og:image"]');
          if (ogImage) return ogImage.content;

          // Try article image
          const articleImg = document.querySelector('article img[src*="instagram"]');
          if (articleImg) return articleImg.src;

          return null;
        })()
        ''',
      );

      if (result != null && result.toString() != 'null') {
        return result.toString();
      }
    } catch (e) {
      debugPrint('Could not extract thumbnail: $e');
    }
    return null;
  }
}
