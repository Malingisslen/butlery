/// Mocks and test helpers for import integration testing
///
/// This file provides:
/// - Mock classes for external dependencies
/// - HTTP response builders
/// - Fallback value registrations
/// - Test helper functions

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/social_media_extractor.dart';

// ============================================================================
// MOCK CLASSES
// ============================================================================

/// Mock HTTP client for URL import testing
class MockHttpClient extends Mock implements http.Client {}

/// Mock HTTP response for streaming responses
class MockStreamedResponse extends Mock implements http.StreamedResponse {}

// ============================================================================
// FAKE CLASSES (for registerFallbackValue)
// ============================================================================

/// Fake URI for mocktail fallback
class FakeUri extends Fake implements Uri {}

/// Fake HTTP Request for mocktail fallback
class FakeHttpRequest extends Fake implements http.BaseRequest {}

// ============================================================================
// HTTP RESPONSE BUILDERS
// ============================================================================

/// Helper class to build HTTP responses for testing
class MockHttpResponseBuilder {
  /// Create successful HTTP response
  static http.Response success(String body, {int statusCode = 200}) {
    return http.Response(body, statusCode, headers: {
      'content-type': 'text/html; charset=utf-8',
    });
  }

  /// Create 404 Not Found response
  static http.Response notFound({String body = 'Not Found'}) {
    return http.Response(body, 404);
  }

  /// Create 500 Internal Server Error response
  static http.Response serverError({String body = 'Internal Server Error'}) {
    return http.Response(body, 500);
  }

  /// Create 401 Unauthorized response
  static http.Response unauthorized({String body = 'Unauthorized'}) {
    return http.Response(body, 401);
  }

  /// Create 403 Forbidden response
  static http.Response forbidden({String body = 'Forbidden'}) {
    return http.Response(body, 403);
  }

  /// Create 503 Service Unavailable response
  static http.Response serviceUnavailable(
      {String body = 'Service Unavailable'}) {
    return http.Response(body, 503);
  }

  /// Create successful response with JSON-LD recipe
  static http.Response successWithJsonLd(String jsonLdHtml) {
    return success(jsonLdHtml);
  }

  /// Create successful response with microdata recipe
  static http.Response successWithMicrodata(String microdataHtml) {
    return success(microdataHtml);
  }

  /// Create successful response with plain HTML (no structured data)
  static http.Response successWithPlainHtml(String plainHtml) {
    return success(plainHtml);
  }
}

// ============================================================================
// WEBSCRAPER RESPONSE BUILDERS
// ============================================================================

/// Helper class to build WebScraper ExtractionResult for testing
class MockWebScraperBuilder {
  /// Create successful WebScraper extraction result
  static ExtractionResult success({
    required String extractedText,
    Map<String, dynamic>? metadata,
  }) {
    return ExtractionResult(
      success: true,
      extractedText: extractedText,
      metadata: metadata ?? {'extraction_method': 'javascript_rendering'},
    );
  }

  /// Create failed WebScraper extraction result
  static ExtractionResult failure({
    required String error,
  }) {
    return ExtractionResult(
      success: false,
      error: error,
      metadata: {'extraction_method': 'javascript_rendering'},
    );
  }

  /// Create extraction result with plain HTML text
  static ExtractionResult fromPlainHtml(String htmlText) {
    return ExtractionResult(
      success: true,
      extractedText: htmlText,
      metadata: {
        'extraction_method': 'html_text_extraction',
        'html_length': htmlText.length,
      },
    );
  }
}

// ============================================================================
// MOCK SETUP HELPERS
// ============================================================================

/// Helper class to register all fallback values for mocktail
class ImportMockSetup {
  /// Register all fallback values needed for import integration tests
  static void registerFallbacks() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeHttpRequest());
    registerFallbackValue(
        SourcePlatform.unknown); // Enum fallback for WebScraper mocking
  }

  /// Setup default HTTP client stubs (can be overridden in specific tests)
  static void setupDefaultHttpStubs(MockHttpClient mockClient) {
    // Default: Return 404 for any unmatched URL
    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => MockHttpResponseBuilder.notFound());

    when(() => mockClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => MockHttpResponseBuilder.notFound());
  }
}

