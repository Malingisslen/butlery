// lib/services/social_media_extractor.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import '../services/content_detector_service.dart';
import '../theme/app_theme.dart';

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

/// Service för att extrahera text från sociala medier med headless WebView
///
/// Designad för att vara modulär och lätt att uppdatera när
/// sociala medier ändrar sin struktur.
class SocialMediaExtractor {
  // Singleton pattern
  static final SocialMediaExtractor _instance =
      SocialMediaExtractor._internal();
  factory SocialMediaExtractor() => _instance;
  SocialMediaExtractor._internal();

  // WebView controller
  HeadlessInAppWebView? _headlessWebView;

  // Flag för att förhindra dubbel cleanup
  bool _isDisposed = false;

  // Timeout för extraktion - ÖKAD TILL 15 SEKUNDER
  static const Duration _extractionTimeout = AppTheme.wait15s;

  /// Platform-specifika selektorer (lätt att uppdatera)
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

  /// Extraherar text från URL
  Future<ExtractionResult> extractFromUrl(String url) async {
    debugPrint('🌐 Startar extraktion från: $url');

    // Återställ disposed flag för ny extraktion
    _isDisposed = false;

    // Konvertera Instagram-länkar till webb-URL:er
    String webUrl = url;
    if (url.startsWith('instagram://')) {
      // Extrahera shortcode från Instagram-länk
      final shortcodeMatch = RegExp(r'shortcode=([^&]+)').firstMatch(url);
      if (shortcodeMatch != null) {
        final shortcode = shortcodeMatch.group(1);
        webUrl = 'https://www.instagram.com/p/$shortcode/';
        debugPrint('📸 Konverterade Instagram-länk till: $webUrl');
      }
    }

    // Identifiera plattform
    final detector = ContentDetectorService();
    final detectionResult = detector.detectContent(webUrl);
    final platform = detectionResult.platform;

    if (platform == null || platform == SourcePlatform.unknown) {
      return ExtractionResult(
        success: false,
        error: 'Okänd plattform för URL: $webUrl',
      );
    }

    // Starta headless WebView
    final result = await _performExtraction(webUrl, platform);

    return result;
  }

