import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;

/// Handles HTTP fetching and web scraping for URL imports.
class HttpContentFetcher {
  static const _fetchTimeout = Duration(seconds: 10);
  static const _maxResponseBytes = 5 * 1024 * 1024; // 5 MB
  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';

  final http.Client? _httpClient;
  final WebScraper Function()? _webScraperFactory;

  HttpContentFetcher({
    http.Client? httpClient,
    WebScraper Function()? webScraperFactory,
  })  : _httpClient = httpClient,
        _webScraperFactory = webScraperFactory;

  /// Fetches HTML content from URL with timeout and size limit.
  ///
  /// Returns the decoded HTML string, or `null` on failure.
  /// Throws [HttpFetchException] with a user-facing message when the
  /// response exceeds the 5 MB size limit.
  Future<String?> fetchHtmlWithTimeout(String url) async {
    try {
      final client = _httpClient ?? http.Client();
      final shouldCloseClient = _httpClient == null;

      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll({
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,sv;q=0.8',
        });

        final streamedResponse =
            await client.send(request).timeout(_fetchTimeout);

        if (streamedResponse.statusCode != 200) {
          return null;
        }

        // Check Content-Length header first for early rejection
        final contentLength = streamedResponse.contentLength;
        if (contentLength != null && contentLength > _maxResponseBytes) {
          throw HttpFetchException(
            'Sidan är för stor att importera '
            '(${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB). '
            'Max 5 MB stöds.',
          );
        }

        // Read bytes incrementally with size cap
        final bytes = await _readBytesWithLimit(streamedResponse.stream);

        // Detect charset and decode
        final charset = _detectCharset(
          streamedResponse.headers['content-type'],
          bytes,
        );
        return _decodeBytes(bytes, charset);
      } finally {
        if (shouldCloseClient) {
          client.close();
        }
      }
    } on HttpFetchException {
      rethrow;
    } catch (e) {
      AppLogger.warning(
          'HttpContentFetcher: Failed to fetch HTML from $url: $e');
      return null;
    }
  }

  /// Reads bytes from a stream, aborting if the total exceeds [_maxResponseBytes].
  Future<Uint8List> _readBytesWithLimit(http.ByteStream stream) async {
    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      if (totalBytes > _maxResponseBytes) {
        throw const HttpFetchException(
          'Sidan är för stor att importera (>5 MB). Max 5 MB stöds.',
        );
      }
      builder.add(chunk);
    }

    return builder.toBytes();
  }

  /// Detects the character encoding from HTTP Content-Type header and HTML meta tags.
  ///
  /// Priority: Content-Type header charset → HTML <meta charset> → UTF-8 default.
  String _detectCharset(String? contentType, Uint8List bytes) {
    // 1. Check Content-Type header
    if (contentType != null) {
      final headerCharset = _parseCharsetFromContentType(contentType);
      if (headerCharset != null) {
        return _normalizeCharset(headerCharset);
      }
    }

    // 2. Scan first 1024 bytes for <meta charset="..."> or <meta http-equiv="Content-Type"...>
    final head = utf8.decode(
      bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
      allowMalformed: true,
    );

    // <meta charset="utf-8">
    final metaCharset = RegExp(
      r'<meta[^>]+charset=["\s]?([^"\s;>]+)',
      caseSensitive: false,
    ).firstMatch(head);
    if (metaCharset != null) {
      return _normalizeCharset(metaCharset.group(1)!);
    }

    // <meta http-equiv="Content-Type" content="text/html; charset=...">
    final httpEquiv = RegExp(
      r'<meta[^>]+http-equiv=["\s]?Content-Type["\s]?[^>]+charset=([^"\s;>]+)',
      caseSensitive: false,
    ).firstMatch(head);
    if (httpEquiv != null) {
      return _normalizeCharset(httpEquiv.group(1)!);
    }

    return 'utf-8';
  }

  /// Extracts charset value from a Content-Type header string.
  String? _parseCharsetFromContentType(String contentType) {
    final match = RegExp(
      r'charset=([^\s;]+)',
      caseSensitive: false,
    ).firstMatch(contentType);
    return match?.group(1);
  }

  /// Normalizes common charset aliases.
  String _normalizeCharset(String charset) {
    final lower = charset.toLowerCase().replaceAll(RegExp(r'[\s"' ']'), '');
    switch (lower) {
      case 'utf8':
      case 'utf-8':
        return 'utf-8';
      case 'iso-8859-1':
      case 'iso88591':
      case 'latin1':
      case 'latin-1':
        return 'latin-1';
      case 'windows-1252':
      case 'cp1252':
        return 'windows-1252';
      default:
        return lower;
    }
  }

  /// Decodes bytes using the detected charset, with UTF-8 → Latin-1 fallback.
  String _decodeBytes(Uint8List bytes, String charset) {
    switch (charset) {
      case 'latin-1':
      case 'windows-1252':
      case 'iso-8859-1':
        return latin1.decode(bytes);
      case 'utf-8':
      default:
        try {
          return utf8.decode(bytes);
        } on FormatException {
          AppLogger.info(
              'HttpContentFetcher: UTF-8 decode failed, falling back to Latin-1');
          return latin1.decode(bytes);
        }
    }
  }

  /// Fetches raw HTML via headless browser (for sites that block simple HTTP).
  Future<String?> tryWebScraperHtml(String url) async {
    try {
      final detector = pd.PlatformDetector();
      final platform = detector.detectPlatform(url);
      final webUrl = detector.convertToWebUrl(url);

      final webScraper = _webScraperFactory?.call() ?? WebScraper();

      try {
        final html = await webScraper.fetchRawHtml(webUrl, platform);
        if (html != null && html.length > 100) {
          return html;
        }
        return null;
      } finally {
        webScraper.dispose();
      }
    } catch (e) {
      AppLogger.warning(
          'HttpContentFetcher: WebScraper HTML fetch failed for $url: $e');
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
        final extractionResult =
            await webScraper.performExtraction(webUrl, platform);

        if (extractionResult.success &&
            extractionResult.extractedText != null) {
          return extractionResult.extractedText;
        }

        return null;
      } finally {
        webScraper.dispose();
      }
    } catch (e) {
      AppLogger.warning('HttpContentFetcher: WebScraper failed for $url: $e');
      return null;
    }
  }
}

/// Exception for HTTP fetch errors with user-facing messages.
class HttpFetchException implements Exception {
  final String message;
  const HttpFetchException(this.message);

  @override
  String toString() => message;
}
