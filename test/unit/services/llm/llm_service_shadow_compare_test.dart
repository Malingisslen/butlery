/// Parser shadow comparison (ADR-0037): what [LlmService.shadowCompareImport]
/// sends to which callable, and that a failing call is a plain `false`.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class _Limiter extends Fake implements ImportRateLimiter {}

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
  Map<String, dynamic> response = {'sampled': true};

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(calls.putIfAbsent(name, () => []), error, response);
}

void main() {
  late _Functions functions;

  LlmService service() => LlmService(
    rateLimiter: _Limiter(),
    consentService: _Consent(),
    functions: functions,
    isGuest: () => false,
  );

  setUp(() => functions = _Functions());

  test(
    'sends the scrubbed payload to shadowCompareImport and reads sampled',
    () async {
      final took = await service().shadowCompareImport({
        'text': 'Pannkakor från anna@example.com\n3 dl vetemjöl',
        'channel': 'text',
      });

      expect(took, isTrue);
      expect(functions.calls.keys, ['shadowCompareImport']);
      final sent = Map<String, dynamic>.from(
        functions.calls['shadowCompareImport']!.single! as Map,
      );
      expect(sent['text'], isNot(contains('anna@example.com')));
      expect(sent['text'], contains('[EMAIL]'));
      expect(sent['channel'], 'text');
    },
  );

  test('a server that took no sample reads as false', () async {
    functions.response = {'sampled': false, 'reason': 'rate_off'};

    expect(await service().shadowCompareImport({'text': 'x'}), isFalse);
  });

  test('a failing callable is a plain false, never a throw', () async {
    functions.error = FirebaseFunctionsException(
      code: 'internal',
      message: 'boom',
    );

    expect(await service().shadowCompareImport({'text': 'x'}), isFalse);
  });
}
