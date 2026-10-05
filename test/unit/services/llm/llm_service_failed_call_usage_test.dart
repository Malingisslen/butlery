/// BUT-2239: a `structureRecipe` call the server answers with
/// `success: false` has still been billed (`structure-recipe.ts` returns the
/// model's cost on an unparseable answer), so the client limiter must count
/// it, for both the whole-recipe and the ingredient-line entry point.
library;

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRateLimiter extends Fake implements ImportRateLimiter {
  final recorded = <double?>[];

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
  }) async {
    recorded.add(llmCost);
  }
}

class _FakeConsentService extends Fake implements ConsentService {
  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async => true;
}

class _FailedResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  @override
  Map<String, dynamic> get data => {
    'success': false,
    'error': 'Kunde inte tolka AI-svaret som ett recept.',
    'estimatedCost': 0.0012,
  };
}

class _FailingCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async => _FailedResult() as HttpsCallableResult<T>;
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FailingCallable();
}

void main() {
  late _RecordingRateLimiter limiter;
  late LlmService service;

  setUp(() {
    limiter = _RecordingRateLimiter();
    service = LlmService(
      rateLimiter: limiter,
      consentService: _FakeConsentService(),
      functions: _FakeFunctions(),
    );
  });

  test('a failed structureRecipe call is recorded with its cost', () async {
    final response = await service.structureRecipe(text: 'Pannkakor');

    expect(response.success, isFalse);
    expect(limiter.recorded, [0.0012]);
  });

  test(
    'a failed parseIngredientLines call is recorded with its cost',
    () async {
      final response = await service.parseIngredientLines(
        lines: ['2 dl mjölk'],
      );

      expect(response.success, isFalse);
      expect(limiter.recorded, [0.0012]);
    },
  );
}
