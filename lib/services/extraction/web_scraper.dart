// lib/services/extraction/web_scraper.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/social_media_extractor.dart';

/// Web scraper for headless browser operations
class WebScraper {
  // WebView controller
  HeadlessInAppWebView? _headlessWebView;
  
  // Flag to prevent double cleanup
  bool _isDisposed = false;
  
  // Timeout for extraction - 15 seconds
  static const Duration _extractionTimeout = Duration(seconds: 15);

  /// Perform extraction with WebView
  Future<ExtractionResult> performExtraction(
    String url,
    SourcePlatform platform,
  ) async {
    final completer = Completer<ExtractionResult>();
    bool hasExtracted = false;
    int loadCount = 0;

    // Set timeout
    late final Timer timeoutTimer;
    timeoutTimer = Timer(_extractionTimeout, () {
      if (!completer.isCompleted && !_isDisposed) {
        debugPrint('⏱️ Timeout reached, ending extraction');
        completer.complete(
          ExtractionResult(
            success: false,
            error: 'Timeout: Could not load page within ${_extractionTimeout.inSeconds} seconds',
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          _safeCleanup();
        });
      }
    });

    try {
      // Create headless WebView
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent: _getUserAgent(platform),
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          domStorageEnabled: true,
          databaseEnabled: false,
          clearCache: true,
        ),
        onProgressChanged: (controller, progress) {
          if (_isDisposed || completer.isCompleted) return;

          debugPrint('📊 Loading: $progress%');

          if (progress == 100 && !hasExtracted && !completer.isCompleted) {
            hasExtracted = true;

            final delay = platform == SourcePlatform.instagram
                ? AppDimensions.animationDurationSlow
                : AppDimensions.animationDurationMedium;

            Future.delayed(delay, () async {
              if (!completer.isCompleted &&
                  !_isDisposed &&
                  _headlessWebView != null) {
                try {
                  debugPrint('🔍 Extracting content...');

                  final extractedText = await _extractTextForPlatform(
                    controller,
                    platform,
                  );

                  timeoutTimer.cancel();

                  if (!completer.isCompleted && !_isDisposed) {
                    if (extractedText != null && extractedText.isNotEmpty) {
                      completer.complete(
                        ExtractionResult(
                          success: true,
                          extractedText: extractedText,
                          metadata: {
                            'platform': platform.toString(),
                            'url': url,
                            'extractedAt': DateTime.now().toIso8601String(),
                          },
                        ),
                      );
                    } else {
                      completer.complete(
                        ExtractionResult(
                          success: false,
                          error: 'No text could be extracted from the page',
                        ),
                      );
                    }
                  }

                  await Future.delayed(const Duration(milliseconds: 1000));
                  _safeCleanup();
                } catch (e) {
                  debugPrint('❌ Extraction error: $e');
                  timeoutTimer.cancel();

                  if (!completer.isCompleted) {
                    completer.complete(
                      ExtractionResult(
                        success: false,
                        error: 'Text extraction error: ${e.toString()}',
                      ),
                    );
                  }

                  await Future.delayed(const Duration(milliseconds: 500));
                  _safeCleanup();
                }
              }
            });
          }
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;

          if (uri != null) {
            final urlString = uri.toString();

            // Block app links
            if (urlString.startsWith('instagram://') ||
                urlString.startsWith('fb://') ||
                urlString.startsWith('twitter://') ||
                urlString.startsWith('tiktok://')) {
              debugPrint('🚫 Blocking app link: $urlString');
              return NavigationActionPolicy.CANCEL;
            }

            // Block app store links
            if (urlString.contains('apps.apple.com') ||
                urlString.contains('play.google.com')) {
              debugPrint('🚫 Blocking app store link: $urlString');
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {
          if (_isDisposed) return;

          loadCount++;
          debugPrint('✅ Page loaded (time $loadCount): $url');

          if (url != null && url.toString().startsWith('instagram://')) {
            debugPrint('⚠️ Ignoring Instagram app URL');
            return;
          }
        },
        onReceivedError: (controller, request, error) {
          if (_isDisposed || completer.isCompleted) return;

          debugPrint('❌ Loading error: ${error.description}');

          timeoutTimer.cancel();

          if (!completer.isCompleted) {
            completer.complete(
              ExtractionResult(
                success: false,
                error: 'Could not load page: ${error.description}',
              ),
            );
          }

          Future.delayed(const Duration(milliseconds: 500), () {
            _safeCleanup();
          });
        },
        onConsoleMessage: (controller, consoleMessage) {
          debugPrint('CONSOLE: ${consoleMessage.message}');
        },
      );

      // Start WebView
      await _headlessWebView?.run();
    } catch (e) {
      debugPrint('❌ Extraction error: $e');
      timeoutTimer.cancel();

      if (!completer.isCompleted) {
        completer.complete(
          ExtractionResult(
            success: false,
            error: 'Technical error: ${e.toString()}',
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _safeCleanup();
    }

    return completer.future;
  }

  /// Extract text based on platform
  Future<String?> _extractTextForPlatform(
    InAppWebViewController controller,
    SourcePlatform platform,
  ) async {
    if (_isDisposed) return null;

    switch (platform) {
      case SourcePlatform.instagram:
        return _extractInstagram(controller);
      case SourcePlatform.facebook:
        return _extractFacebook(controller);
      case SourcePlatform.tiktok:
        return _extractTikTok(controller);
      default:
        return _extractGeneric(controller);
    }
  }

  /// Platform-specific selectors
  static const Map<SourcePlatform, List<String>> _platformSelectors = {
    SourcePlatform.instagram: [
      'article div span[dir="auto"]',
      'article div h1',
      'meta[property="og:description"]',
      'meta[name="description"]',
    ],
    SourcePlatform.facebook: [
      'div[data-ad-preview="message"]',
      'div[role="article"] span[dir="auto"]',
      'div[data-testid="post_message"]',
      'meta[property="og:description"]',
    ],
    SourcePlatform.tiktok: [
      'h1[data-e2e="browse-video-desc"]',
      'span[data-e2e="video-desc"]',
      'meta[property="og:description"]',
    ],
  };

  /// Instagram-specific extraction
  Future<String?> _extractInstagram(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('📸 Extracting from Instagram...');

    // Step 1: Click "more" button to expand text
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

    if (_isDisposed) return null;

    // Step 2: Extract all text after expansion
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
        debugPrint('${extractedText.substring(0, 200)}...');

        return extractedText;
      }
    } catch (e) {
      debugPrint('⚠️ Instagram extraction error: $e');
    }

    return null;
  }

  /// Facebook-specific extraction
  Future<String?> _extractFacebook(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('📘 Extracting from Facebook...');

    final selectors = _platformSelectors[SourcePlatform.facebook] ?? [];

    for (final selector in selectors) {
      if (_isDisposed) break;

      final result = await controller.evaluateJavascript(
        source: '''
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

  /// TikTok-specific extraction
  Future<String?> _extractTikTok(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('🎵 Extracting from TikTok...');

    final selectors = _platformSelectors[SourcePlatform.tiktok] ?? [];

    for (final selector in selectors) {
      if (_isDisposed) break;

      final result = await controller.evaluateJavascript(
        source: '''
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

  /// Generic extraction for other pages
  Future<String?> _extractGeneric(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('🌐 Generic text extraction...');

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

  /// User agent to mimic desktop browser
  String _getUserAgent(SourcePlatform platform) {
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36';
  }

  /// Safe cleanup of WebView
  void _safeCleanup() {
    if (!_isDisposed) {
      _isDisposed = true;

      debugPrint('🧹 Cleaning up WebView...');

      if (_headlessWebView != null) {
        try {
          _headlessWebView?.webViewController?.stopLoading();
        } catch (e) {
          debugPrint('⚠️ Could not stop WebView: $e');
        }

        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            _headlessWebView?.dispose();
            _headlessWebView = null;
            debugPrint('✅ WebView cleaned');
          } catch (e) {
            debugPrint('⚠️ WebView dispose error: $e');
          }
        });
      }
    }
  }

  /// Dispose method to clean up resources
  void dispose() {
    _safeCleanup();
  }
}
