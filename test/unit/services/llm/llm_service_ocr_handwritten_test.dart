/// BUT-684: proves `LlmService.ocrRecipeImage(isHandwritten: ...)` reaches the
/// Cloud Function payload.
///
/// What this proves: the handwriting flag the user toggles on the photo-import
/// screen actually lands in the callable data map sent to `ocrRecipeImage` —
/// `true` when opted in, `false` (default) otherwise. This is the wire that
/// makes the CF pick its handwriting-tuned Swedish OCR prompt.
///
/// Mocking strategy: a capturing fake `FirebaseFunctions` whose `HttpsCallable`
/// records the payload passed to `call(...)` and returns a benign success
/// result. We never mock the subject (LlmService); consent + rate-limit fakes
/// just open the gate so the callable is reached.
library;

import 'dart:typed_data';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
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

class _FakeCallableResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  @override
  Map<String, dynamic> get data => {'success': true, 'estimatedCost': 0.0};
}

class _CapturingHttpsCallable extends Fake implements HttpsCallable {
  Object? lastParameters;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    lastParameters = parameters;
    return _FakeCallableResult() as HttpsCallableResult<T>;
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.callable);
  final _CapturingHttpsCallable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      callable;
}

void main() {
  final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);

  LlmService buildService(_CapturingHttpsCallable callable) => LlmService(
    rateLimiter: _FakeRateLimiter(),
    consentService: _FakeConsentService(),
    functions: _FakeFunctions(callable),
  );

  group('BUT-684: ocrRecipeImage handwriting flag → callable payload', () {
    test('isHandwritten:true is sent in the callable data map', () async {
      final callable = _CapturingHttpsCallable();
      final service = buildService(callable);

      await service.ocrRecipeImage(
        imageBytes: imageBytes,
        isHandwritten: true,
      );

      final payload = callable.lastParameters as Map<String, dynamic>;
      expect(payload['isHandwritten'], isTrue);
    });

    test('default (no flag) sends isHandwritten:false', () async {
      final callable = _CapturingHttpsCallable();
      final service = buildService(callable);

      await service.ocrRecipeImage(imageBytes: imageBytes);

      final payload = callable.lastParameters as Map<String, dynamic>;
      expect(payload['isHandwritten'], isFalse);
    });
  });
}
