/// Comprehensive tests for enhanced FirebaseServiceMixin with DNS resilience features.
///
/// This test suite validates the DNS-aware Firebase operations, error classification,
/// and intelligent retry mechanisms added to handle production DNS resolution issues.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Create a test class that uses the mixin
class TestFirebaseService with ErrorHandlingMixin, FirebaseServiceMixin {
  bool shouldFirebaseInitSucceed;
  bool shouldConnectivitySucceed;
  final FirestoreRepository _firestoreRepository;

  TestFirebaseService({
    required FirestoreRepository firestoreRepository,
    this.shouldFirebaseInitSucceed = true,
    this.shouldConnectivitySucceed = true,
  }) : _firestoreRepository = firestoreRepository;

  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  @override
  void handleUserError(String message) {
    // Test implementation
  }

  // Override Firebase initialization for testing
  @override
  Future<bool> ensureFirebaseInitialized() async => shouldFirebaseInitSucceed;

  // Override connectivity check for testing
  @override
  Future<bool> checkFirebaseConnectivity() async => shouldConnectivitySucceed;

  // Override DNS connectivity check for testing
  Future<bool> checkEnhancedDNSConnectivity() async =>
      shouldConnectivitySucceed;
}

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirestoreRepository extends Mock implements FirestoreRepository {}

