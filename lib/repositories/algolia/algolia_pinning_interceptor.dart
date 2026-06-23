/// Per-host-aware Dio interceptor for SSL certificate pinning on Algolia
/// HTTPS calls (BUT-427).
///
/// **Why this lives next to [AlgoliaSearchRepository] instead of in
/// `lib/services/security/`:** `dio` is a transitive dependency of the
/// `algoliasearch` SDK — it is not a top-level dependency of the app. Keeping
/// the dio-typed interceptor in the same package as Algolia keeps the
/// transitive coupling local. The http-client equivalent for non-Algolia
/// pinning surfaces lives at `lib/services/security/pinned_http_client.dart`.
///
/// **Why we need our own:** the package's `CertificatePinningInterceptor`
/// supports only a single static fingerprint list, which doesn't fit Algolia
/// (read host = `*-dsn.algolia.net`, write host = `*.algolia.net`, retries
/// shuffle three `*.algolianet.com` hosts). This interceptor reads pins from
/// `CertPinConfig` per request URL.
///
/// **Soft-fail telemetry:** mismatches log the `ssl_pin_mismatch` analytics
/// event and reject the request as a `DioException` (caller treats it as a
/// network error). Hosts without configured pins fall through to the platform
/// trust store.
// ignore_for_file: depend_on_referenced_packages — dio is the algoliasearch
// SDK's transport layer and only used here as an Algolia integration glue.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/security/cert_pin_config.dart';
import 'package:butlery/services/security/pinned_http_client.dart'
    show PinCheckFn, PinMismatchTelemetry;

class PinningDioInterceptor extends Interceptor {
  final PinCheckFn _pinCheck;
  final PinMismatchTelemetry? _onPinMismatch;
  final Map<String, List<String>> _pinOverrides;

  /// iOS Alamofire serialization guard, keyed by host. Each host serializes
  /// independently — a single shared field would race under concurrent Dio
  /// requests (BUT-736): request A's `finally` would clobber request B's
  /// reference and silently disable the guard for any subsequent request C.
  final Map<String, Future<String>> _inflightByHost = {};

  PinningDioInterceptor({
    PinCheckFn? pinCheck,
    PinMismatchTelemetry? onPinMismatch,
    Map<String, List<String>>? pinOverrides,
  }) : _pinCheck = pinCheck ?? _defaultPinCheck,
       _onPinMismatch = onPinMismatch,
       _pinOverrides = pinOverrides ?? const <String, List<String>>{};

  List<String> _pinsFor(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    final override = _pinOverrides[normalized];
    if (override != null) return override;
    return CertPinConfig.pinsForHost(normalized);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final fullUrl = _resolveFullUrl(options);
    Uri uri;
    try {
      uri = Uri.parse(fullUrl);
    } catch (_) {
      return handler.next(options);
    }

    final host = uri.host.toLowerCase();
    final pins = _pinsFor(host);
    if (pins.isEmpty) {
      // No pins configured — fall through to platform trust store.
      return handler.next(options);
    }

    if (uri.scheme.toLowerCase() != 'https') {
      _onPinMismatch?.call(host, 'non_https_pinned_host', null);
      return handler.reject(
        DioException(
          requestOptions: options,
          error: const CertificateNotVerifiedException(),
        ),
      );
    }

    try {
      // Wait for any in-flight check on the SAME host before issuing a new
      // one — Alamofire on iOS rejects parallel pin checks against the same
      // host. Different hosts proceed concurrently.
      if (Platform.isIOS) {
        final pending = _inflightByHost[host];
        if (pending != null) {
          await pending;
        }
      }
    } on UnsupportedError {
      // Non-mobile platforms (web/desktop) — ignore.
    }

    String checkResult;
    final pinFuture = _pinCheck(
      serverURL: fullUrl,
      headerHttp: const <String, String>{},
      sha: SHA.SHA256,
      allowedSHAFingerprints: pins,
      timeout: 50,
    );
    _inflightByHost[host] = pinFuture;
    try {
      checkResult = await pinFuture;
    } on PlatformException catch (e) {
      if (e.code == 'NO_INTERNET') {
        return handler.reject(
          DioException.connectionError(
            requestOptions: options,
            reason: 'NO_INTERNET',
          ),
        );
      }
      AppLogger.warning(
        'PinningDioInterceptor: pin check platform error for $host: $e',
      );
      _onPinMismatch?.call(host, 'check_failed', e);
      return handler.reject(
        DioException(
          requestOptions: options,
          error: CertificateCouldNotBeVerifiedException(e),
        ),
      );
    } catch (e) {
      AppLogger.warning(
        'PinningDioInterceptor: pin check failed for $host: $e — failing closed',
      );
      _onPinMismatch?.call(host, 'check_failed', e);
      return handler.reject(
        DioException(
          requestOptions: options,
          error: CertificateCouldNotBeVerifiedException(
            e is Exception ? e : Exception(e.toString()),
          ),
        ),
      );
    } finally {
      // Only clear the entry if it still points to *this* request's future.
      // A later concurrent request to the same host may have replaced it
      // already; clobbering would re-introduce the BUT-736 race.
      if (identical(_inflightByHost[host], pinFuture)) {
        _inflightByHost.remove(host);
      }
    }

    if (!checkResult.contains('CONNECTION_SECURE')) {
      AppLogger.warning(
        'PinningDioInterceptor: pin mismatch for $host (result=$checkResult)',
      );
      _onPinMismatch?.call(host, 'mismatch', null);
      return handler.reject(
        DioException(
          requestOptions: options,
          error: const CertificateNotVerifiedException(),
        ),
      );
    }

    return handler.next(options);
  }

  /// Resolve the absolute URL Dio will hit. The library composes baseUrl +
  /// path, but absolute paths or `path` already containing a scheme override
  /// the base — mirror that to compute the host correctly.
  String _resolveFullUrl(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = options.baseUrl;
    if (base.isEmpty) return path;
    if (base.endsWith('/') && path.startsWith('/')) {
      return '${base.substring(0, base.length - 1)}$path';
    }
    if (!base.endsWith('/') && !path.startsWith('/') && path.isNotEmpty) {
      return '$base/$path';
    }
    return '$base$path';
  }
}

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
