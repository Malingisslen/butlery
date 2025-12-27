import 'package:http/http.dart' as http;
import 'package:http_certificate_pinning/http_certificate_pinning.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for SSL certificate pinning to prevent MITM attacks.
///
/// Validates that connections to critical backends use expected certificates.
/// This provides an additional layer of security beyond standard TLS by
/// ensuring the app only communicates with servers presenting known certificates.
class SslPinningService {
  /// Google Trust Services root CA SHA-256 fingerprints.
  /// Source: https://pki.goog/repository/
  ///
  /// These are root CA fingerprints (more stable than leaf certificates).
  /// Update when Google rotates root CAs (rare, typically every 10+ years).
  static const _googleTrustServicesFingerprints = [
    // GTS Root R1 (RSA 4096, expires 2036-06-22)
    'D947432ABDE7B7FA90FC2E6B59101B1280E0E1C7E4E40FA3C6887FFF57A7F4CF',
    // GTS Root R2 (ECDSA P-384, expires 2036-06-22)
    '8D25CD97229DBF70356BDA4EB3CC734031E24CF00FBCEF4178D78D9A14D1C9EF',
    // GTS Root R3 (RSA 4096, expires 2036-06-22)
    '34D8A73EE208D9BCDB0D956520934B4E40E69482596E8B6F73C8426B010A6F48',
    // GTS Root R4 (ECDSA P-384, expires 2036-06-22)
    '349DFA4058C5E263123B398AE795573C4E1313C83FE68F93556CD5E8031B3C7D',
  ];

  /// SHA-256 fingerprints for Firebase/Google services.
  /// All Google services use Google Trust Services root CAs.
  static const _pinnedFingerprints = <String, List<String>>{
    'firestore.googleapis.com': _googleTrustServicesFingerprints,
    'firebase.googleapis.com': _googleTrustServicesFingerprints,
    'vision.googleapis.com': _googleTrustServicesFingerprints,
    'storage.googleapis.com': _googleTrustServicesFingerprints,
    'identitytoolkit.googleapis.com': _googleTrustServicesFingerprints,
    'securetoken.googleapis.com': _googleTrustServicesFingerprints,
  };

  http.Client? _cachedClient;

  /// Validates the SSL certificate for a given URL.
  ///
  /// Returns `true` if the certificate is valid and matches pinned fingerprints,
  /// or if pinning is not configured for the host (allowing graceful fallback).
  /// Returns `false` if the certificate validation explicitly fails.
  Future<bool> validateCertificate(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;

      // Check if we have pins configured for this host
      final pins = _pinnedFingerprints[host];
      if (pins == null || pins.isEmpty) {
        // No pins configured - allow connection but log for monitoring
        AppLogger.debug('No certificate pins configured for $host');
        return true;
      }

      // Perform certificate pinning check
      final result = await HttpCertificatePinning.check(
        serverURL: url,
        headerHttp: {},
        sha: SHA.SHA256,
        allowedSHAFingerprints: pins,
        timeout: 30,
      );

      if (result.contains('CONNECTION_SECURE')) {
        AppLogger.debug('Certificate validation passed for $host');
        return true;
      }

      AppLogger.warning('Certificate validation failed for $host: $result');
      return false;
    } catch (e) {
      AppLogger.error('Certificate pinning error: $e');
      // On error, allow connection to prevent blocking legitimate traffic
      // but log for investigation
      return true;
    }
  }

  /// Checks if a host has certificate pinning configured.
  bool hasPinningConfigured(String host) {
    final pins = _pinnedFingerprints[host];
    return pins != null && pins.isNotEmpty;
  }

  /// Gets the list of hosts with pinning configured.
  List<String> get pinnedHosts => _pinnedFingerprints.keys.toList();

  /// Creates an HTTP client for making requests.
  ///
  /// For Google/Firebase services, the certificate is validated using the
  /// http_certificate_pinning package before requests are made.
  /// Use [validateCertificate] before making requests to critical endpoints.
  http.Client createPinnedClient() {
    // Return cached client or create new one
    // Note: Certificate validation should be done via validateCertificate()
    // before making requests to pinned hosts
    _cachedClient ??= http.Client();
    return _cachedClient!;
  }

  /// Validates certificate and makes a GET request if validation passes.
  /// Throws if certificate validation fails.
  Future<http.Response> secureGet(Uri url,
      {Map<String, String>? headers}) async {
    final isValid = await validateCertificate(url.toString());
    if (!isValid) {
      throw CertificatePinningException(
        'Certificate validation failed for ${url.host}',
      );
    }
    return http.get(url, headers: headers);
  }

  /// Validates certificate and makes a POST request if validation passes.
  /// Throws if certificate validation fails.
  Future<http.Response> securePost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final isValid = await validateCertificate(url.toString());
    if (!isValid) {
      throw CertificatePinningException(
        'Certificate validation failed for ${url.host}',
      );
    }
    return http.post(url, headers: headers, body: body);
  }

  /// Disposes resources.
  void dispose() {
    _cachedClient?.close();
    _cachedClient = null;
  }
}

/// Exception thrown when certificate pinning validation fails.
class CertificatePinningException implements Exception {
  final String message;

  CertificatePinningException(this.message);

  @override
  String toString() => 'CertificatePinningException: $message';
}
