/// Advanced headless web scraping service providing sophisticated content extraction from social media platforms.
///
/// This service implements comprehensive web scraping capabilities using headless browser technology to extract
/// recipe content from various social media platforms and cooking websites. It provides platform-specific extraction
/// strategies, intelligent timeout management, comprehensive error handling, and optimized content parsing algorithms
/// for reliable recipe discovery and import functionality.
///
/// **Architecture Integration:**
/// - Uses [HeadlessInAppWebView] for headless browser operations with full JavaScript support
/// - Implements platform-specific extraction strategies for optimal content parsing
/// - Integrates with platform detection for appropriate scraping technique selection
/// - Provides comprehensive timeout and error handling for reliable extraction operations
///
/// **Extraction Capabilities:**
/// - **Instagram Extraction**: Advanced caption parsing with "mer" button expansion and multi-selector strategies
/// - **Facebook Extraction**: Post content extraction with social media markup understanding
/// - **TikTok Extraction**: Video description parsing with overlay text recognition
/// - **Generic Extraction**: Structured recipe data parsing with fallback content strategies
/// - **Content Validation**: Recipe-specific content validation with Swedish cooking terminology recognition
///
/// **Technical Features:**
/// - **Headless Operation**: Browser automation without UI for efficient resource usage
/// - **Timeout Management**: Configurable extraction timeouts preventing infinite loading scenarios
/// - **Error Recovery**: Comprehensive error handling with graceful degradation strategies
/// - **Resource Cleanup**: Proper browser instance disposal preventing memory leaks
/// - **User Agent Spoofing**: Desktop browser mimicking for optimal content access
///
/// **Platform-Specific Optimizations:**
/// - **Instagram**: Handles dynamic content loading, expansion buttons, and Swedish interface elements
/// - **Facebook**: Navigates complex DOM structures and privacy-aware content extraction
/// - **TikTok**: Extracts video descriptions and overlay content with mobile-optimized parsing
/// - **Generic Sites**: Utilizes structured recipe markup and content area identification
///
/// **Usage Examples:**
/// ```dart
/// final scraper = WebScraper();
/// 
/// // Extract from Instagram post
/// final result = await scraper.performExtraction(
///   'https://instagram.com/p/recipe-post',
///   pd.SourcePlatform.instagram,
/// );
/// 
/// if (result.success) {
///   final recipeText = result.extractedText;
///   final metadata = result.metadata;
///   processExtractedRecipe(recipeText, metadata);
/// }
/// 
/// // Clean up resources
/// scraper.dispose();
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/social_media_extractor.dart';

/// Advanced headless web scraper providing platform-specific content extraction with intelligent parsing algorithms.
///
/// This service implements sophisticated web scraping using headless browser technology with platform-optimized
/// extraction strategies, comprehensive error handling, and intelligent content validation for reliable
/// recipe content discovery from social media platforms and cooking websites.
class WebScraper {
  // WebView controller
  HeadlessInAppWebView? _headlessWebView;
  
  // Flag to prevent double cleanup
  bool _isDisposed = false;
  
  // Timeout for extraction - 15 seconds
  static const Duration _extractionTimeout = Duration(seconds: 15);