// ============================================================================
// TEST ASSERTION HELPERS
// ============================================================================

/// Helper class with custom matchers and assertions for import testing
class ImportTestAssertions {
  /// Assert that a recipe has valid Swedish recipe structure
  static void assertValidSwedishRecipe(Map<String, dynamic> recipe) {
    expect(recipe['title'], isNotNull, reason: 'Recipe must have title');
    expect(recipe['title'], isNotEmpty, reason: 'Recipe title cannot be empty');
    expect(recipe['ingredients'], isNotNull,
        reason: 'Recipe must have ingredients');
    expect(recipe['instructions'], isNotNull,
        reason: 'Recipe must have instructions');
  }

  /// Assert that metadata includes expected fields
  static void assertMetadataIncludes(
    Map<String, dynamic>? metadata,
    List<String> requiredFields,
  ) {
    expect(metadata, isNotNull, reason: 'Metadata should not be null');
    for (final field in requiredFields) {
      expect(metadata!.containsKey(field), isTrue,
          reason: 'Metadata must include "$field"');
    }
  }

  /// Assert that warnings contain specific text
  static void assertWarningsContain(
      List<String> warnings, String expectedText) {
    expect(warnings.any((w) => w.contains(expectedText)), isTrue,
        reason: 'Warnings should contain "$expectedText"');
  }

  /// Assert that recipe portions are valid
  static void assertValidPortions(int? portions) {
    expect(portions, isNotNull, reason: 'Portions should not be null');
    expect(portions! > 0, isTrue, reason: 'Portions must be positive');
    expect(portions <= 100, isTrue,
        reason: 'Portions should be reasonable (<= 100)');
  }

  /// Assert that recipe time is valid
  static void assertValidTime(int? timeMinutes) {
    if (timeMinutes != null) {
      expect(timeMinutes > 0, isTrue, reason: 'Time must be positive');
      expect(timeMinutes <= 1440, isTrue, reason: 'Time should be <= 24 hours');
    }
  }
}

// ============================================================================
// TIME MANIPULATION HELPERS
// ============================================================================

/// Helper to create deterministic timestamps for testing
class MockTimeProvider {
  static DateTime _currentTime = DateTime(2025, 1, 15, 12, 0, 0);

  /// Get current test time
  static DateTime now() => _currentTime;

  /// Set test time
  static void setTime(DateTime time) {
    _currentTime = time;
  }

  /// Advance time by duration
  static void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }

  /// Reset to default test time
  static void reset() {
    _currentTime = DateTime(2025, 1, 15, 12, 0, 0);
  }
}

// ============================================================================
// URL MATCHING HELPERS
// ============================================================================

/// Helper to match URLs in HTTP client mocks
class URLMatchers {
  /// Match any URL
  static Uri anyUrl() => any();

  /// Match specific URL
  static Uri urlEquals(String url) => Uri.parse(url);

  /// Match URL containing substring
  static Matcher urlContains(String substring) {
    return predicate<Uri>((uri) => uri.toString().contains(substring),
        'URL contains "$substring"');
  }

  /// Match URL with specific domain
  static Matcher urlDomain(String domain) {
    return predicate<Uri>(
        (uri) => uri.host == domain, 'URL domain is "$domain"');
  }

  /// Match URL with specific path
  static Matcher urlPath(String path) {
    return predicate<Uri>((uri) => uri.path == path, 'URL path is "$path"');
  }
}

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/// Create a ByteStream from string data (for HTTP mocking)
http.ByteStream createByteStream(String data) {
  return http.ByteStream.fromBytes(data.codeUnits);
}

/// Create a successful HTTP GET stub
void stubHttpGet(
  MockHttpClient mockClient,
  String url,
  String responseBody, {
  int statusCode = 200,
}) {
  when(() => mockClient.get(
        Uri.parse(url),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response(responseBody, statusCode));
}

/// Verify HTTP client was called with specific URL
void verifyHttpGet(MockHttpClient mockClient, String url) {
  verify(() => mockClient.get(
        Uri.parse(url),
        headers: any(named: 'headers'),
      )).called(1);
}
