// lib/services/extraction/extractors/instagram_content_extractor.dart

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Instagram-specific content extraction with "mer" button expansion and multi-strategy parsing.
class InstagramContentExtractor {
  final bool Function() isDisposed;

  InstagramContentExtractor({
    required this.isDisposed,
  });

  /// Extract content from Instagram post with multi-strategy approach
  Future<String?> extract(InAppWebViewController controller) async {
    if (isDisposed()) return null;

    // Step 1: Click "more" button to expand text
    await _expandContent(controller);

    if (isDisposed()) return null;

    // Step 2: Extract all text after expansion
    return await _extractExpandedContent(controller);
  }

  /// Click "mer"/"more" button to expand Instagram caption
  Future<void> _expandContent(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(
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

      await Future.delayed(AppDimensions.animationDurationSlow);
    } catch (_) {
      // Continue even if clicking more button fails
    }
  }

  /// Extract content using multi-strategy approach (h1 → spans → article text)
  Future<String?> _extractExpandedContent(
    InAppWebViewController controller,
  ) async {
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
        return extractedText;
      }
    } catch (_) {
      // Continue with null result on error
    }

    return null;
  }
}
