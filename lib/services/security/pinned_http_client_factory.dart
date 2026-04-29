/// Factory for [PinnedHttpClient] instances with analytics-wired soft-fail
/// telemetry (BUT-427).
///
/// Call sites use [PinnedHttpClientFactory.create] instead of constructing
/// the wrapper directly so pin-mismatch telemetry stays consistent.
library;

import 'package:http/http.dart' as http;

import 'package:butlery/services/security/cert_pin_telemetry.dart';
import 'package:butlery/services/security/pinned_http_client.dart';

class PinnedHttpClientFactory {
  const PinnedHttpClientFactory._();

  /// Builds a [PinnedHttpClient] that wraps [inner]. When [inner] is null,
  /// the wrapper owns its underlying client and closes it on [Client.close].
  ///
  /// Pin-mismatches are reported via [reportSslPinMismatch] (best-effort
  /// analytics). The wrapped request still throws — soft-fail does not mean
  /// accepting an unverified cert.
  static http.Client create({http.Client? inner}) {
    return PinnedHttpClient(
      inner: inner,
      onPinMismatch: reportSslPinMismatch,
    );
  }
}