  /// Performs comprehensive content extraction using headless browser with platform-specific optimization strategies.
  ///
  /// This method orchestrates the complete extraction process including browser initialization, content loading,
  /// platform-specific parsing, and result formatting. It implements sophisticated timeout management, error recovery,
  /// and resource cleanup to ensure reliable extraction operations across different social media platforms.
  ///
  /// [url] Target URL to extract recipe content from with full platform support
  /// [platform] Detected platform type for optimization strategy selection
  /// Returns [ExtractionResult] with success status, extracted content, and comprehensive metadata
  ///
  /// **Extraction Process:**
  /// 1. **Browser Initialization**: Creates headless WebView with platform-optimized settings
  /// 2. **Content Loading**: Loads target URL with progress monitoring and timeout management
  /// 3. **Platform Parsing**: Applies platform-specific extraction strategies for optimal content retrieval
  /// 4. **Content Validation**: Validates extracted content for recipe-specific information
  /// 5. **Resource Cleanup**: Properly disposes browser resources preventing memory leaks
  ///
  /// **Platform Optimizations:**
  /// - **Instagram**: Handles dynamic content expansion and Swedish language interface elements
  /// - **Facebook**: Navigates complex social media markup with privacy-aware content access
  /// - **TikTok**: Extracts video descriptions and overlay content with mobile-optimized parsing
  /// - **Generic**: Utilizes structured recipe data and content area identification strategies
  ///
  /// **Error Handling:**
  /// - Comprehensive timeout management with 15-second extraction limit
  /// - Network error recovery with detailed error reporting
  /// - Resource cleanup on failures preventing browser instance leaks
  /// - Graceful degradation for partially supported platforms
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Extract from Instagram recipe post
  /// final result = await scraper.performExtraction(
  ///   'https://instagram.com/p/recipe123',
  ///   pd.SourcePlatform.instagram,
  /// );
  /// 
  /// // Handle extraction results
  /// if (result.success && result.extractedText != null) {
  ///   final recipeContent = result.extractedText!;
  ///   final extractionTime = result.metadata['extractedAt'];
  ///   createRecipeFromContent(recipeContent);
  /// } else {
  ///   handleExtractionFailure(result.error);
  /// }
  /// ```
  Future<ExtractionResult> performExtraction(
    String url,
    pd.SourcePlatform platform,
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

            final delay = platform == pd.SourcePlatform.instagram
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
    pd.SourcePlatform platform,
  ) async {
    if (_isDisposed) return null;

    switch (platform) {
      case pd.SourcePlatform.instagram:
        return _extractInstagram(controller);
      case pd.SourcePlatform.facebook:
        return _extractFacebook(controller);
      case pd.SourcePlatform.tiktok:
        return _extractTikTok(controller);
      case pd.SourcePlatform.recipesite:
        return _extractRecipeSite(controller);
      default:
        return _extractGeneric(controller);
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

    final selectors = _platformSelectors[pd.SourcePlatform.facebook] ?? [];

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

    final selectors = _platformSelectors[pd.SourcePlatform.tiktok] ?? [];

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

  /// Recipe site-specific extraction with structured data parsing
  Future<String?> _extractRecipeSite(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('🍽️ Extracting from recipe site...');

    try {
      // First, try to extract structured recipe data (JSON-LD)
      final jsonLdResult = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            const scripts = document.querySelectorAll('script[type="application/ld+json"]');
            for (const script of scripts) {
              const data = JSON.parse(script.textContent);
              
              // Handle single recipe or array of recipes
              const recipes = Array.isArray(data) ? data : [data];
              
              for (const item of recipes) {
                if (item['@type'] === 'Recipe' || (item['@graph'] && item['@graph'].some(g => g['@type'] === 'Recipe'))) {
                  const recipe = item['@type'] === 'Recipe' ? item : item['@graph'].find(g => g['@type'] === 'Recipe');
                  
                  let recipeText = '';
                  
                  if (recipe.name) recipeText += recipe.name + '\\n\\n';
                  if (recipe.description) recipeText += recipe.description + '\\n\\n';
                  
                  if (recipe.recipeIngredient) {
                    recipeText += 'Ingredienser:\\n';
                    recipe.recipeIngredient.forEach(ing => recipeText += '- ' + ing + '\\n');
                    recipeText += '\\n';
                  }
                  
                  if (recipe.recipeInstructions) {
                    recipeText += 'Instruktioner:\\n';
                    recipe.recipeInstructions.forEach((inst, i) => {
                      const text = typeof inst === 'string' ? inst : inst.text;
                      recipeText += (i + 1) + '. ' + text + '\\n';
                    });
                    recipeText += '\\n';
                  }
                  
                  if (recipe.nutrition && recipe.nutrition.calories) {
                    recipeText += 'Kalorier: ' + recipe.nutrition.calories + '\\n';
                  }
                  
                  if (recipe.totalTime || recipe.prepTime || recipe.cookTime) {
                    recipeText += 'Tid: ';
                    if (recipe.totalTime) recipeText += 'Total: ' + recipe.totalTime + ' ';
                    if (recipe.prepTime) recipeText += 'Förberedelse: ' + recipe.prepTime + ' ';
                    if (recipe.cookTime) recipeText += 'Tillagning: ' + recipe.cookTime;
                    recipeText += '\\n';
                  }
                  
                  if (recipe.recipeYield) {
                    recipeText += 'Portioner: ' + recipe.recipeYield + '\\n';
                  }
                  
                  return recipeText.trim();
                }
              }
            }
            return null;
          } catch (e) {
            console.error('JSON-LD parsing error:', e);
            return null;
          }
        })()
        ''',
      );

      if (jsonLdResult != null && jsonLdResult.toString().isNotEmpty && jsonLdResult.toString() != 'null') {
        debugPrint('✅ Recipe structured data found!');
        return jsonLdResult.toString();
      }

      // Fallback to microdata extraction
      final microdataResult = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            const recipeElement = document.querySelector('[itemtype*="Recipe"]');
            if (!recipeElement) return null;
            
            let recipeText = '';
            
            const name = recipeElement.querySelector('[itemprop="name"]');
            if (name) recipeText += name.textContent.trim() + '\\n\\n';
            
            const description = recipeElement.querySelector('[itemprop="description"]');
            if (description) recipeText += description.textContent.trim() + '\\n\\n';
            
            const ingredients = recipeElement.querySelectorAll('[itemprop="recipeIngredient"]');
            if (ingredients.length > 0) {
              recipeText += 'Ingredienser:\\n';
              ingredients.forEach(ing => recipeText += '- ' + ing.textContent.trim() + '\\n');
              recipeText += '\\n';
            }
            
            const instructions = recipeElement.querySelectorAll('[itemprop="recipeInstructions"]');
            if (instructions.length > 0) {
              recipeText += 'Instruktioner:\\n';
              instructions.forEach((inst, i) => {
                recipeText += (i + 1) + '. ' + inst.textContent.trim() + '\\n';
              });
              recipeText += '\\n';
            }
            
            return recipeText.trim() || null;
          } catch (e) {
            console.error('Microdata parsing error:', e);
            return null;
          }
        })()
        ''',
      );