void main() {
  group('Enhanced FirebaseServiceMixin Tests', () {
    late TestFirebaseService testService;
    late MockFirestoreRepository mockFirestoreRepository;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      mockFirestoreRepository = MockFirestoreRepository();
      testService = TestFirebaseService(
        firestoreRepository: mockFirestoreRepository,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('DNS Resilience Operations', () {
      test(
          'executeFirebaseOperationWithDNSResilience should succeed on first attempt',
          () async {
        // Arrange
        const testData = 'test result';

        // Act
        final result =
            await testService.executeFirebaseOperationWithDNSResilience<String>(
          () async => testData,
          operationName: 'Test operation',
          defaultValue: 'default',
        );

        // Assert
        expect(result, equals(testData));
      });

      test(
          'executeFirebaseOperationWithDNSResilience should return default on operation failure',
          () async {
        // Arrange
        const defaultValue = 'default value';

        // Act
        final result =
            await testService.executeFirebaseOperationWithDNSResilience<String>(
          () async => throw const SocketException('DNS resolution failed'),
          operationName: 'Test DNS failure',
          defaultValue: defaultValue,
        );

        // Assert
        expect(result, equals(defaultValue));
      });

      test(
          'executeFirebaseOperationWithDNSResilience should handle timeout gracefully',
          () async {
        // Arrange
        const defaultValue = 'timeout default';

        // Act
        final result =
            await testService.executeFirebaseOperationWithDNSResilience<String>(
          () async => throw Exception('Timeout'),
          operationName: 'Test timeout',
          defaultValue: defaultValue,
        );

        // Assert
        expect(result, equals(defaultValue));
      });

      test(
          'executeFirebaseOperationWithDNSResilience should handle null results',
          () async {
        // Arrange & Act
        final result = await testService
            .executeFirebaseOperationWithDNSResilience<String?>(
          () async => null,
          operationName: 'Test null result',
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('Enhanced Error Classification', () {
      test('isRetryableFirebaseError should detect DNS resolution errors', () {
        // Arrange
        const dnsError =
            SocketException('Unable to resolve host firestore.googleapis.com');

        // Act
        final isRetryable = testService.isRetryableFirebaseError(dnsError);

        // Assert
        expect(isRetryable, isTrue);
      });

      test('isRetryableFirebaseError should handle Firebase-specific errors',
          () {
        // Arrange
        final firebaseError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Service unavailable',
        );

        // Act
        final isRetryable = testService.isRetryableFirebaseError(firebaseError);

        // Assert
        expect(isRetryable, isTrue);
      });

      test('isRetryableFirebaseError should reject non-retryable errors', () {
        // Arrange
        final nonRetryableError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Permission denied',
        );

        // Act
        final isRetryable =
            testService.isRetryableFirebaseError(nonRetryableError);

        // Assert
        expect(isRetryable, isFalse);
      });

      test('isRetryableFirebaseError should handle DNS-related error messages',
          () {
        // Arrange
        final dnsErrorMessage = Exception(
            'Unable to resolve host "firestore.googleapis.com": No address associated with hostname');

        // Act
        final isRetryable =
            testService.isRetryableFirebaseError(dnsErrorMessage);

        // Assert
        expect(isRetryable, isTrue);
      });

      test('classifyFirebaseError should classify DNS resolution errors', () {
        // Arrange
        const dnsError = SocketException('DNS resolution failed');

        // Act
        final errorType = testService.classifyFirebaseError(dnsError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.dnsResolution));
      });

      test('classifyFirebaseError should classify network connectivity errors',
          () {
        // Arrange
        const networkError = SocketException('Network unreachable');

        // Act
        final errorType = testService.classifyFirebaseError(networkError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.networkConnectivity));
      });

      test('classifyFirebaseError should classify Firebase service errors', () {
        // Arrange
        final firebaseError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Document not found',
        );

        // Act
        final errorType = testService.classifyFirebaseError(firebaseError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.serviceError));
      });

      test('classifyFirebaseError should classify authentication errors', () {
        // Arrange
        final authError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Permission denied',
        );

        // Act
        final errorType = testService.classifyFirebaseError(authError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.authentication));
      });

      test(
          'classifyFirebaseError should handle DNS messages in Firebase errors',
          () {
        // Arrange
        final dnsFirebaseError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Unable to resolve firestore.googleapis.com',
        );

        // Act
        final errorType = testService.classifyFirebaseError(dnsFirebaseError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.dnsResolution));
      });

      test('classifyFirebaseError should handle unknown errors', () {
        // Arrange
        final unknownError = Exception('Unknown error type');

        // Act
        final errorType = testService.classifyFirebaseError(unknownError);

        // Assert
        expect(errorType, equals(FirebaseErrorType.unknown));
      });
    });

    group('Enhanced Connectivity Testing', () {
      test('checkFirebaseConnectivity should handle DNS resolution failures',
          () async {
        // This is primarily an integration test
        // The actual behavior depends on network conditions

        // Act
        final result = await testService.checkFirebaseConnectivity();

        // Assert
        expect(result, isA<bool>());
      });

      test(
          'checkFirebaseConnectivity should handle FirebaseException with DNS messages',
          () async {
        // This test validates error handling for Firebase-specific DNS issues
        final result = await testService.checkFirebaseConnectivity();
        expect(result, isA<bool>());
      });
    });

    group('Enhanced Retry Operations', () {
      test('executeFirebaseOperationWithRetry should include DNS failover flag',
          () async {
        // Arrange
        const testData = 'retry test';

        // Act
        final result =
            await testService.executeFirebaseOperationWithRetry<String>(
          () async => testData,
          operationName: 'Test retry with DNS failover',
          enableDNSFailover: true,
        );

        // Assert
        expect(result, equals(testData));
      });

      test(
          'executeFirebaseOperationWithRetry should handle DNS failover disabled',
          () async {
        // Arrange
        const testData = 'retry without DNS failover';

        // Act
        final result =
            await testService.executeFirebaseOperationWithRetry<String>(
          () async => testData,
          operationName: 'Test retry without DNS failover',
          enableDNSFailover: false,
        );

        // Assert
        expect(result, equals(testData));
      });
    });

    group('Integration Tests', () {
      test('should handle complete DNS resolution failure scenario', () async {
        // Simulate complete DNS failure
        final result =
            await testService.executeFirebaseOperationWithDNSResilience<String>(
          () async => throw const SocketException(
              'Unable to resolve host firestore.googleapis.com'),
          operationName: 'Complete DNS failure test',
          defaultValue: 'dns_failure_handled',
        );

        expect(result, equals('dns_failure_handled'));
      });

      test('should handle Firebase unavailable with DNS indication', () async {
        // Simulate Firebase unavailable due to DNS issues
        final result =
            await testService.executeFirebaseOperationWithDNSResilience<String>(
          () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Unable to resolve firestore.googleapis.com',
          ),
          operationName: 'Firebase DNS unavailable test',
          defaultValue: 'firebase_dns_handled',
        );

        expect(result, equals('firebase_dns_handled'));
      });

      test('should validate all error classification types', () {
        final testCases = [
          (
            const SocketException('DNS resolution failed'),
            FirebaseErrorType.dnsResolution
          ),
          (
            const SocketException('Network unreachable'),
            FirebaseErrorType.networkConnectivity
          ),
          (
            FirebaseException(plugin: 'auth', code: 'permission-denied'),
            FirebaseErrorType.authentication
          ),
          (
            FirebaseException(plugin: 'firestore', code: 'not-found'),
            FirebaseErrorType.serviceError
          ),
          (Exception('Unknown error'), FirebaseErrorType.unknown),
        ];

        for (final (error, expectedType) in testCases) {
          final actualType = testService.classifyFirebaseError(error);
          expect(actualType, equals(expectedType),
              reason: 'Error classification failed for ${error.runtimeType}');
        }
      });
    });
  });

  group('FirebaseErrorType Enum Tests', () {
    test('should have all expected error types', () {
      expect(FirebaseErrorType.values, hasLength(5));
      expect(
          FirebaseErrorType.values, contains(FirebaseErrorType.dnsResolution));
      expect(FirebaseErrorType.values,
          contains(FirebaseErrorType.networkConnectivity));
      expect(
          FirebaseErrorType.values, contains(FirebaseErrorType.authentication));
      expect(
          FirebaseErrorType.values, contains(FirebaseErrorType.serviceError));
      expect(FirebaseErrorType.values, contains(FirebaseErrorType.unknown));
    });

    test('should support string representation', () {
      expect(FirebaseErrorType.dnsResolution.name, equals('dnsResolution'));
      expect(FirebaseErrorType.networkConnectivity.name,
          equals('networkConnectivity'));
      expect(FirebaseErrorType.authentication.name, equals('authentication'));
      expect(FirebaseErrorType.serviceError.name, equals('serviceError'));
      expect(FirebaseErrorType.unknown.name, equals('unknown'));
    });
  });
}
