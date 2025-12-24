import 'package:http/http.dart' as http;
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;

/// Handles HTTP fetching and web scraping for URL imports.
class HttpContentFetcher {
  static const _fetchTimeout = Duration(seconds: 10);
  static const _userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';

  final http.Client? _httpClient;
  final WebScraper Function()? _webScraperFactory;

  HttpContentFetcher({
    http.Client? httpClient,
    WebScraper Function()? webScraperFactory,
  })  : _httpClient = httpClient,
        _webScraperFactory = webScraperFactory;

  /// Fetches HTML content from URL with timeout.
  Future<String?> fetchHtmlWithTimeout(String url) async {
    try {
      final client = _httpClient ?? http.Client();
      final shouldCloseClient = _httpClient == null;

      try {
        final response = await client.get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
        ).timeout(_fetchTimeout);

        if (response.statusCode == 200) {
          return response.body;
        }

        return null;
      } finally {
        if (shouldCloseClient) {
          client.close();
        }
      }
    } catch (e) {
      return null;
    }
  }

  /// Attempts extraction using WebScraper for platform-specific handling.
  Future<String?> tryWebScraper(String url) async {
    try {
      final detector = pd.PlatformDetector();
      final platform = detector.detectPlatform(url);
      final webUrl = detector.convertToWebUrl(url);

      final webScraper = _webScraperFactory?.call() ?? WebScraper();

      try {
        final extractionResult = await webScraper.performExtraction(webUrl, platform);

        if (extractionResult.success && extractionResult.extractedText != null) {
          return extractionResult.extractedText;
        }

        return null;
      } finally {
        webScraper.dispose();
      }
    } catch (e) {
      return null;
    }
  }
}
