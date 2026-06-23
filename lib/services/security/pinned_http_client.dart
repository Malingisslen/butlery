/// HTTP client wrapper that enforces per-host SHA-256 SPKI pinning on
/// outbound third-party HTTPS calls (BUT-427).
///
/// **Why a custom BaseClient and not `SecureHttpClient` from the package:**
/// `SecureHttpClient.send()` falls through unconditionally — only the
/// non-streaming `get/post/...` helpers run the pin check. Both
/// [HttpContentFetcher] and [OCRExtractionService] use `client.send(request)`
/// directly to stream responses (size limits, multipart upload), so the
/// package's send() bypass would silently disable pinning on our hottest
/// paths. This wrapper enforces pinning on every send().
///
/// **Soft-fail telemetry:** a pin mismatch logs a `ssl_pin_mismatch` analytics
/// event with `host` and `error_kind`, then throws so the caller treats it as
/// a network error. Soft-fail means the app does not crash — it does NOT
/// mean we accept the request.
///
/// **Hosts without configured pins** fall through to the underlying client
/// (platform trust store). This keeps the wrapper safe to install everywhere
/// — a misconfigured pin map cannot itself break unrelated requests.
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/security/cert_pin_config.dart';

/// Function type for the underlying pin-check call. Defaults to the real
/// platform plugin; tests inject a stub. Returning a string containing
/// `'CONNECTION_SECURE'` means the cert matched at least one allowed pin.
typedef PinCheckFn =
    Future<String> Function({
      required String serverURL,
      required Map<String, String> headerHttp,
      required SHA sha,
      required List<String> allowedSHAFingerprints,
      required int timeout,
    });

/// Function type for the soft-fail telemetry callback. Receives the host
/// and an error kind label (`'mismatch'`, `'check_failed'`).
typedef PinMismatchTelemetry =
    void Function(String host, String errorKind, Object? error);

/// HTTP client that enforces SSL certificate pinning before every request
/// to hosts with configured pins.
class PinnedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final bool _ownsInner;
  final PinCheckFn _pinCheck;
  final PinMismatchTelemetry? _onPinMismatch;
  final Map<String, List<String>> _pinOverrides;

  /// Creates a pinned client wrapping [inner]. When [inner] is null, a
  /// default `http.Client()` is constructed and closed by [close].
  ///
  /// [pinOverrides] is a per-instance override of the global pin map —
  /// useful for tests and for narrowing a client to a single host. When
  /// null, [CertPinConfig.hostPins] is used.
  PinnedHttpClient({
    http.Client? inner,
    PinCheckFn? pinCheck,
    PinMismatchTelemetry? onPinMismatch,
    Map<String, List<String>>? pinOverrides,
  }) : _inner = inner ?? http.Client(),
       _ownsInner = inner == null,
       _pinCheck = pinCheck ?? _defaultPinCheck,
       _onPinMismatch = onPinMismatch,
       _pinOverrides = pinOverrides ?? const <String, List<String>>{};

  /// Resolves pins for a host: per-instance overrides win over the global
  /// config so tests can pin a synthetic host without touching globals.
  List<String> _pinsFor(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    final override = _pinOverrides[normalized];
    if (override != null) return override;
    return CertPinConfig.pinsForHost(normalized);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host.toLowerCase();
    final pins = _pinsFor(host);

    if (pins.isEmpty) {
      // No pins configured for this host. Fall through to the underlying
      // client — platform trust store still applies. Wired-but-inactive
      // hosts (TODO placeholders) live here until the ops rotation task
      // populates real fingerprints.
      return _inner.send(request);
    }

    // Only HTTPS can be pinned; treat anything else as a misconfig + fail.
    if (request.url.scheme.toLowerCase() != 'https') {
      _onPinMismatch?.call(host, 'non_https_pinned_host', null);
      throw const CertificateNotVerifiedException();
    }

    String checkResult;
    try {
      checkResult = await _pinCheck(
        serverURL: request.url.toString(),
        headerHttp: const <String, String>{},
        sha: SHA.SHA256,
        allowedSHAFingerprints: pins,
        timeout: 50,
      );
    } catch (e) {
      // The plugin couldn't complete the check (network, plugin missing on
      // host platform, timeout). Log + fail closed — we'd rather break the
      // request than silently disable pinning.
      AppLogger.warning(
        'PinnedHttpClient: pin check failed for $host: $e — failing closed',
      );
      _onPinMismatch?.call(host, 'check_failed', e);
      throw CertificateCouldNotBeVerifiedException(
        e is Exception ? e : Exception(e.toString()),
      );
    }

    if (!checkResult.contains('CONNECTION_SECURE')) {
      AppLogger.warning(
        'PinnedHttpClient: pin mismatch for $host (result=$checkResult)',
      );
      _onPinMismatch?.call(host, 'mismatch', null);
      throw const CertificateNotVerifiedException();
    }

    return _inner.send(request);
  }

  @override
  void close() {
    if (_ownsInner) {
      _inner.close();
    }
    super.close();
  }
}

/// Default pin-check delegate — calls into the real platform plugin.
Future<String> _defaultPinCheck({
  required String serverURL,
  required Map<String, String> headerHttp,
  required SHA sha,
  required List<String> allowedSHAFingerprints,
  required int timeout,
}) {
  return HttpCertificatePinning.check(
    serverURL: serverURL,
    headerHttp: headerHttp,
    sha: sha,
    allowedSHAFingerprints: allowedSHAFingerprints,
    timeout: timeout,
  );
}
