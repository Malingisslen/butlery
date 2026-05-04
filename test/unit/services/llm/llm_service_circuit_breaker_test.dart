/// BUT-589: regression gate for the LlmService backend circuit breaker.
///
/// What this proves: when 3 consecutive Cloud Function calls fail, the
/// circuit opens and the 4th call short-circuits to a "tjänsten är
/// tillfälligt otillgänglig" denied response — the callable is NOT invoked
/// a 4th time. This is the cost-and-UX guarantee: under a Gemini outage we
/// stop burning the user's daily LLM budget on guaranteed failures.
///
/// Mocking strategy: inject a low-threshold `CircuitBreaker` and a fake
/// `FirebaseFunctions` whose underlying `HttpsCallable` throws on every
/// invocation. We use `Fake` from `mocktail` rather than re-implementing
/// the abstract Firebase types from scratch — the only methods exercised
/// are `httpsCallable(name)` → `call(payload)`.
library;

import 'package:butlery/core/circuit_breaker.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRateLimiter extends Fake implements ImportRateLimiter {
  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async =>
      const RateLimitAllowed(
        remainingInWindow: 999,
        limitType: LimitType.perMinute,
      );

  @override
  Future<void> recordUsage(
    ImportOperation operation, {
    double? llmCost,
  }) async {}
}

class _FakeConsentService extends Fake implements ConsentService {
  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async => true;
}

class _CountingHttpsCallable extends Fake implements HttpsCallable {
  int callCount = 0;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    callCount++;
    // Use a generic Exception (not FirebaseFunctionsException — its
    // constructor is @protected so test code can't instantiate it directly).
    // The CB increments on either branch of the LlmService catch handler;
    // the test only cares that failures count, not which branch.
    throw Exception('simulated Gemini outage');
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.callable);
  final _CountingHttpsCallable callable;

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) =>
      callable;
}

void main() {
  group('BUT-589: LlmService backend circuit breaker', () {
    test(
      '3 consecutive failures open the circuit; 4th call short-circuits '
      'without invoking the callable',
      () async {
        final callable = _CountingHttpsCallable();
        final service = LlmService(
          rateLimiter: _FakeRateLimiter(),
          consentService: _FakeConsentService(),
          functions: _FakeFunctions(callable),
          backendBreaker: CircuitBreaker(
            failureThreshold: 3,
            resetTime: const Duration(seconds: 60),
          ),
        );

        // First 3 calls hit the callable and fail (LlmException is thrown).
        for (var i = 0; i < 3; i++) {
          await expectLater(
            () => service.structureRecipe(text: 'a' * 50),
            throwsA(isA<LlmException>()),
          );
        }
        expect(callable.callCount, 3);
        expect(service.backendBreakerForTest.isOpen, isTrue);

        // 4th call: short-circuits to denied response, callable NOT invoked.
        final response = await service.structureRecipe(text: 'a' * 50);
        expect(callable.callCount, 3,
            reason: 'callable must not be invoked when CB is open');
        expect(response.success, isFalse);
        expect(
          response.error,
          contains('AI-tjänsten är tillfälligt otillgänglig'),
        );
        expect(response.estimatedCost, 0.0);
      },
    );

    test('successful call closes the breaker after a recorded success',
        () async {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        resetTime: const Duration(seconds: 60),
      );

      // Prime: simulate one prior failure (one short of opening).
      breaker.recordFailure();
      expect(breaker.isOpen, isFalse);

      // Then record a success — counter resets, circuit stays closed.
      breaker.recordSuccess();
      expect(breaker.failureCount, 0);
      expect(breaker.isOpen, isFalse);
    });
  });
}
