/// Headless web scraping service for extracting recipe content from social media and cooking websites.
/// Provides platform-specific extraction strategies (Instagram, Facebook, TikTok, recipe sites) using
/// headless browser technology with timeout management and proper resource cleanup.

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'package:butlery/core/constants/http_constants.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/social_media_extractor.dart';

// Extractor imports
import 'package:butlery/services/extraction/extractors/instagram_content_extractor.dart';
import 'package:butlery/services/extraction/extractors/recipe_site_content_extractor.dart';
import 'package:butlery/services/extraction/extractors/social_platform_content_extractor.dart';

/// Headless web scraper with platform-specific content extraction.
class WebScraper {
  HeadlessInAppWebView? _headlessWebView;
  bool _isDisposed = false;
  Completer<void>? _pendingCleanup;

  static const Duration _extractionTimeout = Duration(seconds: 15);

  // Platform-specific extractors
  late final InstagramContentExtractor _instagramExtractor;
  late final RecipeSiteContentExtractor _recipeSiteExtractor;
  late final SocialPlatformContentExtractor _socialPlatformExtractor;

  WebScraper() {
    _initializeExtractors();
  }

  void _initializeExtractors() {
    _instagramExtractor = InstagramContentExtractor(
      isDisposed: () => _isDisposed,
    );

    _recipeSiteExtractor = RecipeSiteContentExtractor(
      isDisposed: () => _isDisposed,
      selectors: _platformSelectors[pd.SourcePlatform.recipesite] ?? [],
    );

    _socialPlatformExtractor = SocialPlatformContentExtractor(
      isDisposed: () => _isDisposed,
      platformSelectors: _platformSelectors,
    );
  }

