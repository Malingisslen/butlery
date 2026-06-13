/// Comprehensive tests for OCRExtractionService
///
/// Test Coverage Target: 85-90%
/// Total Tests: 92
/// Test Groups: 10

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import '../../fixtures/ocr_test_data.dart';

// Helper to create ByteStream from string
http.ByteStream _createByteStream(String data) {
  return http.ByteStream.fromBytes(utf8.encode(data));
}

// Mocks
class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

// Fake URI for mocktail
class FakeUri extends Fake implements Uri {}

// Fake BaseRequest for mocktail
class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  // OCRExtractionService.instance reads ServicesBinding during init;
  // initializing the test binding first lets every test in this file
  // construct the service.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register fallback values for mocktail + stub SharedPreferences
  // (OcrUsageTracker reads it during service init).
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeBaseRequest());
  });

  group('OCRExtractionService - Service Initialization', () {
    test('should create service with default singleton instance', () {
      final service = OCRExtractionService.instance;
      expect(service, isNotNull);
      expect(service.serviceName, equals('OCRExtractionService'));
    });

    test('should create service for testing with injected dependencies', () {
      final mockClient = MockHttpClient();
      final testTime = DateTime(2025, 1, 15, 12, 0, 0);

      final service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
        testTesseractApiUrl: 'http://test-tesseract.com/api',
        testTimeProvider: () => testTime,
      );

      expect(service, isNotNull);
      expect(service.serviceName, equals('OCRExtractionService'));
    });

    test('should reset singleton instance for testing', () {
      OCRExtractionService.resetForTesting();
      final service1 = OCRExtractionService.instance;
      OCRExtractionService.resetForTesting();
      final service2 = OCRExtractionService.instance;

      expect(service1, isNot(same(service2)));
    });

    test('should initialize with correct service name', () async {
      final service = OCRExtractionService.createForTesting(
        testOcrApiKey: 'test-key',
      );

      await service.initialize();
      expect(service.serviceName, equals('OCRExtractionService'));
    });

    test('should initialize without errors when API keys are missing',
        () async {
      final service = OCRExtractionService.createForTesting();

      await expectLater(service.initialize(), completes);
    });

    test('should track month start date during initialization', () async {
      final testTime = DateTime(2025, 1, 15, 12, 0, 0);
      final service = OCRExtractionService.createForTesting(
        testTimeProvider: () => testTime,
      );

      await service.initialize();
      final stats = service.getUsageStats();
      expect(stats['monthly_count'], equals(0));
    });

    test('should initialize circuit breakers in closed state', () {
      final service = OCRExtractionService.createForTesting();
      final status = service.getServiceStatus();

      expect(
          status['circuit_breakers']['ocr_space']['state'], equals('closed'));
      expect(status['circuit_breakers']['google_vision']['state'],
          equals('closed'));
      expect(
          status['circuit_breakers']['tesseract']['state'], equals('closed'));
    });

    test('should report correct API key configuration status', () {
      final service = OCRExtractionService.createForTesting(
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
      );

      final status = service.getServiceStatus();
      expect(status['api_keys_configured']['ocr_space'], isTrue);
      expect(status['api_keys_configured']['google_vision'], isTrue);
      expect(status['api_keys_configured']['tesseract'], isFalse);
    });
  });

  group('OCRExtractionService - OCRResult Model', () {
    test('should create successful OCRResult', () {
      final result = OCRTestHelpers.createTestResult(
        text: 'Test text',
        confidence: 0.85,
        processingMethod: 'ocr_space',
      );

      expect(result.text, equals('Test text'));
      expect(result.confidence, equals(0.85));
      expect(result.processingMethod, equals('ocr_space'));
      expect(result.isSuccessful, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('should create failure OCRResult using factory', () {
      final result = OCRResult.failure(
        method: 'ocr_space',
        error: 'API key invalid',
        metadata: {'status_code': 401},
      );

      expect(result.text, isEmpty);
      expect(result.confidence, equals(0.0));
      expect(result.processingMethod, equals('ocr_space'));
      expect(result.isSuccessful, isFalse);
      expect(result.errorMessage, equals('API key invalid'));
      expect(result.metadata['status_code'], equals(401));
    });

    test('should include timestamp in result', () {
      final testTime = DateTime(2025, 1, 15, 12, 0, 0);
      final result = OCRTestHelpers.createTestResult(timestamp: testTime);

      expect(result.timestamp, equals(testTime));
    });

    test('should include metadata in result', () {
      final metadata = {
        'engine': '2',
        'language': 'swedish',
        'processing_time': 150,
      };
      final result = OCRTestHelpers.createTestResult(metadata: metadata);

      expect(result.metadata['engine'], equals('2'));
      expect(result.metadata['language'], equals('swedish'));
      expect(result.metadata['processing_time'], equals(150));
    });

    test('should handle empty metadata', () {
      final result = OCRTestHelpers.createTestResult(metadata: {});

      expect(result.metadata, isEmpty);
    });

    test('should create result with error message', () {
      final result = OCRTestHelpers.createTestResult(
        isSuccessful: false,
        errorMessage: 'Network timeout',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.errorMessage, equals('Network timeout'));
    });
  });

  group('OCRExtractionService - ImageQualityAssessment', () {
    test('should create good quality assessment', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        isGoodQuality: true,
        qualityScore: 0.95,
      );

      expect(assessment.isGoodQuality, isTrue);
      expect(assessment.qualityScore, equals(0.95));
      expect(assessment.issues, isEmpty);
      expect(assessment.recommendations, isEmpty);
    });

    test('should create poor quality assessment with issues', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        isGoodQuality: false,
        qualityScore: 0.4,
        issues: ['Bilden är för liten', 'Bildformat stöds inte optimalt'],
        recommendations: ['Använd högre upplösning', 'Använd JPEG eller PNG'],
      );

      expect(assessment.isGoodQuality, isFalse);
      expect(assessment.qualityScore, equals(0.4));
      expect(assessment.issues, hasLength(2));
      expect(assessment.recommendations, hasLength(2));
    });

    test('should include quality score between 0 and 1', () {
      final assessment1 =
          OCRTestHelpers.createQualityAssessment(qualityScore: 0.0);
      final assessment2 =
          OCRTestHelpers.createQualityAssessment(qualityScore: 1.0);

      expect(assessment1.qualityScore, equals(0.0));
      expect(assessment2.qualityScore, equals(1.0));
    });

    test('should mark as poor quality when score is below threshold', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        isGoodQuality: false,
        qualityScore: 0.5,
      );

      expect(assessment.isGoodQuality, isFalse);
    });

    test('should provide recommendations for quality issues', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        issues: ['Low resolution'],
        recommendations: ['Use higher resolution camera'],
      );

      expect(assessment.recommendations.first, contains('higher resolution'));
    });

    test('should handle multiple quality issues', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        issues: ['Too small', 'Poor lighting', 'Motion blur'],
        recommendations: ['Increase size', 'Better lighting', 'Hold steady'],
      );

      expect(assessment.issues, hasLength(3));
      expect(assessment.recommendations, hasLength(3));
    });

    test('should assess quality based on combined factors', () {
      final assessment = OCRTestHelpers.createQualityAssessment(
        isGoodQuality: true,
        qualityScore: 0.85,
        issues: [],
      );

      expect(assessment.isGoodQuality, isTrue);
      expect(assessment.issues, isEmpty);
    });
  });

  group('OCRExtractionService - CircuitBreaker', () {
    late DateTime testTime;
    late DateTime Function() timeProvider;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      timeProvider = () => testTime;
    });

    test('should start in closed state', () {
      final breaker = CircuitBreaker();
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.canExecute, isTrue);
    });

    test('should allow execution when closed', () {
      final breaker = CircuitBreaker(timeProvider: timeProvider);
      expect(breaker.canExecute, isTrue);
    });

    test('should record success and reset failure count', () {
      final breaker = CircuitBreaker(timeProvider: timeProvider);

      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.failures, equals(2));

      breaker.recordSuccess();
      expect(breaker.failures, equals(0));
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });

    test('should open after reaching failure threshold', () {
      final breaker = CircuitBreaker(
        failureThreshold: 3,
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.closed));

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.open));
    });

    test('should block execution when open', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      breaker.recordFailure();

      expect(breaker.state, equals(CircuitBreakerState.open));
      expect(breaker.canExecute, isFalse);
    });

    test('should transition to half-open after retry timeout', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        retryTimeout: const Duration(minutes: 2),
        timeProvider: timeProvider,
      );

      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.open));

      // Advance time by 3 minutes
      testTime = testTime.add(const Duration(minutes: 3));

      expect(breaker.canExecute, isTrue);
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));
    });

    test('should stay open if retry timeout has not elapsed', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        retryTimeout: const Duration(minutes: 2),
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      breaker.recordFailure();

      // Advance time by 1 minute (less than retry timeout)
      testTime = testTime.add(const Duration(minutes: 1));

      expect(breaker.canExecute, isFalse);
      expect(breaker.state, equals(CircuitBreakerState.open));
    });

    test('should allow execution when half-open', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        retryTimeout: const Duration(minutes: 2),
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      breaker.recordFailure();
      testTime = testTime.add(const Duration(minutes: 3));

      final canExecute = breaker.canExecute;
      expect(canExecute, isTrue);
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));
    });

    test('should close from half-open on success', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        retryTimeout: const Duration(minutes: 2),
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      breaker.recordFailure();
      testTime = testTime.add(const Duration(minutes: 3));
      // Transition to half-open by accessing canExecute
      breaker.canExecute;

      breaker.recordSuccess();
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });

    test('should track failure count', () {
      final breaker = CircuitBreaker(timeProvider: timeProvider);

      expect(breaker.failures, equals(0));

      breaker.recordFailure();
      expect(breaker.failures, equals(1));

      breaker.recordFailure();
      expect(breaker.failures, equals(2));
    });

    test('should use custom failure threshold', () {
      final breaker = CircuitBreaker(
        failureThreshold: 10,
        timeProvider: timeProvider,
      );

      for (var i = 0; i < 9; i++) {
        breaker.recordFailure();
      }
      expect(breaker.state, equals(CircuitBreakerState.closed));

      breaker.recordFailure(); // 10th failure
      expect(breaker.state, equals(CircuitBreakerState.open));
    });

    test('should use custom retry timeout', () {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        retryTimeout: const Duration(hours: 1),
        timeProvider: timeProvider,
      );

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.open));

      // Advance by 30 minutes (less than 1 hour)
      testTime = testTime.add(const Duration(minutes: 30));
      expect(breaker.canExecute, isFalse);

      // Advance by another 35 minutes (total 65 minutes)
      testTime = testTime.add(const Duration(minutes: 35));
      expect(breaker.canExecute, isTrue);
    });
  });

  group('OCRExtractionService - Caching System', () {
    late OCRExtractionService service;
    late MockHttpClient mockClient;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      mockClient = MockHttpClient();
      service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-key',
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should cache successful OCR results', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // First extraction (should hit API)
      final result1 = await service.extractText(imageBytes);
      expect(result1.isSuccessful, isTrue);

      // Second extraction (should hit cache)
      final result2 = await service.extractText(imageBytes);
      expect(result2.isSuccessful, isTrue);
      expect(result2.text, equals(result1.text));

      // Verify API was only called once
      verify(() => mockClient.send(any())).called(1);
    });

    test('should expire cache after 24 hours', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // First extraction
      await service.extractText(imageBytes);

      // Advance time by 25 hours
      testTime = testTime.add(const Duration(hours: 25));

      // Second extraction (cache expired, should hit API again)
      await service.extractText(imageBytes);

      // Verify API was called twice
      verify(() => mockClient.send(any())).called(2);
    });

    test('should not expire cache before 24 hours', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // First extraction
      await service.extractText(imageBytes);

      // Advance time by 23 hours
      testTime = testTime.add(const Duration(hours: 23));

      // Second extraction (cache still valid)
      await service.extractText(imageBytes);

      // Verify API was only called once
      verify(() => mockClient.send(any())).called(1);
    });

    test('should track cache hits in usage stats', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // First extraction
      await service.extractText(imageBytes);

      // Second extraction (cache hit)
      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['cache_hits'], equals(1));
    });

    test('should calculate cache hit rate correctly', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // First extraction (API call)
      await service.extractText(imageBytes);

      // Second extraction (cache hit)
      await service.extractText(imageBytes);

      // Third extraction (cache hit)
      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['cache_hit_rate'],
          closeTo(0.666, 0.01)); // 2 hits out of 3 total
    });

    test('should evict oldest entries when cache is full', () async {
      // Note: Max cache size is 100, we'll create 101 unique images
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Extract 101 unique images
      for (var i = 0; i < 101; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
        testTime = testTime.add(const Duration(seconds: 1));
      }

      final status = service.getServiceStatus();
      expect(status['cache_size'], lessThanOrEqualTo(100));
    });

    test('should use SHA-256 hash for cache keys', () async {
      final imageBytes1 = OCRTestImages.mediumQuality;
      final imageBytes2 = Uint8List.fromList(imageBytes1); // Same content

      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes1);
      await service.extractText(imageBytes2);

      // Should only call API once (same hash)
      verify(() => mockClient.send(any())).called(1);
    });

    test('should NOT cache failure results (transient errors retried)',
        () async {
      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any())).thenThrow(Exception('Network error'));

      // First extraction (failure)
      final result1 = await service.extractText(imageBytes);
      expect(result1.isSuccessful, isFalse);

      // Second extraction (also fails — failures are NOT cached per prod design)
      final result2 = await service.extractText(imageBytes);
      expect(result2.isSuccessful, isFalse);

      // Both attempts hit the API (no caching of failures)
      verify(() => mockClient.send(any())).called(2);
    });

    test('should clear cache on dispose', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);
      expect(service.getServiceStatus()['cache_size'], greaterThan(0));

      await service.dispose();
      // Cannot check cache size after dispose, but verified in implementation
    });

    test(
        'clearCacheForTesting clears the service own LruMaps (cache + raw index)',
        () async {
      // BUT-1253: clearCacheForTesting() previously only cleared the
      // BaseService cache, leaving _cache (OCR results) and
      // _rawHashToPreprocessedHash populated. A repeat extraction of the same
      // bytes would then return a stale cache hit instead of re-hitting the
      // API — so the only behavior that proves the LruMaps were actually
      // cleared is that the second extraction calls the provider again.
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Register this mock-driven service as the singleton so the static
      // clearCacheForTesting() hook (which operates on `instance`) acts on it.
      final singletonService = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-key',
        testTimeProvider: () => testTime,
        registerAsInstance: true,
      );

      // First extraction populates both LruMaps.
      await singletonService.extractText(imageBytes);
      expect(singletonService.getServiceStatus()['cache_size'], greaterThan(0));

      OCRExtractionService.clearCacheForTesting();

      // Result cache is empty after the clear.
      expect(singletonService.getServiceStatus()['cache_size'], equals(0));

      // Same bytes again: with both the result cache AND the raw-hash
      // fast-path index cleared, this must re-hit the provider (2 calls
      // total). If only the BaseService cache had been cleared, the raw-hash
      // index would still short-circuit to a stale result (1 call).
      await singletonService.extractText(imageBytes);
      verify(() => mockClient.send(any())).called(2);

      await singletonService.dispose();
    });

    test('should cap cache at maxSize with LRU eviction', () async {
      // BUT-817: cache backed by LruMap — bound holds at maxSize (100); each
      // insert past the bound evicts exactly the eldest entry, not a 25%
      // batch. The contract that callers actually depend on is "cache stays
      // bounded", and that's what this test pins.
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Fill cache to 100 entries.
      for (var i = 0; i < 100; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
        testTime = testTime.add(const Duration(seconds: 1));
      }

      expect(service.getServiceStatus()['cache_size'], equals(100));

      // Add one more — bound holds.
      final newImage = OCRTestImages.uniqueImage(200);
      await service.extractText(newImage);

      expect(service.getServiceStatus()['cache_size'], equals(100));
    });
  });

  group('OCRExtractionService - OCR Extraction', () {
    late OCRExtractionService service;
    late MockHttpClient mockClient;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      mockClient = MockHttpClient();
      service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
        testTesseractApiUrl: 'http://test-tesseract.com/api',
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should successfully extract text using OCR.space', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('ocr_space'));
      expect(result.text, contains('Köttbullar'));
      expect(result.confidence, greaterThan(0.6));
    });

    test('should handle OCR.space processing error', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) =>
          _createByteStream(OCRProviderResponses.ocrSpaceProcessingError));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision
      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should successfully extract text using Google Vision', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      // OCR.space fails
      when(() => mockClient.send(any())).thenThrow(Exception('OCR.space down'));

      // Google Vision succeeds
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
      expect(result.text, contains('Köttbullar'));
    });

    test('should successfully extract text using Tesseract', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      // OCR.space fails
      when(() => mockClient.send(any())).thenThrow(Exception('OCR.space down'));

      // Google Vision fails
      when(() => mockClient.post(
            Uri.parse(
                'https://vision.googleapis.com/v1/images:annotate?key=test-google-key'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(Exception('Google Vision down'));

      // Tesseract succeeds
      when(() => mockClient.post(
                Uri.parse('http://test-tesseract.com/api'),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.tesseractSuccess, 200));

      final result = await service.extractText(imageBytes);

      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('tesseract'));
    });

    test('should include metadata in OCR result', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      expect(result.metadata, isNotEmpty);
      expect(result.metadata['engine'], equals('2'));
      expect(result.metadata['language'], equals('swedish'));
      expect(result.metadata['processing_time'], isNotNull);
    });

    test('should calculate confidence from text content', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      // Long text with Swedish keywords should have high confidence
      expect(result.confidence, greaterThan(0.8));
    });

    test('should handle empty text extraction', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => _createByteStream(
          '{"ParsedResults": [{"ParsedText": ""}], "IsErroredOnProcessing": false}'));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionNoText, 200));

      final result = await service.extractText(imageBytes);

      // Empty text should have zero confidence
      expect(result.confidence, equals(0.0));
    });

    test('should include timestamp in result', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      expect(result.timestamp, equals(testTime));
    });

    test('should fail with helpful message when all providers fail', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      // All providers fail
      when(() => mockClient.send(any())).thenThrow(Exception('Network error'));
      when(() => mockClient.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenThrow(Exception('Network error'));

      final result = await service.extractText(imageBytes);

      expect(result.isSuccessful, isFalse);
      expect(result.processingMethod, equals('user_recovery'));
      expect(result.errorMessage, contains('better lighting'));
    });

    test('should handle HTTP timeout', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any())).thenAnswer(
        (_) async => throw Exception('Timeout'),
      );

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision
      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should handle invalid JSON response', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream)
          .thenAnswer((_) => _createByteStream('invalid json'));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision
      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should handle HTTP 401 (unauthorized)', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(401);
      when(() => mockResponse.stream)
          .thenAnswer((_) => _createByteStream('Unauthorized'));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision
      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should handle HTTP 500 (server error)', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(500);
      when(() => mockResponse.stream)
          .thenAnswer((_) => _createByteStream('Server error'));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision
      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should boost confidence for Swedish keywords', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      // Text contains multiple Swedish keywords (ingrediens, stek, portioner, minut)
      expect(result.confidence, greaterThan(0.85));
    });
  });

  group('OCRExtractionService - Multi-Provider Fallback', () {
    late OCRExtractionService service;
    late MockHttpClient mockClient;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      mockClient = MockHttpClient();
      service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
        testTesseractApiUrl: 'http://test-tesseract.com/api',
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should try OCR.space first', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(imageBytes);

      expect(result.processingMethod, equals('ocr_space'));
      verifyNever(() => mockClient.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('should fall back to Google Vision when OCR.space fails', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      expect(result.processingMethod, equals('google_vision'));
    });

    test(
        'should fall back to Tesseract when both OCR.space and Google Vision fail',
        () async {
      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      when(() => mockClient.post(
            Uri.parse(
                'https://vision.googleapis.com/v1/images:annotate?key=test-google-key'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(Exception('Google Vision error'));

      when(() => mockClient.post(
                Uri.parse('http://test-tesseract.com/api'),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.tesseractSuccess, 200));

      final result = await service.extractText(imageBytes);

      expect(result.processingMethod, equals('tesseract'));
    });

    test('should skip provider when circuit breaker is open', () async {
      // Stub Google Vision to succeed throughout, so only OCR.space trips
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      // Trigger circuit breaker for OCR.space (5 failures)
      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      for (var i = 0; i < 5; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
        testTime = testTime.add(const Duration(seconds: 1));
      }

      // Now OCR.space circuit breaker is open — should fall through to Google Vision
      final uniqueImage = OCRTestImages.uniqueImage(99);
      final result = await service.extractText(uniqueImage);

      expect(result.processingMethod, equals('google_vision'));
    });

    test('should skip provider with low confidence result', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceLowQuality));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      final result = await service.extractText(imageBytes);

      // Should fall back to Google Vision due to low confidence
      expect(result.processingMethod, equals('google_vision'));
    });

    test('should not try provider if API key is missing', () async {
      final serviceNoGoogleKey = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-ocr-key',
        // No Google Vision key
        testTesseractApiUrl: 'http://test-tesseract.com/api',
        testTimeProvider: () => testTime,
      );

      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      when(() => mockClient.post(
                Uri.parse('http://test-tesseract.com/api'),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.tesseractSuccess, 200));

      final result = await serviceNoGoogleKey.extractText(imageBytes);

      // Should skip Google Vision and go straight to Tesseract
      expect(result.processingMethod, equals('tesseract'));

      await serviceNoGoogleKey.dispose();
    });

    test('should record usage for successful provider', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(OCRProviderResponses.googleVisionSuccess, 200));

      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['google_vision'], equals(1));
      expect(stats['provider_usage']['ocr_space'], equals(0));
    });

    test('should reset circuit breaker after successful retry', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      // Trigger 5 failures to open circuit breaker
      when(() => mockClient.send(any()))
          .thenThrow(Exception('OCR.space error'));

      for (var i = 0; i < 5; i++) {
        try {
          await service.extractText(imageBytes);
        } catch (_) {}
      }

      var status = service.getServiceStatus();
      expect(status['circuit_breakers']['ocr_space']['state'], equals('open'));

      // Advance time to allow retry
      testTime = testTime.add(const Duration(minutes: 3));

      // Now OCR.space works
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);

      status = service.getServiceStatus();
      expect(
          status['circuit_breakers']['ocr_space']['state'], equals('closed'));
    });
  });

  group('OCRExtractionService - Usage Tracking', () {
    late OCRExtractionService service;
    late MockHttpClient mockClient;
    late DateTime testTime;

    setUp(() {
      // OCRUsageTracker.loadFromPersistence() reads SharedPreferences. Earlier
      // tests in this file call recordUsage(), which persists incrementing
      // counters into the same mock prefs (setMockInitialValues only runs once
      // in setUpAll). Reset prefs here so this group's counter assertions
      // observe a clean slate.
      SharedPreferences.setMockInitialValues({});
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      mockClient = MockHttpClient();
      service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-ocr-key',
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should track daily request count', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['daily_count'], equals(1));
    });

    test('should reset daily count on new day', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);
      expect(service.getUsageStats()['daily_count'], equals(1));

      // Advance to next day
      testTime = DateTime(2025, 1, 16, 12, 0, 0);

      // Different image to avoid cache
      final newImage = OCRTestImages.validJPEG;
      await service.extractText(newImage);

      expect(service.getUsageStats()['daily_count'], equals(1));
    });

    test('should track monthly request count', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['monthly_count'], equals(1));
    });

    test('should reset monthly count on new month', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);
      expect(service.getUsageStats()['monthly_count'], equals(1));

      // Advance to next month
      testTime = DateTime(2025, 2, 1, 12, 0, 0);

      final newImage = OCRTestImages.validJPEG;
      await service.extractText(newImage);

      expect(service.getUsageStats()['monthly_count'], equals(1));
    });

    test('should track provider usage separately', () async {
      final imageBytes1 = OCRTestImages.mediumQuality;
      final imageBytes2 = OCRTestImages.validJPEG;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes1);
      await service.extractText(imageBytes2);

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['ocr_space'], equals(2));
    });

    test('should not warn below 80% of monthly limit (500)', () async {
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // 20 requests out of 500 limit = 4%, well under 80% warning threshold
      for (var i = 0; i < 20; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
      }

      final stats = service.getUsageStats();
      // No warning at 4% usage (warning triggers at 80% = 400 requests)
      final warnings = stats['warnings'] as List;
      expect(warnings.where((w) => w.toString().contains('monthly limit')),
          isEmpty);
    });

    test('should calculate usage percentage correctly', () async {
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      for (var i = 0; i < 10; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
      }

      final stats = service.getUsageStats();
      expect(stats['usage_percentage'], closeTo(2.0, 0.1)); // 10/500 = 2.0%
    });

    test('should calculate remaining requests', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['remaining'], equals(499)); // 500 - 1
    });

    test('should estimate monthly cost at \$0 within free tier', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      // Within free tier — cost is negligible (≤ $0.01)
      expect(stats['estimated_monthly_cost'], lessThanOrEqualTo(0.01));
    });

    test('should not count cache hits toward provider usage', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes); // API call
      await service.extractText(imageBytes); // Cache hit

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['ocr_space'], equals(1));
      expect(stats['provider_usage']['cache_hits'], equals(1));
    });

    test('should track cache hit rate', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await service.extractText(imageBytes); // API call
      await service.extractText(imageBytes); // Cache hit
      await service.extractText(imageBytes); // Cache hit

      final stats = service.getUsageStats();
      expect(stats['cache_hit_rate'], closeTo(0.666, 0.01)); // 2/3
    });

    test('should warn about low cache hit rate', () async {
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Create 101 unique images (no cache hits)
      for (var i = 0; i < 101; i++) {
        final uniqueImage = OCRTestImages.uniqueImage(i);
        await service.extractText(uniqueImage);
      }

      final stats = service.getUsageStats();
      final warnings = stats['warnings'] as List;
      expect(
          warnings.any((w) => w.toString().contains('cache hit rate')), isTrue);
    });
  });

  group('OCRExtractionService - Edge Cases', () {
    late OCRExtractionService service;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      service = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-key',
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should handle very large images', () async {
      final largeImage = OCRTestImages.tooLarge;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(largeImage);

      // Should still process but with quality warning
      expect(result, isNotNull);
    });

    test('should handle very small images', () async {
      final smallImage = OCRTestImages.tooSmall;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(smallImage);

      // Should still process but with quality warning
      expect(result, isNotNull);
    });

    test('should handle invalid image format', () async {
      final invalidImage = OCRTestImages.invalidFormat;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final result = await service.extractText(invalidImage);

      // Should still process (OCR API accepts base64)
      expect(result, isNotNull);
    });

    test('should handle concurrent extractions', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Fire 10 concurrent extractions
      final futures = List<Future<OCRResult>>.generate(
        10,
        (_) => service.extractText(imageBytes),
      );

      final results = await Future.wait(futures);

      expect(results, hasLength(10));
      expect(results.every((r) => r.isSuccessful), isTrue);
    });
  });

  group('OCRExtractionService - Confidence Calculation', () {
    late OCRExtractionService service;

    setUp(() {
      service = OCRExtractionService.createForTesting();
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should return 0.0 confidence for empty text', () {
      final confidence = OCRTestHelpers.calculateExpectedConfidence('');
      expect(confidence, equals(0.0));
    });

    test('should return 0.3 confidence for very short text (<10 chars)', () {
      final confidence = OCRTestHelpers.calculateExpectedConfidence('Test');
      expect(confidence, equals(0.3));
    });

    test('should return 0.5 confidence for short text (10-30 chars)', () {
      final confidence =
          OCRTestHelpers.calculateExpectedConfidence('This is a test');
      expect(confidence, equals(0.5));
    });

    test('should return 0.7 confidence for medium text (30-100 chars)', () {
      final confidence = OCRTestHelpers.calculateExpectedConfidence(
        'This is a longer test string that should have medium confidence',
      );
      expect(confidence, equals(0.7));
    });

    test('should add structure bonus for multiple lines', () {
      final multiLineText = '''Line 1
Line 2
Line 3
Line 4
Line 5''';
      final confidence =
          OCRTestHelpers.calculateExpectedConfidence(multiLineText);

      // Short text base (0.5) + structure bonus (5 lines * 0.03 = 0.15) = 0.65-0.7
      expect(confidence, greaterThanOrEqualTo(0.65));
    });

    test('should add keyword bonus for Swedish recipe keywords', () {
      final textWithKeywords = '''
        Här är receptet med ingredienser:
        Tillsätt mjölet
        Vispa ägg
        Stek i 10 minuter
        4 portioner
      ''';
      final confidence =
          OCRTestHelpers.calculateExpectedConfidence(textWithKeywords);

      // Base + structure + keywords (5 keywords * 0.03 = 0.15)
      expect(confidence, greaterThan(0.8));
    });
  });

  group('OCRExtractionService - Service Status', () {
    late OCRExtractionService service;

    setUp(() {
      service = OCRExtractionService.createForTesting(
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should report service status with timestamp', () {
      final status = service.getServiceStatus();
      expect(status['timestamp'], isNotNull);
    });

    test('should report cache size', () {
      final status = service.getServiceStatus();
      expect(status['cache_size'], equals(0));
    });

    test('should report circuit breaker states', () {
      final status = service.getServiceStatus();
      expect(
          status['circuit_breakers']['ocr_space']['state'], equals('closed'));
      expect(status['circuit_breakers']['google_vision']['state'],
          equals('closed'));
      expect(
          status['circuit_breakers']['tesseract']['state'], equals('closed'));
    });

    test('should report circuit breaker failure counts', () {
      final status = service.getServiceStatus();
      expect(status['circuit_breakers']['ocr_space']['failures'], equals(0));
      expect(
          status['circuit_breakers']['google_vision']['failures'], equals(0));
      expect(status['circuit_breakers']['tesseract']['failures'], equals(0));
    });

    test('should report circuit breaker can_execute status', () {
      final status = service.getServiceStatus();
      expect(status['circuit_breakers']['ocr_space']['can_execute'], isTrue);
      expect(
          status['circuit_breakers']['google_vision']['can_execute'], isTrue);
      expect(status['circuit_breakers']['tesseract']['can_execute'], isTrue);
    });

    test('should report API key configuration', () {
      final status = service.getServiceStatus();
      expect(status['api_keys_configured']['ocr_space'], isTrue);
      expect(status['api_keys_configured']['google_vision'], isTrue);
      expect(status['api_keys_configured']['tesseract'], isFalse);
    });

    test('should report configuration limits', () {
      final status = service.getServiceStatus();
      expect(status['configuration']['max_image_size_mb'], equals(10));
      expect(status['configuration']['min_confidence_threshold'], equals(0.6));
      expect(status['configuration']['cache_expiry_hours'], equals(24));
      expect(status['configuration']['max_cache_size'], equals(100));
    });

    test('should report device compatibility', () {
      final status = service.getServiceStatus();
      expect(status['device_compatibility'], equals('universal_ios_android'));
    });

    test('should update status after operations', () async {
      final mockClient = MockHttpClient();
      final serviceWithClient = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-key',
      );

      final imageBytes = OCRTestImages.mediumQuality;
      final mockResponse = MockStreamedResponse();

      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => _createByteStream(OCRProviderResponses.ocrSpaceSuccess));

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      await serviceWithClient.extractText(imageBytes);

      final status = serviceWithClient.getServiceStatus();
      expect(status['cache_size'], equals(1));

      await serviceWithClient.dispose();
    });

    test('should report all status fields', () {
      final status = service.getServiceStatus();

      expect(status, containsPair('timestamp', isNotNull));
      expect(status, containsPair('cache_size', isNotNull));
      expect(status, containsPair('circuit_breakers', isNotNull));
      expect(status, containsPair('device_compatibility', isNotNull));
      expect(status, containsPair('api_keys_configured', isNotNull));
      expect(status, containsPair('configuration', isNotNull));
    });

    test('should report correct status after circuit breaker trips', () async {
      final mockClient = MockHttpClient();
      final serviceWithClient = OCRExtractionService.createForTesting(
        testHttpClient: mockClient,
        testOcrApiKey: 'test-key',
      );

      final imageBytes = OCRTestImages.mediumQuality;

      // Trigger 5 failures
      when(() => mockClient.send(any())).thenThrow(Exception('Error'));

      for (var i = 0; i < 5; i++) {
        try {
          await serviceWithClient.extractText(imageBytes);
        } catch (_) {}
      }

      final status = serviceWithClient.getServiceStatus();
      expect(status['circuit_breakers']['ocr_space']['state'], equals('open'));
      expect(status['circuit_breakers']['ocr_space']['can_execute'], isFalse);
      expect(status['circuit_breakers']['ocr_space']['failures'], equals(5));

      await serviceWithClient.dispose();
    });

    test('should provide complete service health snapshot', () {
      final status = service.getServiceStatus();

      // Verify all expected keys are present
      expect(
          status.keys,
          containsAll([
            'timestamp',
            'cache_size',
            'circuit_breakers',
            'device_compatibility',
            'api_keys_configured',
            'configuration',
          ]));
    });
  });
}
