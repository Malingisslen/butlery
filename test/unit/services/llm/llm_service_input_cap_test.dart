/// The server refuses a structureRecipe text over `llmMaxInputChars`, so the
/// client cuts it to that length instead of sending a call that must fail.
library;

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class _Limiter extends Fake implements ImportRateLimiter {
  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async =>
      const RateLimitAllowed(
        remainingInWindow: 999,
        limitType: LimitType.perMinute,
      );

  @override
  Future<void> recordUsage(ImportOperation operation) async {}
}

class _Consent extends Fake implements ConsentService {
  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async => true;
}

class _Result extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  @override
  Map<String, dynamic> get data => {'success': true, 'estimatedCost': 0.001};
}

class _Callable extends Fake implements HttpsCallable {
  Map<String, dynamic>? sent;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    sent = Map<String, dynamic>.from(parameters! as Map);
    return _Result() as HttpsCallableResult<T>;
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  final callable = _Callable();

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      callable;
}

void main() {
  late _Functions functions;
  late LlmService service;

  setUp(() {
    functions = _Functions();
    service = LlmService(
      rateLimiter: _Limiter(),
      consentService: _Consent(),
      functions: functions,
    );
  });

  test('a text over the limit is cut to it', () async {
    await service.structureRecipe(text: 'a' * (llmMaxInputChars + 500));

    expect(functions.callable.sent!['text'], 'a' * llmMaxInputChars);
  });

  test('a text within the limit is sent whole', () async {
    await service.structureRecipe(text: 'a' * llmMaxInputChars);

    expect(
      (functions.callable.sent!['text'] as String).length,
      llmMaxInputChars,
    );
  });
}