  /// Extracts recipe content from URL using headless browser with platform-specific strategies.
  /// Handles browser initialization, timeout management (15s), platform parsing, and resource cleanup.
  Future<ExtractionResult> performExtraction(
    String url,
    pd.SourcePlatform platform,
  ) async {
    // Wait for any pending cleanup from a previous extraction to complete
    // before resetting state — prevents race where _safeCleanup sets
    // _isDisposed=true after we already reset it to false.
    if (_pendingCleanup != null && !_pendingCleanup!.isCompleted) {
      await _pendingCleanup!.future;
    }

    _isDisposed = false;
    if (_headlessWebView != null) {
      try {
        _headlessWebView?.dispose();
      } catch (e) {
        AppLogger.debug('WebView dispose: $e');
      }
      _headlessWebView = null;
    }

    final completer = Completer<ExtractionResult>();
    bool hasExtracted = false;

    // Set timeout
    late final Timer timeoutTimer;
    timeoutTimer = Timer(_extractionTimeout, () {
      if (!completer.isCompleted && !_isDisposed) {
        completer.complete(
          ExtractionResult(
            success: false,
            error:
                'Timeout: Could not load page within ${_extractionTimeout.inSeconds} seconds',
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

          if (progress == 100 && !hasExtracted && !completer.isCompleted) {
            hasExtracted = true;

            final delay = platform == pd.SourcePlatform.instagram
                ? AppDimensions.animationDurationSlow
                : AppDimensions.animationDurationMedium;

            Future.delayed(delay, () async {
              if (!completer.isCompleted &&
                  !_isDisposed &&
                  _headlessWebView != null) {
                try {
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
              return NavigationActionPolicy.CANCEL;
            }

            // Block app store links
            if (urlString.contains('apps.apple.com') ||
                urlString.contains('play.google.com')) {
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {
          if (_isDisposed) return;

          if (url != null && url.toString().startsWith('instagram://')) {
            return;
          }
        },
        onReceivedError: (controller, request, error) {
          if (_isDisposed || completer.isCompleted) return;

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
        onConsoleMessage: (controller, consoleMessage) {},
      );

      // Start WebView
      await _headlessWebView?.run();
    } catch (e) {
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

  /// Extract text based on platform using specialized extractors
  Future<String?> _extractTextForPlatform(
    InAppWebViewController controller,
    pd.SourcePlatform platform,
  ) async {
    if (_isDisposed) return null;

    switch (platform) {
      case pd.SourcePlatform.instagram:
        return _instagramExtractor.extract(controller);
      case pd.SourcePlatform.facebook:
        return _socialPlatformExtractor.extractFacebook(controller);
      case pd.SourcePlatform.tiktok:
        return _socialPlatformExtractor.extractTikTok(controller);
      case pd.SourcePlatform.recipesite:
        return _recipeSiteExtractor.extract(controller);
      default:
        return _socialPlatformExtractor.extractGeneric(controller);
    }
  }

  /// Platform-specific selectors
  static final Map<pd.SourcePlatform, List<String>> _platformSelectors = {
    pd.SourcePlatform.instagram: [
      'article div span[dir="auto"]',
      'article div h1',
      'meta[property="og:description"]',
      'meta[name="description"]',
    ],
    pd.SourcePlatform.facebook: [
      'div[data-ad-preview="message"]',
      'div[role="article"] span[dir="auto"]',
      'div[data-testid="post_message"]',
      'meta[property="og:description"]',
    ],
    pd.SourcePlatform.tiktok: [
      'h1[data-e2e="browse-video-desc"]',
      'span[data-e2e="video-desc"]',
      'meta[property="og:description"]',
    ],
    pd.SourcePlatform.recipesite: [
      // Recipe structured data (JSON-LD and microdata)
      'script[type="application/ld+json"]',
      '[itemtype*="Recipe"]',
      '[itemscope][itemtype*="Recipe"]',

      // Common recipe content selectors
      '.recipe-content, .recipe-details, .recipe-instructions',
      '.recipe-ingredients, .ingredients-list',
      '.recipe-method, .method-list',
      'article.recipe, section.recipe',
      '.entry-content',

      // ICA-specific selectors
      '.recipe-description, .recipe-intro',
      '.ingredient-list li, .ingredients li',
      '.instruction-list li, .instructions li',

      // Generic content areas
      'main, article, [role="main"]',
      '.content, .main-content',
    ],
  };

  /// User agent to mimic desktop browser
  String _getUserAgent(pd.SourcePlatform platform) {
    return HttpConstants.desktopUserAgent;
  }

  /// Safe cleanup of WebView, tracked via [_pendingCleanup] so
  /// subsequent extractions can await completion before reusing.
  void _safeCleanup() {
    if (!_isDisposed) {
      _isDisposed = true;
      final cleanupCompleter = Completer<void>();
      _pendingCleanup = cleanupCompleter;

      if (_headlessWebView != null) {
        try {
          _headlessWebView?.webViewController?.stopLoading();
        } catch (e) {
          // Ignore stop loading errors
        }

        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            _headlessWebView?.dispose();
            _headlessWebView = null;
          } catch (e) {
            // Ignore dispose errors
          }
          cleanupCompleter.complete();
        });
      } else {
        cleanupCompleter.complete();
      }
    }
  }

  /// Fetches raw HTML from a URL via headless browser.
  /// Use when simple HTTP fails (bot protection, JS-rendered pages).
  Future<String?> fetchRawHtml(String url, pd.SourcePlatform platform) async {
    if (_isDisposed) return null;

    // Clean up any previous WebView
    if (_headlessWebView != null) {
      try {
        _headlessWebView?.dispose();
      } catch (e) {
        AppLogger.debug('WebView dispose: $e');
      }
      _headlessWebView = null;
    }

    final completer = Completer<String?>();
    bool hasCompleted = false;

    final timeoutTimer = Timer(_extractionTimeout, () {
      if (!hasCompleted && !_isDisposed) {
        hasCompleted = true;
        completer.complete(null);
        Future.delayed(const Duration(milliseconds: 500), () {
          _safeCleanup();
        });
      }
    });

    try {
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent: _getUserAgent(platform),
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: false,
          clearCache: true,
        ),
        onProgressChanged: (controller, progress) {
          if (_isDisposed || hasCompleted) return;

          if (progress == 100 && !hasCompleted) {
            // Wait briefly for JS to finish rendering
            Future.delayed(const Duration(milliseconds: 500), () async {
              if (hasCompleted || _isDisposed) return;
              hasCompleted = true;
              timeoutTimer.cancel();

              try {
                final html = await controller.getHtml();
                completer.complete(html);
              } catch (e) {
                completer.complete(null);
              }

              await Future.delayed(const Duration(milliseconds: 500));
              _safeCleanup();
            });
          }
        },
        onReceivedError: (controller, request, error) {
          if (hasCompleted || _isDisposed) return;
          hasCompleted = true;
          timeoutTimer.cancel();
          completer.complete(null);
          Future.delayed(const Duration(milliseconds: 500), () {
            _safeCleanup();
          });
        },
      );

      await _headlessWebView?.run();
    } catch (e) {
      timeoutTimer.cancel();
      if (!hasCompleted) {
        hasCompleted = true;
        completer.complete(null);
      }
      _safeCleanup();
    }

    return completer.future;
  }

  /// Dispose method to clean up resources
  void dispose() {
    _safeCleanup();
  }
}
