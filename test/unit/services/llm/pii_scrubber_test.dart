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

  // BUT-692: scrubUrlParams must also strip path-embedded tracker IDs.
  group('scrubUrlParams - path-embedded tokens', () {
    test(
      'BUT-534: strips query, preserves fragment (recipe section anchors)',
      () {
        final out = scrubUrlParams(
          'https://example.com/recipe?utm_source=x&token=secret#ingredienser',
        );
        expect(out, isNot(contains('utm_source')));
        expect(out, isNot(contains('token')));
        // Fragment is preserved — anchors like #ingredienser are useful for
        // section-targeted recipe links and aren't sent to servers anyway.
        expect(out, contains('#ingredienser'));
        expect(out, contains('example.com/recipe'));
      },
    );

    test('redacts mixed-case + digit path token (Algolia object-ID shape)', () {
      final out = scrubUrlParams(
        'https://example.com/r/7Br2c3DmEIeu61HVcgWa9/title',
      );
      expect(out, isNot(contains('7Br2c3DmEIeu61HVcgWa9')));
      expect(out, contains(':redacted'));
      expect(out, contains('/title'));
    });

    test('redacts UUID path segment (RFC 4122 layout)', () {
      final out = scrubUrlParams(
        'https://example.com/share/f47ac10b-58cc-4372-a567-0e02b2c3d479/view',
      );
      expect(out, isNot(contains('f47ac10b-58cc-4372-a567-0e02b2c3d479')));
      expect(out, contains(':redacted'));
    });

    test('redacts JWT-shaped token in path', () {
      final out = scrubUrlParams(
        'https://example.com/auth/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_xx',
      );
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_xx')));
      expect(out, contains(':redacted'));
    });

    test('redacts 32-char hex hash path segment', () {
      final out = scrubUrlParams(
        'https://example.com/tracking/a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5/x',
      );
      expect(out, isNot(contains('a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5')));
      expect(out, contains(':redacted'));
    });

    test('keeps Swedish recipe slug intact', () {
      final out = scrubUrlParams(
        'https://recept.se/recept/gulasch-med-svamp-och-russin',
      );
      expect(out, contains('gulasch-med-svamp-och-russin'));
      expect(out, isNot(contains(':redacted')));
    });

    test('keeps long-but-slug-shaped path segments', () {
      // 34 chars total, all-lowercase, hyphen-separated word groups —
      // longest unsplit run is 9 chars ("italienska") so under the
      // 16-char threshold.
      final out = scrubUrlParams(
        'https://example.com/super-premium-italienska-tomater',
      );
      expect(out, contains('super-premium-italienska-tomater'));
      expect(out, isNot(contains(':redacted')));
    });

    test('keeps short opaque-looking segments below threshold', () {
      // 19 chars — one below the 20-char threshold. False-negative bias
      // is intentional per the BUT-692 ticket.
      final out = scrubUrlParams('https://example.com/r/AbCdEf1234567890XYZ');
      expect(out, contains('AbCdEf1234567890XYZ'));
    });

    test('returns input unchanged when not parseable', () {
      const garbage = 'not a url at all';
      expect(scrubUrlParams(garbage), equals(garbage));
    });

    test('handles multiple opaque segments in same path', () {
      final out = scrubUrlParams(
        'https://example.com/r/7Br2c3DmEIeu61HVcgWa9/and/'
        'f47ac10b-58cc-4372-a567-0e02b2c3d479/end',
      );
      expect(out, isNot(contains('7Br2c3DmEIeu61HVcgWa9')));
      expect(out, isNot(contains('f47ac10b-58cc-4372-a567-0e02b2c3d479')));
      expect(out, contains('/and/'));
      expect(out, contains('/end'));
    });
  });

  // BUT-765: opaque-token redaction inside URL fragments. The BUT-534 test
  // above asserts that slug fragments survive; these assert that the
  // tightening for opaque fragments mirrors the path-segment heuristic.
  group('scrubUrlParams - opaque fragment tokens (BUT-765)', () {
    test('keeps short slug fragment intact (#method)', () {
      final out = scrubUrlParams('https://example.com/recipe#method');
      expect(out, contains('#method'));
      expect(out, isNot(contains(':redacted')));
    });

    test('keeps slug-shaped fragment with hyphens intact', () {
      final out = scrubUrlParams(
        'https://example.com/recipe#super-premium-italienska',
      );
      expect(out, contains('#super-premium-italienska'));
      expect(out, isNot(contains(':redacted')));
    });

    test('redacts UUID-shaped fragment wholesale', () {
      final out = scrubUrlParams(
        'https://example.com/share#f47ac10b-58cc-4372-a567-0e02b2c3d479',
      );
      expect(out, isNot(contains('f47ac10b-58cc-4372-a567-0e02b2c3d479')));
      expect(out, contains('#:redacted'));
    });

    test('redacts JWT-shaped value inside keyed fragment', () {
      final out = scrubUrlParams(
        'https://example.com/auth#token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
      );
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(out, contains('token=:redacted'));
    });

    test('redacts long alphanumeric run in unkeyed fragment', () {
      final out = scrubUrlParams(
        'https://example.com#abcdefghijklmnopqrstuvwxyz',
      );
      expect(out, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
      expect(out, contains(':redacted'));
    });

    test('redacts 32-char hex hash fragment', () {
      final out = scrubUrlParams(
        'https://example.com/r#a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5',
      );
      expect(out, isNot(contains('a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5')));
      expect(out, contains(':redacted'));
    });

    test(
      'mixed keyed fragment redacts opaque values, preserves slug values',
      () {
        // Production heuristic does not decompose by `&`/`=`; it scans the
        // whole fragment for 16+ char alphanumeric runs. Slug values stay
        // intact (under threshold), opaque values redact in-place.
        final out = scrubUrlParams(
          'https://example.com#section=ingredienser&token=eyJhbGciOiJIUzI1NiJ9',
        );
        expect(out, contains('section=ingredienser'));
        expect(out, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
        expect(out, contains('token=:redacted'));
      },
    );

    test('parity-pin: percent-encoded fragment redacts after decode', () {
      // Dart's `Uri.fragment` getter returns the decoded form, so
      // `%3D` arrives as `=` to the heuristic. The TS port mirrors this
      // via `decodeURIComponent` so both ports redact the same input.
      final out = scrubUrlParams(
        'https://example.com#token%3DeyJhbGciOiJIUzI1NiJ9_extra',
      );
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiJ9_extra')));
      expect(out, contains(':redacted'));
    });
  });
}