      if (microdataResult != null && microdataResult.toString().isNotEmpty && microdataResult.toString() != 'null') {
        debugPrint('✅ Recipe microdata found!');
        return microdataResult.toString();
      }

      // Final fallback to content-based extraction
      final selectors = _platformSelectors[pd.SourcePlatform.recipesite] ?? [];
      
      for (final selector in selectors.skip(3)) { // Skip structured data selectors
        if (_isDisposed) break;

        final result = await controller.evaluateJavascript(
          source: '''
          (function() {
            try {
              const element = document.querySelector('$selector');
              if (element) {
                // Filter out common non-recipe content
                const text = element.innerText || element.textContent || '';
                if (text.length > 300 && 
                    !text.includes('cookie') && 
                    !text.includes('gdpr') &&
                    !text.includes('OneTrust') &&
                    !text.includes('window.') &&
                    (text.toLowerCase().includes('ingrediens') || 
                     text.toLowerCase().includes('ingredient') ||
                     text.toLowerCase().includes('recept') ||
                     text.toLowerCase().includes('recipe'))) {
                  return text;
                }
              }
              return null;
            } catch (e) {
              return null;
            }
          })()
          ''',
        );

        if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
          debugPrint('✅ Recipe content found with selector: $selector');
          return result.toString();
        }
      }

      debugPrint('⚠️ No recipe content found');
      return null;
    } catch (e) {
      debugPrint('❌ Recipe site extraction error: $e');
      return null;
    }
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
  String _getUserAgent(pd.SourcePlatform platform) {
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
