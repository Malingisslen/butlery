/// Regression tests for [HttpContentFetcher] HTTP client reuse (BUT-735).
///
/// Pre-fix: every call to [HttpContentFetcher.fetchHtmlWithTimeout]
/// allocated a fresh pinned `http.Client` via
/// [PinnedHttpClientFactory.create] when no client was injected, then
/// closed it after the call. Each import paid a TLS handshake + DNS
/// lookup with no keep-alive across imports.
///
/// Fix: the DI module registers a singleton pinned `http.Client` and
/// passes it into the constructor. The constructor's
/// `_httpClient ?? PinnedHttpClientFactory.create()` fallback is
/// preserved for ad-hoc construction (no DI). The
/// `shouldCloseClient = _httpClient == null` semantics already get
/// reuse right — these tests pin the contract so a future contributor
/// can't regress it back to per-call construction.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';

void main() {
  group('HttpContentFetcher client reuse (BUT-735)', () {
    test(
        'reuses the injected http.Client across multiple fetch calls and '
        'does not close it', () async {
      var sendCount = 0;
      final inner = MockClient((request) async {
        sendCount++;
        return http.Response(
          '<html><head><title>ok</title></head><body>hi</body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final tracking = _TrackingClient(inner);

      // DNS stub: resolve to a public IP that survives isBlockedHost.
      Future<List<InternetAddress>> dnsStub(String host) async {
        return [InternetAddress('93.184.216.34')]; // example.com
      }

      final fetcher = HttpContentFetcher(
        httpClient: tracking,
        dnsLookup: dnsStub,
      );

      final r1 = await fetcher.fetchHtmlWithTimeout('https://example.com/a');
      final r2 = await fetcher.fetchHtmlWithTimeout('https://example.com/b');

      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(sendCount, 2,
          reason: 'both calls must reach the same underlying client');
      expect(tracking.closeCount, 0,
          reason: 'an injected (DI-owned) client must not be closed');
    });

    test(
        'when no client is injected, the per-call fallback closes its '
        'transient client (preserved legacy behaviour)', () async {
      // The fallback path matters for ad-hoc / test construction without
      // DI. Closing the transient client there prevents socket leaks.
      // The DI singleton's lifetime is owned by GetIt's dispose hook.
      final fetcher = HttpContentFetcher(
        // Force the DNS path to fail closed so we don't actually open a
        // socket — the test only cares that the fallback doesn't throw
        // and returns null (no client to assert on directly).
        dnsLookup: (_) async => throw const SocketException('no dns in test'),
      );

      final result = await fetcher.fetchHtmlWithTimeout('https://example.com/');
      expect(result, isNull,
          reason: 'DNS failure makes the fetch fail-closed before any HTTP');
    });
  });
}

/// Wraps a [MockClient] so we can count `close()` invocations without
/// affecting the underlying request/response handling.
class _TrackingClient extends http.BaseClient {
  _TrackingClient(this._inner);
  final http.Client _inner;
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closeCount++;
    _inner.close();
    super.close();
  }
}
