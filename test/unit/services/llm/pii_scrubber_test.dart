/// BUT-422: Unit tests for the client-side PII scrubber.
///
/// Mirrors the TypeScript parity test at
/// functions/src/__tests__/pii-scrubber.test.ts — same cases, same tokens.
/// If these diverge, the two scrubbers are out of sync and the
/// defence-in-depth contract is broken.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/llm/pii_scrubber.dart';

void main() {
  group('scrubPii - personnummer', () {
    test('scrubs YYMMDD-XXXX format', () {
      final out = scrubPii('Personnummer: 901015-1234');
      expect(out, contains('[PERSONNUMMER]'));
      expect(out, isNot(contains('901015-1234')));
    });

    test('scrubs YYYYMMDD-XXXX format', () {
      final out = scrubPii('PN 19901015-1234 på kortet');
      expect(out, contains('[PERSONNUMMER]'));
      expect(out, isNot(contains('19901015-1234')));
    });

    test('does NOT scrub EAN-13 barcode', () {
      const input = 'EAN 7310865111294 on package';
      expect(scrubPii(input), equals(input));
    });

    test('does NOT scrub digits without hyphen separator', () {
      const input = 'Ref 9010151234 ingen bindestreck';
      expect(scrubPii(input), equals(input));
    });
  });

  group('scrubPii - Swedish phone', () {
    test('scrubs Swedish mobile 070-123 45 67', () {
      final out = scrubPii('Ring 070-123 45 67');
      expect(out, contains('[PHONE]'));
      expect(out, isNot(contains('070-123')));
    });

    test('scrubs international +46 70 123 45 67', () {
      final out = scrubPii('Ring +46 70 123 45 67');
      expect(out, contains('[PHONE]'));
      expect(out, isNot(contains('+46')));
    });

    test('does NOT scrub cooking range "04-05 min"', () {
      const input = 'Koka i 04-05 min';
      expect(scrubPii(input), equals(input));
    });

    test('does NOT scrub cooking range "10-15 minuter"', () {
      const input = 'Koka i 10-15 minuter';
      expect(scrubPii(input), equals(input));
    });

    test('does NOT scrub temperature + time line', () {
      const input = 'Temp 200°C i 30 min';
      expect(scrubPii(input), equals(input));
    });
  });

  group('scrubPii - email', () {
    test('scrubs email address', () {
      final out = scrubPii('Kontakta chef@exempel.se');
      expect(out, contains('[EMAIL]'));
      expect(out, isNot(contains('chef@exempel.se')));
    });
  });

  group('scrubPayload', () {
    test('scrubs string values recursively', () {
      final out = scrubPayload({
        'text': 'Ring 070-123 45 67',
        'mode': 'extract',
        'partialData': {
          'note': 'Personnummer: 901015-1234',
        },
      });
      expect(out['text'], contains('[PHONE]'));
      expect(out['mode'], equals('extract'));
      final partial = out['partialData'] as Map<String, dynamic>;
      expect(partial['note'], contains('[PERSONNUMMER]'));
    });

    test('preserves opaque base64 image blob verbatim', () {
      const blob = 'iVBORw0KGgoAAAANSUhEUgAAAAEA...'; // not real
      final out = scrubPayload({
        'imageBase64': blob,
        'mimeType': 'image/png',
      });
      expect(out['imageBase64'], equals(blob));
    });

    test('strips URL query parameters on url-keyed fields', () {
      final out = scrubPayload({
        'sourceUrl': 'https://example.com/recipe?utm_source=x&token=secret',
      });
      final url = out['sourceUrl'] as String;
      expect(url, isNot(contains('utm_source')));
      expect(url, isNot(contains('token')));
      expect(url, contains('example.com/recipe'));
    });

    test('passes non-string leaves through untouched', () {
      final out = scrubPayload({
        'count': 3,
        'enabled': true,
        'optional': null,
      });
      expect(out['count'], equals(3));
      expect(out['enabled'], isTrue);
      expect(out['optional'], isNull);
    });
  });
}
