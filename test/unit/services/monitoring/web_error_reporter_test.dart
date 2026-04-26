/// BUT-449: WebErrorReporter payload-shape tests.
///
/// We can't test the full pipeline (FlutterError.onError + callable)
/// without spinning up Firebase + a fake httpsCallable. The contract
/// that matters for this ticket is **PII scrubbing happens on every
/// text field before the payload leaves the device**. `buildPayload`
/// is exposed via `@visibleForTesting` so the assertion is direct.
///
/// The consent gate and the install() side-effects are covered by the
/// runtime — `kIsWeb` is the gate, and the consent check is identical
/// to the native Crashlytics gate in `main.dart` which is itself
/// covered by widget integration tests.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/monitoring/web_error_reporter.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  late WebErrorReporter reporter;

  setUp(() {
    // The mocks satisfy the type signatures; `buildPayload` is pure and
    // never reaches them. The constructor's `??` fallback would lazy
    // init a real FirebaseFunctions and crash without `Firebase.initializeApp()`.
    reporter = WebErrorReporter(
      consentService: _MockConsentService(),
      functions: _MockFunctions(),
    );
  });

  group('buildPayload', () {
    test('scrubs email from message', () {
      final payload = reporter.buildPayload(
        error: 'Failed: user alice@example.com hit 500',
        stack: null,
      );
      expect(payload['message'], contains('[EMAIL]'));
      expect(payload['message'], isNot(contains('alice@example.com')));
    });

    test('scrubs personnummer from stack', () {
      final payload = reporter.buildPayload(
        error: 'exception',
        stack: StackTrace.fromString(
          'Error at handler\npayload: 19900101-1234',
        ),
      );
      expect(payload['stack'], contains('[PERSONNUMMER]'));
      expect(payload['stack'], isNot(contains('19900101-1234')));
    });

    test('scrubs PII from context field', () {
      final payload = reporter.buildPayload(
        error: 'boom',
        stack: null,
        context: 'Triggered by request from bob@host.com',
      );
      expect(payload['context'], contains('[EMAIL]'));
      expect(payload['context'], isNot(contains('bob@host.com')));
    });

    test('omits stack when null', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload.containsKey('stack'), isFalse);
    });

    test('omits context when null', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload.containsKey('context'), isFalse);
    });

    test('truncates oversized message to 2000 chars', () {
      final big = 'A' * 5000;
      final payload = reporter.buildPayload(error: big, stack: null);
      expect((payload['message'] as String).length, equals(2000));
    });

    test('truncates oversized stack to 8000 chars', () {
      final stackText = 'S' * 20000;
      final payload = reporter.buildPayload(
        error: 'short',
        stack: StackTrace.fromString(stackText),
      );
      expect((payload['stack'] as String).length, equals(8000));
    });

    test('passes fatal flag through', () {
      final payload = reporter.buildPayload(
        error: 'crashed',
        stack: null,
        fatal: true,
      );
      expect(payload['fatal'], isTrue);
    });

    test('fatal defaults to false', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload['fatal'], isFalse);
    });

    test('platform is always "web"', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload['platform'], equals('web'));
    });

    test('occurredAt is ISO8601 UTC', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      final ts = payload['occurredAt'] as String;
      expect(ts, endsWith('Z'));
      expect(() => DateTime.parse(ts), returnsNormally);
    });
  });
}
