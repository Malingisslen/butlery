/// BUT-920: the import id the server counts on a guest's AI calls.
library;

// FirebaseFunctionsException's constructor is @protected; the server's denial
// can only be built here this way.
// ignore_for_file: invalid_use_of_protected_member

import 'dart:typed_data';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  _Result(this.data);

  @override
  final Map<String, dynamic> data;
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.sent, this.error, this.response);
  final List<Object?> sent;
  final FirebaseFunctionsException? error;
  final Map<String, dynamic> response;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    sent.add(parameters);
    if (error != null) throw error!;
    return _Result(response) as HttpsCallableResult<T>;
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  final calls = <String, List<Object?>>{};
  FirebaseFunctionsException? error;
  Map<String, dynamic> response = {'success': true, 'estimatedCost': 0.001};

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(calls.putIfAbsent(name, () => []), error, response);
}

void main() {
  late _Functions functions;
  late GuestImportSession session;
  var guest = true;

  LlmService service({bool withSession = true}) => LlmService(
    rateLimiter: _Limiter(),
    consentService: _Consent(),
    functions: functions,
    guestSession: withSession ? session : null,
    isGuest: () => guest,
  );

  Map<String, dynamic> sentTo(String name) =>
      Map<String, dynamic>.from(functions.calls[name]!.single! as Map);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    functions = _Functions();
    guest = true;
    session = GuestImportSession(uid: () => 'guest-1');
    await session.load();
  });

  test('a guest sends the import id with structureRecipe', () async {
    session.begin();
    final id = session.currentId;

    await service().structureRecipe(text: 'Pannkakor');

    expect(sentTo('structureRecipe')['guestImportId'], id);
  });

  test('a guest sends the import id with ocrRecipeImage', () async {
    session.begin();
    final id = session.currentId;

    await service().ocrRecipeImage(imageBytes: Uint8List.fromList([1, 2, 3]));

    expect(sentTo('ocrRecipeImage')['guestImportId'], id);
  });

  test('a guest\'s successful import counts against the three', () async {
    session.begin();
    await service().structureRecipe(text: 'Pannkakor');
    expect(session.remaining, 2);

    await service().structureRecipe(text: 'Pannkakor, igen');
    expect(session.remaining, 2, reason: 'the same import counts once');
  });

  test('an import the server could not structure does not use one of the '
      'three', () async {
    functions.response = {
      'success': false,
      'error': 'no recipe found',
      'estimatedCost': 0.0,
    };
    session.begin();

    final response = await service().structureRecipe(text: 'Inget recept');

    expect(response.success, isFalse);
    expect(session.remaining, 3);
    expect(session.usedCount, 0);
  });

  test('someone who is not a guest sends nothing extra', () async {
    guest = false;

    await service().structureRecipe(text: 'Pannkakor');

    expect(sentTo('structureRecipe'), isNot(contains('guestImportId')));
    expect(session.usedCount, 0);
  });

  test('a service built without a session sends nothing extra', () async {
    await service(withSession: false).structureRecipe(text: 'Pannkakor');

    expect(sentTo('structureRecipe'), isNot(contains('guestImportId')));
  });

  test('the server refusing the guest tells the session and opens no '
      'circuit breaker', () async {
    functions.error = FirebaseFunctionsException(
      code: 'resource-exhausted',
      message: 'guest-import-limit',
      details: const {'reason': 'guest-import-limit'},
    );
    final llm = service();
    var hits = 0;
    session.limitHits.addListener(() => hits++);

    for (var i = 0; i < 5; i++) {
      await expectLater(
        llm.structureRecipe(text: 'Pannkakor'),
        throwsA(
          isA<LlmException>().having(
            (e) => e.code,
            'code',
            LlmException.guestImportLimitCode,
          ),
        ),
      );
    }

    expect(hits, 5);
    expect(llm.backendBreakerForTest.allowRequest(), isTrue);
  });

  test('the per-call guest limit tells the session and opens no circuit '
      'breaker', () async {
    functions.error = FirebaseFunctionsException(
      code: 'resource-exhausted',
      message: 'guest-call-limit',
      details: const {'reason': 'guest-call-limit'},
    );
    final llm = service();
    var hits = 0;
    session.limitHits.addListener(() => hits++);

    for (var i = 0; i < 5; i++) {
      await expectLater(
        llm.structureRecipe(text: 'Pannkakor'),
        throwsA(
          isA<LlmException>().having(
            (e) => e.code,
            'code',
            LlmException.guestCallLimitCode,
          ),
        ),
      );
    }

    expect(hits, 5);
    expect(llm.backendBreakerForTest.allowRequest(), isTrue);
  });

  test(
    'the capacity answer does not open the circuit breaker either',
    () async {
      functions.error = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'guest-capacity',
        details: const {'reason': 'guest-capacity'},
      );
      final llm = service();

      for (var i = 0; i < 5; i++) {
        await expectLater(
          llm.structureRecipe(text: 'Pannkakor'),
          throwsA(isA<LlmException>()),
        );
      }

      expect(llm.backendBreakerForTest.allowRequest(), isTrue);
    },
  );
}
