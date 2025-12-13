import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Normalizes URLs for consistent cache keys.
///
/// Handles:
/// - Stripping tracking parameters (utm_*, fbclid, gclid, ref, etc.)
/// - Removing www. prefix
/// - Lowercasing host
/// - Sorting query parameters
/// - Removing trailing slashes
/// - Generating SHA256 hash for cache key
class UrlNormalizer {
  /// Tracking parameters to strip from URLs
  static const _trackingParams = {
    // Google Analytics
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    // Facebook
    'fbclid',
    'fb_action_ids',
    'fb_action_types',
    'fb_source',
    // Google Ads
    'gclid',
    'gclsrc',
    // Microsoft/Bing
    'msclkid',
    // Mailchimp
    'mc_cid',
    'mc_eid',
    // Other common tracking
    'ref',
    'source',
    'referrer',
    'tracking_id',
    '_ga',
    '_gid',
    'hsCtaTracking',
    'mkt_tok',
    'trk',
    'trkCampaign',
  };

  /// URL schemes that should be converted to https
  static const _httpSchemes = {'http', 'https'};

  /// Normalize a URL for cache lookup
  ///
  /// Returns a normalized URL string suitable for comparison.
  /// Returns null if the URL is invalid.
  String? normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }

    // Must have a valid host
    if (uri.host.isEmpty) return null;

    // Only normalize http/https URLs
    if (!_httpSchemes.contains(uri.scheme.toLowerCase())) {
      return null;
    }

    // Normalize host: lowercase and remove www. prefix
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }

    // Filter out tracking parameters and sort remaining
    final cleanParams = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      if (!_trackingParams.contains(lowerKey)) {
        cleanParams[key] = value;
      }
    });

    // Sort parameters alphabetically by key
    final sortedParams = Map.fromEntries(
      cleanParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    // Normalize path: remove trailing slash (but keep root /)
    var path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Rebuild URL with normalized components
    final normalized = Uri(
      scheme: 'https', // Always use https for consistency
      host: host,
      port: uri.port != 80 && uri.port != 443 ? uri.port : null,
      path: path,
      queryParameters: sortedParams.isEmpty ? null : sortedParams,
      fragment: null, // Remove fragments
    );

    return normalized.toString();
  }

  /// Generate SHA256 hash of normalized URL for cache key
  ///
  /// Returns null if URL cannot be normalized.
  String? hash(String url) {
    final normalized = normalize(url);
    if (normalized == null) return null;

    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  /// Check if a string looks like a URL
  bool looksLikeUrl(String input) {
    final trimmed = input.trim().toLowerCase();

    // Quick checks for common URL patterns
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }

    // Check for domain-like patterns (e.g., "ica.se/recept/...")
    final domainPattern = RegExp(
      r'^[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*(?:/.*)?$',
      caseSensitive: false,
    );
    return domainPattern.hasMatch(trimmed);
  }

  /// Extract domain from URL
  ///
  /// Returns null if URL is invalid.
  String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.host.isEmpty) return null;

      var host = uri.host.toLowerCase();
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host;
    } catch (_) {
      return null;
    }
  }
}
