/// Unit tests for [PinnedHttpClient] (BUT-427).
///
/// Tests the wrapper construction + per-host gating logic. The native pin
/// check itself is mocked — verifying the platform plugin's pinning behavior
/// against a real cert is integration territory and lives elsewhere.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:butlery/services/security/pinned_http_client.dart';

void main() {
  group('PinnedHttpClient', () {
    test('passes through to inner client for unpinned host', () async {
      // Hosts not present in CertPinConfig must NOT incur a pin check —
      // otherwise the wrapper would block every legitimate request to
      // unconfigured third-parties.
      var checkInvoked = false;
      var innerInvoked = false;

      final inner = MockClient((request) async {
        innerInvoked = true;
        return http.Response('ok', 200);
      });

      final client = PinnedHttpClient(
        inner: inner,
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async {
          checkInvoked = true;
          return 'CONNECTION_SECURE';
        },
      );

      final response = await client.get(Uri.parse('https://example.com/path'));

      expect(response.statusCode, 200);
      expect(checkInvoked, isFalse,
          reason: 'pin check must not run for unpinned host');
      expect(innerInvoked, isTrue);
    });

    test('runs pin check and forwards request when secure', () async {
      // For pinned hosts, the cert check runs first. On `CONNECTION_SECURE`
      // the request proceeds normally.
      String? checkedUrl;
      List<String>? checkedPins;

      final inner = MockClient((request) async {
        return http.Response('{"hits":[]}', 200,
            headers: {'content-type': 'application/json'});
      });

      final client = PinnedHttpClient(
        inner: inner,
        pinOverrides: const {
          'api.example.test': ['AA:BB:CC', 'DD:EE:FF']
        },
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async {
          checkedUrl = serverURL;
          checkedPins = allowedSHAFingerprints;
          return 'CONNECTION_SECURE';
        },
      );

      final response = await client.get(
        Uri.parse('https://api.example.test/v1/search'),
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {'hits': []});
      expect(checkedUrl, contains('api.example.test'));
      expect(checkedPins, ['AA:BB:CC', 'DD:EE:FF']);
    });

    test('throws CertificateNotVerifiedException on mismatch', () async {
      // Soft-fail at the app layer means the request fails — we do NOT
      // accept an unverified cert just to keep the request going.
      final telemetry = <_TelemetryEvent>[];
      final client = PinnedHttpClient(
        inner: MockClient((_) async => http.Response('should not reach', 200)),
        pinOverrides: const {
          'api.example.test': ['AA:BB:CC']
        },
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async {
          return 'CONNECTION_NOT_SECURE';
        },
        onPinMismatch: (host, kind, error) =>
            telemetry.add(_TelemetryEvent(host, kind)),
      );

      await expectLater(
        client.get(Uri.parse('https://api.example.test/path')),
        throwsA(isA<CertificateNotVerifiedException>()),
      );
      expect(telemetry, hasLength(1));
      expect(telemetry.single.host, 'api.example.test');
      expect(telemetry.single.kind, 'mismatch');
    });

    test('rejects http:// scheme on pinned host', () async {
      // HTTP cannot be pinned. A pinned host configured but accessed via
      // http:// is a misconfiguration and must fail closed — otherwise an
      // attacker could downgrade the connection.
      final telemetry = <_TelemetryEvent>[];
      final client = PinnedHttpClient(
        inner: MockClient((_) async => http.Response('reach', 200)),
        pinOverrides: const {
          'api.example.test': ['AA:BB:CC']
        },
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async =>
            'CONNECTION_SECURE',
        onPinMismatch: (host, kind, error) =>
            telemetry.add(_TelemetryEvent(host, kind)),
      );

      await expectLater(
        client.get(Uri.parse('http://api.example.test/path')),
        throwsA(isA<CertificateNotVerifiedException>()),
      );
      expect(telemetry.single.kind, 'non_https_pinned_host');
    });

    test('fails closed when pin check itself throws', () async {
      // If the platform plugin throws (network error, plugin missing on
      // current platform), we must NOT accept the request — better to fail
      // visibly than silently disable pinning.
      final telemetry = <_TelemetryEvent>[];
      final client = PinnedHttpClient(
        inner: MockClient((_) async => http.Response('reach', 200)),
        pinOverrides: const {
          'api.example.test': ['AA:BB:CC']
        },
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async =>
            throw StateError('plugin not available'),
        onPinMismatch: (host, kind, error) =>
            telemetry.add(_TelemetryEvent(host, kind)),
      );

      await expectLater(
        client.get(Uri.parse('https://api.example.test/path')),
        throwsA(isA<CertificateCouldNotBeVerifiedException>()),
      );
      expect(telemetry.single.kind, 'check_failed');
    });

    test('per-instance pinOverrides win over global config', () async {
      // The override path lets a test pin a synthetic host without touching
      // the production pin map. Without this, every test would have to
      // monkey-patch CertPinConfig, which would be racy under parallel
      // test execution.
      var checkInvoked = false;
      final client = PinnedHttpClient(
        inner: MockClient((_) async => http.Response('ok', 200)),
        pinOverrides: const {
          'unconfigured.example.test': ['ZZ:YY:XX']
        },
        pinCheck: ({
          required String serverURL,
          required Map<String, String> headerHttp,
          required SHA sha,
          required List<String> allowedSHAFingerprints,
          required int timeout,
        }) async {
          checkInvoked = true;
          return 'CONNECTION_SECURE';
        },
      );

      await client.get(Uri.parse('https://unconfigured.example.test/path'));
      expect(checkInvoked, isTrue);
    });
  });
}

class _TelemetryEvent {
  _TelemetryEvent(this.host, this.kind);
  final String host;
  final String kind;
}
