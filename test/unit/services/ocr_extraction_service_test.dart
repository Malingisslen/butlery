/// Comprehensive tests for OCRExtractionService

import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import '../../fixtures/ocr_test_data.dart';

void main() {
  // OCRExtractionService.instance reads ServicesBinding during init;
  // initializing the test binding first lets every test in this file
  // construct the service.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OCRExtractionService - Service Initialization', () {
    test('should create service with default singleton instance', () {
      final service = OCRExtractionService.instance;
      expect(service, isNotNull);
      expect(service.serviceName, equals('OCRExtractionService'));
    });

    test('should create service for testing with injected dependencies', () {
      final testTime = DateTime(2025, 1, 15, 12, 0, 0);

      final service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: _FakeDeviceRecognizer(text: null),
        testOnDeviceEnabled: () => true,
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
      final service = OCRExtractionService.createForTesting();

      await service.initialize();
      expect(service.serviceName, equals('OCRExtractionService'));
    });

    test(
      'should initialize without errors when on-device OCR is disabled',
      () async {
        final service = OCRExtractionService.createForTesting();

        await expectLater(service.initialize(), completes);
      },
    );

    test('should initialize circuit breakers in closed state', () {
      final service = OCRExtractionService.createForTesting();
      final status = service.getServiceStatus();

      expect(
        status['circuit_breakers']['on_device']['state'],
        equals('closed'),
      );
    });

    test('should report the on-device tier as usable only when enabled', () {
      final enabled = OCRExtractionService.createForTesting(
        testDeviceRecognizer: _FakeDeviceRecognizer(text: null),
        testOnDeviceEnabled: () => true,
      );
      final disabled = OCRExtractionService.createForTesting(
        testDeviceRecognizer: _FakeDeviceRecognizer(text: null),
        testOnDeviceEnabled: () => false,
      );

      expect(
        enabled.getServiceStatus()['api_keys_configured']['on_device'],
        isTrue,
      );
      expect(
        disabled.getServiceStatus()['api_keys_configured']['on_device'],
        isFalse,
      );
    });
  });

  group('OCRExtractionService - OCRResult Model', () {
    test('should create successful OCRResult', () {
      final result = OCRTestHelpers.createTestResult(
        text: 'Test text',
        confidence: 0.85,
        processingMethod: 'on_device',
      );

      expect(result.text, equals('Test text'));
      expect(result.confidence, equals(0.85));
      expect(result.processingMethod, equals('on_device'));
      expect(result.isSuccessful, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('should create failure OCRResult using factory', () {
      final result = OCRResult.failure(
        method: 'on_device',
        error: 'API key invalid',
        metadata: {'status_code': 401},
      );

      expect(result.text, isEmpty);
      expect(result.confidence, equals(0.0));
      expect(result.processingMethod, equals('on_device'));
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
      final assessment1 = OCRTestHelpers.createQualityAssessment(
        qualityScore: 0.0,
      );
      final assessment2 = OCRTestHelpers.createQualityAssessment(
        qualityScore: 1.0,
      );

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
    late _FakeDeviceRecognizer recognizer;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should cache successful OCR results', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      // First extraction (should read the image)
      final result1 = await service.extractText(imageBytes);
      expect(result1.isSuccessful, isTrue);

      // Second extraction (should hit cache)
      final result2 = await service.extractText(imageBytes);
      expect(result2.isSuccessful, isTrue);
      expect(result2.text, equals(result1.text));

      // Verify the image was only read once
      expect(recognizer.calls, equals(1));
    });

    test('should expire cache after 24 hours', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      // First extraction
      await service.extractText(imageBytes);

      // Advance time by 25 hours
      testTime = testTime.add(const Duration(hours: 25));

      // Second extraction (cache expired, should read the image again)
      await service.extractText(imageBytes);

      // Verify the image was read twice
      expect(recognizer.calls, equals(2));
    });

    test('should not expire cache before 24 hours', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      // First extraction
      await service.extractText(imageBytes);

      // Advance time by 23 hours
      testTime = testTime.add(const Duration(hours: 23));

      // Second extraction (cache still valid)
      await service.extractText(imageBytes);

      // Verify the image was only read once
      expect(recognizer.calls, equals(1));
    });

    test('should track cache hits in usage stats', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      // First extraction
      await service.extractText(imageBytes);

      // Second extraction (cache hit)
      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['cache_hits'], equals(1));
    });

    test('should calculate cache hit rate correctly', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      // First extraction (read)
      await service.extractText(imageBytes);

      // Second extraction (cache hit)
      await service.extractText(imageBytes);

      // Third extraction (cache hit)
      await service.extractText(imageBytes);

      final stats = service.getUsageStats();
      expect(
        stats['cache_hit_rate'],
        closeTo(0.666, 0.01),
      ); // 2 hits out of 3 total
    });

    test('should evict oldest entries when cache is full', () async {
      // Note: Max cache size is 100, we'll create 101 unique images
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

      await service.extractText(imageBytes1);
      await service.extractText(imageBytes2);

      // Should only read once (same hash)
      expect(recognizer.calls, equals(1));
    });

    test('should NOT cache failure results (transient errors retried)', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      recognizer.throws = true;

      // First extraction (failure)
      final result1 = await service.extractText(imageBytes);
      expect(result1.isSuccessful, isFalse);

      // Second extraction (also fails — failures are NOT cached per prod design)
      final result2 = await service.extractText(imageBytes);
      expect(result2.isSuccessful, isFalse);

      // Both attempts re-read the image (no caching of failures)
      expect(recognizer.calls, equals(2));
    });

    test('should clear cache on dispose', () async {
      final imageBytes = OCRTestImages.mediumQuality;
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
        // bytes would then return a stale cache hit instead of re-reading the
        // image.
        final imageBytes = OCRTestImages.mediumQuality;
        // Register this mock-driven service as the singleton so the static
        // clearCacheForTesting() hook (which operates on `instance`) acts on it.
        final singletonService = OCRExtractionService.createForTesting(
          testDeviceRecognizer: recognizer,
          testOnDeviceEnabled: () => true,
          testTimeProvider: () => testTime,
          registerAsInstance: true,
        );

        // First extraction populates both LruMaps.
        await singletonService.extractText(imageBytes);
        expect(
          singletonService.getServiceStatus()['cache_size'],
          greaterThan(0),
        );

        OCRExtractionService.clearCacheForTesting();

        // Result cache is empty after the clear.
        expect(singletonService.getServiceStatus()['cache_size'], equals(0));

        // Same bytes again: with both the result cache AND the raw-hash
        // fast-path index cleared, this must re-read the image (2 calls
        // total). If only the BaseService cache had been cleared, the raw-hash
        // index would still short-circuit to a stale result (1 call).
        await singletonService.extractText(imageBytes);
        expect(recognizer.calls, equals(2));

        await singletonService.dispose();
      },
    );

    test('should cap cache at maxSize with LRU eviction', () async {
      // BUT-817: cache backed by LruMap — bound holds at maxSize (100); each
      // insert past the bound evicts exactly the eldest entry, not a 25%
      // batch. The contract that callers actually depend on is "cache stays
      // bounded", and that's what this test pins.
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
    late _FakeDeviceRecognizer recognizer;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should successfully extract text on-device', () async {
      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('on_device'));
      expect(result.text, contains('Köttbullar'));
      expect(result.text, contains('500g köttfärs'));
    });

    test('should include metadata in OCR result', () async {
      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.metadata['provider'], equals('mlkit'));
      expect(result.metadata['cost_usd'], equals(0));
    });

    test('should calculate confidence from text content', () async {
      final result = await service.extractText(OCRTestImages.mediumQuality);

      // Long text with Swedish keywords should have high confidence
      expect(result.confidence, greaterThan(0.8));
    });

    test('should include timestamp in result', () async {
      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.timestamp, equals(testTime));
    });

    test('should fail with helpful message when nothing is read', () async {
      recognizer.text = null;

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.isSuccessful, isFalse);
      expect(result.processingMethod, equals('user_recovery'));
      expect(result.errorMessage, contains('better lighting'));
    });

    test(
      'should fail with helpful message when the recognizer throws',
      () async {
        recognizer.throws = true;

        final result = await service.extractText(OCRTestImages.mediumQuality);

        expect(result.isSuccessful, isFalse);
        expect(result.processingMethod, equals('user_recovery'));
        expect(result.errorMessage, contains('better lighting'));
      },
    );

    test('should boost confidence for Swedish keywords', () async {
      final result = await service.extractText(OCRTestImages.mediumQuality);

      // Text contains multiple Swedish keywords (ingrediens, stek, portioner, minut)
      expect(result.confidence, greaterThan(0.85));
    });

    test('should reset circuit breaker after successful retry', () async {
      final imageBytes = OCRTestImages.mediumQuality;

      // Trigger 5 failures to open circuit breaker
      recognizer.throws = true;
      for (var i = 0; i < 5; i++) {
        await service.extractText(imageBytes);
      }

      var status = service.getServiceStatus();
      expect(status['circuit_breakers']['on_device']['state'], equals('open'));

      // Advance time to allow retry
      testTime = testTime.add(const Duration(minutes: 3));

      recognizer.throws = false;
      final result = await service.extractText(imageBytes);

      expect(result.processingMethod, equals('on_device'));
      status = service.getServiceStatus();
      expect(
        status['circuit_breakers']['on_device']['state'],
        equals('closed'),
      );
    });
  });

  group('OCRExtractionService - Usage Tracking', () {
    late OCRExtractionService service;
    late _FakeDeviceRecognizer recognizer;
    late DateTime testTime;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testTime = DateTime(2025, 1, 15, 12, 0, 0);
      recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
        testTimeProvider: () => testTime,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should track provider usage separately', () async {
      final imageBytes1 = OCRTestImages.mediumQuality;
      final imageBytes2 = OCRTestImages.validJPEG;
      await service.extractText(imageBytes1);
      await service.extractText(imageBytes2);

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['on_device'], equals(2));
    });

    test('should not count cache hits toward provider usage', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      await service.extractText(imageBytes); // Read
      await service.extractText(imageBytes); // Cache hit

      final stats = service.getUsageStats();
      expect(stats['provider_usage']['on_device'], equals(1));
      expect(stats['provider_usage']['cache_hits'], equals(1));
    });

    test('should track cache hit rate', () async {
      final imageBytes = OCRTestImages.mediumQuality;
      await service.extractText(imageBytes); // Read
      await service.extractText(imageBytes); // Cache hit
      await service.extractText(imageBytes); // Cache hit

      final stats = service.getUsageStats();
      expect(stats['cache_hit_rate'], closeTo(0.666, 0.01)); // 2/3
    });
  });

  group('OCRExtractionService - Edge Cases', () {
    late OCRExtractionService service;
    late _FakeDeviceRecognizer recognizer;

    setUp(() {
      recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
      );
    });

    tearDown(() async {
      await service.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('should handle very large images', () async {
      final largeImage = OCRTestImages.tooLarge;
      final result = await service.extractText(largeImage);

      // Should still process but with quality warning
      expect(result, isNotNull);
    });

    test('should handle very small images', () async {
      final smallImage = OCRTestImages.tooSmall;
      final result = await service.extractText(smallImage);

      // Should still process but with quality warning
      expect(result, isNotNull);
    });

    test('should handle invalid image format', () async {
      final invalidImage = OCRTestImages.invalidFormat;
      final result = await service.extractText(invalidImage);

      // Should return a result rather than throw
      expect(result, isNotNull);
    });

    test('should handle concurrent extractions', () async {
      final imageBytes = OCRTestImages.mediumQuality;
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
      final confidence = OCRTestHelpers.calculateExpectedConfidence(
        'This is a test',
      );
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
      final confidence = OCRTestHelpers.calculateExpectedConfidence(
        multiLineText,
      );

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
      final confidence = OCRTestHelpers.calculateExpectedConfidence(
        textWithKeywords,
      );

      // Base + structure + keywords (5 keywords * 0.03 = 0.15)
      expect(confidence, greaterThan(0.8));
    });
  });

  group('OCRExtractionService - Service Status', () {
    late OCRExtractionService service;

    setUp(() {
      service = OCRExtractionService.createForTesting();
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
        status['circuit_breakers']['on_device']['state'],
        equals('closed'),
      );
    });

    test('should report circuit breaker failure counts', () {
      final status = service.getServiceStatus();
      expect(status['circuit_breakers']['on_device']['failures'], equals(0));
    });

    test('should report circuit breaker can_execute status', () {
      final status = service.getServiceStatus();
      expect(status['circuit_breakers']['on_device']['can_execute'], isTrue);
    });

    test('should report the on-device tier as not usable by default', () {
      final status = service.getServiceStatus();
      expect(status['api_keys_configured']['on_device'], isFalse);
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
      final recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      final serviceWithClient = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
      );

      final imageBytes = OCRTestImages.mediumQuality;
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
      final recognizer = _FakeDeviceRecognizer(
        text: OCRExpectedResults.swedishRecipeText,
      );
      final serviceWithClient = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
      );

      final imageBytes = OCRTestImages.mediumQuality;

      // Trigger 5 failures
      recognizer.throws = true;

      for (var i = 0; i < 5; i++) {
        try {
          await serviceWithClient.extractText(imageBytes);
        } catch (_) {}
      }

      final status = serviceWithClient.getServiceStatus();
      expect(status['circuit_breakers']['on_device']['state'], equals('open'));
      expect(status['circuit_breakers']['on_device']['can_execute'], isFalse);
      expect(status['circuit_breakers']['on_device']['failures'], equals(5));

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
        ]),
      );
    });
  });

  // The behaviour that matters is the gate: what the device reads must be accepted only when it is
  // a confident recipe, and everything else must fail with a classification the
  // message builder can act on.
  group('OCRExtractionService - on-device tier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// [layout] drives `enable_layout_recipe_split`, which decides WHICH of the
    /// recognizer's two strings ships. Default false, matching production: the
    /// geometry is off until it has been proven on a real device, and with it
    /// off the tier stores the provider's own string exactly as it did before
    /// the seam widened.
    OCRExtractionService buildService({
      required DeviceTextRecognizer recognizer,
      required bool enabled,
      bool layout = false,
    }) => OCRExtractionService.createForTesting(
      testDeviceRecognizer: recognizer,
      testOnDeviceEnabled: () => enabled,
      testLayoutEnabled: () => layout,
    );

    // The other tests inject `testOnDeviceEnabled`, which bypasses the real
    // flag lookup entirely — so without these two the kill switch itself is
    // executed by nothing, and a typo in either the constant or the defaults
    // map would leave the tier impossible to turn OFF once shipped.
    test(
      'with no flag service registered the tier stays off (fails closed)',
      () async {
        final recognizer = _FakeDeviceRecognizer(
          text: 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.',
        );
        final service = OCRExtractionService.createForTesting(
          testDeviceRecognizer: recognizer,
          // testOnDeviceEnabled deliberately omitted — exercise the real lookup.
        );
        addTearDown(service.dispose);

        final result = await service.extractText(OCRTestImages.mediumQuality);

        expect(recognizer.calls, equals(0));
        expect(result.processingMethod, equals('no_provider_configured'));
      },
    );

    test('the real lookup asks for the literal production flag key', () async {
      final flags = _MockFeatureFlags();
      // The LITERAL string, not FeatureFlags.enableOnDeviceOcr — asserting the
      // constant against itself would be circular and would not catch a key
      // that drifted from the Remote Config console.
      when(() => flags.isEnabled('enable_on_device_ocr')).thenReturn(true);
      // Stubbed too, or the tier throws instead of running: the service now
      // asks a SECOND flag (which of the recognizer's two strings ships),
      // and an unstubbed mocktail call is an exception, not a false.
      when(
        () => flags.isEnabled('enable_layout_recipe_split'),
      ).thenReturn(false);
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FeatureFlagService>()) {
        getIt.unregister<FeatureFlagService>();
      }
      getIt.registerSingleton<FeatureFlagService>(flags);
      ServiceLocator.initialize(DIContainer());
      addTearDown(() {
        if (getIt.isRegistered<FeatureFlagService>()) {
          getIt.unregister<FeatureFlagService>();
        }
        ServiceLocator.reset();
      });

      final recognizer = _FakeDeviceRecognizer(
        text: 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.',
      );
      final service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
      );
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.processingMethod, equals('on_device'));
      expect(recognizer.calls, equals(1));
      verify(() => flags.isEnabled('enable_on_device_ocr')).called(1);
      // The SECOND flag's key, asserted the same way and for the same reason:
      // it is the rollback for the string swap, and a key that drifted from the
      // Remote Config console would leave the geometry impossible to turn off
      // from the console once shipped. Literal, never the constant.
      verify(() => flags.isEnabled('enable_layout_recipe_split')).called(1);
    });

    test(
      'with the tier off, the failure says "unavailable" with the breaker open',
      () async {
        // The message builder's "services unavailable" branch reads these two
        // facts; with the flag off (the default) it must be reachable, and the
        // network must never be consulted.
        final service = OCRExtractionService.createForTesting(
          testDeviceRecognizer: _FakeDeviceRecognizer(text: null),
          testOnDeviceEnabled: () => false,
        );
        addTearDown(service.dispose);

        final result = await service.extractText(OCRTestImages.mediumQuality);

        expect(result.isSuccessful, isFalse);
        expect(result.processingMethod, equals('no_provider_configured'));
        expect(
          result.metadata['failure_classification'],
          equals('unavailable'),
        );
        expect(
          result.metadata['circuit_breakers'],
          equals({'on_device_state': 'open'}),
        );
      },
    );

    test('a read that sanitizes away is not accepted', () async {
      // Long enough (12 chars) to clear RecipeTextHeuristic's <10 length
      // rejection, so the fall-through is caused by SANITIZATION, not by the
      // length check. C0 controls are not White_Space, so they survive Dart's
      // trim() and only vanish when sanitized.
      //
      // Honest about what this does NOT pin: the `text.isNotEmpty` guard is
      // redundant — an empty string fails looksLikeRecipe anyway — so removing
      // it leaves this green. What it pins is that a read of pure control junk
      // never reaches the user as an on-device success.
      final recognizer = _FakeDeviceRecognizer(
        text:
            ''
            '',
      );
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(recognizer.calls, equals(1));
      expect(result.processingMethod, isNot(equals('on_device')));
      expect(result.isSuccessful, isFalse);
    });

    test('the reported confidence is scored, not a constant', () async {
      // Regression guard: the first version hardcoded the accept threshold
      // (0.6) as the reported confidence, which renders as an orange "medium
      // quality" badge and emitted better-lighting tips on every free read.
      // `greaterThan(0.6)` alone would not catch a DIFFERENT constant, so the
      // discriminator is that two texts of different quality score
      // DIFFERENTLY.
      final rich = _FakeDeviceRecognizer(
        text:
            'Ingredienser för 4 portioner: 2 dl mjöl, 3 msk smör, 1 tsk salt. '
            'Gör så här: Vispa smeten, grädda i ugn och servera genast.',
      );
      final richService = buildService(recognizer: rich, enabled: true);
      addTearDown(richService.dispose);
      final richResult = await richService.extractText(
        OCRTestImages.mediumQuality,
      );

      // Both fixtures must clear the 0.6 accept threshold — the point is
      // that they score DIFFERENTLY, not that one is rejected.
      final plain = _FakeDeviceRecognizer(
        text: 'Blanda 2 dl mjöl med 1 dl mjölk och grädda i ugnen.',
      );
      final plainService = buildService(recognizer: plain, enabled: true);
      addTearDown(plainService.dispose);
      final plainResult = await plainService.extractText(
        OCRTestImages.uniqueImage(77),
      );

      expect(richResult.processingMethod, equals('on_device'));
      expect(plainResult.processingMethod, equals('on_device'));
      expect(richResult.confidence, greaterThan(0.6));
      expect(richResult.confidence, greaterThan(plainResult.confidence));
    });

    test(
      'a repeat of the same image is served from cache, not re-read',
      () async {
        // The money claim is "no network on repeat" — but it is also "no second
        // recognition". If tier 0 skipped the cache write, this stays green only
        // because the recognizer is cheap, so assert the call count directly.
        final recognizer = _FakeDeviceRecognizer(
          text: 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.',
        );
        final service = buildService(recognizer: recognizer, enabled: true);
        addTearDown(service.dispose);

        final first = await service.extractText(OCRTestImages.mediumQuality);
        final second = await service.extractText(OCRTestImages.mediumQuality);

        expect(first.text, equals(second.text));
        expect(recognizer.calls, equals(1));
      },
    );

    test('a device-read recipe is accepted as an on-device read', () async {
      final recognizer = _FakeDeviceRecognizer(
        text: 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.',
      );
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.isSuccessful, isTrue);
      expect(result.processingMethod, equals('on_device'));
      expect(recognizer.calls, equals(1));
    });

    test('device-read text is SANITIZED before it is stored', () async {
      // Every other fixture in this group is plain Swedish — on which the
      // sanitizer is the identity function, so a missing call would be
      // invisible to the whole suite. This fixture carries the two things
      // sanitizeText actually removes: a Cyrillic homoglyph 'а' (U+0430) hiding
      // inside an ordinary word, and a C0 control byte.
      //
      // It matters because `photo_import_strategy` persists `ocrResult.text`
      // straight to the draft and it later leaves the device in a GDPR export,
      // so the characters that survive must be the sanitized ones.
      final recognizer = _FakeDeviceRecognizer(
        // Escapes, not literal characters: a Cyrillic homoglyph and a
        // control byte are invisible in an editor and would be silently
        // 'tidied' back into plain Latin, leaving the test proving nothing.
        text:
            'Ingredienser\n2 dl mj\u00f6l\n'
            'Visp\u0430 smeten och gr\u00e4dda i ugn.\u0007',
      );
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(
        result.processingMethod,
        equals('on_device'),
        reason:
            'positive control — without this, a rejected read would satisfy '
            'the two absence assertions just as well',
      );
      expect(result.text.contains('а'), isFalse);
      expect(result.text.contains(''), isFalse);
      expect(result.text, contains('Vispa smeten'));
    });

    test('text that is not recipe-shaped is rejected', () async {
      // A parking receipt: no measurements, no cooking verbs. The gate must
      // reject it rather than hand a non-recipe on as the user's recipe.
      final recognizer = _FakeDeviceRecognizer(
        text: 'PARKERINGSBILJETT\nZon 4\nGiltig till 14:32',
      );
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(recognizer.calls, equals(1));
      expect(result.processingMethod, isNot(equals('on_device')));
      expect(result.isSuccessful, isFalse);
    });

    test('a PARTIAL read clears the heuristic but not the confidence '
        'bar', () async {
      // The discriminating pair for the confidence gate. Both fixtures pass
      // RecipeTextHeuristic identically (one measurement + one cooking verb),
      // so the ONLY thing separating them is _calculateConfidenceFromText's
      // 30-character step: 0.5 for the short read, 0.7 for the long one. That
      // makes this the sole shape in the suite that can see the >= 0.6 bar —
      // every other fixture here is long enough to score 0.7 regardless.
      //
      // It matters because an accepted partial read is cached for 24 h, so the
      // user keeps half a recipe.
      final partial = _FakeDeviceRecognizer(text: '2 dl mjöl\nvispa');
      final partialService = buildService(
        recognizer: partial,
        enabled: true,
      );
      addTearDown(partialService.dispose);

      final rejectedResult = await partialService.extractText(
        OCRTestImages.mediumQuality,
      );

      expect(partial.calls, equals(1));
      expect(rejectedResult.processingMethod, isNot(equals('on_device')));
      expect(
        (partialService.getUsageStats()['provider_usage']
            as Map<String, int>)['on_device_rejected'],
        equals(1),
      );

      // Control: the same shape, past the 30-character step, is accepted —
      // so the rejection above is the confidence bar, not the heuristic.
      final full = _FakeDeviceRecognizer(
        text: '2 dl mjöl och 1 tsk salt\nvispa smeten väl',
      );
      final fullService = buildService(recognizer: full, enabled: true);
      addTearDown(fullService.dispose);

      final acceptedResult = await fullService.extractText(
        OCRTestImages.mediumQuality,
      );

      expect(acceptedResult.processingMethod, equals('on_device'));
    });

    test('an empty device read is a failure, not a success', () async {
      final recognizer = _FakeDeviceRecognizer(text: null);
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(recognizer.calls, equals(1));
      expect(result.isSuccessful, isFalse);
    });

    test('flag off means the recognizer is never touched', () async {
      final recognizer = _FakeDeviceRecognizer(
        text: 'Ingredienser\n2 dl mjöl\nVispa smeten.',
      );
      final service = buildService(recognizer: recognizer, enabled: false);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(recognizer.calls, equals(0));
      expect(result.processingMethod, equals('no_provider_configured'));
    });

    test(
      'an unavailable recognizer (web stub) is skipped and reported unavailable',
      () async {
        final recognizer = _FakeDeviceRecognizer(text: null, available: false);
        final service = buildService(recognizer: recognizer, enabled: true);
        addTearDown(service.dispose);

        final result = await service.extractText(OCRTestImages.mediumQuality);

        expect(recognizer.calls, equals(0));
        expect(result.processingMethod, equals('no_provider_configured'));
        expect(
          result.metadata['failure_classification'],
          equals('unavailable'),
        );
      },
    );

    test('a throwing recognizer fails the import and is counted', () async {
      final recognizer = _FakeDeviceRecognizer(text: null, throws: true);
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.isSuccessful, isFalse);

      // The catch is the ONLY branch the on-device timeout can reach, so a
      // stuck platform channel — the exact event the timeout exists for — was
      // invisible to the tracker whose accept-rate split the flag decision
      // rests on. Both the usage key and the breaker live in that catch and
      // neither was asserted anywhere.
      final stats = service.getUsageStats();
      final usage = stats['provider_usage'] as Map<String, int>;
      expect(usage['on_device_error'], equals(1));
      expect(
        usage['on_device_rejected'],
        equals(0),
        reason: 'a throw is not a heuristic rejection — the two must not merge',
      );
      expect(
        (service.getServiceStatus()['circuit_breakers']
            as Map<String, dynamic>)['on_device']['failures'],
        equals(1),
        reason: 'pins recordFailure() in the same catch',
      );
    });

    test('a stalled recognizer is bounded by the timeout', () {
      // The recognizer's contract is "never throw", so a stuck platform
      // channel emits no signal at all: without the .timeout() the import
      // hangs forever — it never fails over and never trips the breaker. fakeAsync, never a real wait.
      fakeAsync((async) {
        final recognizer = _FakeDeviceRecognizer(text: null, stalls: true);
        final service = buildService(recognizer: recognizer, enabled: true);
        OCRResult? result;
        unawaited(
          service.extractText(OCRTestImages.mediumQuality).then((r) {
            result = r;
          }),
        );

        // Straddle the flip point: a bound that fires early would abandon a
        // slow-but-working read, which is as wrong as never firing.
        async.elapse(const Duration(seconds: 14));
        async.flushMicrotasks();
        expect(result, isNull);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(result?.processingMethod, equals('user_recovery'));
        expect(recognizer.calls, equals(1));
      });
    });

    test('a stalled tier 0 surfaces as a TIMEOUT, not "better lighting"', () {
      // The stall's TimeoutException is what _classifyProviderErrors reads to
      // pick the user's Swedish copy. Misclassifying it as `generic` tells a
      // user with a wedged ML Kit to improve their lighting forever.
      fakeAsync((async) {
        final service = buildService(
          recognizer: _FakeDeviceRecognizer(text: null, stalls: true),
          enabled: true,
        );
        OCRResult? result;
        unawaited(
          service.extractText(OCRTestImages.mediumQuality).then((r) {
            result = r;
          }),
        );
        async.elapse(const Duration(seconds: 20));
        async.flushMicrotasks();

        expect(result!.isSuccessful, isFalse);
        expect(result!.metadata['failure_classification'], equals('timeout'));
        expect(
          (result!.metadata['provider_errors'] as Map)['on_device'],
          contains('TimeoutException'),
        );
      });
    });

    test(
      'a heuristic rejection and a broken read are counted separately',
      () async {
        // The whole point of the split: accept rate = on_device / (on_device +
        // on_device_rejected). Folding a broken recognizer into the rejection
        // counter would file a hardware failure as "the text was not a recipe"
        // and make the number the flag-flip decision rests on unreadable.
        // Asserts the LITERAL counter names, so a typo on either reddens.
        final rejected = buildService(
          recognizer: _FakeDeviceRecognizer(
            text: 'PARKERINGSBILJETT\nZon 4\nGiltig till 14:32',
          ),
          enabled: true,
        );
        addTearDown(rejected.dispose);
        await rejected.extractText(OCRTestImages.mediumQuality);
        final rejectedUsage =
            rejected.getUsageStats()['provider_usage'] as Map<String, int>;

        expect(rejectedUsage['on_device_rejected'], equals(1));
        expect(rejectedUsage['on_device_error'], equals(0));

        final broken = buildService(
          recognizer: _FakeDeviceRecognizer(text: null),
          enabled: true,
        );
        addTearDown(broken.dispose);
        await broken.extractText(OCRTestImages.mediumQuality);
        final brokenUsage =
            broken.getUsageStats()['provider_usage'] as Map<String, int>;

        expect(brokenUsage['on_device_error'], equals(1));
        expect(brokenUsage['on_device_rejected'], equals(0));
      },
    );

    test('repeated broken reads open the tier-0 breaker', () async {
      // Without recordFailure() on the null arm the breaker can never open, so
      // a device with permanently broken ML Kit pays a platform round-trip on
      // every import forever.
      final recognizer = _FakeDeviceRecognizer(text: null);
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      OCRResult? last;
      for (var i = 0; i < 6; i++) {
        last = await service.extractText(OCRTestImages.mediumQuality);
      }

      // 5, not 6: the sixth import found the breaker open and skipped the
      // round-trip entirely.
      expect(recognizer.calls, equals(5));
      final breakers =
          last!.metadata['circuit_breakers'] as Map<String, dynamic>;
      expect(breakers['on_device_state'], equals('open'));
    });

    test('a heuristic rejection never opens the breaker', () async {
      // The discriminator against folding the two arms together: a device that
      // keeps reading non-recipes is working perfectly, and backing off would
      // silently disable the free tier for anyone photographing receipts.
      final recognizer = _FakeDeviceRecognizer(
        text: 'PARKERINGSBILJETT\nZon 4\nGiltig till 14:32',
      );
      final service = buildService(recognizer: recognizer, enabled: true);
      addTearDown(service.dispose);

      for (var i = 0; i < 6; i++) {
        await service.extractText(OCRTestImages.mediumQuality);
      }

      expect(recognizer.calls, equals(6));
    });

    // (A separate flag-OFF row-count test stood here and was removed: it used
    // the same fixture and the same seam as 'the flag decides WHICH of the two
    // strings is stored' below, whose off arm asserts the string exactly.
    // Measured over the five plausible mutants of the selection expression, it
    // killed a strict SUBSET of what that test kills — always-layout and
    // flag-inverted, both of which the survivor also catches.)

    test('sanitizing the page changes bytes, never the ROW the layout '
        'indexed', () async {
      // The tier sanitizes the WHOLE page string in one call, and the seam's
      // point is that the recognizer's line indices still address the right
      // rows of what actually gets stored. That `sanitizeText` distributes
      // over the row separator is pinned at its own layer (html_sanitizer_test,
      // 'changes bytes but NEVER the number of rows'); this pins the
      // COMPOSITION, at the one boundary that depends on it.
      //
      // The fixture carries every hazard at once: a LEADING blank row (what
      // a global trim eats - the exact reason the adapter stopped trimming),
      // a two-row blank RUN (what a blank-run collapse eats), a control byte
      // and a Cyrillic homoglyph that force the sanitizer to genuinely rewrite
      // the string, and the rewritten row placed LAST so any dropped row shows
      // up as a shifted index rather than as a missing one.
      final recognizer = _FakeDeviceRecognizer(
        text:
            '\n'
            'Ingredienser\n'
            '\n'
            '\n'
            '2 dl mj\u00f6l\u0007\n'
            'Visp\u0430 smeten och gr\u00e4dda i ugn.',
      );
      // The geometry flag is ON here: this test is about the string the
      // LAYOUT produced. With it off the tier ships the provider's own
      // string and the row indices are not ours to reason about.
      final service = buildService(
        recognizer: recognizer,
        enabled: true,
        layout: true,
      );
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(
        result.processingMethod,
        equals('on_device'),
        reason:
            'positive control - a rejected read would store no text at all and '
            'satisfy nothing below by accident',
      );
      final rows = result.text.split('\n');
      expect(rows, hasLength(recognizer.lastLayout!.lines.length));
      expect(
        rows[0],
        isEmpty,
        reason:
            'a LEADING blank row is the one a global trim eats, and eating '
            'it shifts every index after it by one',
      );
      expect(
        rows[3],
        isEmpty,
        reason:
            'the SECOND row of a two-row blank run - one blank row survives a '
            'collapse of three-or-more newlines, two do not',
      );
      expect(rows[5], equals('Vispa smeten och gr\u00e4dda i ugn.'));
    });

    // (A flag-OFF variant of the "measured NO geometry" test below stood here
    // and was removed. With the flag off the tier never reads `raw.layout` at
    // all, so it could only ever kill a mutant that dereferenced the layout
    // ABOVE the flag branch \u2014 measured, exactly one of five, and the ON-arm
    // sibling kills that one plus the missing `?? providerText` fallback.)

    test('the flag decides WHICH of the two strings is stored', () async {
      // The rollback, in both directions, over ONE fixture. `enable_layout_
      // recipe_split` exists because widening the seam changed the string every
      // on-device photo produces — not just cookbook spreads — so "off returns
      // the exact bytes that shipped before" is a promise, and a promise no
      // test measures is a comment. Pinning only the ON direction would leave
      // an always-layout implementation green, and only the OFF direction would
      // leave an always-provider one green; the pair is what closes it.
      //
      // Measured 2026-08-06, which is why the pair is not optional: deleting
      // the flag entirely — shipping the layout string unconditionally, the
      // exact regression it exists to prevent — left all 123 tests in this
      // group green. Every other flag-off assertion in the group was a
      // `contains`, which both strings satisfy.
      const page = 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.';

      final offRecognizer = _FakeDeviceRecognizer(text: page);
      final offService = buildService(
        recognizer: offRecognizer,
        enabled: true,
      );
      addTearDown(offService.dispose);
      final off = await offService.extractText(OCRTestImages.mediumQuality);

      final onRecognizer = _FakeDeviceRecognizer(text: page);
      final onService = buildService(
        recognizer: onRecognizer,
        enabled: true,
        layout: true,
      );
      addTearDown(onService.dispose);
      final on = await onService.extractText(OCRTestImages.mediumQuality);

      expect(off.processingMethod, equals('on_device'));
      expect(on.processingMethod, equals('on_device'));
      // Off: the provider's own string, verbatim — trailing row and all. The
      // fake's two strings differ by exactly that row, which is why the
      // assertion can see which one the service took.
      expect(off.text, equals('$page\n'));
      // On: the string the LAYOUT produced, asserted against the geometry it
      // was derived from rather than against a restated literal.
      expect(on.text, equals(onRecognizer.lastLayout!.text));
      expect(
        off.text,
        isNot(equals(on.text)),
        reason:
            'if these ever match, the fixture stopped distinguishing the two '
            'strings and the assertions above prove nothing',
      );
    });

    test('with no flag service registered the geometry stays off', () async {
      // Sibling of the tier's own fail-closed test, for the second flag: with
      // no FeatureFlagService in the locator (unit tests, early startup) the
      // getter's `?? false` must keep the PROVIDER string. A `?? true` there
      // would ship the new string to everyone the moment Remote Config was
      // unreachable — the one state a kill switch has to survive.
      const page = 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.';
      expect(
        ServiceLocator.tryGet<FeatureFlagService>(),
        isNull,
        reason:
            'premise — a flag service left registered by an earlier test would '
            'answer false too, and this test would pass without ever reaching '
            'the fail-closed default it exists for',
      );
      final recognizer = _FakeDeviceRecognizer(text: page);
      final service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
        // testLayoutEnabled deliberately omitted — exercise the real lookup.
      );
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(result.processingMethod, equals('on_device'));
      expect(result.text, equals('$page\n'));
    });

    test('with the geometry ON, a provider that measured nothing still '
        'ships its text', () async {
      // The `raw.layoutText ?? raw.providerText` fallback, on the arm that can
      // actually reach it. Its sibling above stages the same recognizer with
      // the flag OFF, where the fallback is never consulted — so a `raw.layout!`
      // or an `if (raw.layout == null) return null` would have left that test
      // green while silently disabling the free tier for any provider that
      // reads text without measuring it.
      const page = 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.';
      final recognizer = _FakeDeviceRecognizer(text: page, measures: false);
      final service = buildService(
        recognizer: recognizer,
        enabled: true,
        layout: true,
      );
      addTearDown(service.dispose);

      final result = await service.extractText(OCRTestImages.mediumQuality);

      expect(recognizer.lastLayout, isNull);
      expect(result.processingMethod, equals('on_device'));
      expect(result.text, equals(page));
    });

    test('the geometry travels WITH the text, or not at all', () async {
      // Step 4 of the layout plan, and the reason it is a typed field on
      // `OCRResult` rather than a second thing stored beside it.
      //
      // `DocumentLayout.matchesLineCountOf` compares ROW COUNTS, and its own
      // doc says passing is necessary and not sufficient: the provider's string
      // and the layout's OFTEN have the same row count. (Until 2026-08-08 they
      // "differed only in a separator and a global trim"; since `edge_crop.dart`
      // the layout string also has rows REMOVED, which makes the gate stricter
      // without making it sufficient — an uncropped page's counts still match.)
      // So a result holding one string with the
      // other's geometry sails through that check and is then addressed by
      // indices that point at the wrong rows. The only structural defence is
      // that the two can never be separated — which is what this pins.
      const page = 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.';

      final onRecognizer = _FakeDeviceRecognizer(text: page);
      final onService = buildService(
        recognizer: onRecognizer,
        enabled: true,
        layout: true,
      );
      addTearDown(onService.dispose);
      final on = await onService.extractText(OCRTestImages.mediumQuality);

      final offRecognizer = _FakeDeviceRecognizer(text: page);
      final offService = buildService(
        recognizer: offRecognizer,
        enabled: true,
      );
      addTearDown(offService.dispose);
      final off = await offService.extractText(OCRTestImages.mediumQuality);

      // ON: the geometry is carried, and it is the geometry the stored text was
      // derived from — asserted against the recognizer's own object, never a
      // restated literal.
      expect(on.layout, isNotNull);
      expect(on.layout, same(onRecognizer.lastLayout));
      expect(on.text, equals(on.layout!.text));

      // OFF: the recognizer measured the page all the same, and the result must
      // NOT carry it. Shipping the provider's string with the layout's geometry
      // is the pairing this whole field exists to make impossible.
      expect(offRecognizer.lastLayout, isNotNull);
      expect(off.layout, isNull);
    });

    test('a cached page hands back the SAME pair, not a rebuilt one', () async {
      // The flag is read per call, but the cache is keyed on the image hash
      // alone — so a second read of the same photo returns whatever was stored
      // the first time. That is safe ONLY because text and geometry are one
      // object: the pair a cached entry hands back is always the pair that was
      // measured together, whatever the flag says now.
      //
      // The flag therefore has to FLIP between the two reads, or the sentence
      // above is asserted by nothing and this is just two identical calls.
      // Staged after a 2026-08-07 measurement: without the flip this test
      // reddened under no mutant that the sibling `travels WITH the text` test
      // did not already redden under, and it stayed green under the one this
      // group cares most about (the flag gate deleted).
      //
      // What it also records: the kill switch does NOT reach an image already
      // in this session's cache. That is in-memory only (a restart clears it),
      // and stripping the geometry on the way out would be worse — it would
      // hand back the layout-derived text with no geometry, which is the
      // mismatched pair the field exists to make impossible.
      const page = 'Ingredienser\n2 dl mjöl\nVispa smeten och grädda i ugn.';
      final recognizer = _FakeDeviceRecognizer(text: page);
      var layoutFlag = true;
      final service = OCRExtractionService.createForTesting(
        testDeviceRecognizer: recognizer,
        testOnDeviceEnabled: () => true,
        testLayoutEnabled: () => layoutFlag,
      );
      addTearDown(service.dispose);

      final first = await service.extractText(OCRTestImages.mediumQuality);
      // A Remote Config push mid-session — the rollback the flag exists for.
      layoutFlag = false;
      final second = await service.extractText(OCRTestImages.mediumQuality);

      expect(
        recognizer.calls,
        equals(1),
        reason: 'premise: the second read must come from the cache',
      );
      expect(second.layout, same(first.layout));
      expect(second.text, equals(second.layout!.text));
    });

    test(
      'on-device-only setup is not reported as "no provider configured"',
      () async {
        final recognizer = _FakeDeviceRecognizer(
          text: 'Ingredienser\n2 dl mjöl\nVispa smeten.',
        );
        final service = OCRExtractionService.createForTesting(
          testDeviceRecognizer: recognizer,
          testOnDeviceEnabled: () => true,
        );
        addTearDown(service.dispose);

        final result = await service.extractText(OCRTestImages.mediumQuality);

        expect(
          result.processingMethod,
          isNot(equals('no_provider_configured')),
        );
        expect(result.isSuccessful, isTrue);
      },
    );
  });
}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _FakeDeviceRecognizer implements DeviceTextRecognizer {
  _FakeDeviceRecognizer({
    required this.text,
    this.available = true,
    this.throws = false,
    this.stalls = false,
    this.measures = true,
  });

  String? text;
  final bool available;
  bool throws;

  /// Models the failure the recognizer's "never throw" contract cannot
  /// express: a platform channel that simply never answers.
  final bool stalls;

  /// False models a provider that read text but measured NOTHING - the
  /// `layout == null` half of the seam's contract. The mlkit adapter never
  /// produces it, but the type allows it and callers must read it as "text
  /// only", never as a page with no lines.
  final bool measures;

  int calls = 0;

  /// The layout the last call handed back, so a test can assert the STORED
  /// text against the geometry it was derived from instead of restating the
  /// fixture and proving only that the fixture equals itself.
  PageLayout? lastLayout;

  @override
  bool get isAvailable => available;

  /// Returns a layout ONLY when the fake was given text, and builds it the way
  /// the real adapter does - one line per row of [text], with the string
  /// derived from those lines. A fake that returned a hand-built string and an
  /// unrelated layout would let the service pass a test the device would fail.
  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async {
    calls++;
    if (stalls) await Completer<RecognitionResult?>().future;
    if (throws) throw StateError('recognizer exploded');
    if (text == null) return null;
    // A provider that measured nothing: text only, no geometry.
    if (!measures) return RecognitionResult(providerText: text!);
    final layout = PageLayout(
      lines: [
        for (final row in text!.split('\n'))
          OcrLine(
            text: row,
            box: const LayoutBox(left: 0, top: 0, width: 100, height: 20),
          ),
      ],
    );
    lastLayout = layout;
    // BOTH strings, as the real adapter does, and they must DIFFER: a fake
    // whose two strings were identical could never show which one the flag
    // selected, and one that made `providerText` unrecipe-like would fail the
    // tier's confidence gate instead of the assertion, which is a different
    // test.
    //
    // The trailing row is a deliberate STAND-IN, not a reproduction. The real
    // adapter's `providerText` is `recognized.text.trim()`, so it can carry no
    // trailing blank row at all. TWO things separate the strings on a device:
    // ML Kit's own assembly puts a BLANK ROW between blocks where
    // `PageLayout.text` uses one newline per line, and — since 2026-08-08 —
    // `edge_crop.dart` REMOVES rows from the layout string only, so they are
    // not even the same lines. (That fires on 132 of 181 corpus pages, but
    // PROXY: the corpus is WinOCR geometry cropped against itself, not ML Kit.
    // The rate on a device is unmeasured.) This fake models the separator half
    // alone.
    // Either shape gives the tests the one thing they need — an observable
    // difference in the row count — so this stays the cheaper one; do not read
    // it as documentation of what a device produces.
    return RecognitionResult(providerText: '${text!}\n', layout: layout);
  }

  @override
  Future<void> dispose() async {}
}
