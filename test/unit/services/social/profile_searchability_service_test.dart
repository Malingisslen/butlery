import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/social/profile_searchability_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

/// Fake instead of Mock — `HttpsCallableResult.data` reads from a private
/// backing field that `implements` can't see, so a Mock returns null.
class _FakeCallableResult extends Fake
    implements HttpsCallableResult<Map<dynamic, dynamic>> {
  _FakeCallableResult(this._data);
  final Map<dynamic, dynamic> _data;
  @override
  Map<dynamic, dynamic> get data => _data;
}

/// BUT-1629: this wrapper is the ONLY path by which a 15–17-year-old can become
/// discoverable in people-search, so what it reports back is what the privacy
/// toggle renders. The contract under test is the unwrap: the caller must learn
/// what the SERVER stored, and anything that isn't an explicit `true` must read
/// as "not searchable" rather than as an optimistic success.
void main() {
  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  group('ProfileSearchabilityService.setSearchable', () {
    late _MockFunctions functions;
    late _MockCallable callable;
    late ProfileSearchabilityService service;

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      service = ProfileSearchabilityService(functions: functions);

      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
    });

    void stubResponse(Map<dynamic, dynamic> data) {
      when(
        () => callable.call<Map<dynamic, dynamic>>(any()),
      ).thenAnswer((_) async => _FakeCallableResult(data));
    }

    test('sends the requested value to the callable', () async {
      stubResponse({'searchable': true});

      await service.setSearchable(true);

      verify(
        () => functions.httpsCallable('setProfileSearchability'),
      ).called(1);
      verify(
        () => callable.call<Map<dynamic, dynamic>>({'searchable': true}),
      ).called(1);
    });

    test('returns the stored value on a clean opt-in', () async {
      stubResponse({'searchable': true});

      expect(await service.setSearchable(true), isTrue);
    });

    test('reports the server refusal, not the request', () async {
      // The request asked for true; the server stored false.
      stubResponse({'searchable': false});

      expect(
        await service.setSearchable(true),
        isFalse,
        reason: 'the caller must not believe an opt-in the server declined',
      );
    });

    test('a missing key reads as not searchable', () async {
      stubResponse({'ok': true});

      expect(await service.setSearchable(true), isFalse);
    });

    test('a non-bool value reads as not searchable', () async {
      // A truthy-looking string must not be coerced into an opt-in.
      stubResponse({'searchable': 'true'});

      expect(await service.setSearchable(true), isFalse);
    });

    test(
      'propagates a callable failure so the caller can leave the toggle put',
      () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'rate limited',
          ),
        );

        expect(
          () => service.setSearchable(true),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      },
    );
  });
}
