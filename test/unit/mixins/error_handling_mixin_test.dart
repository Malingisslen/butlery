/// Comprehensive tests for ErrorHandlingMixin with enhanced DNS-aware error classification.
///
/// This test suite validates the enhanced error handling capabilities including DNS resolution
/// error detection, network connectivity classification, and intelligent error categorization
/// for production network resilience scenarios.

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Create a test class that uses the mixin
class TestErrorHandlingService with ErrorHandlingMixin {
  String? lastUserError;
  String? lastUserInfo;

  @override
  void handleUserError(String message) {
    lastUserError = message;
  }

  @override
  void handleUserInfo(String message) {
    lastUserInfo = message;
  }
}

void main() {
  group('Enhanced ErrorHandlingMixin Tests', () {
    late TestErrorHandlingService testService;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      testService = TestErrorHandlingService();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Enhanced Error Classification', () {
      test('classifyError should detect DNS resolution errors', () {
        final testCases = [
          SocketException('Unable to resolve host firestore.googleapis.com'),
          Exception('DNS resolution failed'),
          Exception(
            'Unable to resolve host "example.com": No address associated with hostname',
          ),
          Exception('Name resolution failed'),
          Exception('resolve failed'),
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.dnsResolution),
            reason: 'Should classify DNS error: $error',
          );
        }
      });

      test('classifyError should detect network connectivity errors', () {
        final testCases = [
          SocketException('Network unreachable'),
          Exception('Connection timeout'),
          Exception('Network is unreachable'),
          Exception('Connection failed'),
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.networkConnectivity),
            reason: 'Should classify network error: $error',
          );
        }
      });

      test('classifyError should detect authentication errors', () {
        final testCases = [
          Exception('Permission denied'),
          Exception('Unauthorized access'),
          Exception('Authentication failed'),
          Exception('Forbidden request'),
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.authentication),
            reason: 'Should classify auth error: $error',
          );
        }
      });

      test('classifyError should detect not found errors', () {
        final testCases = [
          Exception('Not found'),
          Exception('404 - Resource not found'),
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.notFound),
            reason: 'Should classify not found error: $error',
          );
        }
      });

      test('classifyError should detect service unavailable errors', () {
        final testCases = [
          Exception('Service unavailable'),
          Exception('503 Service Unavailable'),
          Exception('502 Bad Gateway'),
          Exception('Internal server error'),
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.serviceUnavailable),
            reason: 'Should classify service error: $error',
          );
        }
      });

      test('classifyError should handle unknown errors', () {
        final testCases = [
          Exception('Random unknown error'),
          'String error',
          42,
        ];

        for (final error in testCases) {
          final result = testService.classifyError(error);
          expect(
            result,
            equals(ErrorType.unknown),
            reason: 'Should classify unknown error: $error',
          );
        }
      });
    });

    group('User Message Generation', () {
      test('getUserMessageForErrorType should return appropriate messages', () {
        final testCases = {
          ErrorType.dnsResolution:
              'Anslutningsproblem upptäckts. Försöker återansluta...',
          ErrorType.authentication: testService.getUserMessageForErrorType(
            ErrorType.authentication,
          ),
          ErrorType.notFound: testService.getUserMessageForErrorType(
            ErrorType.notFound,
          ),
          ErrorType.serviceUnavailable:
              'Tjänsten är tillfälligt otillgänglig. Försök igen senare.',
        };

        for (final entry in testCases.entries) {
          final message = testService.getUserMessageForErrorType(entry.key);
          expect(message, isA<String>());
          expect(
            message.isNotEmpty,
            isTrue,
            reason: 'Message should not be empty for ${entry.key}',
          );
        }
      });
    });

    group('Error Recovery Assessment', () {
      test('isRecoverableError should identify recoverable DNS errors', () {
        final recoverableErrors = [
          SocketException('DNS resolution failed'),
          Exception('Network unreachable'),
          Exception('Service unavailable'),
        ];

        for (final error in recoverableErrors) {
          final result = testService.isRecoverableError(error);
          expect(result, isTrue, reason: 'Should be recoverable: $error');
        }
      });

      test('isRecoverableError should identify non-recoverable errors', () {
        final nonRecoverableErrors = [
          Exception('Permission denied'),
          Exception('Not found'),
          Exception('Unknown error'),
        ];

        for (final error in nonRecoverableErrors) {
          final result = testService.isRecoverableError(error);
          expect(result, isFalse, reason: 'Should not be recoverable: $error');
        }
      });
    });

    group('DNS-Specific Error Detection', () {
      test('isDNSResolutionError should detect DNS errors specifically', () {
        final dnsErrors = [
          SocketException('Unable to resolve host firestore.googleapis.com'),
          Exception('DNS lookup failed'),
        ];

        for (final error in dnsErrors) {
          final result = testService.isDNSResolutionError(error);
          expect(result, isTrue, reason: 'Should detect DNS error: $error');
        }
      });

      test('isDNSResolutionError should reject non-DNS errors', () {
        final nonDnsErrors = [
          Exception('Permission denied'),
          Exception('Network timeout'),
        ];

        for (final error in nonDnsErrors) {
          final result = testService.isDNSResolutionError(error);
          expect(
            result,
            isFalse,
            reason: 'Should not detect as DNS error: $error',
          );
        }
      });
    });

    group('Network Connectivity Error Detection', () {
      test(
        'isNetworkConnectivityError should detect network errors specifically',
        () {
          final networkErrors = [
            SocketException('Network unreachable'),
            Exception('Connection timeout'),
          ];

          for (final error in networkErrors) {
            final result = testService.isNetworkConnectivityError(error);
            expect(
              result,
              isTrue,
              reason: 'Should detect network error: $error',
            );
          }
        },
      );

      test('isNetworkConnectivityError should reject non-network errors', () {
        final nonNetworkErrors = [
          Exception('Permission denied'),
          Exception('DNS resolution failed'),
        ];

        for (final error in nonNetworkErrors) {
          final result = testService.isNetworkConnectivityError(error);
          expect(
            result,
            isFalse,
            reason: 'Should not detect as network error: $error',
          );
        }
      });
    });

    group('Categorized Error Handling', () {
      test('handleCategorizedError should set appropriate user messages', () {
        final testError = SocketException('DNS resolution failed');

        testService.handleCategorizedError(testError, 'Test operation');

        // The handleCategorizedError should call _handleUserError internally
        expect(
          testService.lastUserError,
          equals('Anslutningsproblem upptäckts. Försöker återansluta...'),
        );
      });

      test(
        'extractUserMessage should return appropriate messages for different errors',
        () {
          final testCases = {
            SocketException('DNS failed'):
                'Anslutningsproblem upptäckts. Försöker återansluta...',
            Exception('Permission denied'): testService
                .getUserMessageForErrorType(ErrorType.authentication),
          };

          for (final entry in testCases.entries) {
            final message = testService.extractUserMessage(entry.key);
            expect(message, isA<String>());
            expect(message.isNotEmpty, isTrue);
          }
        },
      );
    });

    group('Safe Execution Methods', () {
      test('safeExecute should handle DNS errors gracefully', () async {
        final result = await testService.safeExecute<String>(
          () async => throw SocketException('DNS resolution failed'),
          operationName: 'DNS test operation',
          defaultValue: 'default_value',
        );

        expect(result, equals('default_value'));
      });

      test('safeExecuteSync should handle errors gracefully', () {
        final result = testService.safeExecuteSync<String>(
          () => throw Exception('Sync error'),
          operationName: 'Sync test operation',
          defaultValue: 'sync_default',
        );

        expect(result, equals('sync_default'));
      });
    });

    group('Network Operations', () {
      test('safeNetworkOperation should retry on network failures', () async {
        int attempts = 0;
        final result = await testService.safeNetworkOperation<String>(
          () async {
            attempts++;
            if (attempts < 2) {
              throw SocketException('Network error');
            }
            return 'success';
          },
          operationName: 'Network retry test',
          maxRetries: 3,
          retryDelay: Duration(milliseconds: 10),
        );

        expect(result, equals('success'));
        expect(attempts, equals(2));
      });

      test(
        'safeNetworkOperation should return default after max retries',
        () async {
          final result = await testService.safeNetworkOperation<String>(
            () async => throw SocketException('Persistent network error'),
            operationName: 'Network failure test',
            defaultValue: 'network_failed',
            maxRetries: 2,
            retryDelay: Duration(milliseconds: 1),
          );

          expect(result, equals('network_failed'));
        },
      );
    });
  });

  group('ErrorType Enum Tests', () {
    test('should have all expected error types', () {
      expect(ErrorType.values, hasLength(6));
      expect(ErrorType.values, contains(ErrorType.dnsResolution));
      expect(ErrorType.values, contains(ErrorType.networkConnectivity));
      expect(ErrorType.values, contains(ErrorType.authentication));
      expect(ErrorType.values, contains(ErrorType.notFound));
      expect(ErrorType.values, contains(ErrorType.serviceUnavailable));
      expect(ErrorType.values, contains(ErrorType.unknown));
    });

    test('should support string representation', () {
      expect(ErrorType.dnsResolution.name, equals('dnsResolution'));
      expect(ErrorType.networkConnectivity.name, equals('networkConnectivity'));
      expect(ErrorType.authentication.name, equals('authentication'));
      expect(ErrorType.notFound.name, equals('notFound'));
      expect(ErrorType.serviceUnavailable.name, equals('serviceUnavailable'));
      expect(ErrorType.unknown.name, equals('unknown'));
    });
  });
}
