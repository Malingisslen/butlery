/// Unit tests for [CertPinConfig] (BUT-427).
///
/// Validates the host → pin lookup contract that wraps the global pin map.
/// Pinning enforcement itself happens in the HTTP wrapper — these tests pin
/// down only the lookup-helper behavior so a future contributor doesn't
/// accidentally make `pinsForHost` return null for unknown hosts (callers
/// rely on the empty-list contract).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/security/cert_pin_config.dart';

void main() {
  group('CertPinConfig', () {
    test('pinsForHost returns empty list for unknown host', () {
      // Empty (not null) is the documented contract — the HTTP wrapper
      // treats empty as "fall through to platform trust store" and would
      // crash on null.
      expect(CertPinConfig.pinsForHost('not.a.real.host'), isEmpty);
    });

    test('pinsForHost is case-insensitive', () {
      // DNS hostnames are case-insensitive; the lookup must be too,
      // otherwise an Algolia retry that hands us `BUTLERY-APP-DSN.algolia.net`
      // would silently bypass pinning.
      final lower = CertPinConfig.pinsForHost('butlery-app-dsn.algolia.net');
      final upper = CertPinConfig.pinsForHost('Butlery-App-DSN.Algolia.NET');
      expect(upper, equals(lower));
    });

    test('pinsForHost trims whitespace', () {
      // Hostname extraction from URIs occasionally leaves stray whitespace
      // (header parsing edge cases). Tolerate it.
      final clean = CertPinConfig.pinsForHost('api.ocr.space');
      final padded = CertPinConfig.pinsForHost('  api.ocr.space  ');
      expect(padded, equals(clean));
    });

    test('pinsForHost returns empty list for empty input', () {
      expect(CertPinConfig.pinsForHost(''), isEmpty);
      expect(CertPinConfig.pinsForHost('   '), isEmpty);
    });

    test('pinsForUrl extracts host and looks up pins', () {
      final fromUrl =
          CertPinConfig.pinsForUrl('https://api.ocr.space/parse/image?q=1');
      final fromHost = CertPinConfig.pinsForHost('api.ocr.space');
      expect(fromUrl, equals(fromHost));
    });

    test('pinsForUrl returns empty for malformed URL', () {
      expect(CertPinConfig.pinsForUrl('not-a-url'), isEmpty);
      expect(CertPinConfig.pinsForUrl(''), isEmpty);
    });

    test('isPinnedHost is false when host has only TODO placeholders', () {
      // Until the ops rotation task populates real fingerprints, every
      // configured host has an empty pin list — `isPinnedHost` must reflect
      // that so the wrapper doesn't try to enforce pinning against an empty
      // list (which would always fail-closed and break Algolia search in
      // production).
      expect(CertPinConfig.isPinnedHost('api.ocr.space'), isFalse);
      expect(
          CertPinConfig.isPinnedHost('butlery-app-dsn.algolia.net'), isFalse);
    });

    test('hostPins map keys are all lowercased', () {
      // The lookup normalizes the query key but assumes the map keys are
      // already lowercase. A typo with a mixed-case key would silently
      // become unreachable.
      for (final key in CertPinConfig.hostPins.keys) {
        expect(key, equals(key.toLowerCase()),
            reason: 'host map key "$key" is not lowercase');
      }
    });

    group('assertReleaseModeSafety (BUT-769)', () {
      test('debug mode is a no-op even with empty pins', () {
        // Daily dev work runs with empty pin maps — the check must NOT block
        // it. `releaseModeOverrideForTest: false` mimics a debug build.
        expect(
          () => CertPinConfig.assertReleaseModeSafety(
            pinsForTest: const <String, List<String>>{
              'example.com': <String>[],
            },
            releaseModeOverrideForTest: false,
          ),
          returnsNormally,
        );
      });

      test('release mode throws when any host has an empty pin list', () {
        // The whole point: a release build with empty pins is silently
        // insecure (wrapper falls through to platform trust). Throw-loud
        // on boot forces the rotation procedure to run.
        expect(
          () => CertPinConfig.assertReleaseModeSafety(
            pinsForTest: const <String, List<String>>{
              'a.example.com': <String>['AA:BB:CC'],
              'b.example.com': <String>[],
            },
            releaseModeOverrideForTest: true,
          ),
          throwsStateError,
        );
      });

      test('release mode passes when every host has at least one pin', () {
        expect(
          () => CertPinConfig.assertReleaseModeSafety(
            pinsForTest: const <String, List<String>>{
              'a.example.com': <String>['AA:BB:CC'],
              'b.example.com': <String>['DD:EE:FF', '11:22:33'],
            },
            releaseModeOverrideForTest: true,
          ),
          returnsNormally,
        );
      });

      test('error message names every empty host', () {
        // Ops uses the message to know which fingerprints to capture.
        // Burying any host inside an aggregate count would force ops to
        // re-derive the list from the source — wasted minutes during a
        // release-blocked moment.
        try {
          CertPinConfig.assertReleaseModeSafety(
            pinsForTest: const <String, List<String>>{
              'host-a.example.com': <String>[],
              'host-b.example.com': <String>[],
              'host-c.example.com': <String>['present'],
            },
            releaseModeOverrideForTest: true,
          );
          fail('Expected StateError when pins are empty in release mode');
        } on StateError catch (e) {
          expect(e.message, contains('host-a.example.com'));
          expect(e.message, contains('host-b.example.com'));
          expect(e.message, isNot(contains('host-c.example.com')));
        }
      });
    });

    test('hostPins covers all three BUT-427 surface categories', () {
      // Sanity check: the wiring contract is "Algolia + OCR + URL scrape".
      // If any of these three categories goes missing the wiring is broken.
      final keys = CertPinConfig.hostPins.keys;
      expect(keys.any((k) => k.contains('algolia')), isTrue,
          reason: 'no Algolia host configured');
      expect(keys.any((k) => k.contains('ocr.space') || k.contains('vision')),
          isTrue,
          reason: 'no OCR fallback host configured');
      expect(keys.any((k) => k.contains('ica.se') || k.contains('koket.se')),
          isTrue,
          reason: 'no recipe-site host configured');
    });
  });
}