  /// Utför själva extraktionen med WebView
  Future<ExtractionResult> _performExtraction(
    String url,
    SourcePlatform platform,
  ) async {
    final completer = Completer<ExtractionResult>();
    bool hasExtracted = false; // Flag för att förhindra dubbel extraktion
    int loadCount = 0; // Räkna antal laddningar

    // Sätt timeout
    late final Timer timeoutTimer;
    timeoutTimer = Timer(_extractionTimeout, () {
      if (!completer.isCompleted && !_isDisposed) {
        debugPrint('⏱️ Timeout nådd, avslutar extraktion');
        completer.complete(
          ExtractionResult(
            success: false,
            error:
                'Timeout: Kunde inte ladda sidan inom ${_extractionTimeout.inSeconds} sekunder',
          ),
        );
        // Städa upp efter timeout
        Future.delayed(const Duration(milliseconds: 500), () {
          _safeCleanup();
        });
      }
    });

    try {
      // Skapa headless WebView
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent: _getUserAgent(platform),
          javaScriptEnabled: true,
          // Blockera redirects till app-länkar
          useShouldOverrideUrlLoading: true,
          // Säkerhetsinställningar för att undvika krascher
          domStorageEnabled: true,
          databaseEnabled: false,
          clearCache: true,
        ),
        onProgressChanged: (controller, progress) {
          if (_isDisposed || completer.isCompleted) return;

          debugPrint('📊 Laddning: $progress%');

          // När sidan är helt laddad och vi inte har extraherat ännu
          if (progress == 100 && !hasExtracted && !completer.isCompleted) {
            hasExtracted = true;

            // Extrahera efter kort fördröjning - ÖKAD TILL 3 SEKUNDER FÖR INSTAGRAM
            final delay =
                platform == SourcePlatform.instagram
                    ? AppTheme.wait3s
                    : AppTheme.wait2s;

            Future.delayed(delay, () async {
              if (!completer.isCompleted &&
                  !_isDisposed &&
                  _headlessWebView != null) {
                try {
                  debugPrint('🔍 Extraherar innehåll...');

                  // Extrahera text baserat på plattform
                  final extractedText = await _extractTextForPlatform(
                    controller,
                    platform,
                  );

                  // Avbryt timeout
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
                          error: 'Ingen text kunde extraheras från sidan',
                        ),
                      );
                    }
                  }

                  // Vänta lite innan cleanup för att undvika krasch
                  await Future.delayed(const Duration(milliseconds: 1000));
                  _safeCleanup();
                } catch (e) {
                  debugPrint('❌ Fel vid extraktion: $e');
                  timeoutTimer.cancel();

                  if (!completer.isCompleted) {
                    completer.complete(
                      ExtractionResult(
                        success: false,
                        error: 'Fel vid textextraktion: ${e.toString()}',
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

            // Blockera Instagram app-länkar
            if (urlString.startsWith('instagram://') ||
                urlString.startsWith('fb://') ||
                urlString.startsWith('twitter://') ||
                urlString.startsWith('tiktok://')) {
              debugPrint('🚫 Blockerar app-länk: $urlString');
              return NavigationActionPolicy.CANCEL;
            }

            // Blockera även app store-länkar
            if (urlString.contains('apps.apple.com') ||
                urlString.contains('play.google.com')) {
              debugPrint('🚫 Blockerar app store-länk: $urlString');
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {
          if (_isDisposed) return;

          loadCount++;
          debugPrint('✅ Sida laddad (gång $loadCount): $url');

          // Ignorera instagram:// URL:er
          if (url != null && url.toString().startsWith('instagram://')) {
            debugPrint('⚠️ Ignorerar Instagram app URL');
            return;
          }
        },
        onReceivedError: (controller, request, error) {
          if (_isDisposed || completer.isCompleted) return;

          debugPrint('❌ Laddningsfel: ${error.description}');

          timeoutTimer.cancel();

          if (!completer.isCompleted) {
            completer.complete(
              ExtractionResult(
                success: false,
                error: 'Kunde inte ladda sidan: ${error.description}',
              ),
            );
          }

          Future.delayed(const Duration(milliseconds: 500), () {
            _safeCleanup();
          });
        },
        onConsoleMessage: (controller, consoleMessage) {
          // Log JavaScript console messages för debugging
          debugPrint('CONSOLE: ${consoleMessage.message}');
        },
      );

      // Starta WebView
      await _headlessWebView?.run();
    } catch (e) {
      debugPrint('❌ Extraktionsfel: $e');
      timeoutTimer.cancel();

      if (!completer.isCompleted) {
        completer.complete(
          ExtractionResult(
            success: false,
            error: 'Tekniskt fel: ${e.toString()}',
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _safeCleanup();
    }

    return completer.future;
  }

  /// Extraherar text baserat på plattform
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

  /// Instagram-specifik extraktion
  Future<String?> _extractInstagram(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('📸 Extraherar från Instagram...');

    // Steg 1: Klicka på "mer" knappen för att expandera all text
    try {
      final clickResult = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            // Leta efter "mer" knappen mer noggrant
            const allElements = document.querySelectorAll('article *');
            let merButton = null;
            
            for (const element of allElements) {
              const text = (element.textContent || '').trim();
              // Kolla exakt matchning
              if (text === 'mer' || 
                  text === '... mer' ||
                  text === 'more' ||
                  text === '... more') {
                merButton = element;
                console.log('Hittade mer-knapp:', text, element.tagName);
                break;
              }
            }
            
            if (merButton) {
              // Simulera ett riktigt klick
              merButton.click();
              console.log('Klickade på mer-knappen');
              return true;
            }
            
            console.log('Hittade ingen mer-knapp');
            return false;
          } catch (e) {
            console.error('Fel vid klick:', e);
            return false;
          }
        })()
        ''',
      );

      debugPrint('Klick resultat: $clickResult');

      // Vänta för att texten ska expandera - ÖKAD VÄNTETID
      await Future.delayed(AppTheme.wait3s);
    } catch (e) {
      debugPrint('⚠️ Kunde inte klicka på mer-knappen: $e');
    }

    if (_isDisposed) return null;

    // Steg 2: Extrahera all text efter expansion
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            // Metod 1: Leta efter h1 element som ofta innehåller hela caption
            const h1Elements = document.querySelectorAll('article h1');
            for (const h1 of h1Elements) {
              const text = h1.textContent || '';
              // Kolla om det är recepttext (innehåller ingredienser)
              if (text.length > 200 && 
                  (text.toLowerCase().includes('jäst') || 
                   text.toLowerCase().includes('mjöl') || 
                   text.toLowerCase().includes('recept') ||
                   text.includes('dl ') ||
                   text.includes('msk '))) {
                console.log('Hittade recept i h1:', text.substring(0, 100) + '...');
                return text;
              }
            }
            
            // Metod 2: Leta i alla span element
            const article = document.querySelector('article');
            if (!article) return null;
            
            let longestText = '';
            const spans = article.querySelectorAll('span');
            
            for (const span of spans) {
              const text = span.textContent || '';
              // Hitta den längsta texten som verkar vara ett recept
              if (text.length > longestText.length && 
                  text.length > 200 &&
                  !text.includes('Följ') &&
                  !text.includes('gilla-markeringar')) {
                longestText = text;
              }
            }
            
            if (longestText) {
              console.log('Hittade långtext:', longestText.substring(0, 100) + '...');
              return longestText;
            }
            
            // Metod 3: Ta all synlig text från artikeln
            const visibleText = article.innerText || '';
            const lines = visibleText.split('\\n');
            let captionText = '';
            let inCaption = false;
            
            for (const line of lines) {
              // Börja när vi hittar receptets början
              if (line.includes('Här kommer') || 
                  line.toLowerCase().includes('recept') || 
                  inCaption) {
                inCaption = true;
                captionText += line + ' ';
                
                // Sluta när vi kommer till metadata
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
            console.error('Fel vid textextraktion:', e);
            return null;
          }
        })()
        ''',
      );

      if (result != null &&
          result.toString().isNotEmpty &&
          result.toString() != 'null') {
        final extractedText = result.toString();
        debugPrint('✅ Instagram-text hittad!');
        debugPrint('📝 Extraherad text (${extractedText.length} tecken):');
        debugPrint('${extractedText.substring(0, 200)}...');

        return extractedText;
      }
    } catch (e) {
      debugPrint('⚠️ Fel vid Instagram-extraktion: $e');
    }

    return null;
  }

  /// Facebook-specifik extraktion
  Future<String?> _extractFacebook(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('📘 Extraherar från Facebook...');

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

  /// TikTok-specifik extraktion
  Future<String?> _extractTikTok(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('🎵 Extraherar från TikTok...');

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

  /// Generisk extraktion för andra sidor
  Future<String?> _extractGeneric(InAppWebViewController controller) async {
    if (_isDisposed) return null;

    debugPrint('🌐 Generisk textextraktion...');

    // Försök hitta recept-liknande innehåll
    final result = await controller.evaluateJavascript(
      source: '''
      (function() {
        // Leta efter strukturerat recept-data
        const recipe = document.querySelector('[itemtype*="Recipe"]');
        if (recipe) {
          return recipe.innerText;
        }
        
        // Fallback till artikel-innehåll
        const article = document.querySelector('article, main, [role="main"]');
        if (article) {
          return article.innerText;
        }
        
        // Sista utväg - body text
        return document.body.innerText;
      })()
    ''',
    );

    return result?.toString();
  }

  /// User agent för att efterlikna desktop webbläsare
  String _getUserAgent(SourcePlatform platform) {
    // Använd desktop user agent för att undvika app-redirects
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36';
  }

  /// Säker cleanup av WebView
  void _safeCleanup() {
    if (!_isDisposed) {
      _isDisposed = true;

      debugPrint('🧹 Städar upp WebView...');

      // Stoppa WebView först om den finns
      if (_headlessWebView != null) {
        try {
          _headlessWebView?.webViewController?.stopLoading();
        } catch (e) {
          debugPrint('⚠️ Kunde inte stoppa WebView: $e');
        }

        // Vänta lite innan dispose
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            _headlessWebView?.dispose();
            _headlessWebView = null;
            debugPrint('✅ WebView städad');
          } catch (e) {
            debugPrint('⚠️ Fel vid WebView dispose: $e');
          }
        });
      }
    }
  }

  /// Dispose metod för att städa upp resurser
  void dispose() {
    _safeCleanup();
  }
}
