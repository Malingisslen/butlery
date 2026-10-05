/// BUT-2239: `structure-recipe.ts` returns the model's cost on an
/// unparseable answer, so the client limiter must count it, for both the
/// whole-recipe and the ingredient-line entry point. A kill-switch answer
/// costs nothing and must not use up a daily slot.
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
  _FailedResult(this.cost);
  final double cost;

  @override
  Map<String, dynamic> get data => {
    'success': false,
    'error': 'Kunde inte tolka AI-svaret som ett recept.',
    'estimatedCost': cost,
  };
}

class _FailingCallable extends Fake implements HttpsCallable {
  _FailingCallable(this.cost);
  final double cost;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async => _FailedResult(cost) as HttpsCallableResult<T>;
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.cost);
  final double cost;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FailingCallable(cost);
}

void main() {
  late _RecordingRateLimiter limiter;
  late LlmService service;

  LlmService serviceAnswering(double cost) => LlmService(
    rateLimiter: limiter,
    consentService: _FakeConsentService(),
    functions: _FakeFunctions(cost),
  );

  setUp(() {
    limiter = _RecordingRateLimiter();
    service = serviceAnswering(0.0012);
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

  test('a kill-switch answer, which cost nothing, is not recorded', () async {
    final response = await serviceAnswering(0).structureRecipe(
      text: 'Pannkakor',
    );

    expect(response.success, isFalse);
    expect(limiter.recorded, isEmpty);
  });
}
